extends GutTest
## Integration: new game on the real data, 60 s of Forestry (cut_redbirch, T1) through `advance`, expected XP,
## items and mastery with a fixed seed.
##
## Where the numbers come from (real data, no modifiers in a new game):
## - cut_redbirch: interval 3000 ms, 10 XP, 1 redbirch_log (data/actions/forestry.json = 02_FORMULAS.md §8.1 T1).
## - F-03: skill_interval_pct = 0 → 3000 ms, so 60 000 ms = 20 cycles, the lane at elapsed 0 after the 20th.
## - F-02: skill_xp_pct = 0 → 10 XP per cycle → 200 XP. F-01: xp_for_level(3) = 155 ≤ 200 < xp_for_level(4) = 255
##   → level 3; level 2 is reached at cycle 7 (70 XP), level 3 at cycle 16 (160 XP ≥ 155).
## - F-06: double_item_chance = 0 (F-11: mastery level < 10) → never doubled → exactly 20 logs.
## - F-07: 0.5% shard chance per cycle: random, checked as an invariant (shards in the bank = shards in the outputs).
## - F-09 (base 20, growth 1.1, linear 4): mastery xp_for_level 2 = 20, 3 = 46, 4 = 78.
## - F-10 with t = 3, R = Σ mastery levels of the 8 Forestry actions / (99 × 8):
##   L 1: floor(3 × (1 + 0.1 + 3 × 8/792))  = floor(3.39) = 3  (cycles 1-7  → 21 xp, level 2)
##   L 2: floor(3 × (1 + 0.2 + 3 × 9/792))  = floor(3.70) = 3  (cycles 8-16 → 48 xp, level 3)
##   L 3: floor(3 × (1 + 0.3 + 3 × 10/792)) = floor(4.01) = 4  (cycles 17-20 → 64 xp, level 3)
## - F-12: pool gain round(3 × 0.2) = round(4 × 0.2) = 1 per cycle → pool 20.
## - Gold unchanged (start.gold), play_time_ms = 60 000.

const SEED: int = 20261103
const SKILL: StringName = &"forestry"
const ACTION: StringName = &"cut_redbirch"
const LOG_ITEM: StringName = &"redbirch_log"
const SHARD: StringName = &"rift_shard"
const RUN_MS: int = 60000
const TICK_MS: int = 100
const EXPECTED_INTERVAL_MS: int = 3000
const EXPECTED_CYCLES: int = 20
const EXPECTED_XP: int = 200
const EXPECTED_LEVEL: int = 3
const EXPECTED_MASTERY_XP: int = 64
const EXPECTED_MASTERY_LEVEL: int = 3
const EXPECTED_POOL: int = 20

var _session: GameSession = null
var _completed: Array[Dictionary] = []
var _xp_gained: int = 0
var _level_ups: Array[int] = []
var _mastery_gained: int = 0
var _mastery_level_ups: Array[int] = []
var _stops: Array[StringName] = []


func before_each() -> void:
	_completed.clear()
	_xp_gained = 0
	_level_ups.clear()
	_mastery_gained = 0
	_mastery_level_ups.clear()
	_stops.clear()
	_session = _new_session(SEED)


func after_each() -> void:
	_session.free()
	_session = null


func test_new_game_starts_idle_and_empty() -> void:
	assert_false(_session.actions.is_running())
	assert_eq(_session.skills.get_xp(SKILL), 0)
	assert_eq(_session.skills.get_level(SKILL), 1)
	assert_eq(_session.bank.used(), _start_items().size(), "the bank starts empty (no kit)")
	assert_eq(_session.wallet.get_gold(), int(_session.data.balance_value("start.gold")))
	assert_eq(_session.actions.current_interval_ms(ACTION), EXPECTED_INTERVAL_MS, "F-03 with no modifiers")


func test_sixty_seconds_of_forestry_in_ticks() -> void:
	assert_true(_session.actions.start(SKILL, ACTION).ok)
	_advance_in_ticks(_session, RUN_MS)
	_assert_sixty_second_state(_session)


func test_signals_of_sixty_seconds_match_the_state() -> void:
	_session.actions.start(SKILL, ACTION)
	_advance_in_ticks(_session, RUN_MS)
	assert_eq(_completed.size(), EXPECTED_CYCLES, "one action_completed per cycle")
	for entry: Dictionary in _completed:
		assert_eq(entry["skill"], SKILL)
		assert_eq(entry["action"], ACTION)
	assert_eq(_xp_gained, EXPECTED_XP, "sum of xp_gained")
	assert_eq(_level_ups, [2, 3] as Array[int], "one level_up per level")
	assert_eq(_mastery_gained, EXPECTED_MASTERY_XP, "sum of mastery_xp_gained")
	assert_eq(_mastery_level_ups, [2, 3] as Array[int])
	assert_eq(_stops.size(), 0, "the lane never stops")


func test_level_up_cycles_follow_the_xp_table() -> void:
	_session.actions.start(SKILL, ACTION)
	# Cycle 6: 60 XP < 70 (level 1); cycle 7: 70 XP = xp_for_level(2).
	_advance_in_ticks(_session, 6 * EXPECTED_INTERVAL_MS)
	assert_eq(_session.skills.get_level(SKILL), 1)
	assert_eq(_session.mastery.get_mastery_xp(ACTION), 18, "6 cycles × 3")
	_advance_in_ticks(_session, EXPECTED_INTERVAL_MS)
	assert_eq(_session.skills.get_level(SKILL), 2)
	assert_eq(_session.mastery.get_mastery_level(ACTION), 2, "21 ≥ 20")
	# Cycle 15: 150 XP < 155; cycle 16: 160 XP.
	_advance_in_ticks(_session, 8 * EXPECTED_INTERVAL_MS)
	assert_eq(_session.skills.get_level(SKILL), 2)
	_advance_in_ticks(_session, EXPECTED_INTERVAL_MS)
	assert_eq(_session.skills.get_level(SKILL), 3)
	assert_eq(_session.mastery.get_mastery_xp(ACTION), 48, "7 × 3 + 9 × 3")


func test_expected_numbers_agree_with_the_tables() -> void:
	var xp_table: XpTable = _session.data.xp_table()
	assert_eq(xp_table.xp_for_level(2), 70)
	assert_eq(xp_table.xp_for_level(3), 155)
	assert_eq(xp_table.level_for_xp(EXPECTED_XP), EXPECTED_LEVEL)
	var mastery_table: XpTable = _session.data.mastery_table()
	assert_eq(mastery_table.xp_for_level(2), 20)
	assert_eq(mastery_table.xp_for_level(3), 46)
	assert_eq(mastery_table.level_for_xp(EXPECTED_MASTERY_XP), EXPECTED_MASTERY_LEVEL)
	var forestry_actions: int = _session.data.mastery_actions_for_skill(SKILL).size()
	assert_eq(forestry_actions, 8, "R of F-10 divides by 99 × 8")
	for level: int in [1, 2, 3]:
		var ratio: float = float(level + forestry_actions - 1) / float(99 * forestry_actions)
		var expected: int = 4 if level == 3 else 3
		assert_eq(MasteryMath.mastery_xp(EXPECTED_INTERVAL_MS, level, ratio, 0.0, _session.data), expected,
				"F-10 at mastery level %d" % level)


func test_one_big_step_equals_many_ticks() -> void:
	_session.actions.start(SKILL, ACTION)
	_session.advance(RUN_MS)
	var other: GameSession = _new_session(SEED)
	other.actions.start(SKILL, ACTION)
	_advance_in_ticks(other, RUN_MS)
	_assert_sixty_second_state(_session)
	assert_eq(SaveCodec.encode(_session.to_save(0)), SaveCodec.encode(other.to_save(0)), "same state, same rng")
	other.free()


func test_same_seed_same_run() -> void:
	_session.actions.start(SKILL, ACTION)
	_advance_in_ticks(_session, 10 * RUN_MS)
	var other: GameSession = _new_session(SEED)
	other.actions.start(SKILL, ACTION)
	_advance_in_ticks(other, 10 * RUN_MS)
	assert_eq(SaveCodec.encode(_session.to_save(0)), SaveCodec.encode(other.to_save(0)))
	other.free()


func test_play_time_counts_also_when_idle() -> void:
	_advance_in_ticks(_session, RUN_MS)
	assert_eq(_session.play_time_ms, RUN_MS)
	assert_eq(_session.skills.get_xp(SKILL), 0, "no action running: nothing gained")
	assert_eq(_session.bank.used(), _start_items().size())


func _assert_sixty_second_state(session: GameSession) -> void:
	assert_eq(session.skills.get_xp(SKILL), EXPECTED_XP, "20 cycles × 10 XP (F-02)")
	assert_eq(session.skills.get_level(SKILL), EXPECTED_LEVEL, "F-01")
	assert_eq(session.bank.get_count(LOG_ITEM), EXPECTED_CYCLES + _start_count(session, LOG_ITEM), "never doubled")
	assert_eq(session.mastery.get_mastery_xp(ACTION), EXPECTED_MASTERY_XP, "F-10: 7 × 3 + 9 × 3 + 4 × 4")
	assert_eq(session.mastery.get_mastery_level(ACTION), EXPECTED_MASTERY_LEVEL, "F-09")
	assert_eq(session.mastery.get_pool(SKILL), EXPECTED_POOL, "F-12: 1 per cycle")
	assert_eq(session.wallet.get_gold(), int(session.data.balance_value("start.gold")))
	assert_eq(session.play_time_ms, RUN_MS)
	assert_true(session.actions.is_running())
	assert_eq(int(session.actions.get_lane()["elapsed_ms"]), 0, "60 000 is a multiple of 3000")
	var shards_out: int = 0
	for entry: Dictionary in _completed:
		shards_out += int((entry["outputs"] as Dictionary).get(SHARD, 0))
	if session == _session:
		assert_eq(session.bank.get_count(SHARD) - _start_count(session, SHARD), shards_out,
				"shards in the bank = shards in the outputs (F-07)")
	# Other skills untouched.
	for skill: SkillDef in session.data.skills():
		if skill.id != SKILL:
			assert_eq(session.skills.get_xp(skill.id), 0, "%s untouched" % skill.id)


func _new_session(seed_value: int) -> GameSession:
	var session: GameSession = TestFactory.session_no_kit(seed_value, TestFactory.real_data())
	if _session == null:
		session.events.action_completed.connect(_on_action_completed)
		session.events.xp_gained.connect(_on_xp_gained)
		session.events.level_up.connect(_on_level_up)
		session.events.mastery_xp_gained.connect(_on_mastery_xp_gained)
		session.events.mastery_level_up.connect(_on_mastery_level_up)
		session.events.action_stopped.connect(_on_action_stopped)
	return session


func _advance_in_ticks(session: GameSession, ms: int) -> void:
	@warning_ignore("integer_division")
	var ticks: int = ms / TICK_MS
	for i: int in ticks:
		session.advance(TICK_MS)


# The starting kit is removed by TestFactory.session_no_kit (the kit has its own tests): the bank starts empty.
func _start_items() -> Array:
	return []


func _start_count(_session_arg: GameSession, _item_id: StringName) -> int:
	return 0


func _on_action_completed(_lane: StringName, skill_id: StringName, action_id: StringName,
		outputs: Dictionary) -> void:
	_completed.append({"skill": skill_id, "action": action_id, "outputs": outputs.duplicate()})


func _on_xp_gained(_skill_id: StringName, amount: int) -> void:
	_xp_gained += amount


func _on_level_up(_skill_id: StringName, new_level: int) -> void:
	_level_ups.append(new_level)


func _on_mastery_xp_gained(_skill_id: StringName, _action_id: StringName, amount: int) -> void:
	_mastery_gained += amount


func _on_mastery_level_up(_skill_id: StringName, _action_id: StringName, new_level: int) -> void:
	_mastery_level_ups.append(new_level)


func _on_action_stopped(_lane: StringName, _skill_id: StringName, reason: StringName) -> void:
	_stops.append(reason)
