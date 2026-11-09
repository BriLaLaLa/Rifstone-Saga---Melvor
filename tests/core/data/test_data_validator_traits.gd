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


func test_ability_kind_and_params() -> void:
	var raw: Dictionary = V.fixture_raw()
	_ability(raw, 0)["kind"] = "fireball"
	_expect(raw, [CLASS_FILE, "abilities[0].kind", "must be one of"])
	_ability(raw, 0)["kind"] = "cleave"
	_params(raw, 0)["targets"] = -1
	_expect(raw, [CLASS_FILE, "abilities[0].params.targets"])
	_params(raw, 0)["targets"] = 0
	_params(raw, 0)["power_mult"] = 0
	_expect(raw, [CLASS_FILE, "abilities[0].params.power_mult"])
	_params(raw, 1)["power_mult"] = 2.0
	_params(raw, 1)["targets"] = 2
	_expect(raw, [CLASS_FILE, "abilities[1].params.targets", "unknown field"])


func test_heal_and_buff_params() -> void:
	var raw: Dictionary = V.fixture_raw()
	_params(raw, 2)["heal_pct"] = 0
	_expect(raw, [CLASS_FILE, "abilities[2].params.heal_pct"])
	_params(raw, 2)["heal_pct"] = 101
	_expect(raw, [CLASS_FILE, "abilities[2].params.heal_pct"])
	_params(raw, 3)["duration_ms"] = 999
	_params(raw, 3)["modifiers"] = []
	_expect(raw, [CLASS_FILE, "abilities[3].params.duration_ms"])
	_expect(raw, [CLASS_FILE, "abilities[3].params.modifiers", "at least 1"])
	_params(raw, 3)["modifiers"] = [{"stat": "ghost", "value": 1}]
	_expect(raw, [CLASS_FILE, "abilities[3].params.modifiers[0]", "ghost"])


func test_ability_cooldown_has_a_floor_and_setups_are_checked() -> void:
	var raw: Dictionary = V.fixture_raw()
	var floor_ms: int = int(DataValidator.lookup(_balance(raw), "combat.min_attack_interval_ms"))
	_ability(raw, 1)["cooldown_ms"] = floor_ms - 1
	_ability(raw, 0)["setups"] = ["axe"]
	_ability(raw, 2)["id"] = "test_whirl"
	_expect(raw, [CLASS_FILE, "abilities[1].cooldown_ms"])
	_expect(raw, [CLASS_FILE, "abilities[0].setups", "unknown setup 'axe'"])
	_expect(raw, [CLASS_FILE, "abilities[2].id", "duplicate 'test_whirl'"])


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
