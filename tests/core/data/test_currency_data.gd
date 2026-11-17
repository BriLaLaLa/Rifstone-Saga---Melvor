extends GutTest
## `currency` of balance.json (docs/04_DATA_SCHEMA_M27.md §32.1, F-177): the parameters, the accessor and the validator rules,
## and the rounding unit of the generated village costs (F-131) and quest rewards (F-134).

const BALANCE: String = "balance.json"


func _expect(raw: Dictionary, parts: Array) -> void:
	var errors: PackedStringArray = []
	DataValidator.validate(raw, errors)
	var found: bool = false
	for e: String in errors:
		var all: bool = true
		for part: String in parts:
			all = all and e.contains(part)
		found = found or all
	assert_true(found, "expected an error with %s, got %s" % [str(parts), str(errors)])


func _currency(raw: Dictionary) -> Dictionary:
	return load("res://tests/core/data/test_data_validator.gd").file_of(raw, "balance", BALANCE)["currency"] as Dictionary


func _raw() -> Dictionary:
	return load("res://tests/core/data/test_data_validator.gd").fixture_raw() as Dictionary


func test_the_accessor_gives_the_parameters() -> void:
	var p: CurrencyParams = TestFactory.real_data().currency()
	assert_eq(p.copper_per_silver, 100)
	assert_eq(p.silver_per_gold, 100)
	assert_eq(p.copper_per_gold(), 10000)
	assert_eq(p.round_unit(), 1000)
	assert_eq(p.symbols[&"gold"], "o")
	assert_eq(p.symbols[&"silver"], "a")
	assert_eq(p.symbols[&"copper"], "r")
	assert_eq(p.names[&"gold"], "Oro")
	assert_eq(p.names[&"copper"], "Rame")


func test_a_missing_section_is_an_error() -> void:
	var raw: Dictionary = _raw()
	load("res://tests/core/data/test_data_validator.gd").file_of(raw, "balance", BALANCE).erase("currency")
	_expect(raw, [BALANCE, "missing key 'currency'"])


func test_a_ratio_below_two_is_an_error() -> void:
	var raw: Dictionary = _raw()
	_currency(raw)["copper_per_silver"] = 1
	_expect(raw, [BALANCE, "currency.copper_per_silver"])


func test_the_symbols_must_be_the_three_coins_short_and_not_empty() -> void:
	var raw: Dictionary = _raw()
	(_currency(raw)["symbols"] as Dictionary)["copper"] = "abcd"
	_expect(raw, [BALANCE, "currency.symbols.copper"])
	raw = _raw()
	(_currency(raw)["names"] as Dictionary)["silver"] = ""
	_expect(raw, [BALANCE, "currency.names.silver"])
	raw = _raw()
	(_currency(raw)["symbols"] as Dictionary).erase("gold")
	_expect(raw, [BALANCE, "currency.symbols.gold"])
	raw = _raw()
	(_currency(raw)["names"] as Dictionary)["platinum"] = "Platino"
	_expect(raw, [BALANCE, "unknown field 'currency.names.platinum'"])


func test_an_unknown_currency_key_is_an_error() -> void:
	var raw: Dictionary = _raw()
	_currency(raw)["bronze"] = 1
	_expect(raw, [BALANCE, "unknown field 'currency.bronze'"])


func test_the_rounding_unit_follows_the_ratio() -> void:
	var spec: Dictionary = {"cost_spec": {"wood": [], "plate": 0.0, "food": 0.0, "gold_weight": 1.0}}
	var params: Dictionary = {"qty": {}, "woodwright_levels": [1], "gold_base": 12345, "gold_growth": 1.0}
	assert_eq(int(DataValidatorVillage.levels_for(spec, params, 1, 1000)["gold"]), 12000)
	assert_eq(int(DataValidatorVillage.levels_for(spec, params, 1, 100)["gold"]), 12300)
	assert_eq(int(DataValidatorVillage.levels_for(spec, params, 1)["gold"]), 12000, "default: 10 x 100")
