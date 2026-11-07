extends GutTest
## HintDef, `data/hints/hints.json` rules and the structure of `combat.auto_eat_tiers` / `rift.sockets` in
## DataValidatorHints (M9-04, N8). Helpers from test_data_validator.gd.

const V: GDScript = preload("res://tests/core/data/test_data_validator.gd")
const HINTS: String = "hints.json"


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


func _hint(raw: Dictionary, index: int) -> Dictionary:
	return V.entry_of(raw, "hints", HINTS, "hints", index)


func _balance(raw: Dictionary) -> Dictionary:
	return V.file_of(raw, "balance", "balance.json")


func test_fixtures_and_real_data_are_valid() -> void:
	assert_eq(V.validate(V.fixture_raw()), PackedStringArray())
	assert_true(TestFactory.real_data().is_valid())


func test_game_data_loads_hints_in_file_order() -> void:
	var data: GameData = TestFactory.fixture_data()
	var ids: Array[StringName] = []
	for def: HintDef in data.hints():
		ids.append(def.id)
	assert_eq(ids.size(), 7)
	assert_eq(ids[0], &"test_first_action")
	var def: HintDef = data.hint(&"test_bank_full")
	assert_eq([def.title, def.text, def.trigger], ["Banca piena", "Testo di prova.", &"bank_full"])
	assert_eq(TestFactory.real_data().hints().size(), 6, "one hint per trigger (M9-05)")


func test_unknown_hint_is_null() -> void:
	assert_null(TestFactory.fixture_data().hint(&"nope"))
	assert_push_error("unknown hint 'nope'")


func test_from_dict_missing_field_is_null() -> void:
	assert_null(HintDef.from_dict({"id": "x", "title": "t", "text": "t"}))
	assert_push_error("missing field 'trigger'")


func test_unknown_trigger_is_an_error() -> void:
	var raw: Dictionary = V.fixture_raw()
	_hint(raw, 0)["trigger"] = "on_tuesday"
	_expect(raw, [HINTS, "hint 'test_first_action'", "trigger"])


func test_missing_text_and_unknown_field_are_errors() -> void:
	var raw: Dictionary = V.fixture_raw()
	_hint(raw, 0).erase("text")
	_hint(raw, 1)["icon"] = "x"
	_expect(raw, [HINTS, "hint 'test_first_action'", "missing field 'text'"])
	_expect(raw, [HINTS, "hint 'test_bank_full'", "unknown field 'icon'"])


func test_duplicate_id_is_an_error() -> void:
	var raw: Dictionary = V.fixture_raw()
	_hint(raw, 1)["id"] = "test_first_action"
	_expect(raw, [HINTS, "duplicate hint 'test_first_action'"])


func test_section_needs_one_file() -> void:
	var raw: Dictionary = V.fixture_raw()
	raw["hints"] = {}
	_expect(raw, ["section 'hints'", "expected one file, got 0"])


func test_auto_eat_tier_rules() -> void:
	var raw: Dictionary = V.fixture_raw()
	var tiers: Array = (_balance(raw)["combat"] as Dictionary)["auto_eat_tiers"] as Array
	tiers[1] = {"threshold_pct": 70, "target_pct": 60}
	tiers[2] = {"threshold_pct": 40}
	tiers[3] = 5
	tiers[0] = {"threshold_pct": 1, "target_pct": 2}
	_expect(raw, ["null at index 0"])
	_expect(raw, ["auto_eat_tiers[1]", "threshold_pct <= target_pct"])
	_expect(raw, ["auto_eat_tiers[2].target_pct", "missing field"])
	_expect(raw, ["auto_eat_tiers[3]", "must be an object"])


func test_rift_socket_rules() -> void:
	var raw: Dictionary = V.fixture_raw()
	var sockets: Array = (_balance(raw)["rift"] as Dictionary)["sockets"] as Array
	sockets[1] = {"level": 0}
	sockets[2] = {"level": 5, "x": 1}
	sockets[3] = 7
	_expect(raw, ["rift.sockets[1].level", "must be >= 1"])
	_expect(raw, ["rift.sockets[2].x", "unknown field"])
	_expect(raw, ["rift.sockets[3]", "must be an object"])
	_balance(raw)["rift"]["sockets"] = []
	_expect(raw, ["rift.sockets", "at least one socket"])


func test_rift_socket_levels_must_not_decrease() -> void:
	var raw: Dictionary = V.fixture_raw()
	var sockets: Array = (_balance(raw)["rift"] as Dictionary)["sockets"] as Array
	sockets[1] = {"level": 50}
	sockets[2] = {"level": 20}
	_expect(raw, ["rift.sockets[2].level", "must not decrease"])
