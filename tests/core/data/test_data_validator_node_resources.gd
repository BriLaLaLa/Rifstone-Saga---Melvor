extends GutTest
## DataValidatorNodeResources (M35B-1; docs/04_DATA_SCHEMA_M35B.md §36.1-§36.2, the rejected cases): `resources` of the node entries, the
## reachability of the actions (strict data) and `encounters.resource_profile`. One rule per test, on a broken copy of the fixtures.

const V: GDScript = preload("res://tests/core/data/test_data_validator.gd")
const NODES_FILE: String = "res://tests/fixtures/data/encounters/nodes.json"


func _raw() -> Dictionary:
	var raw: Dictionary = V.fixture_raw()
	var errors: PackedStringArray = []
	raw["encounters"] = {NODES_FILE: JsonLoader.load_file(NODES_FILE, errors)}
	return raw


func _area(raw: Dictionary, index: int) -> Dictionary:
	return ((raw["encounters"][NODES_FILE] as Dictionary)["areas"] as Array)[index]


func _node(raw: Dictionary, index: int = 0) -> Dictionary:
	return (_area(raw, index)["nodes"] as Array)[0]


func _res(action: String, weight: int) -> Dictionary:
	return {"action": action, "weight": weight}


func _errors(raw: Dictionary, strict: bool = false) -> PackedStringArray:
	if not strict:
		return V.validate(raw)
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


func _expect(raw: Dictionary, fragment: String, strict: bool = false) -> void:
	var errors: PackedStringArray = _errors(raw, strict)
	for message: String in errors:
		if message.contains(fragment):
			assert_true(true)
			return
	fail_test("no error with '%s' in %s" % [fragment, errors])


func test_the_fixtures_are_valid() -> void:
	assert_eq(_errors(_raw()), PackedStringArray())


func test_two_resources_that_sum_to_100_are_valid() -> void:
	var raw: Dictionary = _raw()
	_node(raw)["resources"] = [_res("gather_twig", 70), _res("gather_log", 30)]
	assert_eq(_errors(raw), PackedStringArray())


func test_missing_or_empty_resources_are_rejected() -> void:
	var raw: Dictionary = _raw()
	_node(raw).erase("resources")
	_expect(raw, "resources")
	var empty: Dictionary = _raw()
	_node(empty)["resources"] = []
	_expect(empty, "field 'nodes.resources' needs at least 1 entries")


func test_an_action_of_another_discipline_or_unknown_is_rejected() -> void:
	var raw: Dictionary = _raw()
	_node(raw)["resources"] = [_res("craft_plank", 100)]
	_expect(raw, "'craft_plank' is not an action of 'test_gather'")
	var unknown: Dictionary = _raw()
	_node(unknown)["resources"] = [_res("no_such_action", 100)]
	_expect(unknown, "unknown action 'no_such_action'")


func test_a_double_action_is_rejected() -> void:
	var raw: Dictionary = _raw()
	_node(raw)["resources"] = [_res("gather_log", 50), _res("gather_log", 50)]
	_expect(raw, "duplicate resource 'gather_log'")


func test_levels_must_increase() -> void:
	var raw: Dictionary = _raw()
	_node(raw)["resources"] = [_res("gather_log", 50), _res("gather_twig", 50)]  # level 5 then 1
	_expect(raw, "must be in order of increasing level")


func test_a_weight_of_zero_is_rejected() -> void:
	var raw: Dictionary = _raw()
	_node(raw)["resources"] = [_res("gather_twig", 0), _res("gather_log", 100)]
	_expect(raw, "field 'nodes.resources.weight' must be >= 1")


func test_the_weights_must_sum_to_100() -> void:
	var raw: Dictionary = _raw()
	_node(raw)["resources"] = [_res("gather_twig", 49), _res("gather_log", 50)]
	_expect(raw, "must sum to 100, got 99")


func test_an_action_in_no_zone_is_rejected_in_strict_data() -> void:
	var raw: Dictionary = _raw()  # the fixture tables only hold gather_log: twig and bundle are never reachable
	_expect(raw, "action 'gather_twig' is in the resource table of no area", true)
	assert_eq(_errors(_raw()), PackedStringArray(), "not in non-strict data")


func test_every_action_in_some_zone_is_reachable() -> void:
	var raw: Dictionary = _raw()
	_node(raw, 0)["resources"] = [_res("gather_twig", 50), _res("gather_log", 50)]
	_node(raw, 1)["resources"] = [_res("gather_bundle", 40), _res("gather_log", 60)]
	for message: String in _errors(raw, true):
		assert_false(message.contains("unreachable"), message)


func test_the_resource_profile_format() -> void:
	var profile: Array = [{"offset": -2, "weight": 5}, {"offset": -1, "weight": 25}, {"offset": 0, "weight": 55}, {"offset": 1, "weight": 15}]
	var raw: Dictionary = _raw()
	V.file_of(raw, "balance", V.BALANCE)["encounters"]["resource_profile"] = profile
	assert_eq(_errors(raw), PackedStringArray())
	var dup: Dictionary = _raw()
	V.file_of(dup, "balance", V.BALANCE)["encounters"]["resource_profile"] = [profile[0], profile[0], profile[2], profile[3]]
	_expect(dup, "duplicate offset -2")
	var short: Dictionary = _raw()
	V.file_of(short, "balance", V.BALANCE)["encounters"]["resource_profile"] = [profile[0]]
	_expect(short, "resource_profile")
	var bad: Dictionary = _raw()
	V.file_of(bad, "balance", V.BALANCE)["encounters"]["resource_profile"] = [profile[0], profile[1], profile[2], {"offset": 5, "weight": 0}]
	_expect(bad, "resource_profile.offset")
