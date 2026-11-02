extends GutTest
## XpTable against 02_FORMULAS.md F-01 (skill curve) and F-09 (mastery curve).
## Curve parameters come from data/config/balance.json; the expected numbers are the F-01/F-09 examples.

const BALANCE_PATH: String = "res://data/config/balance.json"

## F-01 table: level -> total xp.
const SKILL_TOTALS: Dictionary[int, int] = {
	1: 0, 2: 70, 3: 155, 5: 372, 10: 1236, 20: 4941, 30: 13639, 40: 34011,
	50: 83388, 60: 206723, 70: 520603, 80: 1327438, 90: 3411599, 99: 8009532,
}

## F-09 table: level -> total xp.
const MASTERY_TOTALS: Dictionary[int, int] = {
	1: 0, 2: 20, 10: 412, 25: 2864, 50: 25825, 75: 241822, 99: 2296551,
}

var _skill: XpTable
var _mastery: XpTable
var _xp_cap: int = 0


func before_all() -> void:
	var balance: Dictionary = _load_balance()
	var xp_curve: Dictionary = balance["xp_curve"]
	_skill = _table_from(xp_curve)
	_mastery = _table_from(balance["mastery_curve"])
	_xp_cap = int(xp_curve["xp_cap"])


func test_skill_table_matches_f01() -> void:
	for level: int in SKILL_TOTALS:
		assert_eq(_skill.xp_for_level(level), SKILL_TOTALS[level], "F-01 xp_for_level(%d)" % level)


func test_mastery_table_matches_f09() -> void:
	for level: int in MASTERY_TOTALS:
		assert_eq(_mastery.xp_for_level(level), MASTERY_TOTALS[level], "F-09 xp_for_level(%d)" % level)


func test_max_level_from_params() -> void:
	assert_eq(_skill.max_level, 99)
	assert_eq(_mastery.max_level, 99)


func test_delta_examples() -> void:
	assert_eq(_skill.xp_to_next(1), 70)
	assert_eq(_skill.xp_to_next(2), 85)
	assert_eq(_skill.xp_to_next(10), 237)


func test_xp_to_next_is_zero_at_max_level() -> void:
	assert_eq(_skill.xp_to_next(99), 0)
	assert_eq(_mastery.xp_to_next(99), 0)


func test_xp_to_next_matches_totals() -> void:
	for level: int in range(1, _skill.max_level):
		assert_eq(_skill.xp_to_next(level), _skill.xp_for_level(level + 1) - _skill.xp_for_level(level))


func test_level_for_xp_edges() -> void:
	assert_eq(_skill.level_for_xp(0), 1)
	assert_eq(_skill.level_for_xp(69), 1)
	assert_eq(_skill.level_for_xp(70), 2)
	assert_eq(_skill.level_for_xp(154), 2)
	assert_eq(_skill.level_for_xp(155), 3)


func test_level_for_xp_negative_is_level_one() -> void:
	assert_eq(_skill.level_for_xp(-5), 1)


func test_level_for_xp_at_every_threshold() -> void:
	for level: int in range(2, _skill.max_level + 1):
		var total: int = _skill.xp_for_level(level)
		assert_eq(_skill.level_for_xp(total), level, "at threshold of %d" % level)
		assert_eq(_skill.level_for_xp(total - 1), level - 1, "just below threshold of %d" % level)


func test_level_for_xp_beyond_99() -> void:
	assert_eq(_skill.level_for_xp(8009532), 99)
	assert_eq(_skill.level_for_xp(8009531), 98)
	assert_eq(_skill.level_for_xp(50000000), 99)
	assert_eq(_skill.level_for_xp(_xp_cap), 99)


func test_mastery_level_for_xp_edges() -> void:
	assert_eq(_mastery.level_for_xp(19), 1)
	assert_eq(_mastery.level_for_xp(20), 2)
	assert_eq(_mastery.level_for_xp(2296551), 99)
	assert_eq(_mastery.level_for_xp(2296550), 98)


func test_xp_for_level_out_of_range_is_clamped() -> void:
	assert_eq(_skill.xp_for_level(0), 0)
	assert_eq(_skill.xp_for_level(120), 8009532)


func test_progress_within_level() -> void:
	assert_almost_eq(_skill.progress(0), 0.0, 0.000001)
	assert_almost_eq(_skill.progress(35), 0.5, 0.000001)
	assert_almost_eq(_skill.progress(69), 69.0 / 70.0, 0.000001)
	assert_almost_eq(_skill.progress(70), 0.0, 0.000001)
	assert_almost_eq(_skill.progress(70 + 17), 17.0 / 85.0, 0.000001)


func test_progress_is_one_at_max_level() -> void:
	assert_eq(_skill.progress(8009532), 1.0)
	assert_eq(_skill.progress(50000000), 1.0)
	assert_eq(_mastery.progress(2296551), 1.0)


func test_from_params_custom_curve() -> void:
	# Same class, different params (F-09 note): a flat curve gives totals 0, 10, 20.
	var flat: XpTable = XpTable.from_params(10.0, 1.0, 0.0, 3)
	assert_eq(flat.max_level, 3)
	assert_eq(flat.xp_for_level(2), 10)
	assert_eq(flat.xp_for_level(3), 20)
	assert_eq(flat.level_for_xp(25), 3)
	assert_almost_eq(flat.progress(15), 0.5, 0.000001)


func _table_from(curve: Dictionary) -> XpTable:
	return XpTable.from_params(float(curve["base"]), float(curve["growth"]), float(curve["linear"]),
			int(curve["max_level"]))


func _load_balance() -> Dictionary:
	var text: String = FileAccess.get_file_as_string(BALANCE_PATH)
	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed is Dictionary, "balance.json must parse to a Dictionary")
	if parsed is Dictionary:
		return parsed
	return {}
