class_name DataValidatorCurrency
extends RefCounted
## The `currency` section of balance.json (internal, M27-02; docs/04_DATA_SCHEMA_M27.md §32.1, docs/02_FORMULAS_M27.md F-177).

const COINS: PackedStringArray = ["gold", "silver", "copper"]
const SYMBOL_MAX_LENGTH: int = 3


static func is_known_key(path: String) -> bool:
	return path == "currency"


static func validate_balance(v: DataValidatorRules, balance: Dictionary) -> void:
	var section: Variant = DataValidator.lookup(balance, "currency")
	if not section is Dictionary:
		v.fail("missing key 'currency'")
		return
	var currency: Dictionary = section as Dictionary
	v.keys(currency, ["copper_per_silver", "silver_per_gold", "symbols", "names"], "currency")
	v.integer(currency, "copper_per_silver", 2.0, DataValidatorRules.NO_LIMIT, "currency")
	v.integer(currency, "silver_per_gold", 2.0, DataValidatorRules.NO_LIMIT, "currency")
	for key: String in ["symbols", "names"]:
		var table: Dictionary = v.object(currency, key, "currency")
		var prefix: String = "currency.%s" % key
		v.keys(table, COINS, prefix)
		for coin: String in COINS:
			if v.text(table, coin, prefix):
				var value: String = table[coin] as String
				if value.is_empty():
					v.fail("key '%s.%s' must not be empty" % [prefix, coin])
				elif key == "symbols" and value.length() > SYMBOL_MAX_LENGTH:
					v.fail("key '%s.%s' has at most %d characters" % [prefix, coin, SYMBOL_MAX_LENGTH])


## The rounding unit of the generated costs and rewards (10 × `currency.copper_per_silver`, F-131/F-134) from the parsed balance
## files; -1 if no file has a valid `currency` (the balance errors are reported by `validate_balance`).
static func round_unit(balance_files: Dictionary[String, Dictionary]) -> int:
	for path: String in balance_files:
		var probe := DataValidatorRules.new()
		validate_balance(probe, balance_files[path])
		if probe.errors.is_empty():
			return 10 * int(DataValidator.lookup(balance_files[path], "currency.copper_per_silver"))
	return -1
