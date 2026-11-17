extends GutTest
## DataValidatorProfessions (M26-02; docs/04_DATA_SCHEMA_M26.md §31.1-§31.5, rejected cases of §31.8): `colors`, reagents, `profession` shop
## entries, the `vendor` of the Trainers and the Recipe rule (drop or shop). One rule per test on a broken copy of the fixtures
## (helpers of test_data_validator.gd); the real-data rules are called with `strict = true`.

const V: GDScript = preload("res://tests/core/data/test_data_validator.gd")
const TRAINERS: String = "trainers.json"
const SCHEME_ACTION: int = 2  # index of craft_scheme in test_craft.json
const TINT_ACTION: int = 1


func _action(raw: Dictionary, index: int) -> Dictionary:
	return V.entry_of(raw, "actions", "test_craft.json", "actions", index)


func _shop(raw: Dictionary, id: String) -> Dictionary:
	for e: Variant in (V.file_of(raw, "shop", "shop.json")["entries"] as Array):
		if (e as Dictionary)["id"] == id:
			return e as Dictionary
	fail_test("no shop entry %s" % id)
	return {}


func _trainer(raw: Dictionary, index: int) -> Dictionary:
	return V.entry_of(raw, "disciplines", TRAINERS, "trainers", index)


func _item(raw: Dictionary, file_name: String, index: int = 0) -> Dictionary:
	return V.entry_of(raw, "items", file_name, "items", index)


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


# The strict (real data) rules of the Recipes and of the professions, with the rules object filled like DataValidator does.
func _strict_errors(raw: Dictionary) -> PackedStringArray:
	var v := DataValidatorRules.new()
	v.max_skill_level = 99.0
	v.max_character_level = 99.0
	var targets: Dictionary = {"skills": v.skills, "items": v.items, "actions": v.actions}
	for section: String in targets:
		for path: String in raw[section]:
			for e: Variant in ((raw[section][path] as Dictionary)[section] as Array):
				(targets[section] as Dictionary)[StringName((e as Dictionary)["id"] as String)] = e as Dictionary
	for path: String in raw["shop"]:
		for e: Variant in ((raw["shop"][path] as Dictionary)["entries"] as Array):
			v.shop_entries[StringName((e as Dictionary)["id"] as String)] = e as Dictionary
	DataValidatorProfessions.validate(v, raw, true)
	DataValidatorDisciplines._recipes(v, raw, true)
	return v.errors


func _expect_strict(raw: Dictionary, fragment: String) -> void:
	var errors: PackedStringArray = _strict_errors(raw)
	for message: String in errors:
		if message.contains(fragment):
			assert_true(true)
			return
	fail_test("no strict error with '%s' in %s" % [fragment, errors])


# --- the fixtures ----------------------------------------------------------------------------------------------

func test_the_fixtures_with_colors_schemes_and_reagents_are_valid() -> void:
	assert_eq(V.validate(V.fixture_raw()), PackedStringArray())


func test_the_reagent_skill_is_read_from_the_id() -> void:
	assert_eq(DataValidatorProfessions.reagent_skill("reagent_forging_2"), &"forging")
	assert_eq(DataValidatorProfessions.reagent_skill("reagent_test_craft_1"), &"test_craft")
	assert_eq(DataValidatorProfessions.reagent_skill("reagent_forging"), &"")
	assert_eq(DataValidatorProfessions.reagent_skill("plank_2"), &"")


# --- colors (§31.1) --------------------------------------------------------------------------------------------

func test_colors_must_increase() -> void:
	var raw: Dictionary = _raw_with_colors({"yellow": 30, "green": 20, "grey": 40})
	_expect(raw, ["test_craft.json", "action 'craft_tint'", "field 'colors.green' must be >= 31"])


func test_colors_must_be_above_the_level() -> void:
	var raw: Dictionary = _raw_with_colors({"yellow": 2, "green": 30, "grey": 40})
	_expect(raw, ["test_craft.json", "action 'craft_tint'", "field 'colors.yellow' must be >= 3"])


func test_colors_have_a_ceiling_and_exactly_the_three_keys() -> void:
	_expect(_raw_with_colors({"yellow": 20, "green": 30, "grey": 201}), ["field 'colors.grey'"])
	_expect(_raw_with_colors({"yellow": 20, "green": 30}), ["field 'colors.grey'"])
	_expect(_raw_with_colors({"yellow": 20, "green": 30, "grey": 40, "red": 50}), ["unknown field 'colors.red'"])
	_expect(_raw_with_colors({"yellow": 20.5, "green": 30, "grey": 40}), ["field 'colors.yellow'"])


func test_colors_on_a_gathering_action_are_rejected() -> void:
	var raw: Dictionary = V.fixture_raw()
	V.entry_of(raw, "actions", "test_gather.json", "actions", 0)["colors"] = {"yellow": 20, "green": 30, "grey": 40}
	_expect(raw, ["test_gather.json", "field 'colors' is allowed only for artisan actions that are not 'single'"])


func test_colors_on_a_single_action_are_rejected() -> void:
	var raw: Dictionary = V.fixture_raw()
	_action(raw, TINT_ACTION)["single"] = true
	_expect(raw, ["test_craft.json", "field 'colors' is allowed only for artisan actions that are not 'single'"])


func test_the_action_def_reads_the_colors() -> void:
	var data: GameData = TestFactory.fixture_data()
	assert_eq(data.action(&"craft_tint").colors, {&"yellow": 20, &"green": 30, &"grey": 40})
	assert_true(data.action(&"craft_tint").has_colors())
	assert_eq(data.action(&"craft_plank").colors, {})
	assert_false(data.action(&"craft_plank").has_colors())


func _raw_with_colors(colors: Dictionary) -> Dictionary:
	var raw: Dictionary = V.fixture_raw()
	_action(raw, TINT_ACTION)["colors"] = colors
	return raw


# --- Trainers (§31.5) ------------------------------------------------------------------------------------------

func test_a_vendor_is_unique_among_the_trainers() -> void:
	var raw: Dictionary = V.fixture_raw()
	_trainer(raw, 0)["vendor"] = "fabbro"
	_expect(raw, [TRAINERS, "trainer 'test_craft'", "'fabbro' is already the vendor of another Trainer"])


func test_a_vendor_on_a_gathering_discipline_is_rejected() -> void:
	var raw: Dictionary = V.fixture_raw()
	_trainer(raw, 0)["vendor"] = "cuoco"
	_expect(raw, [TRAINERS, "trainer 'test_gather'", "'vendor' is allowed only on an artisan discipline"])


func test_an_unknown_vendor_is_rejected() -> void:
	var raw: Dictionary = V.fixture_raw()
	_trainer(raw, 1)["vendor"] = "nowhere"
	_expect(raw, [TRAINERS, "field 'vendor' must be one of"])


func test_the_trainer_def_reads_the_vendor() -> void:
	var data: GameData = TestFactory.fixture_data()
	assert_eq(data.trainer(&"test_craft").vendor, &"fabbro")
	assert_eq(data.trainer(&"test_gather").vendor, &"")


# --- shop entries (§31.4) --------------------------------------------------------------------------------------

func test_a_profession_entry_of_another_skill_is_rejected() -> void:
	var raw: Dictionary = V.fixture_raw()
	_shop(raw, "buy_recipe_craft_scheme")["requires"] = {"skills": {"test_gather": 5}}
	_expect(raw, ["shop.json", "shop entry 'buy_recipe_craft_scheme'", "field 'requires.skills' must name only the skill 'test_craft'"])


func test_a_profession_entry_with_two_skills_is_rejected() -> void:
	var raw: Dictionary = V.fixture_raw()
	_shop(raw, "buy_reagent_test_craft_1")["requires"] = {"skills": {"test_craft": 5, "test_gather": 5}}
	_expect(raw, ["shop entry 'buy_reagent_test_craft_1'", "field 'requires.skills' must name only"])


func test_a_profession_entry_with_another_vendor_is_rejected() -> void:
	var raw: Dictionary = V.fixture_raw()
	_shop(raw, "buy_recipe_craft_scheme")["vendor"] = "cuoco"
	_expect(raw, ["shop entry 'buy_recipe_craft_scheme'", "field 'vendor' must be the vendor of the Trainer of 'test_craft' (fabbro)"])


func test_a_scheme_must_be_bought_once() -> void:
	var raw: Dictionary = V.fixture_raw()
	_shop(raw, "buy_recipe_craft_scheme")["max_purchases"] = 0
	_expect(raw, ["shop entry 'buy_recipe_craft_scheme'", "field 'max_purchases' must be 1 for a recipe"])


func test_a_reagent_must_be_unlimited() -> void:
	var raw: Dictionary = V.fixture_raw()
	_shop(raw, "buy_reagent_test_craft_1")["max_purchases"] = 3
	_expect(raw, ["shop entry 'buy_reagent_test_craft_1'", "field 'max_purchases' must be 0 for a reagent"])


func test_the_price_must_be_above_the_value_of_what_is_sold() -> void:
	var raw: Dictionary = V.fixture_raw()
	_shop(raw, "buy_reagent_test_craft_1")["cost"] = {"gold": 1}
	_expect(raw, ["shop entry 'buy_reagent_test_craft_1'", "field 'cost.gold' (1) must be above the value of the item sold (1)"])
	var raw_qty: Dictionary = V.fixture_raw()
	_shop(raw_qty, "test_buy_log")["effect"]["item"]["qty"] = 10
	_expect(raw_qty, ["shop entry 'test_buy_log'", "field 'cost.gold' (20) must be above the value of the item sold (30)"])


func test_a_profession_entry_sells_only_a_recipe_or_a_reagent() -> void:
	var raw: Dictionary = V.fixture_raw()
	_shop(raw, "test_buy_log")["category"] = "profession"
	_expect(raw, ["shop entry 'test_buy_log'", "a 'profession' entry must sell a Recipe or a reagent"])


func test_a_profession_entry_without_a_vendor_in_the_trainers() -> void:
	var raw: Dictionary = V.fixture_raw()
	_trainer(raw, 1).erase("vendor")
	_expect(raw, ["shop entry 'buy_recipe_craft_scheme'", "field 'vendor' must be the vendor of the Trainer of 'test_craft' (none)"])


func test_the_shop_reads_by_vendor_and_by_item_sold() -> void:
	var data: GameData = TestFactory.fixture_data()
	var ids: Array[StringName] = []
	for entry: ShopEntryDef in data.shop_entries_of_vendor(&"fabbro"):
		ids.append(entry.id)
	assert_eq(ids, [&"buy_recipe_craft_scheme", &"buy_reagent_test_craft_1"] as Array[StringName], "file order")
	assert_true(data.shop_entries_of_vendor(&"cuoco").is_empty())
	assert_eq(data.shop_entry_selling(&"recipe_craft_scheme").id, &"buy_recipe_craft_scheme")
	assert_eq(data.shop_entry_selling(&"reagent_test_craft_1").id, &"buy_reagent_test_craft_1")
	assert_null(data.shop_entry_selling(&"recipe_secret"), "no entry sells it: null without error")
	assert_null(data.shop_entry_selling(&"nothing"))


# --- reagents (§31.3) ------------------------------------------------------------------------------------------

func test_a_reagent_cannot_be_the_output_of_an_action() -> void:
	var raw: Dictionary = V.fixture_raw()
	(_action(raw, TINT_ACTION)["outputs"] as Array)[0]["item"] = "reagent_test_craft_1"
	_expect(raw, ["test_craft.json", "action 'craft_tint'", "reagent 'reagent_test_craft_1' cannot be the output of an action"])


func test_a_reagent_is_an_input_only_of_discover_actions() -> void:
	var raw: Dictionary = V.fixture_raw()
	_action(raw, SCHEME_ACTION).erase("discover")
	_expect(raw, ["action 'craft_scheme'", "reagent 'reagent_test_craft_1' is an input of an action without 'discover: true'"])


func test_a_reagent_of_another_skill_is_rejected() -> void:
	var raw: Dictionary = V.fixture_raw()
	_item(raw, "reagents.json")["id"] = "reagent_test_gather_1"
	((_action(raw, SCHEME_ACTION)["inputs"] as Array)[1] as Dictionary)["item"] = "reagent_test_gather_1"
	_shop(raw, "buy_reagent_test_craft_1")["effect"]["item"]["item"] = "reagent_test_gather_1"
	_expect(raw, ["action 'craft_scheme'", "reagent 'reagent_test_gather_1' is an input of an action of another skill"])


func test_a_reagent_has_no_other_sub_object() -> void:
	var raw: Dictionary = V.fixture_raw()
	_item(raw, "reagents.json")["food"] = {"heal": 5}
	_expect(raw, ["reagents.json", "'food' is not allowed"])


func test_a_reagent_must_live_in_the_reagents_file() -> void:
	var raw: Dictionary = V.fixture_raw()
	_item(raw, "reagents.json")["category"] = "material"
	_expect(raw, ["reagents.json", "does not match its file (expected 'reagent')"])


func test_the_reagent_is_sorted_after_the_materials() -> void:
	var sorted: Array[StringName] = Bank.SORT_CATEGORIES
	assert_eq(sorted.find(&"reagent"), sorted.find(&"material") + 1)


# --- the Recipe rule: a loot table or the shop (§31.2) ---------------------------------------------------------

func test_a_recipe_in_a_loot_table_and_in_the_shop_is_rejected() -> void:
	var raw: Dictionary = V.fixture_raw()
	var entries: Array = (V.file_of(raw, "loot_tables", "loot_tables.json")["tables"] as Array)[0]["entries"]
	entries.append({"item": "recipe_craft_scheme", "chance_pct": 1, "qty": [1, 1]})
	_expect(raw, ["items", "Recipe 'recipe_craft_scheme' is both in a loot table and sold in the shop"])


func test_strict_a_recipe_in_neither_a_table_nor_the_shop_is_rejected() -> void:
	var raw: Dictionary = V.fixture_raw()
	var list: Array = V.file_of(raw, "shop", "shop.json")["entries"]
	list.erase(_shop(raw, "buy_recipe_craft_scheme"))
	_expect_strict(raw, "Recipe 'recipe_craft_scheme' is in no loot table and in no shop entry")
	_expect_strict(V.fixture_raw(), "Recipe 'recipe_secret' is in no loot table and in no shop entry")


func test_strict_a_scheme_sold_by_the_shop_needs_no_loot_table() -> void:
	for message: String in _strict_errors(V.fixture_raw()):
		assert_false(message.contains("recipe_craft_scheme"), message)


# --- real data (strict, with colors) ----------------------------------------------------------------------------

func test_strict_the_real_trainers_need_their_vendor() -> void:
	_expect_strict(V.fixture_raw(), "the Trainer of 'forging' must have vendor 'fabbro'")
	_expect_strict(V.fixture_raw(), "the Trainer of 'hearthcraft' must have vendor 'cuoco'")


func test_the_real_rules_are_off_while_no_action_has_colors() -> void:
	var raw: Dictionary = V.fixture_raw()
	_action(raw, TINT_ACTION).erase("colors")
	_action(raw, SCHEME_ACTION).erase("colors")
	for message: String in _strict_errors(raw):
		assert_false(message.contains("must have vendor"), message)


func test_strict_a_scheme_requires_the_level_of_its_action() -> void:
	var raw: Dictionary = V.fixture_raw()
	_shop(raw, "buy_recipe_craft_scheme")["requires"] = {"skills": {"test_craft": 9}}
	_expect_strict(raw, "field 'requires.skills.test_craft' must be the level of the action (5)")


# --- TestFactory helpers (§5.36) -----------------------------------------------------------------------------

func test_teach_recipes_and_give_reagents_helpers() -> void:
	var session: GameSession = TestFactory.session()
	assert_false(session.disciplines.knows_recipe(&"craft_scheme"))
	TestFactory.teach_recipes(session, &"test_craft")
	assert_true(session.disciplines.knows_recipe(&"craft_scheme"))
	assert_false(session.disciplines.knows_recipe(&"craft_secret"), "another skill: untouched")
	TestFactory.give_reagents(session, &"test_craft", 3)
	assert_eq(session.bank.get_count(&"reagent_test_craft_1"), 3)
