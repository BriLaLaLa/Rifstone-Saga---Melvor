extends GutTest
## Integration (M2-05): long Forestry gathering through the runner with a fixed seed → mastery pool → node purchases →
## the interval changes by the expected amount; pool spent on an action → new mastery level and F-11 bonus.
## Model only (session.mastery), no UI.
##
## The long run (21 h of cut_redbirch, real data) is done once in before_all through `session.advance`; its save is the
## starting point of the other tests (`from_save` of a new session: same state and same rng). Where a test needs more
## pool than 21 h give, it raises the pool in a copy of that save, like test_mastery_panel_smoke.gd: preparing the
## state is allowed, the "gathering → pool" part always comes from the runner.
##
## Where the numbers come from (real data; F-xx of docs/02_FORMULAS.md):
## - cut_redbirch: interval 3000 ms, 10 XP; 21 h = 75 600 000 ms = 25 200 cycles, lane at elapsed 0 at the end.
## - F-02: no skill_xp_pct → 252 000 XP → F-01 level 62.
## - F-10/F-12 per cycle, t = 3, R = (L + 7) / 792 (the other 7 Forestry actions stay at mastery level 1):
##   mxp = floor(3 × (1 + 0.1 L + 3 R)), pool += round(mxp × 0.2). Summed over 25 200 cycles (test_expected_numbers_
##   follow_the_formulas recomputes them): mastery xp 625 318 → F-09 level 85 (613 515 ≤ xp < 673 832), pool 125 671.
## - F-13: 8 actions × 300 000 = 2 400 000. F-15: n1 5% → 120 000; n2, n3 7.5% → 180 000; n4, n5 10% → 240 000;
##   n6 20% → 480 000 (total 1 440 000).
## - F-03: n1 skill_interval_pct −3 → round(3000 × 0.97) = 2910, cut_ashpine round(3200 × 0.97) = 3104; n1 + n6 −8 →
##   2760. In 1 h at 2910 ms: floor(3 600 000 / 2910) = 1237 cycles, elapsed 3 600 000 − 1237 × 2910 = 330.
## - F-10 at L 85 uses the base interval: floor(3 × (1 + 8.5 + 3 × 92/792)) = floor(29.55) = 29 with every node;
##   with n5 (mastery_xp_pct +5): floor(29.55 × 1.05) = floor(31.02) = 31.
## - F-14 on cut_ashpine (xp 0): 5000 → level 30 (4584 ≤ 5000 < 5017), F-11 double_item_chance floor(30/10) = 3;
##   cut_redbirch 625 318 → 99 needs 2 296 551 − 625 318 = 1 671 233; F-11 at 99: 9 + 5 = 14.

const SEED: int = 20261103
const SKILL: StringName = &"forestry"
const ACTION: StringName = &"cut_redbirch"
const OTHER_ACTION: StringName = &"cut_ashpine"
const OTHER_SKILL_ACTION: StringName = &"quarry_emberbronze"
const LOG_ITEM: StringName = &"redbirch_log"
const SHARD: StringName = &"rift_shard"
const N1: StringName = &"forestry_n1_quick_axe"
const N2: StringName = &"forestry_n2_keen_eye"
const N3: StringName = &"forestry_n3_lore"
const N4: StringName = &"forestry_n4_rift_bark"
const N5: StringName = &"forestry_n5_patience"
const N6: StringName = &"forestry_n6_master"
const HOUR_MS: int = 3600000
const RUN_HOURS: int = 21
const BASE_INTERVAL_MS: int = 3000
const EXPECTED_CYCLES: int = 25200
const EXPECTED_SKILL_XP: int = 252000
const EXPECTED_SKILL_LEVEL: int = 62
const EXPECTED_MASTERY_XP: int = 625318
const EXPECTED_MASTERY_LEVEL: int = 85
const EXPECTED_POOL: int = 125671
const EXPECTED_POOL_CAP: int = 2400000
const NODE_COSTS: Dictionary[StringName, int] = {
	N1: 120000, N2: 180000, N3: 180000, N4: 240000, N5: 240000, N6: 480000,
}
const INTERVAL_AFTER_N1: int = 2910
const OTHER_INTERVAL_AFTER_N1: int = 3104
const INTERVAL_AFTER_N1_N6: int = 2760
const CYCLES_PER_HOUR_AFTER_N1: int = 1237
const ELAPSED_AFTER_HOUR_N1: int = 330
const MXP_AT_85: int = 29
const MXP_AT_85_WITH_N5: int = 31
const MASTERY_XP_MAX: int = 2296551

static var _plain_data: GameData = null

var _long_run_save: Dictionary = {}
var _long_run: Dictionary = {}
var _session: GameSession = null
var _completed: int = 0
var _logs_out: int = 0
var _shards_out: int = 0
var _mastery_gains: Array[int] = []
var _mastery_level_ups: Array[int] = []
var _pool_changes: Array[int] = []
var _purchases: Array[StringName] = []


## The real data without the forestry milestones (M12): this file is about the pool and the nodes, with the fixed numbers of
## the comments above; the milestones are tested in tests/systems/mastery/test_mastery_milestones.gd.
static func _data() -> GameData:
	if _plain_data == null:
		_plain_data = GameData.load_from_dirs()
		TestFactory.without_mastery_steps(_plain_data)  # M14: the numbers below are derived without the F-122 steps
		for action: ActionDef in _plain_data.actions_for_skill(SKILL):
			action.milestones.clear()
	return _plain_data


func before_all() -> void:
	before_each()
	var session: GameSession = TestFactory.session_no_kit(SEED, _data())
	_connect(session)
	session.actions.enqueue(SKILL, ACTION, 1, true)
	var started_ms: int = Time.get_ticks_msec()
	for hour: int in RUN_HOURS:
		session.advance(HOUR_MS)
	var mastery_sum: int = 0
	for amount: int in _mastery_gains:
		mastery_sum += amount
	_long_run = {
		"run_ms": Time.get_ticks_msec() - started_ms, "cycles": _completed, "logs_out": _logs_out,
		"shards_out": _shards_out, "mastery_sum": mastery_sum, "levels": _mastery_level_ups.duplicate(),
		"last_pool": _pool_changes[-1] if not _pool_changes.is_empty() else -1,
		"logs": session.bank.get_count(LOG_ITEM), "shards": session.bank.get_count(SHARD),
	}
	_long_run_save = session.to_save(0)
	session.free()
	gut.p("mastery flow: %d cycles of gathering in %d ms" % [_completed, int(_long_run["run_ms"])])


func before_each() -> void:
	_completed = 0
	_logs_out = 0
	_shards_out = 0
	_mastery_gains.clear()
	_mastery_level_ups.clear()
	_pool_changes.clear()
	_purchases.clear()
	_session = null


func after_each() -> void:
	if _session != null:
		_session.free()
	_session = null


func test_expected_numbers_follow_the_formulas() -> void:
	var data: GameData = _data()
	var table: XpTable = data.mastery_table()
	var base_factor: float = float(data.balance_value("mastery.base_factor"))
	var per_level: float = float(data.balance_value("mastery.per_level"))
	var ratio_weight: float = float(data.balance_value("mastery.ratio_weight"))
	var share_pct: float = float(data.balance_value("mastery.pool_share_pct"))
	var action_count: int = data.mastery_actions_for_skill(SKILL).size()
	var t: float = float(data.action(ACTION).interval_ms) / 1000.0
	var xp: int = 0
	var pool: int = 0
	for cycle: int in EXPECTED_CYCLES:
		var level: int = table.level_for_xp(xp)
		var ratio: float = float(level + action_count - 1) / float(table.max_level * action_count)
		var mxp: int = maxi(1, floori(t * (base_factor + per_level * level + ratio_weight * ratio)))
		xp = mini(xp + mxp, table.xp_for_level(table.max_level))
		pool += roundi(mxp * share_pct / 100.0)
	assert_eq(xp, EXPECTED_MASTERY_XP, "F-10 summed over the run")
	assert_eq(table.level_for_xp(xp), EXPECTED_MASTERY_LEVEL, "F-09")
	assert_eq(pool, EXPECTED_POOL, "F-12 summed over the run (below the cap)")
	assert_eq(data.action(ACTION).interval_ms, BASE_INTERVAL_MS)
	assert_eq(EXPECTED_CYCLES * BASE_INTERVAL_MS, RUN_HOURS * HOUR_MS)
	assert_eq(data.xp_table().level_for_xp(EXPECTED_SKILL_XP), EXPECTED_SKILL_LEVEL, "F-01")
	assert_eq(table.xp_for_level(table.max_level), MASTERY_XP_MAX)
	assert_eq(MasteryMath.pool_cap(action_count, int(data.balance_value("mastery.pool_cap_per_item"))),
			EXPECTED_POOL_CAP, "F-13")
	var ratio_85: float = float(EXPECTED_MASTERY_LEVEL + action_count - 1) / float(table.max_level * action_count)
	assert_eq(MasteryMath.mastery_xp(BASE_INTERVAL_MS, EXPECTED_MASTERY_LEVEL, ratio_85, 0.0, data), MXP_AT_85)
	assert_eq(MasteryMath.mastery_xp(BASE_INTERVAL_MS, EXPECTED_MASTERY_LEVEL, ratio_85, 5.0, data), MXP_AT_85_WITH_N5)
















# Mastery levels from..to, both included, as the typed array the signal handlers fill.
func _levels(from: int, to: int) -> Array[int]:
	var result: Array[int] = []
	for level: int in range(from, to + 1):
		result.append(level)
	return result


func _restore(save: Dictionary) -> GameSession:
	var session: GameSession = TestFactory.session_no_kit(SEED, _data())
	var result: CommandResult = session.from_save(save.duplicate(true))
	assert_true(result.ok, "from_save of the long run")
	_connect(session)
	return session


func _connect(session: GameSession) -> void:
	session.events.action_completed.connect(_on_action_completed)
	session.events.mastery_xp_gained.connect(_on_mastery_xp_gained)
	session.events.mastery_level_up.connect(_on_mastery_level_up)
	session.events.mastery_pool_changed.connect(_on_mastery_pool_changed)
	session.events.mastery_node_purchased.connect(_on_mastery_node_purchased)


# Copy of the long-run save with the Forestry pool raised to `pool` (state preparation only).
func _with_pool(pool: int) -> Dictionary:
	var save: Dictionary = _long_run_save.duplicate(true)
	var modules: Dictionary = save["modules"]
	var mastery: Dictionary = modules["mastery"]
	var forestry: Dictionary = mastery[String(SKILL)]
	forestry["pool"] = pool
	return save


func _has_source(stat: StringName, ctx: ModifierContext, source: StringName) -> bool:
	for entry: Dictionary in _session.modifiers.breakdown(stat, ctx):
		if StringName(str(entry["source"])) == source:
			return true
	return false


func _on_action_completed(_lane: StringName, _skill_id: StringName, _action_id: StringName,
		outputs: Dictionary) -> void:
	_completed += 1
	_logs_out += int(outputs.get(LOG_ITEM, 0))
	_shards_out += int(outputs.get(SHARD, 0))


func _on_mastery_xp_gained(_skill_id: StringName, _action_id: StringName, amount: int) -> void:
	_mastery_gains.append(amount)


func _on_mastery_level_up(_skill_id: StringName, _action_id: StringName, new_level: int) -> void:
	_mastery_level_ups.append(new_level)


func _on_mastery_pool_changed(_skill_id: StringName, pool_xp: int) -> void:
	_pool_changes.append(pool_xp)


func _on_mastery_node_purchased(_skill_id: StringName, node_id: StringName) -> void:
	_purchases.append(node_id)
