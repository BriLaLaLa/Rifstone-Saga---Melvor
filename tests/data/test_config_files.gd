extends GutTest
## Checks data/config/balance.json and data/config/stats.json against the MVP specification
## (02_FORMULAS.md §9 and §11, 04_DATA_SCHEMA.md §2-3). The expected values below are the oracle.

const BALANCE_PATH: String = "res://data/config/balance.json"
const STATS_PATH: String = "res://data/config/stats.json"

## Every leaf of balance.json, flattened as "dotted.path" (array indices are path segments).
## Numbers are floats because JSON numbers parse as float.
const EXPECTED_BALANCE: Dictionary = {
	"tick_ms": 100.0,
	"max_catchup_ms": 5000.0,
	"autosave_interval_ms": 10000.0,
	"slots.count": 4.0,
	"player_name.min_length": 1.0,
	"player_name.max_length": 24.0,
	"start.gold": 50.0,
	"start.items.0.item": "seared_brookfin",
	"start.items.0.qty": 20.0,
	"start.armory.0.base": "emberbronze_sword",
	"start.armory.0.equip": "weapon",
	"start.armory.1.base": "emberbronze_greatsword",
	"start.armory.1.equip": "",
	"start.armory.2.base": "emberbronze_shield",
	"start.armory.2.equip": "offhand",
	"start.tools.0.base": "unique_hatchet",
	"start.tools.1.base": "unique_pick",
	"start.tools.2.base": "unique_rod",
	"start.purchases.auto_eat_1": 1.0,
	"start.food": "seared_brookfin",
	"xp_curve.base": 70.0,
	"xp_curve.growth": 1.1,
	"xp_curve.linear": 8.0,
	"xp_curve.max_level": 99.0,
	"xp_curve.xp_cap": 50000000.0,
	"mastery_curve.base": 20.0,
	"mastery_curve.growth": 1.1,
	"mastery_curve.linear": 4.0,
	"mastery_curve.max_level": 99.0,
	"mastery.base_factor": 1.0,
	"mastery.per_level": 0.1,
	"mastery.ratio_weight": 3.0,
	"mastery.pool_share_pct": 20.0,
	"mastery.pool_cap_per_item": 300000.0,
	"mastery.pool_warning_pct": 95.0,
	"mastery.milestones.byproduct_at": 25.0,
	"mastery.milestones.resource_at": 50.0,
	"mastery.milestones.trade_at": 99.0,
	"mastery.milestones.byproduct_chance_pct": 2.0,
	"action.min_interval_ms": 250.0,
	"gathering.rift_shard_base_chance_pct": 0.5,
	"deposit.base_slots": 60.0,
	"deposit.bag_slots": 6.0,
	"helper.xp_pct": 25.0,
	"helper.mastery_pct": 25.0,
	"helper.grades.0.id": "apprentice",
	"helper.grades.0.interval_mult": 3.0,
	"helper.grades.1.id": "journeyman",
	"helper.grades.1.interval_mult": 2.5,
	"helper.grades.2.id": "expert",
	"helper.grades.2.interval_mult": 2.0,
	"helper.grades.3.id": "master",
	"helper.grades.3.interval_mult": 1.5,
	"engraver.crystal_chance_min_pct": 40.0,
	"engraver.crystal_chance_max_pct": 90.0,
	"engraver.crystal_fail_loss_pct": 50.0,
	"engraver.merge_ratio": 3.0,
	"rune.upgrade_ratio": 3.0,
	"rune.grade_mult.0": 1.0,
	"rune.grade_mult.1": 2.0,
	"rune.grade_mult.2": 3.0,
	"rune.grade_mult.3": 4.0,
	"rune.grade_mult.4": 5.0,
	"combat.acc_level_offset": 8.0,
	"combat.acc_bonus_offset": 50.0,
	"combat.maxhit_level_offset": 10.0,
	"combat.maxhit_bonus_offset": 40.0,
	"combat.min_hit_ratio": 0.1,
	"combat.hit_chance_min": 0.05,
	"combat.hit_chance_max": 0.95,
	"combat.triangle.advantage_damage_mult": 1.15,
	"combat.triangle.disadvantage_damage_mult": 0.85,
	"combat.triangle.defender_dr_mult": 0.75,
	"combat.triangle.beats.blade": "arcana",
	"combat.triangle.beats.arcana": "marksmanship",
	"combat.triangle.beats.marksmanship": "blade",
	"combat.min_attack_interval_ms": 800.0,
	"combat.unarmed.style": "blade",
	"combat.unarmed.attack_interval_ms": 2400.0,
	"combat.unarmed.dmg_min": 0.0,
	"combat.unarmed.dmg_max": 0.0,
	"combat.dual_wield.interval_mult": 0.75,
	"combat.max_pack_size": 6.0,
	"combat.hp_base": 50.0,
	"combat.hp_per_level": 10.0,
	"combat.auto_eat_tiers.0": null,
	"combat.auto_eat_tiers.1.threshold_pct": 30.0,
	"combat.auto_eat_tiers.1.target_pct": 60.0,
	"combat.auto_eat_tiers.2.threshold_pct": 40.0,
	"combat.auto_eat_tiers.2.target_pct": 75.0,
	"combat.auto_eat_tiers.3.threshold_pct": 50.0,
	"combat.auto_eat_tiers.3.target_pct": 90.0,
	"combat.respawn_ms": 1500.0,
	"combat.loot_bag_base_slots": 12.0,
	"combat.kill_xp_mult": 0.11,
	"character_curve.base": 70.0,
	"character_curve.growth": 1.1,
	"character_curve.linear": 8.0,
	"character_curve.max_level": 99.0,
	"character_curve.xp_cap": 50000000.0,
	"character.start_class": "rift_blade",
	"traits.slot_levels.0": 1.0,
	"traits.slot_levels.1": 10.0,
	"traits.slot_levels.2": 25.0,
	"traits.slot_levels.3": 50.0,
	"abilities.slot_levels.0": 1.0,
	"abilities.slot_levels.1": 1.0,
	"abilities.slot_levels.2": 30.0,
	"blueprint.duration_base_min": 10.0,
	"blueprint.duration_per_grade_min": 7.0,
	"blueprint.xp_mult": 1.5,
	"blueprint.rare_base_pct": 10.0,
	"blueprint.rare_per_forging_level": 0.5,
	"blueprint.choose_affix_level": 50.0,
	"blueprint.chosen_affix_tier": 2.0,
	"blueprint.cost_mult": 3.0,  # M14 (F-119)
	"blueprint.extra_rare": 2.0,
	"rarity.affix_count.magic.0": 1.0,
	"rarity.affix_count.magic.1": 2.0,
	"rarity.affix_count.rare.0": 3.0,
	"rarity.affix_count.rare.1": 4.0,
	"rarity.masterwork.base_mult": 1.25,  # M14 (F-119, F-91)
	"rarity.masterwork.affix_count.0": 1.0,
	"rarity.masterwork.affix_count.1": 2.0,
	"rarity.legendary.base_mult": 1.4,  # M14 (F-120)
	"rarity.drop.magic_pct": 25.0,  # M14 (F-121)
	"rarity.drop.rare_pct": 5.0,
	"rarity.rift_stone.magic_pct": 40.0,
	"rarity.rift_stone.rare_pct": 12.0,
	"rift_stone.chance_pct": 0.5,
	"rift_stone.pity_kills": 300.0,
	"rift.sockets.0.level": 1.0,
	"rift.sockets.1.level": 20.0,
	"rift.sockets.2.level": 40.0,
	"rift.sockets.3.level": 60.0,
	"rift.sockets.4.level": 80.0,
	"sockets.by_rarity.common": 0.0,
	"sockets.by_rarity.magic": 1.0,
	"sockets.by_rarity.rare": 2.0,
	"sockets.by_rarity.masterwork": 2.0,  # M14 (F-89)
	"sockets.by_rarity.legendary": 2.0,
	"sockets.bonus_at_upgrade": 7.0,
	"offline.cap_ms": 43200000.0,
	"offline.min_ms": 60000.0,
	"offline.chunk_ms": 60000.0,
}

## The stats of M1-M6 and upgrade_success_pct (M7) of 02_FORMULAS.md §11: id -> [min, max, formula].
const EXPECTED_STATS: Dictionary = {
	"skill_interval_pct": [-80.0, 100.0, "F-03"],
	"skill_xp_pct": [0.0, 1000.0, "F-02"],
	"mastery_xp_pct": [0.0, 1000.0, "F-10"],
	"double_item_chance": [0.0, 100.0, "F-06"],
	"preservation_chance": [0.0, 80.0, "F-08"],
	"rift_shard_chance": [0.0, 100.0, "F-07"],
	"accuracy_bonus": [-1000.0, 100000.0, "F-20"],
	"accuracy_pct": [-90.0, 1000.0, "F-20"],
	"power_bonus": [-1000.0, 100000.0, "F-22"],
	"power_pct": [-90.0, 1000.0, "F-22"],
	"evasion_bonus": [-1000.0, 100000.0, "F-21"],
	"evasion_pct": [-90.0, 1000.0, "F-21"],
	"armor": [0.0, 100000.0, "F-117"],
	"barrier": [0.0, 100000.0, "F-117"],
	"attack_interval_pct": [-90.0, 200.0, "F-26"],
	"max_hp_flat": [0.0, 100000.0, "F-27"],
	"food_healing_pct": [0.0, 500.0, "F-29"],
	"gold_drop_pct": [0.0, 1000.0, "F-31"],
	"loot_bag_slots": [0.0, 100.0, "F-33"],
	"auto_loot": [0.0, 1.0, "10.6"],
	"auto_eat_tier": [0.0, 3.0, "F-30"],
	"item_rarity_pct": [0.0, 1000.0, "F-84"],
	"block_chance": [0.0, 50.0, "F-75"],
	"upgrade_success_pct": [0.0, 300.0, "F-86"],
}

const STAT_FIELDS: Array[String] = ["id", "name", "format", "min", "max", "description", "formula", "test"]
const STAT_FORMATS: Array[String] = ["pct", "flat", "flag"]
const LATER_MILESTONE_STATS: Array[String] = []  # fracture_duration_pct was removed with the timed Fracture (R-04)
const LATER_MILESTONE_BALANCE_KEYS: Array[String] = [
	"fractures", "parallel",
]


func _load_json(path: String) -> Variant:
	var text: String = FileAccess.get_file_as_string(path)
	assert_ne(text, "", "file %s exists and is not empty" % path)
	var json: JSON = JSON.new()
	var err: Error = json.parse(text)
	assert_eq(err, OK, "%s parses (line %d: %s)" % [path, json.get_error_line(), json.get_error_message()])
	return json.data


func _load_dict(path: String) -> Dictionary:
	var data: Variant = _load_json(path)
	if data is Dictionary:
		return data
	fail_test("%s root is a Dictionary" % path)
	return {}


func _flatten(value: Variant, prefix: String, out: Dictionary) -> void:
	if value is Dictionary:
		var dict: Dictionary = value
		for key: Variant in dict:
			_flatten(dict[key], _join(prefix, str(key)), out)
	elif value is Array and not (value as Array).is_empty():
		var arr: Array = value
		for i: int in arr.size():
			_flatten(arr[i], _join(prefix, str(i)), out)
	else:
		out[prefix] = value


# The leaves of balance.json except the M7 sections `upgrade` and `salvage` (tests/data/test_loot_balance.gd) and the M10
# section `tool_upgrade` (tests/data/test_balance_m10_keys.gd).
func _flatten_without_loot(out: Dictionary) -> void:
	_flatten(_load_dict(BALANCE_PATH), "", out)
	for key: String in out.keys():
		if key.begins_with("upgrade.") or key.begins_with("salvage.") or key.begins_with("tool_upgrade.") \
				or key.begins_with("fracture.") or key.begins_with("equipment.") or key.begins_with("combat.armor.") \
				or key.begins_with("loot."):
			# fracture.* is covered by tests/core/data/test_map_data_validation.gd, equipment.* and combat.armor.* (M14) by
			# tests/systems/combat/test_armor_math.gd and tests/core/data/test_weapon_validation.gd, loot.* (M14-05) by tests/data/test_loot_data.gd
			out.erase(key)


func _join(prefix: String, key: String) -> String:
	return key if prefix.is_empty() else prefix + "." + key


func _stats() -> Array:
	var root: Dictionary = _load_dict(STATS_PATH)
	var stats: Variant = root.get("stats")
	if stats is Array:
		return stats
	fail_test("stats.json has a 'stats' array")
	return []


func test_balance_parses_as_dictionary() -> void:
	var root: Dictionary = _load_dict(BALANCE_PATH)
	assert_false(root.is_empty(), "balance.json is a non-empty object")


func test_balance_has_every_mvp_key_with_expected_value() -> void:
	var flat: Dictionary = {}
	_flatten_without_loot(flat)
	for path: String in EXPECTED_BALANCE:
		assert_true(flat.has(path), "balance key %s present" % path)
		if not flat.has(path):
			continue
		var expected: Variant = EXPECTED_BALANCE[path]
		var actual: Variant = flat[path]
		if expected is Array:
			assert_true(actual is Array and (actual as Array).is_empty(), "%s is an empty list" % path)
		else:
			assert_eq(typeof(actual), typeof(expected), "%s has the expected type" % path)
			assert_eq(actual, expected, "%s value" % path)


func test_balance_has_no_unexpected_keys() -> void:
	var flat: Dictionary = {}
	_flatten_without_loot(flat)
	for path: String in flat:
		assert_true(EXPECTED_BALANCE.has(path), "balance key %s is part of the MVP specification" % path)
	assert_eq(flat.size(), EXPECTED_BALANCE.size(), "balance.json leaf count")


func test_balance_has_no_later_milestone_sections() -> void:
	var root: Dictionary = _load_dict(BALANCE_PATH)
	for key: String in LATER_MILESTONE_BALANCE_KEYS:
		assert_false(root.has(key), "balance.json has no '%s' section (M7+)" % key)


func test_stats_has_exactly_24_stats() -> void:
	var stats: Array = _stats()
	assert_eq(stats.size(), 24, "stats.json lists the 25 stats of M1-M7 minus bank_slots and armory_slots (M12), plus barrier (M14)")
	var ids: Array[String] = []
	for entry: Variant in stats:
		if entry is Dictionary:
			ids.append(str((entry as Dictionary).get("id", "")))
	for id: String in EXPECTED_STATS:
		assert_has(ids, id, "stat %s present" % id)
	for id: String in ids:
		assert_true(EXPECTED_STATS.has(id), "stat %s is a registered stat" % id)
		assert_eq(ids.count(id), 1, "stat id %s is unique" % id)
	for id: String in LATER_MILESTONE_STATS:
		assert_does_not_have(ids, id, "later-milestone stat %s absent" % id)


func test_stats_have_required_fields_and_valid_values() -> void:
	for entry: Variant in _stats():
		assert_true(entry is Dictionary, "stat entry is an object")
		if not entry is Dictionary:
			continue
		var stat: Dictionary = entry
		var id: String = str(stat.get("id", ""))
		for field: String in STAT_FIELDS:
			assert_true(stat.has(field), "stat %s has field %s" % [id, field])
		assert_eq(stat.size(), STAT_FIELDS.size(), "stat %s has only the schema fields" % id)
		for field: String in ["id", "name", "format", "description", "formula", "test"]:
			assert_eq(typeof(stat.get(field)), TYPE_STRING, "stat %s field %s is a String" % [id, field])
		var stat_name: String = str(stat.get("name", ""))
		assert_between(stat_name.length(), 1, 40, "stat %s name length 1-40" % id)
		assert_false(str(stat.get("description", "")).is_empty(), "stat %s has a description" % id)
		assert_has(STAT_FORMATS, str(stat.get("format", "")), "stat %s format is pct/flat/flag" % id)
		var test_ref: String = str(stat.get("test", ""))
		assert_true(test_ref.begins_with("tests/"), "stat %s test path starts with tests/" % id)
		assert_string_contains(test_ref, ".gd::test_", "stat %s test is path::function" % id)


func test_stats_limits_and_formulas_match_specification() -> void:
	for entry: Variant in _stats():
		if not entry is Dictionary:
			continue
		var stat: Dictionary = entry
		var id: String = str(stat.get("id", ""))
		if not EXPECTED_STATS.has(id):
			continue
		var expected: Array = EXPECTED_STATS[id]
		var min_value: Variant = stat.get("min")
		var max_value: Variant = stat.get("max")
		assert_eq(typeof(min_value), TYPE_FLOAT, "stat %s min is a number" % id)
		assert_eq(typeof(max_value), TYPE_FLOAT, "stat %s max is a number" % id)
		assert_eq(min_value, expected[0], "stat %s min" % id)
		assert_eq(max_value, expected[1], "stat %s max" % id)
		assert_true(float(min_value) < float(max_value), "stat %s min < max" % id)
		assert_eq(stat.get("formula"), expected[2], "stat %s formula" % id)


func test_flag_stats_are_bounded_zero_one() -> void:
	for entry: Variant in _stats():
		if not entry is Dictionary:
			continue
		var stat: Dictionary = entry
		if stat.get("format") != "flag":
			continue
		assert_eq(stat.get("min"), 0.0, "flag stat %s min is 0" % stat.get("id"))
		assert_eq(stat.get("max"), 1.0, "flag stat %s max is 1" % stat.get("id"))
