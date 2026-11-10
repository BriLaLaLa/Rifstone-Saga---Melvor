extends GutTest
## Integration, Engraver chain (M12-08; F-104, F-105, F-106, F-107, 05 §5.22) on the real data and the real runner:
## drops from the loot tables of an area -> Fuse -> Crystallize (fixed seed) -> Engrave -> Upgrade up to grade V -> rune in
## the Altar socket with the effect of its grade. Also the order of the drops and the conservation of the items.
## Fixed seeds, sessions freed, no real slot.

const SEED: int = 120804
const AREA: StringName = &"redrock_plains"
const TABLE: StringName = &"loot_area_redrock_plains"
const SKILL: StringName = &"riftbinding"
const DUST: StringName = &"rift_dust"
const CHIP: StringName = &"stone_ember_chip"
const STONE: StringName = &"stone_ember_stone"
const HEART: StringName = &"stone_ember_heart"
const HERO: StringName = &"test:hero"
const TICK_MS: int = 500
const MAX_STEPS: int = 20000

var _s: GameSession = null
var _completed: Array[Dictionary] = []
var _stops: Array[StringName] = []


func after_each() -> void:
	if _s != null:
		_s.free()
	_s = null


# A private copy of the real data whose Roccarossa table drops dust and chips every time (the real chances are for hours).
func _drop_data() -> GameData:
	var data: GameData = GameData.load_from_dirs(TestFactory.REAL_CONTENT_ROOT, TestFactory.CONFIG_ROOT)
	assert_true(data.is_valid())
	var entries: Array[DropEntry] = []
	for pair: Array in [[DUST, 10], [CHIP, 3]]:
		var entry := DropEntry.new()
		entry.item_id = pair[0]
		entry.chance_pct = 100.0
		entry.qty_min = pair[1]
		entry.qty_max = pair[1]
		entries.append(entry)
	data.loot_table(TABLE).entries = entries
	return data


func _new(data: GameData = null) -> GameSession:
	if _s != null:
		_s.free()
	_s = TestFactory.session_no_kit(SEED, data if data != null else TestFactory.real_data())
	_completed = []
	_stops = []
	_s.events.action_completed.connect(func(_l: StringName, _k: StringName, a: StringName, o: Dictionary) -> void:
		_completed.append({"action": a, "outputs": o}))
	_s.events.action_stopped.connect(func(_l: StringName, _k: StringName, r: StringName) -> void: _stops.append(r))
	return _s


# Runs `action_id` until `cycles` cycles completed (or the runner stopped).
func _cycles(action_id: StringName, cycles: int) -> void:
	_completed = []
	assert_true(_s.actions.start(SKILL, action_id).ok, "start %s" % action_id)
	var steps: int = 0
	while _completed.size() < cycles and _s.actions.is_running() and steps < MAX_STEPS:
		_s.advance(TICK_MS)
		steps += 1
	_s.actions.stop()


func _kill_some(kills: int) -> int:
	_s.modifiers.set_source(HERO, [Modifier.make(&"power_bonus", 5000.0), Modifier.make(&"max_hp_flat", 100000.0), Modifier.make(&"auto_loot", 1.0)])
	var count: Array[int] = [0]
	_s.events.monster_killed.connect(func(_i: int, _m: StringName) -> void: count[0] += 1)
	assert_true(_s.combat.start(AREA).ok)
	var steps: int = 0
	while count[0] < kills and steps < MAX_STEPS:
		_s.advance(TICK_MS)
		steps += 1
	_s.combat.stop(Reasons.STOPPED_BY_USER)
	assert_gte(count[0], kills)
	return count[0]


func test_the_kills_drop_what_the_area_table_says_into_the_bank() -> void:
	_new(_drop_data())
	TestFactory.make_roomy(_s)
	var kills: int = _kill_some(6)
	assert_eq(_s.bank.get_count(DUST), 10 * kills, "10 dust per kill from the area table, none lost, none copied")
	assert_eq(_s.bank.get_count(CHIP), 3 * kills)
	assert_eq(_s.combat.loot.items().size(), 0, "auto loot: nothing left in the loot bag")


func test_fuse_turns_nine_chips_into_three_stones_and_a_heart_needs_three_stones() -> void:
	_new()
	TestFactory.set_level(_s, SKILL, 40)
	TestFactory.give(_s, CHIP, 11)
	_cycles(&"fuse_ember_stone", 3)
	assert_eq(_completed.size(), 3)
	assert_eq(_s.bank.get_count(STONE), 3, "F-105: 9 chips -> 3 stones")
	assert_eq(_s.bank.get_count(CHIP), 2, "the remaining 2 are not enough")
	assert_eq(_s.actions.start(SKILL, &"fuse_ember_stone").reason, Reasons.MISSING_INPUTS)
	_cycles(&"fuse_ember_heart", 1)
	assert_eq(_s.bank.get_count(HEART), 1, "3 stones -> 1 perfect stone")
	assert_eq(_s.bank.get_count(STONE), 0)
	assert_gt(_s.skills.get_xp(SKILL), 0)
	assert_gt(_s.mastery.get_mastery_xp(&"fuse_ember_stone"), 0)


func test_crystallize_with_a_fixed_seed_follows_f104_in_dust_xp_and_mastery() -> void:
	_new()
	TestFactory.set_level(_s, SKILL, 5)
	var xp_start: int = _s.skills.get_xp(SKILL)
	TestFactory.give(_s, DUST, 100)
	_completed = []
	assert_true(_s.actions.start(SKILL, &"crystallize_spark").ok)
	var steps: int = 0
	while _s.actions.is_running() and steps < MAX_STEPS:
		_s.advance(TICK_MS)
		steps += 1
	var action: ActionDef = _s.data.action(&"crystallize_spark")
	var n: int = action.inputs[0].qty
	var lost_on_fail: int = EngraverResolver.fail_loss(n, _s.data)
	assert_eq(lost_on_fail, 5, "F-104: N 10 -> 5 lost")
	var successes: int = _s.bank.get_count(&"currency_spark")
	var cycles: int = _completed.size()
	var failures: int = cycles - successes
	assert_gt(successes, 0, "seed %d: some succeed" % SEED)
	assert_gt(failures, 0, "seed %d: some fail" % SEED)
	assert_eq(_s.bank.get_count(DUST), 100 - successes * n - failures * lost_on_fail, "dust spent exactly")
	assert_eq(_stops.back(), Reasons.MISSING_INPUTS, "stops when fewer than N dust are left")
	assert_lt(_s.bank.get_count(DUST), n)
	var xp: int = _s.skills.get_xp(SKILL) - xp_start
	assert_eq(xp, successes * action.xp + failures * (action.xp * lost_on_fail / n), "full XP on success, floor(xp x lost / N) on failure")
	assert_gt(_s.mastery.get_mastery_xp(&"crystallize_spark"), 0, "mastery only from the successes")
	assert_almost_eq(EngraverResolver.crystal_chance_pct(5, _s.data), 40.0 + 50.0 * 4.0 / 98.0, 0.0001)


func test_the_same_seed_gives_the_same_crystals() -> void:
	var results: Array[int] = []
	for i: int in 2:
		_new()
		TestFactory.set_level(_s, SKILL, 5)
		TestFactory.give(_s, DUST, 100)
		assert_true(_s.actions.start(SKILL, &"crystallize_spark").ok)
		for step: int in 2000:
			_s.advance(TICK_MS)
		results.append(_s.bank.get_count(&"currency_spark"))
	assert_eq(results[0], results[1])


func test_engrave_then_upgrade_to_grade_five_is_a_pure_conversion_of_runes() -> void:
	_new()
	TestFactory.set_level(_s, SKILL, 30)
	TestFactory.give(_s, &"rune_slab", 1)
	TestFactory.give(_s, &"boar_tusk", 13)
	_cycles(&"engrave_swift_hands", 1)
	assert_eq(_s.bank.get_count(&"inf_swift_hands"), 1, "engraved from a slab and tusks")
	assert_eq(_s.bank.get_count(&"rune_slab"), 0)
	assert_eq(_s.bank.get_count(&"boar_tusk"), 0)
	TestFactory.give(_s, &"inf_swift_hands", 80)  # 81 grade I runes in all: 3^4
	var left: int = 81
	for grade: int in range(2, 6):
		var from_id: StringName = &"inf_swift_hands" if grade == 2 else StringName("inf_swift_hands_%d" % (grade - 1))
		var to_id: StringName = StringName("inf_swift_hands_%d" % grade)
		left /= 3
		_cycles(StringName("upgrade_swift_hands_%d" % grade), left)
		assert_eq(_s.bank.get_count(to_id), left, "grade %d: %d runes" % [grade, left])
		assert_eq(_s.bank.get_count(from_id), 0, "all the lower runes were consumed (F-106: 3 -> 1)")
	assert_eq(_s.bank.get_count(&"inf_swift_hands_5"), 1, "81 grade I -> one grade V")
	assert_eq(_s.actions.start(SKILL, &"upgrade_swift_hands_5").reason, Reasons.MISSING_INPUTS)
	for a: ActionDef in _s.data.actions_for_skill(SKILL):
		for input: ItemQty in a.inputs:
			assert_ne(input.item_id, &"inf_swift_hands_5", "grade V is never an upgrade input")


func test_the_upgrade_needs_the_level_of_the_rune_plus_five_per_step() -> void:
	_new()
	TestFactory.give(_s, &"inf_swift_hands", 3)
	var below: CommandResult = _s.actions.start(SKILL, &"upgrade_swift_hands_2")
	var action: ActionDef = _s.data.action(&"upgrade_swift_hands_2")
	assert_eq(action.level, 6, "F-106: level of the rune I (1) + 5")
	assert_eq(below.reason, Reasons.LEVEL_TOO_LOW)
	assert_eq(_s.bank.get_count(&"inf_swift_hands"), 3, "nothing spent")


func test_a_grade_v_rune_in_the_altar_has_five_times_the_effect_and_leaves_the_bank() -> void:
	_new()
	var forestry_base: int = _s.actions.current_interval_ms(&"cut_redbirch")
	var ctx: ModifierContext = ModifierContext.for_skill(&"forestry")
	for grade: int in range(1, 6):
		var id: StringName = &"inf_swift_hands" if grade == 1 else StringName("inf_swift_hands_%d" % grade)
		TestFactory.give(_s, id, 1)
		assert_true(_s.rift.socket(0, id).ok, "socket grade %d" % grade)
		assert_eq(_s.bank.get_count(id), 0, "one place: the Altar")
		assert_eq(_s.modifiers.total(&"skill_interval_pct", ctx), -3.0 * grade, "F-107: value x %d" % grade)
		assert_eq(_s.actions.current_interval_ms(&"cut_redbirch"), ActionMath.interval_ms(forestry_base, -3.0 * grade, 250))
		assert_true(_s.rift.clear_socket(0).ok)
	assert_eq(_s.modifiers.total(&"skill_interval_pct", ctx), 0.0, "cleared")
	assert_eq(_s.actions.current_interval_ms(&"cut_redbirch"), forestry_base)


func test_the_whole_chain_from_the_kills_to_the_altar_loses_and_creates_nothing() -> void:
	_new(_drop_data())
	TestFactory.make_roomy(_s)
	TestFactory.set_level(_s, SKILL, 40)
	var kills: int = _kill_some(8)
	var chips: int = _s.bank.get_count(CHIP)
	assert_eq(chips, 3 * kills)
	var batches: int = chips / 3
	_cycles(&"fuse_ember_stone", batches)
	assert_eq(_s.bank.get_count(STONE), batches)
	assert_eq(_s.bank.get_count(CHIP), chips - batches * 3, "chips: 3 per stone, the rest untouched")
	# The dust of the same kills feeds the Crystals: every cycle either pays N or the loss.
	var dust: int = _s.bank.get_count(DUST)
	assert_eq(dust, 10 * kills)
	_cycles(&"crystallize_spark", 1)
	var crystals: int = _s.bank.get_count(&"currency_spark")
	assert_eq(_s.bank.get_count(DUST), dust - (10 if crystals == 1 else 5))
