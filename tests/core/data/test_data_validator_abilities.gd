extends GutTest
## DataValidatorAbilities (M28-02, cases moved from test_data_validator_traits.gd): the abilities of a class
## (04_DATA_SCHEMA.md §14, F-80). One test per rule on a broken copy of the fixtures; helpers from test_data_validator.gd.

const V: GDScript = preload("res://tests/core/data/test_data_validator.gd")
const CLASS_FILE: String = "test_class.json"


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


func _class(raw: Dictionary) -> Dictionary:
	return V.file_of(raw, "classes", CLASS_FILE)


func _ability(raw: Dictionary, index: int) -> Dictionary:
	return (_class(raw)["abilities"] as Array)[index] as Dictionary


func _params(raw: Dictionary, ability: int) -> Dictionary:
	return _ability(raw, ability)["params"] as Dictionary


func _balance(raw: Dictionary) -> Dictionary:
	return V.file_of(raw, "balance", "balance.json")


func test_ability_kind_and_params() -> void:
	var raw: Dictionary = V.fixture_raw()
	_ability(raw, 0)["kind"] = "fireball"
	_expect(raw, [CLASS_FILE, "abilities[0].kind", "must be one of"])
	_ability(raw, 0)["kind"] = "cleave"
	_params(raw, 0)["targets"] = -1
	_expect(raw, [CLASS_FILE, "abilities[0].params.targets"])
	_params(raw, 0)["targets"] = 0
	_params(raw, 0)["power_mult"] = 0
	_expect(raw, [CLASS_FILE, "abilities[0].params.power_mult"])
	_params(raw, 1)["power_mult"] = 2.0
	_params(raw, 1)["targets"] = 2
	_expect(raw, [CLASS_FILE, "abilities[1].params.targets", "unknown field"])


func test_heal_and_buff_params() -> void:
	var raw: Dictionary = V.fixture_raw()
	_params(raw, 2)["heal_pct"] = 0
	_expect(raw, [CLASS_FILE, "abilities[2].params.heal_pct"])
	_params(raw, 2)["heal_pct"] = 101
	_expect(raw, [CLASS_FILE, "abilities[2].params.heal_pct"])
	_params(raw, 3)["duration_ms"] = 999
	_params(raw, 3)["modifiers"] = []
	_expect(raw, [CLASS_FILE, "abilities[3].params.duration_ms"])
	_expect(raw, [CLASS_FILE, "abilities[3].params.modifiers", "at least 1"])
	_params(raw, 3)["modifiers"] = [{"stat": "ghost", "value": 1}]
	_expect(raw, [CLASS_FILE, "abilities[3].params.modifiers[0]", "ghost"])


func test_ability_cooldown_has_a_floor_and_setups_are_checked() -> void:
	var raw: Dictionary = V.fixture_raw()
	var floor_ms: int = int(DataValidator.lookup(_balance(raw), "combat.min_attack_interval_ms"))
	_ability(raw, 1)["cooldown_ms"] = floor_ms - 1
	_ability(raw, 0)["setups"] = ["axe"]
	_ability(raw, 2)["id"] = "test_whirl"
	_expect(raw, [CLASS_FILE, "abilities[1].cooldown_ms"])
	_expect(raw, [CLASS_FILE, "abilities[0].setups", "unknown setup 'axe'"])
	_expect(raw, [CLASS_FILE, "abilities[2].id", "duplicate 'test_whirl'"])
