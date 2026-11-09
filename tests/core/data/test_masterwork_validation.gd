extends GutTest
## DataValidator, M14: Masterwork bases (`equip.masterwork`, F-119), the blueprints that craft them (`rare_components`, grade of
## the material, Plates only), the balance keys `rarity.masterwork`, `rarity.legendary`, `blueprint.cost_mult`, `blueprint.extra_rare`
## and the five rarities of `sockets.by_rarity` / `salvage.shards_by_rarity` (docs/04_DATA_SCHEMA.md §21). One test per rule on
## a broken copy of the fixtures plus a Masterwork chest (grade 11, material 6) and its blueprint.

const V: GDScript = preload("res://tests/core/data/test_data_validator.gd")
const BLUEPRINTS_PATH: String = "res://tests/fixtures/data/items/blueprints.json"


func _raw() -> Dictionary:
	var raw: Dictionary = V.fixture_raw()
	var equipment: Dictionary = V.file_of(raw, "items", "equipment.json")
	(equipment["items"] as Array).append({"id": "mw_chest", "name": "Corpo capolavoro", "category": "equipment",
		"icon": "res://assets/icons/items/test_helm.png", "value": 0, "sort_order": 900, "description": "Prova.",
		"equip": {"slot": "body", "grade": 11, "material": "plate", "masterwork": true, "requirements": {"character": 50},
			"modifiers": [{"stat": "armor", "value": 121}]}})
	raw["items"][BLUEPRINTS_PATH] = {"items": [{"id": "bp_mw_chest", "name": "Progetto", "category": "blueprint", "value": 0,
		"sort_order": 1, "icon": "res://assets/icons/items/bp_test_blade.png", "description": "Prova.",
		"blueprint": {"base": "mw_chest", "grade": 6, "inputs": [{"item": "test_plank", "qty": 12}],
			"rare_components": [{"item": "test_log", "qty": 1}, {"item": "test_twig", "qty": 1}]}}]}
	return raw


func _blueprint(raw: Dictionary) -> Dictionary:
	return (((raw["items"] as Dictionary)[BLUEPRINTS_PATH] as Dictionary)["items"] as Array)[0]["blueprint"] as Dictionary


func _chest(raw: Dictionary) -> Dictionary:
	var items: Array = V.file_of(raw, "items", "equipment.json")["items"] as Array
	return (items.back() as Dictionary)["equip"] as Dictionary


func _balance(raw: Dictionary) -> Dictionary:
	var files: Dictionary = raw["balance"]
	return files[files.keys()[0]] as Dictionary


func _expect(raw: Dictionary, fragments: Array[String]) -> void:
	for message: String in V.validate(raw):
		var matched: bool = true
		for fragment: String in fragments:
			matched = matched and message.contains(fragment)
		if matched:
			assert_true(true)
			return
	fail_test("no error with %s in %s" % [fragments, V.validate(raw)])


func test_a_valid_masterwork_and_blueprint_pass() -> void:
	assert_eq(V.validate(_raw()), PackedStringArray())


func test_the_blueprint_of_a_masterwork_has_the_grade_of_the_material() -> void:
	var raw: Dictionary = _raw()
	_blueprint(raw)["grade"] = 11
	_expect(raw, ["item 'bp_mw_chest'", "field 'blueprint.grade': 11 differs from the grade 6 of 'mw_chest'"])


func test_a_masterwork_needs_the_new_form_with_two_rare_components() -> void:
	var raw: Dictionary = _raw()
	var bp: Dictionary = _blueprint(raw)
	bp.erase("rare_components")
	bp["rare_component"] = {"item": "test_log", "qty": 1}
	_expect(raw, ["item 'bp_mw_chest'", "needs them (F-119)"])
	var one: Dictionary = _raw()
	_blueprint(one)["rare_components"] = [{"item": "test_log", "qty": 1}]
	_expect(one, ["item 'bp_mw_chest'", "needs exactly 2 entries"])
	var three: Dictionary = _raw()
	_blueprint(three)["rare_components"] = [{"item": "test_log", "qty": 1}, {"item": "test_twig", "qty": 1}, {"item": "test_plank", "qty": 1}]
	_expect(three, ["item 'bp_mw_chest'", "needs exactly 2 entries"])


func test_the_two_rare_components_are_different_materials() -> void:
	var raw: Dictionary = _raw()
	_blueprint(raw)["rare_components"] = [{"item": "test_log", "qty": 1}, {"item": "test_log", "qty": 2}]
	_expect(raw, ["item 'bp_mw_chest'", "'test_log' is repeated"])
	var not_a_material: Dictionary = _raw()
	_blueprint(not_a_material)["rare_components"] = [{"item": "test_log", "qty": 1}, {"item": "test_blade", "qty": 1}]
	_expect(not_a_material, ["item 'bp_mw_chest'", "'test_blade' must be a material"])


func test_both_forms_together_are_rejected() -> void:
	var raw: Dictionary = _raw()
	_blueprint(raw)["rare_component"] = {"item": "test_log", "qty": 1}
	_expect(raw, ["item 'bp_mw_chest'", "cannot be given together"])


func test_only_plates_have_a_blueprint() -> void:
	var raw: Dictionary = _raw()
	_chest(raw)["material"] = "leather"
	_expect(raw, ["item 'bp_mw_chest'", "only Plates have a blueprint"])
	_expect(raw, ["item 'mw_chest'", "armour Masterworks are only of material 'plate'"])


func test_a_masterwork_without_its_blueprint_is_rejected() -> void:
	var raw: Dictionary = _raw()
	(raw["items"] as Dictionary).erase(BLUEPRINTS_PATH)
	_expect(raw, ["item 'mw_chest'", "no blueprint crafts it"])


func test_the_legacy_blueprint_form_is_still_accepted_for_an_ordinary_base() -> void:
	var raw: Dictionary = V.fixture_raw()
	raw["items"][BLUEPRINTS_PATH] = {"items": [{"id": "bp_old", "name": "Progetto", "category": "blueprint", "value": 0,
		"sort_order": 1, "icon": "res://assets/icons/items/bp_test_blade.png", "description": "Prova.",
		"blueprint": {"base": "test_blade", "grade": 1, "inputs": [{"item": "test_plank", "qty": 5}],
			"rare_component": {"item": "test_log", "qty": 1}}}]}
	assert_eq(V.validate(raw), PackedStringArray(), "TRANSITIONAL until M14-05")
	var def: ItemDef = ItemDef.from_dict(((raw["items"][BLUEPRINTS_PATH] as Dictionary)["items"] as Array)[0] as Dictionary)
	assert_eq(def.blueprint.rare_components.size(), 1)
	assert_eq(def.blueprint.rare_component.item_id, &"test_log")


# --- balance.json --------------------------------------------------------------------------------------------------

func test_the_new_balance_keys_are_required() -> void:
	for key: String in ["rarity.masterwork.base_mult", "rarity.masterwork.affix_count", "rarity.legendary.base_mult",
			"blueprint.cost_mult", "blueprint.extra_rare"]:
		var raw: Dictionary = V.fixture_raw()
		var parts: PackedStringArray = key.split(".")
		var node: Dictionary = _balance(raw)
		for i: int in parts.size() - 1:
			node = node[parts[i]] as Dictionary
		node.erase(parts[-1])
		_expect(raw, ["balance.json", "missing key '%s'" % key])


func test_the_multipliers_and_counts_are_checked() -> void:
	var raw: Dictionary = V.fixture_raw()
	_balance(raw)["rarity"]["masterwork"]["base_mult"] = 0.5
	_balance(raw)["rarity"]["masterwork"]["affix_count"] = [2, 1]
	_balance(raw)["rarity"]["legendary"]["base_mult"] = 11
	_balance(raw)["blueprint"]["cost_mult"] = 0
	_expect(raw, ["balance.json", "rarity.masterwork", "base_mult"])
	_expect(raw, ["balance.json", "rarity.masterwork", "affix_count"])
	_expect(raw, ["balance.json", "rarity.legendary", "base_mult"])
	_expect(raw, ["balance.json", "blueprint", "cost_mult"])


func test_sockets_and_shards_need_the_five_rarities() -> void:
	var raw: Dictionary = V.fixture_raw()
	_balance(raw)["sockets"]["by_rarity"].erase("legendary")
	_balance(raw)["salvage"]["shards_by_rarity"].erase("masterwork")
	_expect(raw, ["balance.json", "sockets.by_rarity.legendary"])
	_expect(raw, ["balance.json", "salvage.shards_by_rarity.masterwork"])


func test_drops_cannot_name_a_masterwork_base() -> void:
	var raw: Dictionary = _raw()
	var monsters: Dictionary = V.file_of(raw, "monsters", "monsters.json")
	((monsters["monsters"] as Array)[0] as Dictionary)["drops"] = [{"item": "mw_chest", "chance_pct": 5, "qty": [1, 1]}]
	_expect(raw, ["monster 'test_monster_a'", "mw_chest", "Masterwork"])
