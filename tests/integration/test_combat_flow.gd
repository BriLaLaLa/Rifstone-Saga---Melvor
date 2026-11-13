extends GutTest
## Integration, combat flow (M5): sword + shield equipped -> fight in redrock_plains (kills, XP, gold, loot bag, parry
## with the shield) -> food (manual and automatic) -> death (only the loot bag is lost) -> save/load identical and
## the same continuation -> combat and main action replace each other. Also the conservation of items between the loot
## bag and the bank, and the equivalence of advance steps on the real data.
##
## Real data, fixed seeds, only public APIs (docs/05_INTERFACES.md 5.10, 6). No slot is written.

const SEED: int = 5150
const OTHER_SEED: int = 9
const SEED_BETWEEN: int = 6   # a seed where the unboosted character wins the first group (M13-06 changed the drops, hence the draws)
const NOW_MS: int = 1793603600000
const AREA: StringName = &"redrock_plains"
const SWORD: StringName = &"emberbronze_sword"
const SHIELD: StringName = &"emberbronze_shield"
const FOOD: StringName = &"seared_brookfin"
const FOOD_HEAL: int = 20
const LOOT_ITEM: StringName = &"boar_tusk"
const BOOST: StringName = &"test:flow"
const TIER: StringName = &"test:tier"
const SAMPLE_MS: int = 2400000
const STEP_MS: int = 1000
const BIG_HP: float = 100000.0

var _hits: Array[Array] = []
var _eaten: Array[Array] = []
var _lost: Array[Array] = []
var _killed: int = 0
var _called: int = 0  # M15: monsters called by the waves of the Rift Stones (killed, but no counted kills)
var _died: int = 0
var _stops: Array[StringName] = []


# A real-data session with the sword and the shield worn; `hp_flat` > 0 adds max_hp_flat (practically immortal).
func _geared(seed_value: int, hp_flat: float = 0.0) -> GameSession:
	var s: GameSession = autofree(TestFactory.session_no_kit(seed_value, TestFactory.real_data()))
	assert_true(s.equipment.equip(TestFactory.give_piece(s, SWORD)).ok)
	assert_true(s.equipment.equip(TestFactory.give_piece(s, SHIELD)).ok)
	var mods: Array[Modifier] = [Modifier.make(&"block_chance", 40.0)]
	if hp_flat > 0.0:
		mods.append(Modifier.make(&"max_hp_flat", hp_flat))
	s.modifiers.set_source(BOOST, mods)
	_hits = []
	_eaten = []
	_lost = []
	_killed = 0
	_called = 0
	_died = 0
	_stops = []
	s.events.combat_hit.connect(func(a: int, t: int, h: bool, d: int, b: bool) -> void: _hits.append([a, t, h, d, b]))
	s.events.food_eaten.connect(func(item: StringName, healed: int) -> void: _eaten.append([item, healed]))
	s.events.loot_lost.connect(func(item: StringName, qty: int) -> void: _lost.append([item, qty]))
	s.events.monster_killed.connect(func(_i: int, _m: StringName) -> void: _killed += 1)
	s.events.rift_stone_wave.connect(func(_id: StringName, _t: int, count: int) -> void: _called += count)
	s.events.player_died.connect(func() -> void: _died += 1)
	s.events.combat_stopped.connect(func(reason: StringName) -> void: _stops.append(reason))
	return s


func _run(s: GameSession, total_ms: int, step_ms: int = STEP_MS) -> void:
	for i: int in total_ms / step_ms:
		s.advance(step_ms)


func _hurt(s: GameSession, hp: int) -> void:
	var saved: Dictionary = s.combat.to_save()
	saved["player_hp"] = hp
	s.combat.from_save(saved)
	s.rebuild_modifiers()


func _tier(s: GameSession, tier: float, extra: Array[Modifier] = []) -> void:
	var mods: Array[Modifier] = [Modifier.make(&"auto_eat_tier", tier)]
	mods.append_array(extra)
	s.modifiers.set_source(TIER, mods)


func _count(s: GameSession, item: StringName) -> int:
	var in_bag: int = 0
	for entry: Dictionary in s.combat.loot.items():
		if entry["item"] == item:
			in_bag += int(entry["qty"])
	return s.bank.get_count(item) + in_bag


func _blob(s: GameSession) -> String:
	return SaveCodec.encode(s.to_save(NOW_MS))


# --- fight and parry -------------------------------------------------------------------------------------------

func test_fight_gives_xp_gold_loot_and_a_parry_that_does_no_damage() -> void:
	var s: GameSession = _geared(SEED, BIG_HP)
	assert_gt(s.combat.player_stats().block_chance, 40.0, "shield block + boost")
	assert_true(s.combat.start(AREA).ok)
	var xp_before: int = s.character.get_xp()
	var gold_before: int = s.wallet.get_gold()
	_run(s, SAMPLE_MS)
	assert_gt(_killed, 50, "many kills in 40 minutes")
	var total: int = 0
	for n: int in s.combat.total_kills().values():
		total += n
	# a defeated Rift Stone (M7-04) emits monster_killed but is not counted as a monster kill
	assert_between(_killed - total, 0, 3 + _called, "the counters match the monster_killed signals (less the stones and their called monsters)")
	assert_gt(s.character.get_xp(), xp_before, "F-28 xp")
	assert_gt(s.wallet.get_gold(), gold_before, "F-31 gold")
	assert_gt(s.combat.loot.items().size(), 0, "F-32 drops land in the loot bag")
	var enemy_hits: int = 0
	var parried: int = 0
	for h: Array in _hits:
		if int(h[0]) >= 0 and bool(h[2]):
			enemy_hits += 1
			if bool(h[4]):
				parried += 1
				assert_eq(h[3], 0, "a parried hit does 0 damage")
		if int(h[0]) < 0:
			assert_false(bool(h[4]), "the attacks of the player are never parried")
	assert_gt(enemy_hits, 50, "enough enemy hits")
	assert_gt(parried, 0, "the shield parried something")
	var rate: float = float(parried) / float(enemy_hits)
	assert_between(rate, 0.35, 0.55, "parry rate %.2f near the 45%% of the setup (cap 50%%)" % rate)
	assert_eq(s.combat.deaths(), 0)


func test_without_a_shield_nothing_is_parried() -> void:
	var s: GameSession = _geared(SEED, BIG_HP)
	assert_true(s.equipment.unequip(&"offhand").ok)
	assert_eq(s.combat.player_stats().block_chance, 0.0, "block_chance needs a shield in the offhand")
	s.combat.start(AREA)
	_run(s, 600000)
	assert_gt(_hits.size(), 50)
	for h: Array in _hits:
		assert_false(bool(h[4]), "no parry without a shield")


# --- items: one place only ---------------------------------------------------------------------------------------

func test_collect_all_moves_the_bag_to_the_bank_without_creating_or_losing_items() -> void:
	var s: GameSession = _geared(SEED, BIG_HP)
	s.combat.start(AREA)
	_run(s, 1200000)
	var bag: Array[Dictionary] = s.combat.loot.items()
	assert_gt(bag.size(), 0)
	var before: Dictionary = {}
	for entry: Dictionary in bag:
		before[entry["item"]] = _count(s, entry["item"])
	assert_true(s.combat.loot.collect_all().ok)
	assert_true(s.combat.loot.items().is_empty(), "the bag is empty")
	for item: StringName in before:
		assert_eq(_count(s, item), before[item], "%s: same total, now only in the bank" % item)
		assert_eq(s.bank.get_count(item), before[item])


func test_worn_pieces_exist_once_in_the_armory_through_a_fight() -> void:
	var s: GameSession = _geared(SEED, BIG_HP)
	var count: int = s.armory.instances().size()
	var weapon: int = s.equipment.get_uid(&"weapon")
	var offhand: int = s.equipment.get_uid(&"offhand")
	s.combat.start(AREA)
	_run(s, 600000)
	# piece drops (M7-03/M7-05) may add pieces; none may disappear
	assert_gte(s.armory.instances().size(), count, "no piece destroyed")
	assert_eq(s.equipment.get_uid(&"weapon"), weapon)
	assert_eq(s.equipment.get_uid(&"offhand"), offhand)
	assert_true(s.armory.is_worn(weapon) and s.armory.is_worn(offhand))


# --- food ------------------------------------------------------------------------------------------------------

func test_manual_and_automatic_food() -> void:
	var s: GameSession = _geared(SEED)
	TestFactory.give(s, FOOD, 10)
	assert_true(s.equipment.set_food(FOOD).ok)
	s.combat.start(AREA)
	_hurt(s, 10)
	assert_true(s.combat.eat().ok)
	assert_eq(int(s.combat.get_state()["player_hp"]), 10 + FOOD_HEAL)
	assert_eq(s.bank.get_count(FOOD), 9)
	assert_eq(s.combat.food_eaten(), 1)
	assert_eq(_eaten.size(), 1, "one food_eaten, emitted by AutoEat only")
	assert_eq(_eaten[0], [FOOD, FOOD_HEAL] as Array)
	# Automatic: tier 1 eats under the threshold after a hit taken.
	_hurt(s, 25)   # rebuild_modifiers() drops the test sources: set the tier afterwards
	_tier(s, 1.0)
	var guard: int = 0
	while s.combat.food_eaten() < 2 and s.combat.deaths() == 0 and guard < 3000:
		s.advance(STEP_MS)
		guard += 1
	assert_gte(s.combat.food_eaten(), 2, "auto-eat ate after a hit")
	assert_eq(s.bank.get_count(FOOD), 10 - s.combat.food_eaten(), "the counter equals the pieces taken from the bank")
	assert_eq(_eaten.size(), s.combat.food_eaten(), "one food_eaten signal per piece")


# --- death -----------------------------------------------------------------------------------------------------

func test_death_loses_only_the_loot_bag() -> void:
	var s: GameSession = _geared(SEED)
	TestFactory.give(s, &"redbirch_log", 7)
	s.wallet.add_gold(40)
	var weapon: int = s.equipment.get_uid(&"weapon")
	var offhand: int = s.equipment.get_uid(&"offhand")
	s.combat.start(AREA)
	assert_true(s.combat.loot.add(LOOT_ITEM, 4))
	var gold: int = s.wallet.get_gold()
	_hurt(s, 1)
	var guard: int = 0
	while s.combat.deaths() == 0 and guard < 5000:
		s.advance(STEP_MS)
		guard += 1
	assert_eq(s.combat.deaths(), 1)
	assert_eq(_died, 1)
	assert_eq(_stops, [Reasons.PLAYER_DIED] as Array[StringName])
	assert_eq(s.combat.state(), CombatEngine.STATE_IDLE)
	assert_true(s.combat.loot.items().is_empty(), "the bag is lost")
	var lost_qty: int = 0
	for l: Array in _lost:
		if l[0] == LOOT_ITEM:
			lost_qty += int(l[1])
	assert_gte(lost_qty, 4, "loot_lost reports the bag")
	assert_eq(s.bank.get_count(&"redbirch_log"), 7, "the bank is untouched")
	assert_gte(s.wallet.get_gold(), gold, "gold is kept")
	assert_eq(s.equipment.get_uid(&"weapon"), weapon, "worn pieces are kept")
	assert_eq(s.equipment.get_uid(&"offhand"), offhand)
	assert_eq(int(s.combat.get_state()["player_hp"]), s.combat.player_stats().max_hp, "hp back to the maximum")
	assert_false(s.combat.is_active())
	assert_eq(s.combat.area_id(), &"", "idle has no area (05 5.10)")
	assert_eq(String(s.combat.to_save()["area"]), "", "nor in the save")
	assert_true(s.combat.start(AREA).ok, "a new start after the death works")


# --- save / load -------------------------------------------------------------------------------------------------

func test_save_load_in_the_middle_of_a_fight_is_identical_and_continues_identically() -> void:
	var a: GameSession = _geared(SEED)
	a.modifiers.set_source(BOOST, [] as Array[Modifier])   # only saved state: test sources are not in the save
	TestFactory.set_character_level(a, 40)
	TestFactory.give(a, FOOD, 200)  # M17-04: packs of up to 8 monsters eat more
	a.equipment.set_food(FOOD)
	a.wallet.add_gold(2000)
	assert_true(a.shop.buy(&"auto_eat_1").ok)
	a.combat.start(AREA)
	_run(a, 400000)
	a.combat.loot.add(LOOT_ITEM, 2)
	var saved: Dictionary = a.to_save(NOW_MS)
	assert_true((saved["modules"] as Dictionary).has(String(CombatEngine.SAVE_KEY)), "the combat has its own key")
	var text: String = SaveCodec.encode(saved)
	var b: GameSession = autofree(TestFactory.session_no_kit(OTHER_SEED, TestFactory.real_data()))
	assert_true(b.from_save(SaveCodec.decode(text)).ok)
	assert_eq(_blob(b), text, "identical byte for byte")
	assert_eq(b.combat.state(), a.combat.state())
	assert_eq(b.combat.get_state(), a.combat.get_state())
	_run(a, 600000)
	_run(b, 600000)
	assert_eq(_blob(b), _blob(a), "same state after going on")
	assert_eq(b.rng.to_save(), a.rng.to_save())


func test_state_between_encounters_survives_a_save() -> void:
	var a: GameSession = _geared(SEED_BETWEEN)
	a.modifiers.set_source(BOOST, [] as Array[Modifier])   # test sources are not in the save
	a.combat.start(AREA)
	var guard: int = 0
	while a.combat.state() != CombatEngine.STATE_BETWEEN and guard < 5000:
		a.advance(100)
		guard += 1
	assert_eq(a.combat.state(), CombatEngine.STATE_BETWEEN)
	var b: GameSession = autofree(TestFactory.session_no_kit(OTHER_SEED, TestFactory.real_data()))
	assert_true(b.from_save(SaveCodec.decode(_blob(a))).ok)
	assert_eq(b.combat.state(), CombatEngine.STATE_BETWEEN)
	assert_eq(int(b.combat.get_state()["between_ms"]), int(a.combat.get_state()["between_ms"]))
	_run(a, 30000, 100)
	_run(b, 30000, 100)
	assert_eq(_blob(b), _blob(a))


# --- equivalence on the real data ---------------------------------------------------------------------------------

func test_advance_steps_are_equivalent_with_a_shield_and_food() -> void:
	var sessions: Array[GameSession] = []
	for i: int in 3:
		var s: GameSession = _geared(SEED + 1, BIG_HP)
		TestFactory.give(s, FOOD, 20)
		s.equipment.set_food(FOOD)
		_tier(s, 2.0)
		s.combat.start(AREA)
		sessions.append(s)
	_run(sessions[0], 900000, 1000)
	_run(sessions[1], 900000, 100)
	_run(sessions[2], 900000, 900000)
	var first: String = _blob(sessions[0])
	assert_eq(_blob(sessions[1]), first, "advance(1000) x N = advance(100) x 10N")
	assert_eq(_blob(sessions[2]), first, "one big advance gives the same state")


# --- combat and actions replace each other -------------------------------------------------------------------------

func test_combat_and_main_action_replace_each_other() -> void:
	var s: GameSession = _geared(SEED)
	assert_true(s.actions.start(&"forestry", &"cut_redbirch").ok)
	_run(s, 10000)
	assert_true(s.combat.start(AREA).ok)
	assert_false(s.actions.is_running(), "combat stops the main action")
	assert_true(s.actions.stop_reasons_log().has(Reasons.REPLACED))
	_run(s, 30000)
	assert_true(s.actions.start(&"forestry", &"cut_redbirch").ok)
	assert_false(s.combat.is_active(), "an action stops the combat")
	assert_eq(s.combat.stop_reasons_log().back(), Reasons.REPLACED)
	assert_eq(String(s.combat.get_state()["area"]), "", "idle has no area (05 5.10)")
	assert_eq(int(s.combat.get_state()["player_hp"]), s.combat.player_stats().max_hp, "idle shows the full hp")
	_run(s, 10000)
	assert_true(s.actions.is_running())
	assert_true(s.combat.start(AREA).ok, "and back to the combat")
	assert_eq(s.combat.start(&"nowhere").reason, Reasons.UNKNOWN_ID)
	assert_true(s.combat.is_active(), "a failed start changes nothing")
