extends GutTest
## ClassDef and SetupDef: the example of docs/04_DATA_SCHEMA.md §14 and the setup derivation of F-72.

const RIFT_BLADE: String = """
	{"id": "rift_blade", "name": "Lama del Rift", "order": 1, "icon": "res://assets/icons/classes/rift_blade.svg",
	 "description": "Combatte solo con le spade, in tre assetti.",
	 "weapon_kinds": ["greatsword", "sword"], "offhand_kinds": ["shield", "sword"],
	 "setups": [
	   {"id": "greatsword", "name": "Spadone", "weapon": "greatsword", "offhand": "", "modifiers": []},
	   {"id": "sword_shield", "name": "Spada e scudo", "weapon": "sword", "offhand": "shield", "modifiers": []},
	   {"id": "dual_swords", "name": "Due spade", "weapon": "sword", "offhand": "sword", "alternate": true,
	    "modifiers": [{"stat": "accuracy_pct", "value": -10}]},
	   {"id": "sword", "name": "Spada", "weapon": "sword", "offhand": "", "modifiers": []}
	 ],
	 "traits": [], "abilities": []}"""


func _parse(text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed is Dictionary, "test JSON must be an object")
	return parsed as Dictionary


func test_class_schema_example() -> void:
	var def: ClassDef = ClassDef.from_dict(_parse(RIFT_BLADE))
	assert_not_null(def)
	assert_eq(def.id, &"rift_blade")
	assert_eq(def.name, "Lama del Rift")
	assert_eq(def.description, "Combatte solo con le spade, in tre assetti.")
	assert_eq(def.order, 1)
	assert_eq(typeof(def.order), TYPE_INT)
	assert_eq(def.weapon_kinds, [&"greatsword", &"sword"] as Array[StringName])
	assert_eq(def.offhand_kinds, [&"shield", &"sword"] as Array[StringName])
	assert_eq(def.setups.size(), 4)


func test_setup_fields() -> void:
	var def: ClassDef = ClassDef.from_dict(_parse(RIFT_BLADE))
	var dual: SetupDef = def.setups[2]
	assert_eq(dual.id, &"dual_swords")
	assert_eq(dual.name, "Due spade")
	assert_eq(dual.weapon_kind, &"sword")
	assert_eq(dual.offhand_kind, &"sword")
	assert_true(dual.alternate)
	assert_eq(dual.modifiers.size(), 1)
	assert_eq(dual.modifiers[0].stat, &"accuracy_pct")
	assert_eq(dual.modifiers[0].value, -10.0)
	assert_false(def.setups[0].alternate, "alternate defaults to false")
	assert_eq(def.setups[0].offhand_kind, &"")


func test_setup_derivation_examples_of_f72() -> void:
	var def: ClassDef = ClassDef.from_dict(_parse(RIFT_BLADE))
	assert_eq(def.setup_for(&"greatsword", &"").id, &"greatsword")
	assert_eq(def.setup_for(&"sword", &"shield").id, &"sword_shield")
	assert_eq(def.setup_for(&"sword", &"sword").id, &"dual_swords")
	assert_eq(def.setup_for(&"sword", &"").id, &"sword")


func test_setup_for_without_a_match_is_null() -> void:
	var def: ClassDef = ClassDef.from_dict(_parse(RIFT_BLADE))
	assert_null(def.setup_for(&"", &"shield"), "no weapon: unarmed is not a setup of the class")
	assert_null(def.setup_for(&"greatsword", &"shield"))


func test_setup_for_takes_the_first_in_file_order() -> void:
	var d: Dictionary = _parse(RIFT_BLADE)
	(d["setups"] as Array).append({"id": "sword_again", "name": "Bis", "weapon": "sword", "offhand": "",
			"modifiers": []})
	var def: ClassDef = ClassDef.from_dict(d)
	assert_eq(def.setup_for(&"sword", &"").id, &"sword")


func test_class_missing_field_is_null() -> void:
	var d: Dictionary = _parse(RIFT_BLADE)
	d.erase("weapon_kinds")
	assert_null(ClassDef.from_dict(d))
	assert_push_error(1)


func test_class_with_a_bad_setup_is_null() -> void:
	var d: Dictionary = _parse(RIFT_BLADE)
	((d["setups"] as Array)[1] as Dictionary).erase("weapon")
	assert_null(ClassDef.from_dict(d))
	assert_push_error(1)


func test_setup_with_a_bad_modifier_is_null() -> void:
	var setup: Dictionary = {"id": "x", "name": "X", "weapon": "sword", "offhand": "",
			"modifiers": [{"stat": "accuracy_pct", "value": 1, "scope": "zone:x"}]}
	assert_null(SetupDef.from_dict(setup))
	assert_push_error(1)
