extends GutTest
## M30-05: the 20 starter quests on a real session (real data, tutorial completed): for each one a path with real events (the model's own
## commands, never `emit`), then `claim` -> a Mail message -> `collect`. The quests reachable with the starting state (1-7, 9-10, 19-20) are done
## with no helper; the others use only the test helpers (`give`, `set_character_level`, buildings set from the model, hero modifiers).
## The sum collected is the scale of docs/01_GDD_M30.md §41.6 (docs/05_INTERFACES_M30.md §5.42).

const Play := preload("res://tests/integration/test_tutorial_playthrough.gd")
const FractureUtil := preload("res://tests/systems/fractures/fracture_util.gd")
const AREA: StringName = &"redrock_plains"
const TICK_MS: int = 500
const MAX_TICKS: int = 400000
const TOTAL_MONEY: int = 40800
const TOTAL_XP: int = 250

var _s: GameSession = null
var _money: int = 0
var _items: Dictionary[StringName, int] = {}
var _xp_base: int = 0
var _announced: Array[StringName] = []
var _changed: int = 0


func after_each() -> void:
	if is_instance_valid(_s):
		_s.free()
	_s = null


func _open_session(seed_value: int) -> void:
	_s = Play.new_game_session(seed_value)
	_s.tutorial.from_save({"completed": true, "step": "", "visited": []})  # the factory's way to end the tutorial
	_s.events.starter_quest_completed.connect(func(id: StringName) -> void: _announced.append(id))
	_s.events.starter_quests_changed.connect(func() -> void: _changed += 1)


func _quest(id: StringName) -> StarterQuestDef:
	return _s.data.starter_quest(id)


## Claims a quest that must be complete, checks the Mail and collects the message. Adds to the totals.
func _claim(id: StringName) -> void:
	var st: StarterQuests = _s.tutorial.starter
	var def: StarterQuestDef = _quest(id)
	assert_true(st.is_complete(id), "%s: the goal is true" % id)
	assert_false(st.is_claimed(id))
	assert_true(st.claimable().any(func(d: StarterQuestDef) -> bool: return d.id == id), "%s is claimable" % id)
	var gold_before: int = _s.wallet.get_gold()
	var xp_before: int = _s.character.get_xp()
	var mail_before: int = _s.mail.count()
	assert_true(st.can_claim(id).ok)
	assert_true(st.claim(id).ok, "%s: claim" % id)
	assert_eq(_s.mail.count(), mail_before + 1, "%s: the reward is one Mail message" % id)
	assert_eq(_s.wallet.get_gold(), gold_before, "%s: nothing is paid before the Mail is collected" % id)
	_xp_base += _s.character.get_xp() - xp_before
	if def.reward_character_xp > 0:
		assert_gt(_s.character.get_xp(), xp_before, "%s: the xp is given at once" % id)
	assert_true(st.is_claimed(id))
	assert_eq(st.can_claim(id).reason, Reasons.ALREADY_CLAIMED, "%s: only once" % id)
	assert_false(st.claim(id).ok)
	var message: Dictionary = _s.mail.messages()[0]
	assert_eq(message["kind"], &"starter_reward")
	var bank_before: Dictionary[StringName, int] = {}
	for row: ItemQty in def.reward_items:
		bank_before[row.item_id] = _s.bank.get_count(row.item_id)
	assert_true(_s.mail.collect(int(message["id"])).ok, "%s: collect" % id)
	assert_eq(_s.wallet.get_gold() - gold_before, def.reward_money, "%s: the money arrives" % id)
	_money += _s.wallet.get_gold() - gold_before
	for row: ItemQty in def.reward_items:
		assert_eq(_s.bank.get_count(row.item_id) - int(bank_before[row.item_id]), row.qty, "%s: the items arrive" % id)
		_items[row.item_id] = int(_items.get(row.item_id, 0)) + row.qty


func _fight_until(done: Callable) -> void:
	var ticks: int = 0
	while not done.call() and ticks < MAX_TICKS:
		if not _s.combat.is_active():
			_s.combat.start(AREA)
		_s.advance(TICK_MS)
		ticks += 1
	assert_lt(ticks, MAX_TICKS, "reached by fighting")


func _kills_of(monster_id: StringName) -> int:
	return int(_s.combat.total_kills().get(monster_id, 0))


func _hero() -> void:
	FractureUtil.hero(_s)


## The quests of the starting state: no helper.
func _part_without_helpers() -> void:
	var st: StarterQuests = _s.tutorial.starter
	assert_true(st.is_enabled())
	assert_eq(st.claimed_count(), 0)
	assert_true(st.claimable().is_empty(), "nothing is claimable in a new game")
	# 1: the trait is set while the combat is stopped
	assert_true(_s.loadout.set_trait(0, &"chain_cleave").ok)
	_claim(&"first_trait")
	# 7: sell the first item
	assert_true(_s.shop.sell(&"seared_brookfin", 1).ok)
	_claim(&"sell_first")
	# 9, 10: the first grade of a Trainer is free
	assert_true(_s.disciplines.learn(&"forestry").ok)
	_claim(&"learn_gathering")
	assert_true(_s.disciplines.learn(&"forging").ok)
	_claim(&"learn_artisan")
	# 20: the Guide page is opened
	assert_false(st.is_complete(&"visit_guide"))
	_s.tutorial.notify_page_opened(&"guide")
	_claim(&"visit_guide")
	# 2-6: fighting in the Plains
	_fight_until(func() -> bool: return _s.character.get_level() >= 3)
	_claim(&"level_3")
	_s.combat.eat()
	_fight_until(func() -> bool: return _s.combat.food_eaten() >= 1 or _s.combat.total_kills().is_empty())
	_fight_until(func() -> bool: return _kills_of(&"ember_rat") >= 5 and _s.combat.total_kills().values().reduce(func(a: int, b: int) -> int: return a + b, 0) >= 25)
	_claim(&"kills_25")
	_claim(&"beat_arcane")
	if _s.tutorial.starter.is_complete(&"eat_once"):
		_claim(&"eat_once")
	else:
		_s.combat.eat()
		_claim(&"eat_once")
	_fight_until(func() -> bool: return _s.character.get_level() >= 10)
	_claim(&"level_10")
	# 19: two messages collected: they are the ones of the claims above
	_claim(&"mail_two")


func _part_with_helpers() -> void:
	var st: StarterQuests = _s.tutorial.starter
	_s.combat.stop()
	TestFactory.make_roomy(_s)
	_hero()
	# 13 + 14: the Notice Board is built (gold and items given), a kill quest is fought, claimed
	var cost: Dictionary = _s.village.next_cost(&"noticeboard")
	_s.wallet.add_gold(int(cost["gold"]))
	for row: Dictionary in cost["items"] as Array:
		TestFactory.give(_s, row["item"] as StringName, int(row["qty"]))
	assert_true(_s.village.upgrade(&"noticeboard").ok)
	_claim(&"first_building")
	assert_gt(_s.quests.slot_count(), 0, "the Notice Board gives a slot")
	var guard: int = 0
	while _s.data.quest(_s.quests.quest_at(0)).type != &"kill" and guard < 50:
		_s.quests.abandon(0)
		guard += 1
	assert_eq(_s.data.quest(_s.quests.quest_at(0)).type, &"kill", "a kill quest is in the slot")
	_changed = 0
	_fight_until(func() -> bool: return _s.quests.is_complete(0))
	assert_true(_s.quests.claim(0).ok, "the Notice Board quest is claimed")
	assert_eq(_s.quests.completed_total(), 1)
	assert_true(st.is_complete(&"noticeboard_claim"), "the measure reads the model")
	_claim(&"noticeboard_claim")
	_s.combat.stop()
	# 8: the Engraver learned, a rune in the Altar
	TestFactory.learn_engraver(_s)
	var sockets: Array = _s.data.balance_value("rift.sockets") as Array
	TestFactory.set_level(_s, &"riftbinding", int((sockets[0] as Dictionary)["level"]))
	assert_true(_s.rift.is_unlocked(0))
	TestFactory.give(_s, &"inf_swift_hands", 1)
	assert_true(_s.rift.socket(0, &"inf_swift_hands").ok)
	_claim(&"first_infusion")
	# 11: a production from the queue
	TestFactory.set_level(_s, &"forging", 10)
	TestFactory.teach_recipes(_s, &"forging")
	TestFactory.give(_s, &"emberbronze_ore", 100)
	assert_true(_s.actions.enqueue(&"forging", &"smelt_emberbronze", 1, false).ok)
	_fight_until_actions()
	_claim(&"first_craft")
	# M32: the Cucina (free place) and a meat recipe
	if not _s.disciplines.is_learned(&"hearthcraft"):
		assert_true(_s.disciplines.learn(&"hearthcraft").ok)
	TestFactory.give(_s, &"plains_haunch", 5)
	assert_true(_s.actions.enqueue(&"hearthcraft", &"cook_plains_haunch", 1, false).ok)
	_fight_until_actions()
	_claim(&"campfire_meal")
	# 12: a mastery node
	var node: MasteryNodeDef = _s.data.mastery_nodes(&"forestry")[0]
	var pools: Dictionary = {"forestry": {"pool": 1_000_000, "actions": {}}}
	_s.mastery.from_save(pools)
	assert_true(_s.mastery.buy_node(node.id).ok, "a node without requirement")
	_claim(&"mastery_node")
	# 15: the Auction House built, a purchase
	_s.village._levels[&"auction_house"] = 1
	_s.village.rebuild_modifiers()
	assert_true(_s.auction.is_open())
	_s.wallet.add_gold(10_000_000)
	var bought: bool = false
	for item_id: StringName in _s.auction.buyable_items():
		if _s.auction.buy(item_id, 1).ok:
			bought = true
			break
	assert_true(bought, "something is for sale")
	_claim(&"auction_buy")
	# 16, 17: a Card, a won Fracture
	var uid: int = FractureUtil.card(_s, 1)
	assert_gt(uid, 0)
	_claim(&"first_card")
	assert_true(_s.fractures.open(uid).ok)
	FractureUtil.run_until(_s, func() -> bool: return not _s.combat.in_fracture(), 500)
	assert_false(_s.fractures.is_active())
	_claim(&"fracture_won")
	# 18: the Monkey Den won
	TestFactory.set_character_level(_s, 55)
	_s.bank.add(&"dungeon_ticket_monkey_den", 1)
	assert_true(_s.dungeon.open(&"monkey_den").ok)
	var steps: int = 0
	while _s.dungeon.is_active() and steps < 30000:
		var phase: StringName = _s.dungeon.state()["phase"]
		if phase == &"await" or phase == &"event":
			assert_true(_s.dungeon.choose(0).ok)
		else:
			_s.advance(500)
		steps += 1
	assert_eq(_s.dungeon.wins(&"monkey_den"), 1)
	_claim(&"dungeon_won")


func _fight_until_actions() -> void:
	var ticks: int = 0
	while _s.actions.is_running() and ticks < 2000:
		_s.advance(TICK_MS)
		ticks += 1
	assert_lt(ticks, 2000, "the queue finished")


func test_every_starter_quest_is_reached_with_real_events_and_paid_by_mail() -> void:
	_open_session(3010)
	_part_without_helpers()
	_part_with_helpers()
	var st: StarterQuests = _s.tutorial.starter
	assert_eq(st.claimed_count(), 21, "all twenty-one are claimed")
	assert_null(st.next_open())
	assert_eq(_money, TOTAL_MONEY, "40.800 copper in total")
	assert_eq(_items.get(&"seared_brookfin", 0), 10)
	assert_eq(_items.get(&"rift_dust", 0), 10)
	assert_eq(_xp_base, TOTAL_XP, "250 xp in total (no xp bonus in the session)")


## BUG-M30-05-1: the metric `quests_completed` is reread on `quest_completed` (emitted when the Notice Board quest reaches its target), but
## `Quests.completed_total()` grows later, in `claim`: the starter module is never told that "noticeboard_claim" became true (no
## `starter_quest_completed`, no `starter_quests_changed`: the sidebar dot and the page stay stale). Pending until it is fixed.
func test_claiming_a_notice_board_quest_tells_the_starter_module() -> void:
	_open_session(3011)
	TestFactory.make_roomy(_s)
	_hero()
	var cost: Dictionary = _s.village.next_cost(&"noticeboard")
	_s.wallet.add_gold(int(cost["gold"]))
	for row: Dictionary in cost["items"] as Array:
		TestFactory.give(_s, row["item"] as StringName, int(row["qty"]))
	assert_true(_s.village.upgrade(&"noticeboard").ok)
	var guard: int = 0
	while _s.data.quest(_s.quests.quest_at(0)).type != &"kill" and guard < 50:
		_s.quests.abandon(0)
		guard += 1
	_fight_until(func() -> bool: return _s.quests.is_complete(0))
	_announced.clear()
	_changed = 0
	assert_true(_s.quests.claim(0).ok)
	assert_true(_s.tutorial.starter.is_complete(&"noticeboard_claim"), "read live, the measure is true")
	assert_true(_announced.has(&"noticeboard_claim"))
