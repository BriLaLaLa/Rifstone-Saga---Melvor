extends GutTest
## DataValidator switches the strict rules of docs/04_DATA_SCHEMA_M24.md §29 on (STRICT_REAL_DATA and
## DataValidatorDisciplines.is_real_data) for the real data of res://data and leaves them off for the minimal fixtures
## (review of M24-05). The branch is proved through DataValidator.validate: a strict-only rule (every discipline has its
## Trainer) fires on the real data and stays silent on the fixtures.

const V: GDScript = preload("res://tests/core/data/test_data_validator.gd")
const REAL_ROOT: String = "res://data"
const FIXTURE_NODES: String = "res://tests/fixtures/data/encounters/nodes.json"
const TRAINERS: String = "trainers.json"
const NO_TRAINER: String = "has no Trainer"


# The raw data of DataValidator for res://data, read like GameData does (with the Guide, the Dungeon and the nodes).
func _real_raw() -> Dictionary:
	var errors: PackedStringArray = []
	var raw: Dictionary = {
		"balance": DataBuildUtil.read_files([V.CONFIG_ROOT.path_join(GameData.BALANCE_FILE)], errors),
		"stats": DataBuildUtil.read_files([V.CONFIG_ROOT.path_join(GameData.STATS_FILE)], errors),
	}
	for section: String in GameData.CONTENT_FILES:
		raw[section] = DataBuildUtil.read_files([REAL_ROOT.path_join(GameData.CONTENT_FILES[section])], errors)
	for section: String in GameData.CONTENT_DIRS:
		raw[section] = DataBuildUtil.read_files(JsonLoader.list_json_files(REAL_ROOT.path_join(GameData.CONTENT_DIRS[section]), errors), errors)
	raw["guide"] = DataBuildUtil.read_files(DataValidatorGuide.list_files(REAL_ROOT, errors), errors)
	raw["dungeons"] = DataBuildUtil.read_files(DungeonIndex.list_files(REAL_ROOT, errors), errors)
	raw["encounters"] = DataBuildUtil.read_files(DisciplineIndex.nodes_files(REAL_ROOT), errors)
	assert_eq(errors, PackedStringArray(), "real files must load")
	return raw


func _fixture_raw() -> Dictionary:
	var raw: Dictionary = V.fixture_raw()
	var errors: PackedStringArray = []
	raw["encounters"] = {FIXTURE_NODES: JsonLoader.load_file(FIXTURE_NODES, errors)}
	assert_eq(errors, PackedStringArray())
	return raw


func _without_first_trainer(raw: Dictionary) -> Dictionary:
	(V.file_of(raw, "disciplines", TRAINERS)["trainers"] as Array).remove_at(0)
	return raw


func _mentions(errors: PackedStringArray, text: String) -> bool:
	for e: String in errors:
		if e.contains(text):
			return true
	return false


func test_the_real_data_is_real_and_the_fixtures_are_not() -> void:
	assert_true(DataValidatorDisciplines.STRICT_REAL_DATA)
	assert_true(DataValidatorDisciplines.is_real_data(_real_raw()), "res://data has the narrow areas (level_min)")
	assert_false(DataValidatorDisciplines.is_real_data(_fixture_raw()), "the fixtures keep the old area format")


func test_the_real_data_passes_the_strict_branch() -> void:
	assert_eq(V.validate(_real_raw()), PackedStringArray())


func test_the_strict_branch_is_active_on_the_real_data() -> void:
	var errors: PackedStringArray = V.validate(_without_first_trainer(_real_raw()))
	assert_true(_mentions(errors, NO_TRAINER), "a discipline without Trainer is refused in res://data: %s" % [errors])


func test_the_strict_branch_is_off_on_the_fixtures() -> void:
	var errors: PackedStringArray = V.validate(_without_first_trainer(_fixture_raw()))
	assert_false(_mentions(errors, NO_TRAINER), "the fixtures are not strict: %s" % [errors])
