extends GutTest
## Lesson "no decorative stat": every stat of data/config/stats.json names the test that verifies its effect
## (`tests/...::test_x`, docs/02_FORMULAS.md §11) and that test must exist as a file and a function.
##
## Formulas of closed milestones (CLOSED_FORMULAS) must already have their test. For the others the missing tests are
## checked too. Strict mode (M9-07, N10): no pending, every stat must name an existing test.
## The registry is read through the public API (GameData.stats, StatRegistry.info), test sources are read as text.

const TESTS_PREFIX: String = "tests/"
const RES_PREFIX: String = "res://"
const SEPARATOR: String = "::"
const TEST_FUNC_PREFIX: String = "test_"
# Formulas whose milestone is closed (M1): F-02 skill xp, F-03 interval, F-06 double, F-07 shard, F-10 mastery,
# F-16 bank capacity; M3: F-08 preservation; M4: F-82 Armory capacity, F-83 item rarity;
# M5: combat F-20..F-22, F-25..F-27, F-29..F-31, F-33, F-75 and 10.6 (auto_loot, GDD loot bag).
# M6: F-78..F-81 (loadout slots, ability cooldown and effect, trait effects): no registry stat uses them, the class data
# is checked below.
# M7: F-86 (refinement: upgrade_success_pct, tests/systems/armory/test_upgrade.gd), F-84 (drop rarity, item_rarity_pct:
# tests/systems/items/test_item_roller.gd::test_drop_rarity), F-87 (Rift Stones, tests/systems/combat/test_rift_stone.gd),
# F-85 (affixes, test_item_roller.gd::test_affix_rolls), F-88 (salvage, tests/systems/armory/test_salvage.gd): M7 closed (M7-07).
# A milestone that closes adds its formulas here.
const CLOSED_FORMULAS: Array[String] = [
	"F-02", "F-03", "F-06", "F-07", "F-08", "F-10", "F-16", "F-82", "F-83",
	"F-20", "F-21", "F-22", "F-25", "F-26", "F-27", "F-29", "F-30", "F-31", "F-33", "F-75", "10.6",
	"F-78", "F-79", "F-80", "F-81",
	"F-86", "F-84", "F-87", "F-85", "F-88",
]
# The stats whose effect M1 delivers: they must be covered by the closed formulas above.
const M1_STATS: Array[StringName] = [
	&"skill_interval_pct", &"skill_xp_pct", &"mastery_xp_pct", &"double_item_chance", &"rift_shard_chance",
]
# Formula -> milestone that implements it (for the pending messages).
const FORMULA_MILESTONES: Dictionary[String, String] = {"F-50": "M13"}

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


func test_combat_stat_effects_through_player_stats() -> void:
	# The "test" in stats.json of the 9 player stats of F-20..F-22 and F-25..F-27: each one reaches the player through
	# the modifiers (public API: modifiers -> CombatantStats) with the value of CombatMath.
	var data: GameData = TestFactory.real_data()
	var session: GameSession = autofree(TestFactory.session(7, data))
	# M10: a new game wears the starting kit; the cases below expect the bare character of the formulas.
	for slot: StringName in [&"weapon", &"offhand"]:
		session.equipment.unequip(slot)
	var base: CombatantStats = CombatantStats.for_player(session)
	var cases: Array = [
		[&"accuracy_bonus", 20.0, &"accuracy", CombatMath.accuracy_rating(1, 20.0, 0.0, data)],
		[&"accuracy_pct", 10.0, &"accuracy", CombatMath.accuracy_rating(1, 0.0, 10.0, data)],
		[&"power_bonus", 20.0, &"max_hit", CombatMath.max_hit(1, 20.0, 0.0, data)],
		[&"power_pct", 10.0, &"max_hit", CombatMath.max_hit(1, 0.0, 10.0, data)],
		[&"evasion_bonus", 20.0, &"evasion", CombatMath.evasion_rating(1, 20.0, 0.0, data)],
		[&"evasion_pct", 10.0, &"evasion", CombatMath.evasion_rating(1, 0.0, 10.0, data)],
		[&"damage_reduction", 10.0, &"damage_reduction", 10.0],
		[&"attack_interval_pct", -10.0, &"attack_interval_ms", 2160],
		[&"max_hp_flat", 20.0, &"max_hp", 80],
	]
	for c: Array in cases:
		session.modifiers.set_source(&"test:stat", [Modifier.make(c[0], c[1])])
		var stats: CombatantStats = CombatantStats.for_player(session)
		assert_ne(stats.get(c[2]), base.get(c[2]), "%s changes %s" % [c[0], c[2]])
		assert_eq(stats.get(c[2]), c[3], "%s -> %s" % [c[0], c[2]])
	session.modifiers.set_source(&"test:stat", [])
	assert_eq(CombatantStats.for_player(session).accuracy, base.accuracy, "removing the source restores the base")


func test_class_data_only_uses_registered_stats() -> void:
	# M6: every stat named by a setup, trait or ability modifier, or by a stat_trade, is in the registry (no hidden stat).
	var data: GameData = TestFactory.real_data()
	var def: ClassDef = data.character_class(&"rift_blade")
	var names: Dictionary[StringName, String] = {}
	for setup: SetupDef in def.setups:
		for m: Modifier in setup.modifiers:
			names[m.stat] = "setup %s" % setup.id
	for t: TraitDef in def.traits:
		for m: Modifier in t.modifiers:
			names[m.stat] = "trait %s" % t.id
		for e: TraitEffectDef in t.effects:
			if e.type != &"stat_trade":
				continue
			for z: Variant in e.params.get("zero", []):
				names[StringName(str(z))] = "trait %s (zero)" % t.id
			for k: Variant in e.params.get("mult", {}):
				names[StringName(str(k))] = "trait %s (mult)" % t.id
	assert_gt(names.size(), 0)
	for stat: StringName in names:
		assert_true(_registry.has(stat), "%s (%s) is registered in stats.json" % [stat, names[stat]])
	for a: AbilityDef in def.abilities:
		for m: Modifier in a.modifiers:
			assert_true(_registry.has(m.stat), "ability %s: stat %s registered" % [a.id, m.stat])


func test_every_trait_effect_type_used_by_the_class_has_its_test_file() -> void:
	var def: ClassDef = TestFactory.real_data().character_class(&"rift_blade")
	var seen: Dictionary[StringName, bool] = {}
	for t: TraitDef in def.traits:
		for e: TraitEffectDef in t.effects:
			seen[e.type] = true
	assert_eq(seen.size(), 8, "the class uses all 8 effect types of F-81")
	for type: StringName in seen:
		var path: String = "res://tests/systems/combat/effects/test_%s.gd" % type
		assert_true(FileAccess.file_exists(path), "%s: %s exists" % [type, path])
	for a: AbilityDef in def.abilities:
		assert_true(FileAccess.file_exists("res://tests/systems/combat/test_abilities.gd"), "ability tests exist")


func test_every_stat_has_its_test() -> void:
	# Strict mode (N10, M9-07): no stat is pending. A stat whose test is missing is an error, whatever its milestone.
	var missing: PackedStringArray = []
	for stat: StringName in _registry.ids():
		var info: Dictionary = _registry.info(stat)
		if not _reference_exists(str(info["test"])):
			missing.append("%s (%s, %s)" % [stat, info["formula"], FORMULA_MILESTONES.get(str(info["formula"]), "closed")])
	assert_eq(missing.size(), 0, "stat tests missing: %s" % "; ".join(missing))


func test_the_check_finds_a_missing_function() -> void:
	# Guard for the checker itself: an existing file with a missing function and a missing file are both rejected.
	assert_true(_reference_exists("tests/systems/bank/test_bank_bags.gd::test_unequip_bag_rejections"))
	assert_false(_reference_exists("tests/systems/bank/test_bank_bags.gd::test_does_not_exist"))
	assert_false(_reference_exists("tests/systems/nothing/test_nothing.gd::test_unequip_bag_rejections"))
	assert_false(_reference_exists("tests/systems/bank/test_bank_bags.gd::test_unequip_bag"), "whole name only")


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
