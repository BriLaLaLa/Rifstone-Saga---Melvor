extends GutTest
## GameData reads of M24-02 (docs/05_INTERFACES_M24.md §4b, 04_DATA_SCHEMA_M24.md §29): disciplines, Trainer grades and
## Trainers, area nodes and the Recipe item of an action, on the fixtures and on the real data; absent things are null without error.

var _fixture: GameData
var _real: GameData


func before_all() -> void:
	_fixture = TestFactory.fixture_data()
	_real = TestFactory.real_data()


func test_disciplines_by_category_in_order() -> void:
	assert_eq(_fixture.disciplines(), [&"test_gather", &"test_gather_b", &"test_craft", &"test_craft_b"] as Array[StringName])
	assert_eq(_fixture.disciplines(&"gathering"), [&"test_gather", &"test_gather_b"] as Array[StringName])
	assert_eq(_fixture.disciplines(&"artisan"), [&"test_craft", &"test_craft_b"] as Array[StringName])
	assert_true(_fixture.disciplines(&"nothing").is_empty())
	assert_true(_fixture.skill(&"test_gather").discipline)
	assert_false(_fixture.skill(&"riftbinding").discipline, "the Engraver is always available")


func test_the_real_disciplines_are_the_eight_trades() -> void:
	assert_eq(_real.disciplines(&"gathering"), [&"forestry", &"quarrying", &"angling", &"herbalism"] as Array[StringName])
	assert_eq(_real.disciplines(&"artisan"), [&"forging", &"hearthcraft", &"woodwright", &"riftbinding"] as Array[StringName])
	assert_true(_real.skill(&"riftbinding").discipline)


func test_trainer_grades_follow_f158() -> void:
	var grades: Array[TrainerGradeDef] = _real.trainer_grades()
	assert_eq(grades.size(), 5)
	var caps: Array[int] = []
	var levels: Array[int] = []
	for grade: TrainerGradeDef in grades:
		caps.append(grade.cap)
		levels.append(grade.character_level)
	assert_eq(caps, [20, 40, 60, 80, 99] as Array[int])
	assert_eq(levels, [1, 15, 35, 55, 75] as Array[int])
	assert_eq(grades[0].id, &"novice")
	assert_eq(grades[0].name, "Novizio")
	assert_eq(grades[4].name, "Luminare")


func test_trainer_grade_is_one_based_and_null_outside() -> void:
	assert_eq(_real.trainer_grade(1).cap, 20)
	assert_eq(_real.trainer_grade(5).cap, 99)
	assert_null(_real.trainer_grade(0))
	assert_null(_real.trainer_grade(6))
	assert_null(_real.trainer_grade(-1))


func test_the_grade_gold_table_of_f158() -> void:
	var gold: Array[int] = []
	for grade: int in range(1, 6):
		gold.append(TrainerGradeDef.gold(_real, grade))
	assert_eq(gold, [0, 25000, 125000, 625000, 3125000] as Array[int])
	var total: int = 0
	for value: int in gold:
		total += value
	assert_eq(total, 3900000, "the total cost up to the fifth grade")
	assert_eq(TrainerGradeDef.gold(_real, 0), 0)


func test_the_trainer_grades_guide_table() -> void:
	var rows: Array[Array] = GuideTables.build("trainer_grades", _real)
	assert_eq(rows.size(), 6)
	assert_eq(rows[0], ["Grado", "Livello massimo", "Livello del personaggio", "Monete"] as Array)
	assert_eq(rows[2], ["Lavorante", "40", "15", "2g 50s"] as Array)
	assert_eq(rows[5], ["Luminare", "99", "75", "312g 50s"] as Array)


func test_trainer_is_null_without_error_when_absent() -> void:
	assert_not_null(_real.trainer(&"forestry"), "the real Trainers (M24-05)")
	assert_null(_real.trainer(&"nothing"))
	assert_eq(_fixture.trainer(&"test_gather").name, "Maestro di prova")
	assert_eq(_fixture.trainer(&"test_craft").fed_by, [&"test_gather"] as Array[StringName])
	assert_eq(_fixture.trainer(&"test_gather").fed_by.size(), 0)


func test_area_nodes_are_null_without_error_when_absent() -> void:
	var nodes: AreaNodesDef = _fixture.area_nodes(&"test_area")
	assert_not_null(nodes)
	assert_eq(nodes.area, &"test_area")
	assert_eq(nodes.max_level, 10)
	assert_eq(nodes.entries.size(), 1)
	assert_eq(nodes.entries[0].skill, &"test_gather")
	assert_eq(nodes.entries[0].weight, 100)
	assert_eq(_fixture.area_nodes(&"test_loot_area").max_level, 20)
	assert_null(_fixture.area_nodes(&"nowhere"))
	assert_not_null(_real.area_nodes(&"redrock_plains"), "the real nodes (M24-05)")


func test_recipe_item_for_an_action() -> void:
	var recipe: ItemDef = _fixture.recipe_item_for(&"craft_secret")
	assert_not_null(recipe)
	assert_eq(recipe.id, &"recipe_secret")
	assert_true(recipe.is_recipe())
	assert_eq(recipe.recipe_action, &"craft_secret")
	assert_eq(recipe.category, &"recipe")
	assert_eq(recipe.value, 0)
	assert_null(_fixture.recipe_item_for(&"craft_plank"), "an action without a Recipe")
	assert_null(_fixture.recipe_item_for(&"nothing"))
	assert_true(_fixture.action(&"craft_secret").discover)
	assert_false(_fixture.action(&"craft_plank").discover)


func test_other_items_are_not_recipes() -> void:
	assert_false(_fixture.item(&"test_twig").is_recipe())
	assert_eq(_fixture.item(&"test_twig").recipe_action, &"")


func test_the_removed_lookups_are_gone() -> void:
	for removed: String in ["hel" + "per_grades", "hel" + "per_grade", "con" + "tract_for"]:
		assert_false(_fixture.has_method(removed), removed)
