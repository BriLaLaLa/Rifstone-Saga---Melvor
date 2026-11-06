extends GutTest
## DataValidator, part 1: the fixtures are valid, common rules (unknown fields, ids, types, sections), balance.json,
## stats.json and skills.json. One test per rule: each breaks one thing in a copy of the fixture data and expects
## an error naming the file, the entry and the problem. Items/actions: test_data_validator_items.gd; mastery,
## combat and shop: test_data_validator_combat.gd. The static helpers below are shared by those files.

const FIXTURE_ROOT: String = "res://tests/fixtures/data"
const CONFIG_ROOT: String = "res://data/config"
const BALANCE: String = "balance.json"
const STATS: String = "stats.json"
const SKILLS: String = "skills.json"


## The `raw` dictionary of DataValidator for the fixtures, read like GameData does (fresh copy at every call).
static func fixture_raw() -> Dictionary:
	var errors: PackedStringArray = []
	var raw: Dictionary = {
		"balance": _read([CONFIG_ROOT.path_join(GameData.BALANCE_FILE)], errors),
		"stats": _read([CONFIG_ROOT.path_join(GameData.STATS_FILE)], errors),
	}
	for section: String in GameData.CONTENT_FILES:
		raw[section] = _read([FIXTURE_ROOT.path_join(GameData.CONTENT_FILES[section])], errors)
	for section: String in GameData.CONTENT_DIRS:
		raw[section] = _read(JsonLoader.list_json_files(FIXTURE_ROOT.path_join(GameData.CONTENT_DIRS[section]),
				errors), errors)
	assert(errors.is_empty(), "fixture files must load: %s" % [errors])
	return raw


## The top-level object of the file of `section` whose name is `file_name`.
static func file_of(raw: Dictionary, section: String, file_name: String) -> Dictionary:
	for path: String in raw[section]:
		if path.get_file() == file_name:
			return raw[section][path] as Dictionary
	assert(false, "no file %s in section %s" % [file_name, section])
	return {}


## Entry `index` of the list `list_key` in a file.
static func entry_of(raw: Dictionary, section: String, file_name: String, list_key: String, index: int) -> Dictionary:
	return (file_of(raw, section, file_name)[list_key] as Array)[index] as Dictionary


static func validate(raw: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	DataValidator.validate(raw, errors)
	return errors


static func _read(paths: PackedStringArray, errors: PackedStringArray) -> Dictionary:
	var files: Dictionary = {}
	for path: String in paths:
		files[path] = JsonLoader.load_file(path, errors)
	return files


# Validates and expects one error containing every fragment (file, entry, message).
func _expect(raw: Dictionary, fragments: Array[String]) -> void:
	var errors: PackedStringArray = validate(raw)
	for message: String in errors:
		var matched: bool = true
		for fragment: String in fragments:
			matched = matched and message.contains(fragment)
		if matched:
			assert_true(true)
			return
	fail_test("no error with %s in %s" % [fragments, errors])


func _skill(raw: Dictionary, index: int) -> Dictionary:
	return entry_of(raw, "skills", SKILLS, "skills", index)


# --- fixtures and common rules -----------------------------------------------------------------------------------

func test_fixtures_are_valid() -> void:
	assert_eq(validate(fixture_raw()), PackedStringArray())


func test_unknown_field_is_an_error_and_doc_is_allowed() -> void:
	var raw: Dictionary = fixture_raw()
	_skill(raw, 0)["_doc"] = "a comment"
	_skill(raw, 0)["colour"] = "#ffffff"
	_expect(raw, [SKILLS, "skill 'test_gather'", "unknown field 'colour'"])
	assert_eq(validate(raw).size(), 1, "_doc is ignored")


func test_doc_must_be_a_string() -> void:
	var raw: Dictionary = fixture_raw()
	_skill(raw, 0)["_doc"] = 3
	_expect(raw, [SKILLS, "skill 'test_gather'", "unknown field '_doc'"])


func test_id_must_be_snake_case() -> void:
	var raw: Dictionary = fixture_raw()
	_skill(raw, 1)["id"] = "Test-Gather"
	_expect(raw, [SKILLS, "skill 'Test-Gather'", "does not match"])


func test_duplicate_id_is_an_error() -> void:
	var raw: Dictionary = fixture_raw()
	_skill(raw, 1)["id"] = "test_gather"
	_expect(raw, [SKILLS, "skill 'test_gather'", "duplicate skill 'test_gather'"])


func test_missing_field_is_an_error() -> void:
	var raw: Dictionary = fixture_raw()
	_skill(raw, 0).erase("description")
	_expect(raw, [SKILLS, "skill 'test_gather'", "missing field 'description'"])


func test_wrong_type_is_an_error() -> void:
	var raw: Dictionary = fixture_raw()
	_skill(raw, 0)["name"] = 12
	_expect(raw, [SKILLS, "skill 'test_gather'", "field 'name' must be a string"])


func test_fractional_number_in_int_field_is_an_error() -> void:
	var raw: Dictionary = fixture_raw()
	_skill(raw, 0)["order"] = 1.5
	_expect(raw, [SKILLS, "skill 'test_gather'", "field 'order' must be an integer"])


func test_entry_without_id_is_named_by_index() -> void:
	var raw: Dictionary = fixture_raw()
	_skill(raw, 2).erase("id")
	_expect(raw, [SKILLS, "skill #2", "missing field 'id'"])


func test_missing_single_file_section_is_an_error() -> void:
	var raw: Dictionary = fixture_raw()
	raw["shop"] = {}
	_expect(raw, ["section 'shop'", "expected one file, got 0"])


func test_unknown_top_level_field_is_an_error() -> void:
	var raw: Dictionary = fixture_raw()
	file_of(raw, "skills", SKILLS)["skils"] = []
	_expect(raw, [SKILLS, "unknown field 'skils'"])


# --- balance.json ------------------------------------------------------------------------------------------------

func test_required_balance_keys_are_all_in_the_real_file() -> void:
	assert_eq(DataValidator.REQUIRED_BALANCE_KEYS.size(), 85)
	for key: String in DataValidator.REQUIRED_BALANCE_KEYS:
		assert_not_null(DataValidator.lookup(file_of(fixture_raw(), "balance", BALANCE), key), key)


func test_missing_balance_key_is_an_error() -> void:
	var raw: Dictionary = fixture_raw()
	(file_of(raw, "balance", BALANCE)["combat"] as Dictionary).erase("respawn_ms")
	_expect(raw, [BALANCE, "missing key 'combat.respawn_ms'"])


func test_unknown_balance_key_is_an_error() -> void:
	var raw: Dictionary = fixture_raw()
	(file_of(raw, "balance", BALANCE)["bank"] as Dictionary)["slot_cost_grwth"] = 1.0
	_expect(raw, [BALANCE, "unknown key 'bank.slot_cost_grwth'"])


func test_balance_number_key_must_be_a_number() -> void:
	var raw: Dictionary = fixture_raw()
	file_of(raw, "balance", BALANCE)["tick_ms"] = "100"
	_expect(raw, [BALANCE, "key 'tick_ms' must be a number"])


func test_balance_list_key_must_be_an_array() -> void:
	var raw: Dictionary = fixture_raw()
	(file_of(raw, "balance", BALANCE)["rift"] as Dictionary)["sockets"] = 5
	_expect(raw, [BALANCE, "key 'rift.sockets' must be an array"])


func test_balance_style_key_must_be_a_style() -> void:
	var raw: Dictionary = fixture_raw()
	(file_of(raw, "balance", BALANCE)["combat"]["unarmed"] as Dictionary)["style"] = "fists"
	_expect(raw, [BALANCE, "key 'combat.unarmed.style' must be one of"])


func test_xp_curve_must_be_buildable() -> void:
	var raw: Dictionary = fixture_raw()
	(file_of(raw, "balance", BALANCE)["xp_curve"] as Dictionary)["growth"] = 0
	(file_of(raw, "balance", BALANCE)["mastery_curve"] as Dictionary)["max_level"] = 9.5
	_expect(raw, [BALANCE, "key 'xp_curve.growth' must be > 0"])
	_expect(raw, [BALANCE, "key 'mastery_curve.max_level' must be an integer >= 1"])


func test_missing_player_name_keys_are_errors() -> void:
	var raw: Dictionary = fixture_raw()
	(file_of(raw, "balance", BALANCE)["player_name"] as Dictionary).erase("min_length")
	_expect(raw, [BALANCE, "missing key 'player_name.min_length'"])
	raw = fixture_raw()
	file_of(raw, "balance", BALANCE).erase("player_name")
	_expect(raw, [BALANCE, "missing key 'player_name.min_length'"])
	_expect(raw, [BALANCE, "missing key 'player_name.max_length'"])


func test_player_name_lengths_must_be_positive_integers() -> void:
	var raw: Dictionary = fixture_raw()
	(file_of(raw, "balance", BALANCE)["player_name"] as Dictionary)["max_length"] = "24"
	_expect(raw, [BALANCE, "key 'player_name.max_length' must be a number"])
	for bad: float in [0.0, -1.0, 2.5]:
		raw = fixture_raw()
		(file_of(raw, "balance", BALANCE)["player_name"] as Dictionary)["min_length"] = bad
		_expect(raw, [BALANCE, "key 'player_name.min_length' must be an integer >= 1"])


func test_player_name_min_length_must_not_exceed_max_length() -> void:
	var raw: Dictionary = fixture_raw()
	(file_of(raw, "balance", BALANCE)["player_name"] as Dictionary)["min_length"] = 25
	_expect(raw, [BALANCE, "key 'player_name.min_length' must be <= 'player_name.max_length'"])
	raw = fixture_raw()
	(file_of(raw, "balance", BALANCE)["player_name"] as Dictionary)["min_length"] = 24
	assert_eq(validate(raw), PackedStringArray(), "min equal to max is valid")


func test_pool_warning_pct_is_required() -> void:
	var raw: Dictionary = fixture_raw()
	(file_of(raw, "balance", BALANCE)["mastery"] as Dictionary).erase("pool_warning_pct")
	_expect(raw, [BALANCE, "missing key 'mastery.pool_warning_pct'"])
	raw = fixture_raw()
	(file_of(raw, "balance", BALANCE)["mastery"] as Dictionary)["pool_warning_pct"] = "95"
	_expect(raw, [BALANCE, "key 'mastery.pool_warning_pct' must be a number"])


func test_pool_warning_pct_must_be_a_share_of_the_cap() -> void:
	for bad: float in [0.0, -5.0, 100.5]:
		var raw: Dictionary = fixture_raw()
		(file_of(raw, "balance", BALANCE)["mastery"] as Dictionary)["pool_warning_pct"] = bad
		_expect(raw, [BALANCE, "key 'mastery.pool_warning_pct' must be > 0 and <= 100"])
	for good: float in [100.0, 62.5]:
		var raw: Dictionary = fixture_raw()
		(file_of(raw, "balance", BALANCE)["mastery"] as Dictionary)["pool_warning_pct"] = good
		assert_eq(validate(raw), PackedStringArray(), "%s is valid" % good)


func test_start_items_must_exist() -> void:
	var raw: Dictionary = fixture_raw()
	(file_of(raw, "balance", BALANCE)["start"] as Dictionary)["items"] = [{"item": "ghost_item", "qty": 1}]
	_expect(raw, [BALANCE, "field 'start.items[0].item': unknown item 'ghost_item'"])


func test_start_class_of_balance_must_exist() -> void:
	var raw: Dictionary = fixture_raw()
	(file_of(raw, "balance", BALANCE)["character"] as Dictionary)["start_class"] = "ghost"
	_expect(raw, [BALANCE, "field 'character.start_class': unknown class 'ghost'"])


func test_keys_removed_by_the_reform_are_unknown() -> void:
	var raw: Dictionary = fixture_raw()
	(file_of(raw, "balance", BALANCE)["combat"] as Dictionary)["hp_skill"] = "vitality"
	_expect(raw, [BALANCE, "unknown key 'combat.hp_skill'"])


# --- stats.json --------------------------------------------------------------------------------------------------

func _stat(raw: Dictionary) -> Dictionary:
	return entry_of(raw, "stats", STATS, "stats", 0)


func test_stat_unknown_field_is_an_error() -> void:
	var raw: Dictionary = fixture_raw()
	_stat(raw)["unit"] = "%"
	_expect(raw, [STATS, "stat 'skill_interval_pct'", "unknown field 'unit'"])


func test_stat_name_is_at_most_40_characters() -> void:
	var raw: Dictionary = fixture_raw()
	_stat(raw)["name"] = "x".repeat(41)
	_expect(raw, [STATS, "stat 'skill_interval_pct'", "field 'name' must be 1-40 characters"])


func test_stat_formula_and_test_formats() -> void:
	var raw: Dictionary = fixture_raw()
	_stat(raw)["formula"] = "formula three"
	_stat(raw)["test"] = "tests/x.gd"
	_expect(raw, [STATS, "stat 'skill_interval_pct'", "field 'formula' must be F-xx"])
	_expect(raw, [STATS, "stat 'skill_interval_pct'", "field 'test' must be <path>.gd::<function>"])


func test_stat_registry_errors_name_the_file() -> void:
	var raw: Dictionary = fixture_raw()
	_stat(raw)["min"] = 200
	_expect(raw, [STATS, "skill_interval_pct", "'min' must be lower than 'max'"])


# --- skills.json -------------------------------------------------------------------------------------------------

func test_skill_category_must_be_known() -> void:
	var raw: Dictionary = fixture_raw()
	_skill(raw, 0)["category"] = "farming"
	_expect(raw, [SKILLS, "skill 'test_gather'", "field 'category' must be one of"])


func test_skill_order_must_be_unique() -> void:
	var raw: Dictionary = fixture_raw()
	_skill(raw, 1)["order"] = 1
	_expect(raw, [SKILLS, "skill 'test_gather_b'", "duplicate order 1"])


func test_skill_icon_must_be_under_the_skill_icons() -> void:
	var raw: Dictionary = fixture_raw()
	_skill(raw, 0)["icon"] = "res://assets/icons/items/x.png"
	_expect(raw, [SKILLS, "skill 'test_gather'", "field 'icon' must be a path under res://assets/icons/skills/"])


func test_skill_color_must_be_rrggbb() -> void:
	var raw: Dictionary = fixture_raw()
	_skill(raw, 0)["color"] = "green"
	_expect(raw, [SKILLS, "skill 'test_gather'", "field 'color' must be #rrggbb"])


func test_combat_is_not_a_skill_category() -> void:
	var raw: Dictionary = fixture_raw()
	_skill(raw, 0)["category"] = "combat"
	_expect(raw, [SKILLS, "skill 'test_gather'", "field 'category' must be one of"])


func test_has_mastery_does_not_depend_on_the_category() -> void:
	var raw: Dictionary = fixture_raw()
	_skill(raw, 3)["has_mastery"] = true  # riftbinding is artisan and had none
	assert_eq(validate(raw), PackedStringArray())


func test_character_is_a_reserved_skill_id() -> void:
	var raw: Dictionary = fixture_raw()
	_skill(raw, 1)["id"] = "character"
	_expect(raw, [SKILLS, "skill 'character'", "id 'character' is reserved"])


func test_mastery_bonuses_need_has_mastery() -> void:
	var raw: Dictionary = fixture_raw()
	_skill(raw, 3)["mastery_bonuses"] = []
	_expect(raw, [SKILLS, "skill 'riftbinding'", "'mastery_bonuses' is allowed only with 'has_mastery': true"])


func test_mastery_bonus_needs_exactly_one_of_every_levels_and_at_level() -> void:
	var raw: Dictionary = fixture_raw()
	((_skill(raw, 0)["mastery_bonuses"] as Array)[0] as Dictionary)["at_level"] = 50
	((_skill(raw, 0)["mastery_bonuses"] as Array)[1] as Dictionary).erase("at_level")
	_expect(raw, [SKILLS, "skill 'test_gather'", "'mastery_bonuses[0]' needs exactly one of"])
	_expect(raw, [SKILLS, "skill 'test_gather'", "'mastery_bonuses[1]' needs exactly one of"])


func test_mastery_bonus_level_is_within_the_mastery_curve() -> void:
	var raw: Dictionary = fixture_raw()
	((_skill(raw, 0)["mastery_bonuses"] as Array)[1] as Dictionary)["at_level"] = 100
	_expect(raw, [SKILLS, "skill 'test_gather'", "field 'mastery_bonuses[1].at_level' must be >= 1 and <= 99"])


func test_modifier_stat_must_be_registered() -> void:
	var raw: Dictionary = fixture_raw()
	(((_skill(raw, 0)["mastery_bonuses"] as Array)[0] as Dictionary)["modifiers"] as Array)[0]["stat"] = "luck"
	_expect(raw, [SKILLS, "skill 'test_gather'", "mastery_bonuses[0].modifiers[0].stat': stat 'luck' is not in"])


func test_modifier_value_must_not_be_zero() -> void:
	var raw: Dictionary = fixture_raw()
	(((_skill(raw, 0)["mastery_bonuses"] as Array)[0] as Dictionary)["modifiers"] as Array)[0]["value"] = 0
	_expect(raw, [SKILLS, "skill 'test_gather'", "field 'mastery_bonuses[0].modifiers[0].value' must not be 0"])


func test_mastery_bonus_scope_is_ignored() -> void:
	var raw: Dictionary = fixture_raw()
	(((_skill(raw, 0)["mastery_bonuses"] as Array)[0] as Dictionary)["modifiers"] as Array)[0]["scope"] = "x"
	assert_eq(validate(raw), PackedStringArray())
