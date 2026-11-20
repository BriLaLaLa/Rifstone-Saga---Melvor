extends GutTest
## Traits and abilities of the real class file (01_GDD.md §20, 04_DATA_SCHEMA.md §14, F-80, F-81). The file is read
## raw; the format rules themselves are checked by the validator (tests/core/data/test_data_validator_traits.gd).

const EFFECT_TYPES: Array[String] = ["every_nth_attack_all", "on_kill_timer_cut", "low_hp_damage_mult", "stat_trade",
	"target_rule", "reflect_pct", "leech_pct", "opening_strike"]
const M28_EFFECT_TYPES: Array[String] = ["stack_damage", "stack_haste", "focus_combo", "riposte", "damage_trade", "apply_on_hit",
	"status_damage_mult", "kill_cooldown_cut", "after_ability_mult", "ward_on", "lone_target_mult", "hit_cap_pct", "execute_mult"]
const COMBAT_SETUPS: Array[String] = ["greatsword", "sword_shield", "dual_swords", "sword"]
const ABILITIES_PER_SETUP: Dictionary = {"greatsword": 5, "sword_shield": 5, "dual_swords": 5, "sword": 4}

var _class: Dictionary = {}
var _stats: Dictionary = {}


func before_all() -> void:
	_class = JSON.parse_string(FileAccess.get_file_as_string("res://data/classes/rift_blade.json")) as Dictionary
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/config/stats.json")) as Dictionary
	for entry: Variant in raw["stats"] as Array:
		_stats[(entry as Dictionary)["id"]] = entry


func test_counts() -> void:
	assert_eq((_class["traits"] as Array).size(), 31)
	assert_eq((_class["abilities"] as Array).size(), 19)


func test_m28_effect_types_and_ability_params_are_used() -> void:
	var used: Dictionary = {}
	for t: Dictionary in _class["traits"] as Array:
		for e: Dictionary in t["effects"] as Array:
			used[e["type"]] = true
	for type: String in M28_EFFECT_TYPES:
		assert_true(used.has(type), "trait type %s used" % type)
	var kinds: Dictionary = {}
	var params: Dictionary = {}
	for a: Dictionary in _class["abilities"] as Array:
		kinds[a["kind"]] = true
		for key: Variant in (a["params"] as Dictionary).keys():
			params[key] = true
	assert_true(kinds.has("ward"), "ability kind ward")
	for key: String in ["hits", "target", "execute", "apply", "drain_pct"]:
		assert_true(params.has(key), "ability param %s used" % key)


func test_blade_volley_is_renamed_and_the_first_entries_are_unchanged() -> void:
	var abilities: Array = _class["abilities"] as Array
	assert_eq((abilities[5] as Dictionary)["id"], "blade_volley")
	assert_eq((abilities[5] as Dictionary)["name"], "Sciame di tagli")
	var first_traits: Array[String] = ["chain_cleave", "first_blood", "ember_thirst", "hunters_eye", "last_stand", "stone_stance",
		"glass_edge", "rift_thorns", "cornered_fury", "blood_ember", "giant_breaker", "greedy_fangs"]
	for i: int in first_traits.size():
		assert_eq(((_class["traits"] as Array)[i] as Dictionary)["id"], first_traits[i])
	var first_abilities: Array[String] = ["whirl", "rift_maul", "shield_bash", "ember_breath", "twin_frenzy", "blade_volley"]
	for i: int in first_abilities.size():
		assert_eq((abilities[i] as Dictionary)["id"], first_abilities[i])


func test_all_eight_effect_types_are_used() -> void:
	var used: Dictionary = {}
	for t: Dictionary in _class["traits"] as Array:
		assert_gt((t["effects"] as Array).size(), 0, "%s has effects" % t["id"])
		for e: Dictionary in t["effects"] as Array:
			used[e["type"]] = true
	for type: String in EFFECT_TYPES:
		assert_true(used.has(type), "type %s used" % type)


func test_ids_and_names_are_unique() -> void:
	var ids: Dictionary = {}
	var names: Dictionary = {}
	for list: String in ["traits", "abilities"]:
		for e: Dictionary in _class[list] as Array:
			assert_false(ids.has(e["id"]), "duplicate id %s" % e["id"])
			assert_false(names.has(e["name"]), "duplicate name %s" % e["name"])
			ids[e["id"]] = true
			names[e["name"]] = true


func test_abilities_per_combat_setup_with_a_level_one() -> void:
	for setup: String in COMBAT_SETUPS:
		var count: int = 0
		var first_level: int = 99
		for a: Dictionary in _class["abilities"] as Array:
			if (a["setups"] as Array).has(setup):
				count += 1
				first_level = mini(first_level, int(a["unlock_level"]))
		assert_eq(count, int(ABILITIES_PER_SETUP[setup]), "abilities of %s" % setup)
		assert_eq(first_level, 1, "%s has a level 1 ability" % setup)


func test_ability_roles_are_varied() -> void:
	var kinds: Dictionary = {}
	for a: Dictionary in _class["abilities"] as Array:
		kinds[a["kind"]] = true
	for kind: String in ["strike", "cleave", "heal", "buff", "ward"]:
		assert_true(kinds.has(kind), "kind %s" % kind)


func test_a_trait_is_available_at_level_one() -> void:
	var at_one: int = 0
	for t: Dictionary in _class["traits"] as Array:
		if int(t["unlock_level"]) == 1:
			at_one += 1
	assert_gt(at_one, 1, "the first slot has a choice")


func test_buff_and_trait_modifiers_use_registered_stats() -> void:
	for t: Dictionary in _class["traits"] as Array:
		for m: Dictionary in t["modifiers"] as Array:
			assert_true(_stats.has(m["stat"]), "%s modifier %s" % [t["id"], m["stat"]])
	for a: Dictionary in _class["abilities"] as Array:
		if a["kind"] == "buff":
			for m: Dictionary in (a["params"] as Dictionary)["modifiers"] as Array:
				assert_true(_stats.has(m["stat"]), "%s buff %s" % [a["id"], m["stat"]])


func test_stat_trade_uses_combat_stats_only() -> void:
	var seen: int = 0
	for t: Dictionary in _class["traits"] as Array:
		for e: Dictionary in t["effects"] as Array:
			if e["type"] != "stat_trade":
				continue
			seen += 1
			var p: Dictionary = e["params"] as Dictionary
			for stat: Variant in (p["zero"] as Array) + (p["mult"] as Dictionary).keys():
				assert_true(DataValidatorTraits.STAT_TRADE_STATS.has(str(stat)), "%s: %s" % [t["id"], stat])
	assert_gt(seen, 0)


## Numbers are generated by the UI from the effect params: the hand-written text stays qualitative.
func test_descriptions_have_no_digits_or_numeric_words() -> void:
	var digits := RegEx.create_from_string("[0-9]")
	var words := RegEx.create_from_string("(?i)\\b(terzo|secondo|metà|dimezz\\w*|raddopp\\w*|doppio|due|tre|quattro|cinque)\\b")
	for group: String in ["traits", "abilities"]:
		for entry: Dictionary in _class[group] as Array:
			var text: String = str(entry["description"])
			assert_null(digits.search(text), "%s: digits in description" % entry["id"])
			assert_null(words.search(text), "%s: numeric word in description" % entry["id"])
