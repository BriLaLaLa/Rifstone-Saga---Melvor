extends "res://tests/data/m10_base.gd"
## M10-01: the blueprint and component categories (04_DATA_SCHEMA.md §5, §18) on the M10 fixtures: one test per rule of
## the validator, then the Defs (BlueprintInfo) and the GameData lookups `blueprints()` and `blueprint_for_base()`.

const BLUEPRINTS: String = "blueprints.json"
const COMPONENTS: String = "components.json"


func _bp(raw: Dictionary, id: String = "bp_test_blade") -> Dictionary:
	return item_of(raw, BLUEPRINTS, id)["blueprint"] as Dictionary


# --- validator ---------------------------------------------------------------------------------------------------

func test_m10_fixtures_are_valid() -> void:
	assert_eq(validate(m10_raw()), PackedStringArray())


func test_blueprint_needs_its_object() -> void:
	var raw: Dictionary = m10_raw()
	item_of(raw, BLUEPRINTS, "bp_test_blade").erase("blueprint")
	expect_error(raw, [BLUEPRINTS, "item 'bp_test_blade'", "missing field 'blueprint'"])


func test_blueprint_object_is_forbidden_for_other_categories() -> void:
	var raw: Dictionary = m10_raw()
	item_of(raw, COMPONENTS, "test_plate_1")["blueprint"] = _bp(raw)
	expect_error(raw, [COMPONENTS, "item 'test_plate_1'", "field 'blueprint' is not allowed for category 'component'"])


func test_component_must_be_in_the_components_file() -> void:
	var raw: Dictionary = m10_raw()
	item_of(raw, COMPONENTS, "test_plate_1")["category"] = "material"
	expect_error(raw, [COMPONENTS, "item 'test_plate_1'", "does not match its file"])


func test_blueprint_unknown_field() -> void:
	var raw: Dictionary = m10_raw()
	_bp(raw)["quality"] = 3
	expect_error(raw, [BLUEPRINTS, "item 'bp_test_blade'", "unknown field 'blueprint.quality'"])


func test_blueprint_base_must_exist() -> void:
	var raw: Dictionary = m10_raw()
	_bp(raw)["base"] = "no_such_piece"
	expect_error(raw, [BLUEPRINTS, "item 'bp_test_blade'", "unknown item 'no_such_piece'"])


func test_blueprint_base_cannot_be_a_tool() -> void:
	var raw: Dictionary = m10_raw()
	_bp(raw)["base"] = "test_hatchet"
	expect_error(raw, [BLUEPRINTS, "item 'bp_test_blade'", "must be an equipment base, not a tool"])


func test_blueprint_base_cannot_be_a_material() -> void:
	var raw: Dictionary = m10_raw()
	_bp(raw)["base"] = "test_log"
	expect_error(raw, [BLUEPRINTS, "item 'bp_test_blade'", "must be an equipment base"])


func test_blueprint_base_cannot_be_a_ring_or_amulet() -> void:
	var raw: Dictionary = m10_raw()
	(item_of(raw, "equipment.json", "test_helm_high")["equip"] as Dictionary)["slot"] = "ring"
	expect_error(raw, [BLUEPRINTS, "item 'bp_test_helm_high'", "they have no blueprint"])
	(item_of(raw, "equipment.json", "test_helm_high")["equip"] as Dictionary)["slot"] = "neck"
	expect_error(raw, [BLUEPRINTS, "item 'bp_test_helm_high'", "they have no blueprint"])


func test_blueprint_grade_must_equal_the_base_grade() -> void:
	var raw: Dictionary = m10_raw()
	_bp(raw)["grade"] = 2
	expect_error(raw, [BLUEPRINTS, "item 'bp_test_blade'", "field 'blueprint.grade': 2 differs from the grade 1"])


func test_blueprint_grade_range() -> void:
	var raw: Dictionary = m10_raw()
	_bp(raw)["grade"] = 9
	expect_error(raw, [BLUEPRINTS, "item 'bp_test_blade'", "blueprint.grade"])


func test_one_blueprint_per_base() -> void:
	var raw: Dictionary = m10_raw()
	_bp(raw, "bp_test_greatsword")["base"] = "test_blade"
	expect_error(raw, [BLUEPRINTS, "item 'bp_test_greatsword'", "blueprint for base 'test_blade' is already given by"])


func test_blueprint_needs_at_least_one_input() -> void:
	var raw: Dictionary = m10_raw()
	_bp(raw)["inputs"] = []
	expect_error(raw, [BLUEPRINTS, "item 'bp_test_blade'", "blueprint.inputs"])


func test_blueprint_inputs_are_components_or_materials() -> void:
	var raw: Dictionary = m10_raw()
	(_bp(raw)["inputs"] as Array)[0] = {"item": "test_ration", "qty": 1}
	expect_error(raw, [BLUEPRINTS, "item 'bp_test_blade'", "'test_ration' must be a component or a material"])


func test_blueprint_inputs_must_exist() -> void:
	var raw: Dictionary = m10_raw()
	(_bp(raw)["inputs"] as Array)[0] = {"item": "no_such_item", "qty": 1}
	expect_error(raw, [BLUEPRINTS, "item 'bp_test_blade'", "unknown item 'no_such_item'"])


func test_blueprint_input_quantity_is_positive() -> void:
	var raw: Dictionary = m10_raw()
	(_bp(raw)["inputs"] as Array)[0] = {"item": "test_plate_1", "qty": 0}
	expect_error(raw, [BLUEPRINTS, "item 'bp_test_blade'", "blueprint.inputs[0]"])


func test_blueprint_needs_a_rare_component() -> void:
	var raw: Dictionary = m10_raw()
	_bp(raw).erase("rare_component")
	expect_error(raw, [BLUEPRINTS, "item 'bp_test_blade'", "missing field 'blueprint.rare_components'"])  # M14: the new name (transitional: the old one is still accepted)


func test_rare_component_is_a_material() -> void:
	var raw: Dictionary = m10_raw()
	_bp(raw)["rare_component"] = {"item": "test_plate_1", "qty": 1}
	expect_error(raw, [BLUEPRINTS, "item 'bp_test_blade'", "blueprint.rare_component.item': 'test_plate_1' must be a material"])


func test_blueprint_is_not_sellable() -> void:
	var raw: Dictionary = m10_raw()
	item_of(raw, BLUEPRINTS, "bp_test_blade")["value"] = 5
	expect_error(raw, [BLUEPRINTS, "item 'bp_test_blade'", "must have 'value' 0"])


func test_blueprint_drops_once() -> void:
	var raw: Dictionary = m10_raw()
	var drops: Array = entry_of(raw, "monsters", "monsters.json", "monsters", 0)["drops"] as Array
	(drops[1] as Dictionary)["qty"] = [1, 2]
	expect_error(raw, ["monster 'test_monster_a'", "drops[1].qty': a blueprint drops as [1, 1]"])


# --- Defs and GameData ---------------------------------------------------------------------------------------------

func test_game_data_loads_the_m10_fixtures() -> void:
	var data: GameData = load_m10()
	assert_eq(data.errors, PackedStringArray())
	assert_true(data.is_valid())


func test_blueprints_are_sorted_by_grade_then_sort_order() -> void:
	var data: GameData = load_m10()
	var ids: Array[StringName] = []
	for def: ItemDef in data.blueprints():
		ids.append(def.id)
	assert_eq(ids, [&"bp_test_blade", &"bp_test_greatsword", &"bp_test_helm_high", &"bp_mw_test_sword_8",
			&"bp_mw_test_chest_11"] as Array[StringName])


func test_blueprint_for_base() -> void:
	var data: GameData = load_m10()
	assert_eq(data.blueprint_for_base(&"test_blade").id, &"bp_test_blade")
	assert_eq(data.blueprint_for_base(&"test_helm_high").id, &"bp_test_helm_high")


func test_blueprint_for_base_without_blueprint_is_null_without_error() -> void:
	var data: GameData = load_m10()
	assert_null(data.blueprint_for_base(&"test_helm"), "a base with no blueprint")
	assert_null(data.blueprint_for_base(&"test_hatchet"), "tools have none")
	assert_null(data.blueprint_for_base(&"no_such_id"))  # an unexpected push_error would fail the test


func test_blueprint_def_fields() -> void:
	var data: GameData = load_m10()
	var def: ItemDef = data.item(&"bp_test_greatsword")
	assert_true(def.is_blueprint())
	assert_false(def.is_component())
	assert_eq(def.category, &"blueprint")
	assert_eq(def.blueprint.base_id, &"test_greatsword")
	assert_eq(def.blueprint.grade, 1)
	assert_eq(def.blueprint.inputs.size(), 2)
	assert_eq(def.blueprint.inputs[0].item_id, &"test_plate_1")
	assert_eq(def.blueprint.inputs[0].qty, 10)
	assert_eq(def.blueprint.rare_component.item_id, &"test_log")
	assert_eq(def.blueprint.rare_component.qty, 2)
	assert_eq(def.value, 0)


func test_component_def() -> void:
	var data: GameData = load_m10()
	var plate: ItemDef = data.item(&"test_plate_3")
	assert_true(plate.is_component())
	assert_false(plate.is_blueprint())
	assert_null(plate.blueprint)
	assert_false(data.item(&"test_log").is_component())


func test_blueprint_def_from_dict_errors() -> void:
	assert_null(BlueprintInfo.from_dict({"base": "x", "grade": 1, "inputs": [], "rare_component": {"item": "a"}}))
	assert_push_error(1)
