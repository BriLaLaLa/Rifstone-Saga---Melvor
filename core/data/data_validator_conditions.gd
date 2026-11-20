class_name DataValidatorConditions
extends RefCounted
## The `combat.conditions` section of balance.json (internal, M28-03; docs/04_DATA_SCHEMA_M28.md §33.1, docs/02_FORMULAS_M28.md §9f).

const KEYS: PackedStringArray = ["tick_ms", "stagger_immunity_ms"]
const TICK_MS_MAX: float = 10000.0
const IMMUNITY_MS_MAX: float = 60000.0


static func is_known_key(path: String) -> bool:
	return path == "combat.conditions"


static func validate_balance(v: DataValidatorRules, balance: Dictionary) -> void:
	var section: Variant = DataValidator.lookup(balance, "combat.conditions")
	if not section is Dictionary:
		v.fail("missing key 'combat.conditions'")
		return
	var conditions: Dictionary = section as Dictionary
	v.keys(conditions, KEYS, "combat.conditions")
	v.integer(conditions, "tick_ms", 100.0, TICK_MS_MAX, "combat.conditions")
	v.integer(conditions, "stagger_immunity_ms", 0.0, IMMUNITY_MS_MAX, "combat.conditions")
