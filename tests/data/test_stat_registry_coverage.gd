extends GutTest
## Lesson "no decorative stat": every stat of data/config/stats.json names the test that verifies its effect
## (`tests/...::test_x`, docs/02_FORMULAS.md §11) and that test must exist as a file and a function.
##
## Formulas of closed milestones (CLOSED_FORMULAS) must already have their test. For the others the missing tests are
## reported as pending with the reason; M6-07 turns that into an error. A reference that already exists passes.
## The registry is read through the public API (GameData.stats, StatRegistry.info), test sources are read as text.

const TESTS_PREFIX: String = "tests/"
const RES_PREFIX: String = "res://"
const SEPARATOR: String = "::"
const TEST_FUNC_PREFIX: String = "test_"
# Formulas whose milestone is closed (M1): F-02 skill xp, F-03 interval, F-06 double, F-07 shard, F-10 mastery,
# F-16 bank capacity; M3: F-08 preservation. A milestone that closes adds its formulas here.
const CLOSED_FORMULAS: Array[String] = ["F-02", "F-03", "F-06", "F-07", "F-08", "F-10", "F-16"]
# The stats whose effect M1 delivers: they must be covered by the closed formulas above.
const M1_STATS: Array[StringName] = [
	&"skill_interval_pct", &"skill_xp_pct", &"mastery_xp_pct", &"double_item_chance", &"rift_shard_chance",
	&"bank_slots",
]
# Formula -> milestone that implements it (for the pending messages).
const FORMULA_MILESTONES: Dictionary[String, String] = {
	"F-20": "M4", "F-21": "M4", "F-22": "M4", "F-25": "M4", "F-26": "M4", "F-27": "M4",
	"F-29": "M4", "F-30": "M4", "F-31": "M4", "F-33": "M4", "F-50": "M10", "F-51": "M11",
	# Armory and rarity (M4); block_chance is delivered with the combat engine (M5).
	"F-75": "M5", "F-82": "M4", "F-83": "M4",
	# auto_loot: its formula field is "10.6" (docs/01_GDD.md §10.6, loot bag).
	"10.6": "M4",
}

var _registry: StatRegistry = null
var _sources: Dictionary[String, String] = {}


func before_all() -> void:
	_registry = TestFactory.real_data().stats


func test_registry_is_not_empty() -> void:
	assert_gt(_registry.ids().size(), 0)


func test_every_reference_is_well_formed() -> void:
	for stat: StringName in _registry.ids():
		var ref: String = str(_registry.info(stat)["test"])
		var parts: PackedStringArray = ref.split(SEPARATOR)
		assert_eq(parts.size(), 2, "%s: '%s' is path::function" % [stat, ref])
		if parts.size() != 2:
			continue
		assert_true(parts[0].begins_with(TESTS_PREFIX), "%s: test under tests/" % stat)
		assert_true(parts[0].get_file().begins_with(TEST_FUNC_PREFIX) and parts[0].ends_with(".gd"),
				"%s: GUT file test_*.gd" % stat)
		assert_true(parts[1].begins_with(TEST_FUNC_PREFIX), "%s: GUT function test_*" % stat)


func test_every_stat_has_a_formula_with_a_milestone() -> void:
	for stat: StringName in _registry.ids():
		var formula: String = str(_registry.info(stat)["formula"])
		assert_true(CLOSED_FORMULAS.has(formula) or FORMULA_MILESTONES.has(formula),
				"%s: formula '%s' is neither closed nor planned (update this test)" % [stat, formula])


func test_m1_stats_belong_to_closed_formulas() -> void:
	for stat: StringName in M1_STATS:
		assert_true(_registry.has(stat), "%s registered" % stat)
		if _registry.has(stat):
			assert_true(CLOSED_FORMULAS.has(str(_registry.info(stat)["formula"])), "%s in a closed formula" % stat)


func test_stats_of_closed_milestones_have_their_test() -> void:
	var checked: int = 0
	for stat: StringName in _registry.ids():
		var info: Dictionary = _registry.info(stat)
		if not CLOSED_FORMULAS.has(str(info["formula"])):
			continue
		var ref: String = str(info["test"])
		assert_true(_reference_exists(ref), "%s (%s): test %s exists" % [stat, info["formula"], ref])
		checked += 1
	assert_gte(checked, M1_STATS.size(), "at least the M1 stats are checked")


func test_stats_of_open_milestones() -> void:
	var missing: PackedStringArray = []
	for stat: StringName in _registry.ids():
		var info: Dictionary = _registry.info(stat)
		var formula: String = str(info["formula"])
		if CLOSED_FORMULAS.has(formula):
			continue
		var ref: String = str(info["test"])
		if not _reference_exists(ref):
			missing.append("%s (%s, %s)" % [stat, formula, FORMULA_MILESTONES.get(formula, "?")])
	if missing.is_empty():
		pass_test("every stat of an open milestone already has its test")
		return
	pending("%d stat tests of open milestones not written yet, error from M6-07: %s"
			% [missing.size(), "; ".join(missing)])


func test_the_check_finds_a_missing_function() -> void:
	# Guard for the checker itself: an existing file with a missing function and a missing file are both rejected.
	assert_true(_reference_exists("tests/systems/bank/test_bank.gd::test_capacity_uses_bank_slots"))
	assert_false(_reference_exists("tests/systems/bank/test_bank.gd::test_does_not_exist"))
	assert_false(_reference_exists("tests/systems/nothing/test_nothing.gd::test_capacity_uses_bank_slots"))
	assert_false(_reference_exists("tests/systems/bank/test_bank.gd::test_capacity_uses_bank"), "whole name only")


# True when `path::function` names an existing file under res:// that declares `func function(`.
func _reference_exists(ref: String) -> bool:
	var parts: PackedStringArray = ref.split(SEPARATOR)
	if parts.size() != 2:
		return false
	var source: String = _source(RES_PREFIX + parts[0])
	if source.is_empty():
		return false
	var regex: RegEx = RegEx.create_from_string("(?m)^func\\s+%s\\s*\\(" % parts[1])
	return regex.search(source) != null


func _source(path: String) -> String:
	if not _sources.has(path):
		_sources[path] = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	return _sources[path]
