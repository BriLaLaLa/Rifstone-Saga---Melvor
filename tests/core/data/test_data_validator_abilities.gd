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


# --- M28-04 (04_DATA_SCHEMA_M28.md §33.2-§33.3, §33.6) ----------------------------------------------------------------
# The fixture has test_rain (strike, abilities[4]), test_sweep (cleave, [5]) and test_barrier (ward, [6]).

func test_m28_abilities_of_the_fixture_are_valid() -> void:
	assert_eq(V.validate(V.fixture_raw()), PackedStringArray())


func test_hits_and_target_only_on_a_strike_with_a_range() -> void:
	var raw: Dictionary = V.fixture_raw()
	_params(raw, 5)["hits"] = 2
	_expect(raw, [CLASS_FILE, "abilities[5].params.hits", "unknown field"])
	_params(raw, 5).erase("hits")
	_params(raw, 5)["target"] = "first"
	_expect(raw, [CLASS_FILE, "abilities[5].params.target", "unknown field"])
	_params(raw, 5).erase("target")
	_params(raw, 4)["hits"] = 0
	_expect(raw, [CLASS_FILE, "abilities[4].params.hits"])
	_params(raw, 4)["hits"] = 6
	_expect(raw, [CLASS_FILE, "abilities[4].params.hits"])
	_params(raw, 4)["hits"] = 5
	_params(raw, 4)["target"] = "weakest"
	_expect(raw, [CLASS_FILE, "abilities[4].params.target", "must be one of"])


func test_execute_needs_a_multiplier_above_one() -> void:
	var raw: Dictionary = V.fixture_raw()
	(_params(raw, 4)["execute"] as Dictionary)["mult"] = 1
	_expect(raw, [CLASS_FILE, "abilities[4].params.execute.mult"])
	(_params(raw, 4)["execute"] as Dictionary)["mult"] = 2.0
	(_params(raw, 4)["execute"] as Dictionary)["hp_pct"] = 0
	_expect(raw, [CLASS_FILE, "abilities[4].params.execute.hp_pct"])
	(_params(raw, 4)["execute"] as Dictionary)["hp_pct"] = 30
	(_params(raw, 4)["execute"] as Dictionary)["extra"] = 1
	_expect(raw, [CLASS_FILE, "abilities[4].params.execute.extra", "unknown field"])


func test_apply_list_size_and_distinct_conditions() -> void:
	var raw: Dictionary = V.fixture_raw()
	_params(raw, 4)["apply"] = []
	_expect(raw, [CLASS_FILE, "abilities[4].params.apply"])
	_params(raw, 4)["apply"] = [{"condition": "bleed", "pct": 30, "ms": 4000}, {"condition": "weaken", "pct": 20, "ms": 4000},
		{"condition": "expose", "pct": 20, "ms": 4000}, {"condition": "stagger", "ms": 1500}]
	_expect(raw, [CLASS_FILE, "abilities[4].params.apply", "at most 3"])
	_params(raw, 4)["apply"] = [{"condition": "bleed", "pct": 30, "ms": 4000}, {"condition": "bleed", "pct": 10, "ms": 4000}]
	_expect(raw, [CLASS_FILE, "abilities[4].params.apply[1].condition", "duplicate"])


func test_apply_entries_follow_the_ranges_of_each_condition() -> void:
	var raw: Dictionary = V.fixture_raw()
	_params(raw, 4)["apply"] = [{"condition": "stagger", "pct": 10, "ms": 1500}]
	_expect(raw, [CLASS_FILE, "abilities[4].params.apply[0].pct", "unknown field"])
	_params(raw, 4)["apply"] = [{"condition": "stagger", "ms": 99}]
	_expect(raw, [CLASS_FILE, "abilities[4].params.apply[0].ms"])
	_params(raw, 4)["apply"] = [{"condition": "weaken", "pct": 95, "ms": 4000}]
	_expect(raw, [CLASS_FILE, "abilities[4].params.apply[0].pct"])
	_params(raw, 4)["apply"] = [{"condition": "bleed", "pct": 30, "ms": 70000}]
	_expect(raw, [CLASS_FILE, "abilities[4].params.apply[0].ms"])
	_params(raw, 4)["apply"] = [{"condition": "ward", "pct": 30, "ms": 4000}]
	_expect(raw, [CLASS_FILE, "abilities[4].params.apply[0].condition", "must be one of"])
	_params(raw, 4)["apply"] = [{"condition": "bleed", "ms": 4000}]
	_expect(raw, [CLASS_FILE, "abilities[4].params.apply[0].pct"])


func test_drain_pct_range() -> void:
	var raw: Dictionary = V.fixture_raw()
	_params(raw, 4)["drain_pct"] = 0
	_expect(raw, [CLASS_FILE, "abilities[4].params.drain_pct"])
	_params(raw, 4)["drain_pct"] = 101
	_expect(raw, [CLASS_FILE, "abilities[4].params.drain_pct"])


func test_ward_params() -> void:
	var raw: Dictionary = V.fixture_raw()
	_params(raw, 6)["ward_pct"] = 0
	_expect(raw, [CLASS_FILE, "abilities[6].params.ward_pct"])
	_params(raw, 6)["ward_pct"] = 15
	_params(raw, 6).erase("duration_ms")
	_expect(raw, [CLASS_FILE, "abilities[6].params.duration_ms"])
	_params(raw, 6)["duration_ms"] = 500
	_expect(raw, [CLASS_FILE, "abilities[6].params.duration_ms"])
	_params(raw, 6)["duration_ms"] = 6000
	_params(raw, 6)["heal_pct"] = 5
	_expect(raw, [CLASS_FILE, "abilities[6].params.heal_pct", "unknown field"])


func test_the_new_params_are_not_for_a_heal_or_a_buff() -> void:
	var raw: Dictionary = V.fixture_raw()
	_params(raw, 2)["drain_pct"] = 10
	_expect(raw, [CLASS_FILE, "abilities[2].params.drain_pct", "unknown field"])
	_params(raw, 3)["apply"] = [{"condition": "bleed", "pct": 30, "ms": 4000}]
	_expect(raw, [CLASS_FILE, "abilities[3].params.apply", "unknown field"])
