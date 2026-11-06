extends GutTest
## TraitDef, TraitEffectDef, AbilityDef and the lists of ClassDef (M6-01): the examples of
## docs/04_DATA_SCHEMA.md §14, flattening of the ability params, null on a mistyped field.

const TRAIT: String = """
	{"id": "chain_cleave", "name": "Fendente a catena", "description": "Ogni terzo attacco colpisce tutti i nemici.",
	 "unlock_level": 5, "setups": [],
	 "effects": [{"type": "every_nth_attack_all", "params": {"n": 3}}], "modifiers": []}"""
const WHIRL: String = """
	{"id": "whirl", "name": "Mulinello", "description": "Un giro di spadone che colpisce tutti.",
	 "unlock_level": 1, "setups": ["greatsword"], "kind": "cleave", "cooldown_ms": 9000,
	 "params": {"power_mult": 1.2, "targets": 0}}"""


func _parse(text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed is Dictionary, "test JSON must be an object")
	return parsed as Dictionary


func test_trait_schema_example() -> void:
	var def: TraitDef = TraitDef.from_dict(_parse(TRAIT))
	assert_not_null(def)
	assert_eq(def.id, &"chain_cleave")
	assert_eq(def.unlock_level, 5)
	assert_eq(typeof(def.unlock_level), TYPE_INT)
	assert_true(def.setups.is_empty())
	assert_eq(def.effects.size(), 1)
	assert_eq(def.effects[0].type, &"every_nth_attack_all")
	assert_eq(int(def.effects[0].params["n"]), 3)
	assert_true(def.modifiers.is_empty())


func test_trait_with_modifiers_and_setups() -> void:
	var d: Dictionary = _parse(TRAIT)
	d["setups"] = ["greatsword"]
	d["modifiers"] = [{"stat": "accuracy_pct", "value": 5}]
	var def: TraitDef = TraitDef.from_dict(d)
	assert_eq(def.modifiers.size(), 1)
	assert_eq(def.modifiers[0].stat, &"accuracy_pct")
	assert_true(def.allows_setup(&"greatsword"))
	assert_false(def.allows_setup(&"sword"))
	assert_true(TraitDef.from_dict(_parse(TRAIT)).allows_setup(&"sword"), "empty setups = every setup")


func test_trait_effect_params_are_a_copy() -> void:
	var d: Dictionary = _parse(TRAIT)
	var def: TraitDef = TraitDef.from_dict(d)
	((d["effects"] as Array)[0]["params"] as Dictionary)["n"] = 9
	assert_eq(int(def.effects[0].params["n"]), 3)


func test_trait_missing_or_mistyped_field_is_null() -> void:
	var d: Dictionary = _parse(TRAIT)
	d.erase("effects")
	assert_null(TraitDef.from_dict(d))
	d = _parse(TRAIT)
	d["unlock_level"] = 5.5
	assert_null(TraitDef.from_dict(d))
	d = _parse(TRAIT)
	(d["effects"] as Array)[0] = {"type": "opening_strike"}
	assert_null(TraitDef.from_dict(d))
	assert_push_error(3)


func test_ability_cleave_example() -> void:
	var def: AbilityDef = AbilityDef.from_dict(_parse(WHIRL))
	assert_not_null(def)
	assert_eq(def.kind, AbilityDef.KIND_CLEAVE)
	assert_eq(def.cooldown_ms, 9000)
	assert_eq(def.power_mult, 1.2)
	assert_eq(def.targets, 0)
	assert_eq(def.heal_pct, 0.0)
	assert_eq(def.duration_ms, 0)
	assert_true(def.modifiers.is_empty())
	assert_true(def.allows_setup(&"greatsword"))
	assert_false(def.allows_setup(&"sword"))


func test_ability_kinds_set_only_their_fields() -> void:
	var d: Dictionary = _parse(WHIRL)
	d["kind"] = "strike"
	d["params"] = {"power_mult": 2.0}
	var strike: AbilityDef = AbilityDef.from_dict(d)
	assert_eq(strike.power_mult, 2.0)
	assert_eq(strike.targets, 0)
	d["kind"] = "heal"
	d["params"] = {"heal_pct": 20}
	var heal: AbilityDef = AbilityDef.from_dict(d)
	assert_eq(heal.heal_pct, 20.0)
	assert_eq(heal.power_mult, 0.0)
	d["kind"] = "buff"
	d["params"] = {"modifiers": [{"stat": "damage_reduction", "value": 5}], "duration_ms": 6000}
	var buff: AbilityDef = AbilityDef.from_dict(d)
	assert_eq(buff.duration_ms, 6000)
	assert_eq(buff.modifiers.size(), 1)
	assert_eq(buff.heal_pct, 0.0)


func test_ability_bad_kind_or_missing_param_is_null() -> void:
	var d: Dictionary = _parse(WHIRL)
	d["kind"] = "fireball"
	assert_null(AbilityDef.from_dict(d))
	d = _parse(WHIRL)
	d["params"] = {"power_mult": 1.2}
	assert_null(AbilityDef.from_dict(d))
	assert_push_error(2)


func test_class_lists_from_fixture_data() -> void:
	var def: ClassDef = TestFactory.fixture_data().character_class(&"test_class")
	assert_eq(def.traits.size(), 5)
	assert_eq(def.abilities.size(), 4)
	assert_eq(def.traits[1].id, &"test_cut")
	assert_eq(def.abilities[3].kind, AbilityDef.KIND_BUFF)
