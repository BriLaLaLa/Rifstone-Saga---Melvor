extends GutTest
## DataValidator, part 5 (M6-01): the traits and abilities of a class (04_DATA_SCHEMA.md §14, F-80, F-81) and the
## `traits.slot_levels` / `abilities.slot_levels` keys of balance.json (F-78). One test per rule on a broken copy of
## the fixtures; helpers from test_data_validator.gd.

const V: GDScript = preload("res://tests/core/data/test_data_validator.gd")
const CLASS_FILE: String = "test_class.json"


func _expect(raw: Dictionary, fragments: Array[String]) -> void:
	var errors: PackedStringArray = V.validate(raw)
	for message: String in errors:
		var matched: bool = true
		for fragment: String in fragments:
			matched = matched and message.contains(fragment)
		if matched:
			assert_true(true)
			return
	fail_test("no error with %s in %s" % [fragments, errors])


func _class(raw: Dictionary) -> Dictionary:
	return V.file_of(raw, "classes", CLASS_FILE)


func _trait(raw: Dictionary, index: int) -> Dictionary:
	return (_class(raw)["traits"] as Array)[index] as Dictionary


func _effect(raw: Dictionary, index: int) -> Dictionary:
	return ((_trait(raw, index)["effects"] as Array)[0]) as Dictionary


func _ability(raw: Dictionary, index: int) -> Dictionary:
	return (_class(raw)["abilities"] as Array)[index] as Dictionary


func _params(raw: Dictionary, ability: int) -> Dictionary:
	return _ability(raw, ability)["params"] as Dictionary


func _balance(raw: Dictionary) -> Dictionary:
	return V.file_of(raw, "balance", "balance.json")


func test_fixture_classes_with_traits_and_abilities_are_valid() -> void:
	assert_eq(V.validate(V.fixture_raw()), PackedStringArray())


func test_trait_unknown_field_and_missing_field() -> void:
	var raw: Dictionary = V.fixture_raw()
	_trait(raw, 0)["power"] = 3
	_trait(raw, 1).erase("effects")
	_expect(raw, [CLASS_FILE, "unknown field 'traits[0].power'"])
	_expect(raw, [CLASS_FILE, "missing field 'traits[1].effects'"])


func test_trait_id_and_unlock_level() -> void:
	var raw: Dictionary = V.fixture_raw()
	_trait(raw, 1)["id"] = "test_cleave"
	_trait(raw, 2)["unlock_level"] = 100
	_trait(raw, 3)["id"] = "Bad Id"
	_expect(raw, [CLASS_FILE, "traits[1].id", "duplicate 'test_cleave'"])
	_expect(raw, [CLASS_FILE, "traits[2].unlock_level", "99"])
	_expect(raw, [CLASS_FILE, "traits[3].id", "does not match"])


func test_trait_setups_must_be_setups_of_the_class() -> void:
	var raw: Dictionary = V.fixture_raw()
	_trait(raw, 1)["setups"] = ["greatsword", "archery"]
	_expect(raw, [CLASS_FILE, "traits[1].setups", "unknown setup 'archery'"])


func test_trait_needs_at_least_one_effect() -> void:
	var raw: Dictionary = V.fixture_raw()
	_trait(raw, 0)["effects"] = []
	_trait(raw, 1)["modifiers"] = [{"stat": "accuracy_pct", "value": 5}]
	_expect(raw, [CLASS_FILE, "traits[0].effects", "at least 1"])


func test_trait_modifiers_are_checked() -> void:
	var raw: Dictionary = V.fixture_raw()
	_trait(raw, 1)["modifiers"] = [{"stat": "ghost_stat", "value": 5}]
	_expect(raw, [CLASS_FILE, "traits[1].modifiers[0]", "ghost_stat"])


func test_effect_type_and_unknown_param() -> void:
	var raw: Dictionary = V.fixture_raw()
	_effect(raw, 0)["type"] = "explode"
	_effect(raw, 1)["params"] = {"pct": 50, "extra": 1}
	_expect(raw, [CLASS_FILE, "traits[0].effects[0].type", "unknown effect type 'explode'"])
	_expect(raw, [CLASS_FILE, "traits[1].effects[0].params.extra", "unknown field"])


func test_effect_param_ranges() -> void:
	var raw: Dictionary = V.fixture_raw()
	_effect(raw, 0)["params"] = {"n": 1}
	_effect(raw, 1)["params"] = {"pct": 0}
	_effect(raw, 2)["params"] = {"pct": 101}
	_effect(raw, 4)["params"] = {"hp_pct": 30, "mult": 0, "no_auto_eat": "yes"}
	_expect(raw, [CLASS_FILE, "traits[0].effects[0].params.n"])
	_expect(raw, [CLASS_FILE, "traits[1].effects[0].params.pct"])
	_expect(raw, [CLASS_FILE, "traits[2].effects[0].params.pct"])
	_expect(raw, [CLASS_FILE, "traits[4].effects[0].params.mult"])
	_expect(raw, [CLASS_FILE, "traits[4].effects[0].params.no_auto_eat"])


func test_effect_missing_param() -> void:
	var raw: Dictionary = V.fixture_raw()
	_effect(raw, 0)["params"] = {}
	_expect(raw, [CLASS_FILE, "missing field 'traits[0].effects[0].params.n'"])


func test_opening_strike_takes_no_params() -> void:
	var raw: Dictionary = V.fixture_raw()
	_effect(raw, 3)["params"] = {"x": 1}
	_expect(raw, [CLASS_FILE, "traits[3].effects[0].params.x", "unknown field"])


func test_target_rule_and_stat_trade() -> void:
	var raw: Dictionary = V.fixture_raw()
	_effect(raw, 0)["type"] = "target_rule"
	_effect(raw, 0)["params"] = {"rule": "random"}
	_expect(raw, [CLASS_FILE, "traits[0].effects[0].params.rule", "must be one of"])
	_effect(raw, 0)["params"] = {"rule": "lowest_hp"}
	assert_eq(V.validate(raw), PackedStringArray())
	_effect(raw, 1)["type"] = "stat_trade"
	_effect(raw, 1)["params"] = {"zero": ["evasion_pct"], "mult": {"armor": 2, "ghost": 1}}
	_expect(raw, [CLASS_FILE, "traits[1].effects[0].params.mult.ghost", "not in stats.json"])
	_effect(raw, 1)["params"] = {"zero": ["armor"], "mult": {"armor": 2}}
	_expect(raw, [CLASS_FILE, "params.mult.armor", "also in zero"])
	_effect(raw, 1)["params"] = {"zero": [], "mult": {}}
	_expect(raw, [CLASS_FILE, "traits[1].effects[0].params", "at least one stat"])
	_effect(raw, 1)["params"] = {"zero": ["ghost"], "mult": {"armor": 0}}
	_expect(raw, [CLASS_FILE, "params.zero", "ghost"])
	_expect(raw, [CLASS_FILE, "params.mult.armor", "> 0"])


func test_stat_trade_valid() -> void:
	var raw: Dictionary = V.fixture_raw()
	_effect(raw, 1)["type"] = "stat_trade"
	_effect(raw, 1)["params"] = {"zero": ["evasion_pct"], "mult": {"armor": 2}}
	assert_eq(V.validate(raw), PackedStringArray())


func test_stat_trade_rejects_stats_without_combat_effect() -> void:
	var raw: Dictionary = V.fixture_raw()
	_effect(raw, 1)["type"] = "stat_trade"
	_effect(raw, 1)["params"] = {"zero": ["skill_xp_pct"], "mult": {"gold_drop_pct": 2}}
	_expect(raw, [CLASS_FILE, "params.zero", "skill_xp_pct", "no combat effect"])
	_expect(raw, [CLASS_FILE, "params.mult.gold_drop_pct", "no combat effect"])
	for stat: String in DataValidatorTraits.STAT_TRADE_STATS:
		_effect(raw, 1)["params"] = {"zero": [stat], "mult": {}}
		assert_eq(V.validate(raw), PackedStringArray(), stat)


func test_trait_and_ability_ids_are_separate_namespaces() -> void:
	var raw: Dictionary = V.fixture_raw()
	_ability(raw, 0)["id"] = "test_cleave"
	assert_eq(V.validate(raw), PackedStringArray())


func test_slot_levels_are_required_and_checked() -> void:
	var raw: Dictionary = V.fixture_raw()
	_balance(raw)["traits"] = {"slot_levels": [1, 10, 5]}
	_expect(raw, ["balance.json", "traits.slot_levels", "not decreasing"])
	_balance(raw)["traits"] = {"slot_levels": []}
	_expect(raw, ["balance.json", "traits.slot_levels", "1..8"])
	_balance(raw)["traits"] = {"slot_levels": [1, 100]}
	_expect(raw, ["balance.json", "traits.slot_levels", "1..99"])
	_balance(raw)["traits"] = {"slot_levels": [1.5]}
	_expect(raw, ["balance.json", "traits.slot_levels"])
	_balance(raw)["traits"] = {"slot_levels": [1, 10]}
	_balance(raw)["abilities"] = {}
	_expect(raw, ["balance.json", "missing key 'abilities.slot_levels'"])
	_balance(raw).erase("abilities")
	_expect(raw, ["balance.json", "missing key 'abilities.slot_levels'"])


func test_equal_levels_are_allowed() -> void:
	var raw: Dictionary = V.fixture_raw()
	_balance(raw)["abilities"] = {"slot_levels": [1, 1, 30]}
	assert_eq(V.validate(raw), PackedStringArray())


# --- M28-05: the types of F-192 and the combat types of F-120 in a trait (docs/04_DATA_SCHEMA_M28.md §33.4, §33.6) ----------

const M28_FIRST_TRAIT: int = 5  # the fixture traits after the five of M6: one per new type, then the F-120 types


func _with(raw: Dictionary, index: int, params: Dictionary) -> void:
	_effect(raw, index)["params"] = params


func test_every_new_type_has_a_valid_fixture_trait() -> void:
	var seen: Dictionary[String, bool] = {}
	for entry: Variant in _class(V.fixture_raw())["traits"] as Array:
		for effect: Variant in (entry as Dictionary)["effects"] as Array:
			seen[(effect as Dictionary)["type"] as String] = true
	for type: String in DataValidatorTraits.M28_TYPES:
		assert_true(seen.has(type), "a fixture trait with %s" % type)
	for type: String in ["execute_mult", "hit_cap_pct", "armor_pierce_pct", "kill_heal_pct", "block_heal_pct", "stat_convert", "double_hit_pct"]:
		assert_true(seen.has(type), "a fixture trait with %s" % type)
	assert_eq(V.validate(V.fixture_raw()), PackedStringArray())


func test_stack_types_reject_a_bad_gain_lose_or_max() -> void:
	var raw: Dictionary = V.fixture_raw()
	_with(raw, M28_FIRST_TRAIT, {"gain": "heal", "pct": 5, "max": 5, "lose": "damaged"})
	_with(raw, M28_FIRST_TRAIT + 1, {"gain": "kill", "pct": 3, "max": 0, "lose": "encounter"})
	_with(raw, M28_FIRST_TRAIT + 2, {"pct": 60, "max": 21})
	_expect(raw, [CLASS_FILE, "traits[5].effects[0].params.gain", "must be one of"])
	_expect(raw, [CLASS_FILE, "traits[6].effects[0].params.max"])
	_expect(raw, [CLASS_FILE, "traits[7].effects[0].params.pct"])
	_expect(raw, [CLASS_FILE, "traits[7].effects[0].params.max"])
	_with(raw, M28_FIRST_TRAIT, {"gain": "kill", "pct": 5, "max": 5, "lose": "never"})
	_expect(raw, [CLASS_FILE, "traits[5].effects[0].params.lose", "must be one of"])
	_with(raw, M28_FIRST_TRAIT, {"gain": "kill", "pct": 5, "max": 5})
	_expect(raw, [CLASS_FILE, "missing field 'traits[5].effects[0].params.lose'"])


func test_damage_trade_needs_both_fields() -> void:
	var raw: Dictionary = V.fixture_raw()
	_with(raw, M28_FIRST_TRAIT + 4, {"dealt_pct": 25})
	_expect(raw, [CLASS_FILE, "missing field 'traits[9].effects[0].params.taken_pct'"])
	_with(raw, M28_FIRST_TRAIT + 4, {"dealt_pct": 201, "taken_pct": 0})
	_expect(raw, [CLASS_FILE, "traits[9].effects[0].params.dealt_pct"])
	_expect(raw, [CLASS_FILE, "traits[9].effects[0].params.taken_pct"])


func test_ability_mult_kinds() -> void:
	var raw: Dictionary = V.fixture_raw()
	_with(raw, M28_FIRST_TRAIT + 10, {"kinds": [], "pct": 25})
	_expect(raw, [CLASS_FILE, "traits[15].effects[0].params.kinds"])
	_with(raw, M28_FIRST_TRAIT + 10, {"kinds": ["strike", "buff"], "pct": 25})
	_expect(raw, [CLASS_FILE, "traits[15].effects[0].params.kinds", "'buff'"])
	_with(raw, M28_FIRST_TRAIT + 10, {"kinds": ["heal", "heal"], "pct": 25})
	_expect(raw, [CLASS_FILE, "traits[15].effects[0].params.kinds", "duplicate"])
	_with(raw, M28_FIRST_TRAIT + 10, {"kinds": ["strike", "cleave", "heal", "ward"], "pct": 200})
	assert_eq(V.validate(raw), PackedStringArray())


func test_apply_on_hit_follows_the_condition_rules() -> void:
	var raw: Dictionary = V.fixture_raw()
	_with(raw, M28_FIRST_TRAIT + 5, {"every": 3, "condition": "stagger", "pct": 10, "ms": 1000})
	_expect(raw, [CLASS_FILE, "traits[10].effects[0].params.pct", "stagger has no pct"])
	_with(raw, M28_FIRST_TRAIT + 5, {"every": 3, "condition": "stagger", "ms": 1000})
	assert_eq(V.validate(raw), PackedStringArray())
	_with(raw, M28_FIRST_TRAIT + 5, {"every": 21, "condition": "weaken", "pct": 95, "ms": 4000})
	_expect(raw, [CLASS_FILE, "traits[10].effects[0].params.every"])
	_expect(raw, [CLASS_FILE, "traits[10].effects[0].params.pct"])
	_with(raw, M28_FIRST_TRAIT + 5, {"every": 3, "condition": "burn", "pct": 10, "ms": 4000})
	_expect(raw, [CLASS_FILE, "traits[10].effects[0].params.condition", "must be one of"])
	_with(raw, M28_FIRST_TRAIT + 5, {"every": 3, "condition": "bleed", "ms": 4000})
	_expect(raw, [CLASS_FILE, "missing field 'traits[10].effects[0].params.pct'"])
	_with(raw, M28_FIRST_TRAIT + 5, {"every": 3, "condition": "bleed", "pct": 40, "ms": 999})
	_expect(raw, [CLASS_FILE, "traits[10].effects[0].params.ms"])


func test_the_other_new_types_check_their_ranges() -> void:
	var raw: Dictionary = V.fixture_raw()
	_with(raw, M28_FIRST_TRAIT + 2, {"pct": 6, "max": 5, "extra": 1})
	_with(raw, M28_FIRST_TRAIT + 3, {"on": "kill", "mult": 11})
	_with(raw, M28_FIRST_TRAIT + 6, {"condition": "bleed", "pct": 0})
	_with(raw, M28_FIRST_TRAIT + 7, {"ms": 0})
	_with(raw, M28_FIRST_TRAIT + 8, {"mult": 1})
	_with(raw, M28_FIRST_TRAIT + 9, {"on": "kill", "pct": 8, "ms": 999})
	_with(raw, M28_FIRST_TRAIT + 11, {"pct": 201})
	_expect(raw, [CLASS_FILE, "traits[7].effects[0].params.extra", "unknown field"])
	_expect(raw, [CLASS_FILE, "traits[8].effects[0].params.on", "must be one of"])
	_expect(raw, [CLASS_FILE, "traits[8].effects[0].params.mult"])
	_expect(raw, [CLASS_FILE, "traits[11].effects[0].params.pct"])
	_expect(raw, [CLASS_FILE, "traits[12].effects[0].params.ms"])
	_expect(raw, [CLASS_FILE, "traits[13].effects[0].params.mult"])
	_expect(raw, [CLASS_FILE, "traits[14].effects[0].params.ms"])
	_expect(raw, [CLASS_FILE, "traits[16].effects[0].params.pct"])


func test_at_most_one_effect_with_a_state_per_trait() -> void:
	var raw: Dictionary = V.fixture_raw()
	(_trait(raw, M28_FIRST_TRAIT)["effects"] as Array).append({"type": "apply_on_hit",
			"params": {"every": 3, "condition": "bleed", "pct": 40, "ms": 4000}})
	_expect(raw, [CLASS_FILE, "traits[5].effects", "at most one effect with a state"])
	(_trait(raw, M28_FIRST_TRAIT)["effects"] as Array).pop_back()
	(_trait(raw, M28_FIRST_TRAIT)["effects"] as Array).append({"type": "ward_on", "params": {"on": "block", "pct": 5, "ms": 2000}})
	assert_eq(V.validate(raw), PackedStringArray(), "one with a state and others without is fine")
	(_trait(raw, 0)["effects"] as Array).append({"type": "every_nth_attack_all", "params": {"n": 2}})
	_expect(raw, [CLASS_FILE, "traits[0].effects", "at most one effect with a state"])


func test_the_f120_combat_types_are_checked_in_a_trait() -> void:
	var raw: Dictionary = V.fixture_raw()
	var effects: Array = _trait(raw, M28_FIRST_TRAIT + 12)["effects"] as Array
	(effects[0] as Dictionary)["params"] = {"hp_pct": 30, "mult": 1}
	(effects[1] as Dictionary)["params"] = {"pct": 0}
	(effects[2] as Dictionary)["params"] = {"pct": 101}
	(effects[5] as Dictionary)["params"] = {"from": "armor", "to": "armor", "pct": 50}
	(effects[6] as Dictionary)["params"] = {"pct": 50, "extra": 1}
	_expect(raw, [CLASS_FILE, "traits[17].effects[0].params.mult"])
	_expect(raw, [CLASS_FILE, "traits[17].effects[1].params.pct"])
	_expect(raw, [CLASS_FILE, "traits[17].effects[2].params.pct"])
	_expect(raw, [CLASS_FILE, "traits[17].effects[5].params", "must differ"])
	_expect(raw, [CLASS_FILE, "traits[17].effects[6].params.extra", "unknown field"])
	(effects[5] as Dictionary)["params"] = {"from": "ghost", "to": "armor", "pct": 50}
	_expect(raw, [CLASS_FILE, "traits[17].effects[5].params.from", "not in stats.json"])


func test_gathering_monolith_and_card_types_are_rejected_in_a_trait() -> void:
	var raw: Dictionary = V.fixture_raw()
	for type: String in ["gather_bonus_item", "gather_grade_up_pct", "byproduct_mult", "monolith_loot_mult", "card_drop_mult"]:
		_effect(raw, 1)["type"] = type
		_effect(raw, 1)["params"] = {"mult": 2}
		_expect(raw, [CLASS_FILE, "traits[1].effects[0].type", type, "not allowed in a trait"])


func test_a_trait_effect_of_f192_is_rejected_on_a_legendary() -> void:
	var raw: Dictionary = V.fixture_raw()
	var equipment: Dictionary = V.file_of(raw, "items", "equipment.json")
	var extra: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/data/m14/equipment.json"))
	(equipment["items"] as Array).append_array(extra["items"] as Array)
	assert_eq(V.validate(raw), PackedStringArray())
	for entry: Variant in equipment["items"] as Array:
		if (entry as Dictionary)["id"] == "fx_leg_cap":
			(((entry as Dictionary)["equip"] as Dictionary)["legendary"] as Dictionary)["effects"] = [
					{"type": "stack_damage", "gain": "kill", "pct": 5, "max": 5, "lose": "damaged"}]
	_expect(raw, ["item 'fx_leg_cap'", "equip.legendary.effects[0].type", "stack_damage", "not allowed on a legendary"])
