extends GutTest
## M31-04: the touch-ups of the tutorial on a real session (real data, a real new game, fixed seeds, no helper that learns or equips):
## the 22 steps with the real combat (kills counted one by one, the wound, the meal, the pause with Ok, the forced node), the 20 starter
## quests and the final bonus by Mail; a save and a reload in the middle of the pause and of the forced node; a pre-M31 slot at 20/20.
## Helpers only where the goal is out of reach of a new game (buildings, Fracture, Dungeon, Engraver). docs/M31_RITOCCHI_TUTORIAL.md.

const Play := preload("res://tests/integration/test_tutorial_playthrough.gd")
const FractureUtil := preload("res://tests/systems/fractures/fracture_util.gd")
const AREA: StringName = &"redrock_plains"
const TICK_MS: int = 100
const MAX_TICKS: int = 60000
const SLOT_V11: String = "res://tests/fixtures/saves/slot_v11.json"

var _nodes_started: Array[Dictionary] = []
var _hp_at_eat: Array[Vector2i] = []
var _kills_signals: int = 0
var _money: int = 0


func _watch(s: GameSession) -> void:
	_nodes_started.clear()
	_hp_at_eat.clear()
	_kills_signals = 0
	s.events.node_started.connect(func(skill: StringName, _a: StringName, skipped: bool, _d: int) -> void:
		_nodes_started.append({"skill": skill, "skipped": skipped, "step": s.tutorial.current_step().id if s.tutorial.is_active() else &""}))
	s.events.player_hp_changed.connect(func(hp: int, max_hp: int) -> void:
		if s.tutorial.is_active() and s.tutorial.current_step().id == &"combat_eat":
			_hp_at_eat.append(Vector2i(hp, max_hp)))
	s.events.monster_killed.connect(func(...args: Array) -> void: _kills_signals += 1)


func _advance_until(s: GameSession, done: Callable, tick_ms: int = TICK_MS, max_ticks: int = MAX_TICKS) -> int:
	var ticks: int = 0
	while not done.call() and ticks < max_ticks:
		if not s.combat.is_active() and not s.combat.is_frozen():
			s.combat.start(AREA)
		s.advance(tick_ms)
		ticks += 1
	assert_lt(ticks, max_ticks, "reached in game time")
	return ticks


func _leave_step(s: GameSession) -> void:
	var index: int = s.tutorial.step_index()
	_advance_until(s, func() -> bool: return s.tutorial.step_index() != index)


## The player's action for the current step (the same as the playthrough test, the new steps included).
func _act(s: GameSession) -> void:
	var id: StringName = s.tutorial.current_step().id
	match id:
		&"equipment":
			for inst: ItemInstance in s.armory.instances():
				if inst.base_id == &"emberbronze_greatsword":
					assert_true(s.equipment.equip(inst.uid).ok)
		&"combat_start":
			assert_true(s.combat.start(AREA).ok)
		&"combat_kills", &"combat_eat", &"nodes":
			_leave_step(s)
		&"trainers":
			assert_true(s.disciplines.learn(&"forestry").ok)
		&"mail":
			for message: Dictionary in s.mail.messages():
				s.mail.collect(int(message["id"]))
		_:
			s.tutorial.notify_page_opened(s.tutorial.current_step().page)
			assert_true(s.tutorial.acknowledge().ok, "%s: Avanti/Ok" % id)


func _play_to(s: GameSession, stop_id: StringName) -> void:
	var guard: int = 0
	while s.tutorial.is_active() and s.tutorial.current_step().id != stop_id and guard < 40:
		_act(s)
		guard += 1
	assert_eq(s.tutorial.current_step().id, stop_id)


func _reload(old: GameSession) -> GameSession:
	var parsed: Variant = JSON.parse_string(JSON.stringify(old.to_save(1_700_000_000_000)))
	var events: GameEvents = GameEvents.new()
	var s: GameSession = GameSession.new(TestFactory.real_data(), events, 1)
	s.add_child(events)
	assert_true(s.from_save(SaveMigrator.migrate(parsed as Dictionary)).ok, "the slot loads")
	old.free()
	_watch(s)
	return s


## Steps 5 to 14 with the checks of M31, then the rest of the tutorial.
func _walk(s: GameSession) -> void:
	_watch(s)
	assert_eq(s.tutorial.step_count(), 22)
	_play_to(s, &"combat_kills")
	var progress_seen: Array[int] = []
	var step_5: int = s.tutorial.step_index()
	assert_eq(s.tutorial.step_progress_text().count("%d"), 2, "the label has two numbers")
	while s.tutorial.step_index() == step_5:
		_advance_until(s, func() -> bool: return s.tutorial.step_index() != step_5 or s.tutorial.step_progress() > (progress_seen.back() if not progress_seen.is_empty() else 0))
		if s.tutorial.step_index() == step_5:
			progress_seen.append(s.tutorial.step_progress())
	assert_eq(progress_seen, [1, 2], "the counter goes 1, 2, then the step ends at 3 (one per kill)")
	assert_gte(_kills_signals, 3)
	assert_eq(s.tutorial.current_step().id, &"combat_triangle")
	_act(s)
	# 7: the wound, then the meal (auto eat or Mangia)
	assert_eq(s.tutorial.current_step().id, &"combat_eat")
	var wound: int = s.tutorial.current_step().wound_hp_pct
	assert_gt(wound, 0)
	assert_false(s.combat.is_frozen(), "the combat runs while the character is hurt")
	_leave_step(s)
	assert_false(_hp_at_eat.is_empty(), "the hp changed while the step was current")
	var first: Vector2i = _hp_at_eat[0]
	assert_lte(first.x, ceili(first.y * wound / 100.0), "the wound brings the hp to the data percentage")
	assert_gte(first.x, 1)
	# 8: the combat is frozen in the model; nothing moves but the clock
	assert_eq(s.tutorial.current_step().id, &"combat_food")
	assert_true(s.combat.is_frozen())
	assert_true(s.tutorial.is_combat_frozen())
	assert_eq(s.tutorial.ack_text(), "Ok")
	var kills: Dictionary = s.combat.total_kills().duplicate()
	var rng_state: Variant = s.rng.to_save()
	var hp_signals: int = _hp_at_eat.size()
	var clock: int = s.play_time_ms
	s.advance(60_000)
	for _i: int in 50:
		s.advance(TICK_MS)
	assert_eq(s.rng.to_save(), rng_state, "no roll while frozen")
	assert_eq(s.combat.total_kills(), kills, "no kill while frozen")
	assert_eq(s.play_time_ms - clock, 60_000 + 50 * TICK_MS, "the play time goes on")
	assert_eq(s.tutorial.current_step().id, &"combat_food", "the pause waits for Ok, there is no valve")
	assert_false(s.tutorial.can_skip_step())
	assert_eq(_hp_at_eat.size(), hp_signals)
	assert_true(s.tutorial.acknowledge().ok, "Ok")
	assert_false(s.combat.is_frozen(), "Ok unfreezes")
	assert_eq(s.tutorial.current_step().id, &"bank")
	s.advance(3000)
	assert_ne(s.rng.to_save(), rng_state, "the combat runs again")
	_play_to(s, &"nodes")
	# 14: the forced node (the first trip after the entry is a node, worked, of the learned discipline)
	assert_true(s.combat.is_force_node())
	_nodes_started.clear()
	_leave_step(s)
	assert_false(_nodes_started.is_empty())
	assert_eq(_nodes_started[0]["skill"], &"forestry")
	assert_false(_nodes_started[0]["skipped"], "a worked node, not a skipped one")
	assert_false(s.combat.is_force_node(), "the flag goes out with the step")
	assert_eq(s.tutorial.current_step().id, &"village")
	_play_to(s, &"finish")
	_act(s)
	assert_true(s.tutorial.is_completed())
	assert_true(s.tutorial.starter.is_enabled())
	assert_false(s.combat.is_frozen())
	assert_false(s.combat.is_force_node())


func test_steps_5_to_14_with_the_real_combat_on_three_seeds() -> void:
	for seed_value: int in [3101, 3102, 3103]:
		var s: GameSession = Play.new_game_session(seed_value)
		_walk(s)
		s.free()


# ---- the quests and the final bonus ------------------------------------------------------------------------------------------------------

func _claim(s: GameSession, id: StringName) -> void:
	var st: StarterQuests = s.tutorial.starter
	assert_true(st.is_complete(id), "%s: the goal is true" % id)
	assert_eq(st.can_claim_final().reason, Reasons.QUEST_INCOMPLETE, "the bonus waits for all the quests")
	var gold: int = s.wallet.get_gold()
	assert_true(st.claim(id).ok, "%s: claim" % id)
	assert_true(s.mail.collect(int(s.mail.messages()[0]["id"])).ok, "%s: collect" % id)
	_money += s.wallet.get_gold() - gold


func _quests_part_one(s: GameSession) -> void:
	s.combat.stop()
	assert_true(s.loadout.set_trait(0, &"chain_cleave").ok)
	_claim(s, &"first_trait")
	assert_true(s.shop.sell(&"seared_brookfin", 1).ok)
	_claim(s, &"sell_first")
	_claim(s, &"learn_gathering")  # forestry was learned in the tutorial
	assert_true(s.disciplines.learn(&"forging").ok)
	_claim(s, &"learn_artisan")
	s.tutorial.notify_page_opened(&"guide")
	_claim(s, &"visit_guide")
	_advance_until(s, func() -> bool: return s.character.get_level() >= 3, 500, 400000)
	_claim(s, &"level_3")
	_advance_until(s, func() -> bool:
		return s.tutorial.starter.is_complete(&"beat_arcane") and s.tutorial.starter.is_complete(&"kills_25"))  # M32-05: the quest counts the kills after the tutorial, not the total (the new drops moved the RNG)
	_claim(s, &"kills_25")
	_claim(s, &"beat_arcane")
	if not s.tutorial.starter.is_complete(&"eat_once"):
		s.combat.eat()
	_claim(s, &"eat_once")
	_advance_until(s, func() -> bool: return s.character.get_level() >= 10, 500, 400000)
	_claim(s, &"level_10")
	_claim(s, &"mail_two")


## Out of reach of a new game: the buildings, the Fracture, the Dungeon, the Engraver (the same helpers as the starter flow test).
func _quests_part_two(s: GameSession) -> void:
	s.combat.stop()
	TestFactory.make_roomy(s)
	FractureUtil.hero(s)
	var cost: Dictionary = s.village.next_cost(&"noticeboard")
	s.wallet.add_gold(int(cost["gold"]))
	for row: Dictionary in cost["items"] as Array:
		TestFactory.give(s, row["item"] as StringName, int(row["qty"]))
	assert_true(s.village.upgrade(&"noticeboard").ok)
	_claim(s, &"first_building")
	var guard: int = 0
	while s.data.quest(s.quests.quest_at(0)).type != &"kill" and guard < 50:
		s.quests.abandon(0)
		guard += 1
	_advance_until(s, func() -> bool: return s.quests.is_complete(0), 500, 400000)
	assert_true(s.quests.claim(0).ok)
	_claim(s, &"noticeboard_claim")
	s.combat.stop()
	TestFactory.learn_engraver(s)
	var sockets: Array = s.data.balance_value("rift.sockets") as Array
	TestFactory.set_level(s, &"riftbinding", int((sockets[0] as Dictionary)["level"]))
	TestFactory.give(s, &"inf_swift_hands", 1)
	assert_true(s.rift.socket(0, &"inf_swift_hands").ok)
	_claim(s, &"first_infusion")
	TestFactory.set_level(s, &"forging", 10)
	TestFactory.teach_recipes(s, &"forging")
	TestFactory.give(s, &"emberbronze_ore", 100)
	assert_true(s.actions.enqueue(&"forging", &"smelt_emberbronze", 1, false).ok)
	var ticks: int = 0
	while s.actions.is_running() and ticks < 2000:
		s.advance(500)
		ticks += 1
	_claim(s, &"first_craft")
	var node: MasteryNodeDef = s.data.mastery_nodes(&"forestry")[0]
	s.mastery.from_save({"forestry": {"pool": 1_000_000, "actions": {}}})
	assert_true(s.mastery.buy_node(node.id).ok)
	_claim(s, &"mastery_node")
	s.village._levels[&"auction_house"] = 1
	s.village.rebuild_modifiers()
	s.wallet.add_gold(10_000_000)
	var bought: bool = false
	for item_id: StringName in s.auction.buyable_items():
		if s.auction.buy(item_id, 1).ok:
			bought = true
			break
	assert_true(bought)
	_claim(s, &"auction_buy")
	var uid: int = FractureUtil.card(s, 1)
	_claim(s, &"first_card")
	assert_true(s.fractures.open(uid).ok)
	FractureUtil.run_until(s, func() -> bool: return not s.combat.in_fracture(), 500)
	_claim(s, &"fracture_won")
	TestFactory.set_character_level(s, 55)
	s.bank.add(&"dungeon_ticket_monkey_den", 1)
	assert_true(s.dungeon.open(&"monkey_den").ok)
	var steps: int = 0
	while s.dungeon.is_active() and steps < 30000:
		var phase: StringName = s.dungeon.state()["phase"]
		if phase == &"await" or phase == &"event":
			assert_true(s.dungeon.choose(0).ok)
		else:
			s.advance(500)
		steps += 1
	_claim(s, &"dungeon_won")


func test_the_whole_path_22_steps_20_quests_and_the_final_bonus_by_mail() -> void:
	var s: GameSession = autofree(Play.new_game_session(3100))
	_walk(s)
	var st: StarterQuests = s.tutorial.starter
	assert_false(st.is_final_available())
	assert_eq(st.can_claim_final().reason, Reasons.QUEST_INCOMPLETE)
	_quests_part_one(s)
	_quests_part_two(s)
	assert_eq(st.claimed_count(), 20)
	assert_true(st.is_final_available())
	assert_true(st.can_claim_final().ok)
	var final: StarterFinalDef = st.final_reward()
	var xp_before: int = s.character.get_xp()
	var trout_before: int = s.bank.get_count(&"seared_brookfin")
	var mail_before: int = s.mail.count()
	assert_true(st.claim_final().ok)
	assert_eq(s.mail.count(), mail_before + 1, "the bonus is one Mail message")
	assert_eq(s.bank.get_count(&"seared_brookfin"), trout_before, "nothing before the Mail is collected")
	assert_eq(s.character.get_xp() - xp_before, final.reward_character_xp, "the xp is given at once")
	var message: Dictionary = s.mail.messages()[0]
	assert_eq(message["kind"], &"starter_reward")
	assert_true(s.mail.collect(int(message["id"])).ok)
	assert_eq(s.bank.get_count(&"pioneer_emblem"), 1)
	assert_eq(s.bank.get_count(&"seared_brookfin") - trout_before, 30)
	assert_true(st.is_final_claimed())
	assert_true(st.all_done())
	assert_false(st.is_final_available())
	assert_eq(st.can_claim_final().reason, Reasons.ALREADY_CLAIMED)
	assert_false(st.claim_final().ok)
	assert_eq(_money, 40800, "the 20 quests pay the scale of the GDD")


# ---- save and reload in the middle of the pause and of the forced node -------------------------------------------------------------------

func test_a_reload_in_the_middle_of_the_pause_resumes_frozen_with_ok() -> void:
	var s: GameSession = Play.new_game_session(3110)
	_watch(s)
	_play_to(s, &"combat_food")
	assert_true(s.combat.is_frozen())
	s.advance(30_000)
	var kills: Dictionary = s.combat.total_kills().duplicate()
	s = _reload(s)
	assert_eq(s.tutorial.current_step().id, &"combat_food")
	assert_true(s.combat.is_frozen(), "frozen again after the load (derived from the step)")
	var rng_state: Variant = s.rng.to_save()
	s.advance(60_000)
	assert_eq(s.rng.to_save(), rng_state)
	assert_eq(s.combat.total_kills(), kills)
	assert_true(s.tutorial.can_acknowledge())
	assert_true(s.tutorial.acknowledge().ok)
	assert_false(s.combat.is_frozen())
	_play_to(s, &"finish")
	s.free()


func test_a_reload_in_the_middle_of_the_forced_node_keeps_it_forced() -> void:
	var s: GameSession = Play.new_game_session(3111)
	_play_to(s, &"nodes")
	assert_true(s.combat.is_force_node())
	s = _reload(s)
	assert_eq(s.tutorial.current_step().id, &"nodes")
	assert_true(s.combat.is_force_node(), "forced again after the load")
	_nodes_started.clear()
	_leave_step(s)
	assert_false(_nodes_started.is_empty())
	assert_false(_nodes_started[0]["skipped"])
	assert_eq(_nodes_started[0]["skill"], &"forestry")
	assert_false(s.combat.is_force_node())
	_play_to(s, &"finish")
	_act(s)
	assert_true(s.tutorial.is_completed())
	s.free()


func test_a_reload_while_the_character_is_hurt_wounds_once_and_the_meal_comes() -> void:
	var s: GameSession = Play.new_game_session(3112)
	_play_to(s, &"combat_eat")
	s = _reload(s)
	assert_eq(s.tutorial.current_step().id, &"combat_eat")
	assert_false(s.combat.is_frozen())
	_leave_step(s)
	assert_eq(s.tutorial.current_step().id, &"combat_food")
	assert_true(s.combat.is_frozen())
	s.free()


# ---- a slot saved before M31 at 20/20 ---------------------------------------------------------------------------------------------------

func test_a_pre_m31_slot_at_20_of_20_shows_the_final_bonus_as_available() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SLOT_V11))
	var d: Dictionary = SaveMigrator.migrate(parsed as Dictionary)
	assert_eq(int(d["format_version"]), 12)
	var ids: Array = []
	for def: StarterQuestDef in TestFactory.real_data().starter_quests():
		ids.append(String(def.id))
	var tutorial: Dictionary = (d["modules"] as Dictionary)["tutorial"]
	tutorial["starter"] = {"claimed": ids, "progress": {}}  # as a v12 slot written before M31: no `final_claimed`
	var events: GameEvents = GameEvents.new()
	var s: GameSession = autofree(GameSession.new(TestFactory.real_data(), events, 1))
	s.add_child(events)
	assert_true(s.from_save(d).ok)
	var st: StarterQuests = s.tutorial.starter
	assert_eq(st.claimed_count(), 20)
	assert_true(st.is_final_available(), "the bonus is available")
	assert_false(st.is_final_claimed())
	assert_false(st.all_done())
	assert_true(st.can_claim_final().ok)
	s.mail.collect_all()
	for i: int in int(s.data.balance_value("mail.capacity")):
		s.mail.post(&"starter_reward", {"money": 1})
	assert_eq(st.can_claim_final().reason, Reasons.MAILBOX_FULL)
	assert_false(st.claim_final().ok)
