extends GutTest
## v9 -> v10 (M26-06, docs/05_INTERFACES_M26.md §6d, docs/01_GDD_M26.md §38.7): the schemes already within reach of a learned
## discipline, and those of the queued jobs, become known for free. Nothing else changes.

const Step := preload("res://core/save/migrations/migration_9_to_10.gd")


func _xp_of(level: int) -> int:
	return TestFactory.real_data().xp_table().xp_for_level(level)


# A v9 save: forging learned at grade 2 with the xp of `forge_level` (0 = not learned).
func _v9(forge_level: int, jobs: Array = [], recipes: Array = []) -> Dictionary:
	var learned: Dictionary = {"forging": 2} if forge_level > 0 else {}
	return {"format_version": 9, "player_name": "x", "modules": {
		"wallet": {"gold": 1234},
		"skills": {"forging": {"xp": _xp_of(maxi(forge_level, 1))}, "hearthcraft": {"xp": 77}},
		"mastery": {"forging": {"pool": 3, "actions": {"forge_emberbronze_plate": 7}, "nodes": []}},
		"bank": {"stacks": {"emberbronze_ore": 5}},
		"shop": {"purchases": {"market_shelf_1": 1}},
		"disciplines": {"learned": learned, "recipes": recipes, "extra": []},
		"actions": {"jobs": jobs, "elapsed_ms": 40}}}


func _recipes(out: Dictionary) -> Array:
	return ((out["modules"] as Dictionary)["disciplines"] as Dictionary)["recipes"] as Array


func test_the_current_version_is_10() -> void:
	assert_eq(SaveMigrator.CURRENT_VERSION, 10)
	assert_eq(SaveMigrator.migrate(_v9(25))["format_version"], 10)


func test_forging_learned_at_level_25_knows_the_schemes_within_reach() -> void:
	var recipes: Array = _recipes(Step.migrate(_v9(25)))
	assert_true(recipes.has("forge_ashlead_plate"))
	assert_true(recipes.has("forge_stormzinc_plate"))
	assert_false(recipes.has("forge_duskcobalt_plate"), "level 30 is above 25")
	assert_eq(recipes.size(), 2)


func test_forging_not_learned_gives_no_scheme() -> void:
	assert_eq(_recipes(Step.migrate(_v9(0))), [])


func test_a_queued_job_teaches_its_scheme() -> void:
	var jobs: Array = [{"skill": "hearthcraft", "action": "cook_riftmaw", "remaining": 0, "repeat": true}]
	assert_true(_recipes(Step.migrate(_v9(0, jobs))).has("cook_riftmaw"))


func test_known_recipes_are_not_duplicated() -> void:
	var recipes: Array = _recipes(Step.migrate(_v9(25, [], ["forge_ashlead_plate", "brew_tonic_1"])))
	assert_eq(recipes.count("forge_ashlead_plate"), 1)
	assert_true(recipes.has("brew_tonic_1"), "a recipe outside the list is kept")


func test_everything_else_is_identical() -> void:
	var before: Dictionary = _v9(25, [{"skill": "forging", "action": "forge_ashlead_plate", "remaining": 0, "repeat": true}])
	var out: Dictionary = Step.migrate(before)
	var modules: Dictionary = (out["modules"] as Dictionary).duplicate(true)
	var original: Dictionary = (before["modules"] as Dictionary).duplicate(true)
	(modules["disciplines"] as Dictionary).erase("recipes")
	(original["disciplines"] as Dictionary).erase("recipes")
	assert_eq(modules, original, "xp, mastery, queue, bank and shop untouched")
	assert_eq(_recipes(before), [], "the input is not changed")


func test_the_chain_from_v7_reaches_v10() -> void:
	var v7: Dictionary = {"format_version": 7, "player_name": "x", "modules": {
		"skills": {"forging": {"xp": _xp_of(25)}}, "actions": {"lanes": {}}}}
	var out: Dictionary = SaveMigrator.migrate(v7)
	assert_eq(out["format_version"], 10)
	assert_true(out["modules"].has("disciplines"))


func test_a_session_loads_the_migrated_recipes() -> void:
	var session: GameSession = autofree(TestFactory.session_no_kit(3, TestFactory.real_data()))
	var out: Dictionary = SaveMigrator.migrate(_v9(25))
	session.disciplines.from_save((out["modules"] as Dictionary)["disciplines"] as Dictionary)
	assert_true(session.disciplines.knows_recipe(&"forge_stormzinc_plate"))
	assert_false(session.disciplines.knows_recipe(&"forge_duskcobalt_plate"))
