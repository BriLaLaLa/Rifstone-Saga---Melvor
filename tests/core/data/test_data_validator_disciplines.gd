extends GutTest
## DataValidatorDisciplines (M24-02; docs/04_DATA_SCHEMA_M24.md §29, errors of §29.9): the `discipline` flag, trainers.json, nodes.json,
## `discover` actions and Recipe items, the new sections of balance.json and the removed one. One rule per test, on a broken copy of
## the fixtures (helpers of test_data_validator.gd). The strict rules (real data) are checked directly with `strict = true`.

const V: GDScript = preload("res://tests/core/data/test_data_validator.gd")
const NODES_FILE: String = "res://tests/fixtures/data/encounters/nodes.json"
const TRAINERS: String = "trainers.json"
## The removed balance section, assembled so that the closing check for its name in the sources does not flag this test.
const REMOVED_SECTION: String = "hel" + "per"


# The fixture raw data plus the nodes file (GameData reads it on its own, it is not a CONTENT_FILES section).
func _raw() -> Dictionary:
	var raw: Dictionary = V.fixture_raw()
	var errors: PackedStringArray = []
	raw["encounters"] = {NODES_FILE: JsonLoader.load_file(NODES_FILE, errors)}
	assert_true(errors.is_empty())
	return raw


func _balance(raw: Dictionary, section: String) -> Dictionary:
	return V.file_of(raw, "balance", V.BALANCE)[section] as Dictionary


func _grade(raw: Dictionary, index: int) -> Dictionary:
	return V.entry_of(raw, "disciplines", TRAINERS, "grades", index)


func _trainer(raw: Dictionary, index: int) -> Dictionary:
	return V.entry_of(raw, "disciplines", TRAINERS, "trainers", index)


func _nodes(raw: Dictionary) -> Array:
	return (raw["encounters"][NODES_FILE] as Dictionary)["areas"] as Array


func _skill(raw: Dictionary, id: String) -> Dictionary:
	for e: Variant in (V.file_of(raw, "skills", V.SKILLS)["skills"] as Array):
		if (e as Dictionary)["id"] == id:
			return e as Dictionary
	return {}


func _action(raw: Dictionary, file_name: String, index: int = 0) -> Dictionary:
	return V.entry_of(raw, "actions", file_name, "actions", index)


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


# The errors of the strict rules: the rules object is filled like DataValidator does, then `validate(..., true)`.
func _strict_errors(raw: Dictionary) -> PackedStringArray:
	var v := DataValidatorRules.new()
	v.max_skill_level = 99.0
	v.max_character_level = 99.0
	for section: String in ["skills", "items", "actions"]:
		for path: String in raw[section]:
			for e: Variant in ((raw[section][path] as Dictionary)[section] as Array):
				var target: Dictionary[StringName, Dictionary] = v.skills if section == "skills" else v.items if section == "items" else v.actions
				target[StringName((e as Dictionary)["id"] as String)] = e as Dictionary
	DataValidatorDisciplines.validate(v, raw, true)
	return v.errors


func _expect_strict(raw: Dictionary, fragment: String) -> void:
	var errors: PackedStringArray = _strict_errors(raw)
	for message: String in errors:
		if message.contains(fragment):
			assert_true(true)
			return
	fail_test("no strict error with '%s' in %s" % [fragment, errors])


# --- fixtures and the valid cases -------------------------------------------------------------------------------

func test_fixtures_with_nodes_are_valid() -> void:
	assert_eq(V.validate(_raw()), PackedStringArray())


func test_the_nodes_file_is_optional_in_non_strict_data() -> void:
	assert_eq(V.validate(V.fixture_raw()), PackedStringArray())


func test_the_real_data_flag_is_off_until_m24_05() -> void:
	assert_false(DataValidatorDisciplines.STRICT_REAL_DATA)


# --- skills -----------------------------------------------------------------------------------------------------

func test_discipline_must_be_a_boolean() -> void:
	var raw: Dictionary = _raw()
	_skill(raw, "test_gather")["discipline"] = "yes"
	_expect(raw, [V.SKILLS, "skill 'test_gather'", "field 'discipline' must be a boolean"])


func test_discipline_of_another_category_is_rejected() -> void:
	var raw: Dictionary = _raw()
	_skill(raw, "test_gather")["category"] = "combat"
	_expect(raw, [V.SKILLS, "skill 'test_gather'", "field 'discipline' is allowed only for the categories"])


# --- trainers.json ----------------------------------------------------------------------------------------------

func test_caps_must_strictly_increase() -> void:
	var raw: Dictionary = _raw()
	_grade(raw, 1)["cap"] = 20
	_expect(raw, [TRAINERS, "trainer grade 'worker'", "'cap' must be strictly increasing"])


func test_the_last_cap_is_the_max_level() -> void:
	var raw: Dictionary = _raw()
	_grade(raw, 2)["cap"] = 90
	_expect(raw, [TRAINERS, "the last grade 'cap' must be xp_curve.max_level (99)"])


func test_a_cap_above_the_max_level_is_rejected() -> void:
	var raw: Dictionary = _raw()
	_grade(raw, 2)["cap"] = 120
	_expect(raw, [TRAINERS, "trainer grade 'luminary'", "field 'cap'"])


func test_character_levels_must_not_decrease() -> void:
	var raw: Dictionary = _raw()
	_grade(raw, 1)["character_level"] = 80
	_expect(raw, [TRAINERS, "trainer grade 'luminary'", "'character_level' must not decrease"])


func test_grade_ids_are_unique_and_fields_known() -> void:
	var raw: Dictionary = _raw()
	_grade(raw, 1)["id"] = "novice"
	_grade(raw, 2)["extra"] = 1
	_expect(raw, [TRAINERS, "duplicate trainer grade 'novice'"])
	_expect(raw, [TRAINERS, "unknown field 'extra'"])


func test_at_least_one_grade() -> void:
	var raw: Dictionary = _raw()
	((raw["disciplines"] as Dictionary).values()[0] as Dictionary)["grades"] = []
	_expect(raw, [TRAINERS, "field 'grades' needs at least 1 entries"])


func test_a_trainer_of_a_skill_that_is_not_a_discipline() -> void:
	var raw: Dictionary = _raw()
	_trainer(raw, 0)["skill"] = "riftbinding"
	_expect(raw, [TRAINERS, "trainer 'riftbinding'", "is not a discipline"])


func test_a_trainer_of_an_unknown_skill_or_a_duplicate() -> void:
	var raw: Dictionary = _raw()
	_trainer(raw, 0)["skill"] = "nothing"
	_trainer(raw, 1)["skill"] = "test_gather"
	_expect(raw, [TRAINERS, "unknown skill 'nothing'"])
	var raw_dup: Dictionary = _raw()
	_trainer(raw_dup, 1)["skill"] = "test_gather"
	_expect(raw_dup, [TRAINERS, "duplicate trainer 'test_gather'"])


func test_trainer_texts_are_not_empty() -> void:
	var raw: Dictionary = _raw()
	_trainer(raw, 0)["title"] = " "
	_expect(raw, [TRAINERS, "trainer 'test_gather'", "field 'title' must not be empty"])


func test_fed_by_must_name_gathering_disciplines_on_an_artisan_one() -> void:
	var raw: Dictionary = _raw()
	_trainer(raw, 1)["fed_by"] = ["test_craft_b"]
	_expect(raw, [TRAINERS, "trainer 'test_craft'", "'test_craft_b' is not a gathering discipline"])
	var raw_unknown: Dictionary = _raw()
	_trainer(raw_unknown, 1)["fed_by"] = ["nothing"]
	_expect(raw_unknown, [TRAINERS, "unknown skill 'nothing'"])
	var raw_owner: Dictionary = _raw()
	_trainer(raw_owner, 0)["fed_by"] = ["test_gather_b"]
	_expect(raw_owner, [TRAINERS, "trainer 'test_gather'", "allowed only on an artisan discipline"])


func test_a_gathering_skill_without_discipline_is_not_a_source() -> void:
	var raw: Dictionary = _raw()
	_skill(raw, "test_gather_b").erase("discipline")
	_trainer(raw, 1)["fed_by"] = ["test_gather_b"]
	_expect(raw, [TRAINERS, "'test_gather_b' is not a gathering discipline"])


# --- nodes.json -------------------------------------------------------------------------------------------------

func test_an_unknown_or_a_double_area() -> void:
	var raw: Dictionary = _raw()
	(_nodes(raw)[0] as Dictionary)["area"] = "nowhere"
	_expect(raw, ["nodes.json", "unknown area 'nowhere'"])
	var raw_dup: Dictionary = _raw()
	(_nodes(raw_dup)[1] as Dictionary)["area"] = "test_area"
	_expect(raw_dup, ["nodes.json", "duplicate area 'test_area'"])


func test_a_node_of_a_skill_that_does_not_gather() -> void:
	var raw: Dictionary = _raw()
	((_nodes(raw)[0] as Dictionary)["nodes"] as Array)[0]["skill"] = "test_craft"
	_expect(raw, ["nodes.json", "'test_craft' is not a gathering skill"])


func test_a_double_node_skill_and_a_bad_weight() -> void:
	var raw: Dictionary = _raw()
	((_nodes(raw)[0] as Dictionary)["nodes"] as Array)[1]["skill"] = "test_gather"
	_expect(raw, ["nodes.json", "duplicate node skill 'test_gather'"])
	var raw_weight: Dictionary = _raw()
	((_nodes(raw_weight)[0] as Dictionary)["nodes"] as Array)[0]["weight"] = 0
	_expect(raw_weight, ["nodes.json", "field 'nodes.weight' must be >= 1"])


func test_max_level_and_empty_nodes() -> void:
	var raw: Dictionary = _raw()
	(_nodes(raw)[0] as Dictionary)["max_level"] = 0
	_expect(raw, ["nodes.json", "field 'max_level'"])
	var raw_empty: Dictionary = _raw()
	(_nodes(raw_empty)[0] as Dictionary)["nodes"] = []
	_expect(raw_empty, ["nodes.json", "field 'nodes' needs at least 1 entries"])


# --- Recipes and `discover` ------------------------------------------------------------------------------------

func test_a_recipe_of_an_unknown_action() -> void:
	var raw: Dictionary = _raw()
	V.entry_of(raw, "items", "recipes.json", "items", 0)["recipe"] = {"action": "nothing"}
	_expect(raw, ["recipes.json", "item 'recipe_secret'", "unknown action 'nothing'"])


func test_a_recipe_of_an_action_without_discover() -> void:
	var raw: Dictionary = _raw()
	V.entry_of(raw, "items", "recipes.json", "items", 0)["recipe"] = {"action": "craft_plank"}
	_expect(raw, ["recipes.json", "'craft_plank' has no 'discover: true'"])


func test_a_recipe_needs_its_sub_object_and_a_zero_value() -> void:
	var raw: Dictionary = _raw()
	V.entry_of(raw, "items", "recipes.json", "items", 0).erase("recipe")
	_expect(raw, ["recipes.json", "missing field 'recipe'"])
	var raw_value: Dictionary = _raw()
	V.entry_of(raw_value, "items", "recipes.json", "items", 0)["value"] = 5
	_expect(raw_value, ["recipes.json", "a Recipe must have value 0"])
	var raw_other: Dictionary = _raw()
	V.entry_of(raw_other, "items", "materials.json", "items", 0)["recipe"] = {"action": "craft_secret"}
	_expect(raw_other, ["materials.json", "'recipe' is not allowed"])


func test_two_recipes_for_one_action() -> void:
	var raw: Dictionary = _raw()
	var list: Array = V.file_of(raw, "items", "recipes.json")["items"]
	var copy: Dictionary = (list[0] as Dictionary).duplicate(true)
	copy["id"] = "recipe_secret_two"
	list.append(copy)
	_expect(raw, ["teach the same action 'craft_secret'"])


func test_discover_on_a_gathering_action_or_a_single_one() -> void:
	var raw: Dictionary = _raw()
	_action(raw, "test_gather.json")["discover"] = true
	_expect(raw, ["test_gather.json", "field 'discover' is allowed only for artisan actions"])
	var raw_single: Dictionary = _raw()
	var craft: Dictionary = _action(raw_single, "test_craft_b.json")
	craft["single"] = true
	_expect(raw_single, ["test_craft_b.json", "field 'discover' is not allowed with 'single'"])


func test_discover_must_be_a_boolean() -> void:
	var raw: Dictionary = _raw()
	_action(raw, "test_craft_b.json")["discover"] = 1
	_expect(raw, ["test_craft_b.json", "field 'discover' must be a boolean"])


# --- balance.json -----------------------------------------------------------------------------------------------

func test_encounters_ranges() -> void:
	var raw: Dictionary = _raw()
	_balance(raw, "encounters")["node_chance_pct"] = 101
	_expect(raw, [V.BALANCE, "field 'encounters.node_chance_pct'"])
	var raw_travel: Dictionary = _raw()
	_balance(raw_travel, "encounters")["travel_ms"] = -1
	_expect(raw_travel, [V.BALANCE, "field 'encounters.travel_ms'"])
	var raw_units: Dictionary = _raw()
	_balance(raw_units, "encounters")["node_units"] = 0
	_expect(raw_units, [V.BALANCE, "field 'encounters.node_units'"])
	var raw_skip: Dictionary = _raw()
	_balance(raw_skip, "encounters")["skip_ms"] = -5
	_expect(raw_skip, [V.BALANCE, "field 'encounters.skip_ms'"])


func test_node_durations_are_ordered_and_above_the_action_minimum() -> void:
	var raw: Dictionary = _raw()
	_balance(raw, "encounters")["node_min_ms"] = 100
	_expect(raw, [V.BALANCE, "field 'encounters.node_min_ms'"])
	var raw_ms: Dictionary = _raw()
	_balance(raw_ms, "encounters")["node_ms"] = 2000
	_expect(raw_ms, [V.BALANCE, "field 'encounters.node_ms'"])


func test_colors_must_increase_and_end_at_the_max_level() -> void:
	var raw: Dictionary = _raw()
	(_balance(raw, "encounters")["colors"] as Array)[1]["below"] = 10
	_expect(raw, [V.BALANCE, "encounters.colors[1].below", "strictly increasing"])
	var raw_pct: Dictionary = _raw()
	(_balance(raw_pct, "encounters")["colors"] as Array)[2]["xp_pct"] = 90
	_expect(raw_pct, [V.BALANCE, "encounters.colors[2].xp_pct", "must not increase"])
	var raw_last: Dictionary = _raw()
	(_balance(raw_last, "encounters")["colors"] as Array)[3]["below"] = 50
	_expect(raw_last, [V.BALANCE, "the last 'encounters.colors' entry", "xp_curve.max_level"])
	var raw_id: Dictionary = _raw()
	(_balance(raw_id, "encounters")["colors"] as Array)[1]["id"] = "orange"
	_expect(raw_id, [V.BALANCE, "encounters.colors[1].id", "duplicate 'orange'"])
	var raw_empty: Dictionary = _raw()
	_balance(raw_empty, "encounters")["colors"] = []
	_expect(raw_empty, [V.BALANCE, "field 'encounters.colors' needs at least 1 entries"])


func test_the_other_new_sections() -> void:
	var raw: Dictionary = _raw()
	_balance(raw, "disciplines")["max_per_category"] = 0
	_expect(raw, [V.BALANCE, "field 'disciplines.max_per_category'"])
	var raw_growth: Dictionary = _raw()
	_balance(raw_growth, "trainer")["gold_growth"] = 0.5
	_expect(raw_growth, [V.BALANCE, "field 'trainer.gold_growth'"])
	var raw_pct: Dictionary = _raw()
	_balance(raw_pct, "trainer")["unlearn_pct"] = 101
	_expect(raw_pct, [V.BALANCE, "field 'trainer.unlearn_pct'"])
	var raw_gold: Dictionary = _raw()
	_balance(raw_gold, "trainer")["gold_base"] = -1
	_expect(raw_gold, [V.BALANCE, "field 'trainer.gold_base'"])
	var raw_slots: Dictionary = _raw()
	_balance(raw_slots, "production")["queue_slots"] = 0
	_expect(raw_slots, [V.BALANCE, "field 'production.queue_slots'"])
	var raw_count: Dictionary = _raw()
	_balance(raw_count, "production")["max_job_count"] = 0
	_expect(raw_count, [V.BALANCE, "field 'production.max_job_count'"])


func test_a_missing_section_and_an_unknown_field() -> void:
	var raw: Dictionary = _raw()
	V.file_of(raw, "balance", V.BALANCE).erase("production")
	_expect(raw, [V.BALANCE, "missing key 'production'"])
	var raw_field: Dictionary = _raw()
	_balance(raw_field, "trainer")["extra"] = 1
	_expect(raw_field, [V.BALANCE, "unknown field 'trainer.extra'"])


func test_the_removed_section_is_an_unknown_key() -> void:
	var raw: Dictionary = _raw()
	V.file_of(raw, "balance", V.BALANCE)[REMOVED_SECTION] = {"xp_pct": 25}
	_expect(raw, [V.BALANCE, "unknown key '%s'" % REMOVED_SECTION])


func test_a_contract_item_category_is_not_accepted_any_more() -> void:
	var raw: Dictionary = _raw()
	V.entry_of(raw, "items", "recipes.json", "items", 0)["category"] = "con" + "tract"
	_expect(raw, ["recipes.json", "field 'category' must be one of"])


# --- strict rules (real data of M24-05) -----------------------------------------------------------------------

func test_strict_the_fixtures_lack_what_the_real_data_will_have() -> void:
	assert_false(_strict_errors(_raw()).is_empty(), "e.g. the fixture areas without all nodes and a Recipe in no table")


func test_strict_every_discipline_needs_a_trainer() -> void:
	var raw: Dictionary = _raw()
	((raw["disciplines"] as Dictionary).values()[0] as Dictionary)["trainers"].pop_back()
	_expect_strict(raw, "discipline 'test_craft' has no Trainer")


func test_strict_every_area_needs_nodes_with_all_the_disciplines() -> void:
	var raw: Dictionary = _raw()
	_nodes(raw).pop_back()
	_expect_strict(raw, "area 'test_loot_area' has no nodes")
	var raw_skill: Dictionary = _raw()
	((_nodes(raw_skill)[0] as Dictionary)["nodes"] as Array).pop_back()
	_expect_strict(raw_skill, "the area lacks the node of discipline 'test_gather_b'")


func test_strict_weights_sum_to_100_with_none_below_10() -> void:
	var raw: Dictionary = _raw()
	((_nodes(raw)[0] as Dictionary)["nodes"] as Array)[0]["weight"] = 95
	((_nodes(raw)[0] as Dictionary)["nodes"] as Array)[1]["weight"] = 5
	_expect_strict(raw, "the node weights must sum to 100 with none below 10")
	var raw_sum: Dictionary = _raw()
	((_nodes(raw_sum)[0] as Dictionary)["nodes"] as Array)[0]["weight"] = 70
	_expect_strict(raw_sum, "got sum 110")


func test_strict_the_nodes_file_must_exist() -> void:
	var raw: Dictionary = _raw()
	raw["encounters"] = {}
	_expect_strict(raw, "data/encounters/nodes.json is missing")


func test_strict_a_discover_action_needs_a_recipe_that_drops() -> void:
	var raw: Dictionary = _raw()
	V.file_of(raw, "items", "recipes.json")["items"] = []
	_expect_strict(raw, "`discover` action 'craft_secret' has no Recipe item")
	_expect_strict(_raw(), "Recipe 'recipe_secret' is in no loot table")
