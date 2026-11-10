class_name DataValidatorMetin
extends RefCounted
## Part of DataValidator (internal, not API for other modules): the balance keys of M15 (docs/04_DATA_SCHEMA.md §22,
## docs/02_FORMULAS.md §5f): `metin.*`, `combat.crowd_threshold`, `combat.skip_stone_level`.

const METIN_KEYS: PackedStringArray = ["hp_base", "hp_per_level", "pulse_damage", "wave_size", "wave_thresholds",
	"rarity_bonus_pct", "guaranteed_pieces"]
const COMBAT_KEYS: PackedStringArray = ["combat.crowd_threshold", "combat.skip_stone_level"]
const WAVE_SIZE_MAX: int = 30  # format limit of metin.wave_size


## True for the section and the keys of M15 (so that DataValidator does not report them as unknown).
static func is_known_key(path: String) -> bool:
	return path == "metin" or path.begins_with("metin.") and METIN_KEYS.has(path.substr(6)) or COMBAT_KEYS.has(path)


static func validate_balance(v: DataValidatorRules, balance: Dictionary) -> void:
	var metin: Variant = DataValidator.lookup(balance, "metin")
	if not metin is Dictionary:
		v.fail("missing key 'metin'")
	else:
		var m: Dictionary = metin as Dictionary
		v.number(m, "hp_base", 1.0, DataValidatorRules.NO_LIMIT, "metin")
		v.number(m, "hp_per_level", 0.0, DataValidatorRules.NO_LIMIT, "metin")
		v.integer(m, "pulse_damage", 1.0, DataValidatorRules.NO_LIMIT, "metin")
		v.integer(m, "wave_size", 1.0, WAVE_SIZE_MAX, "metin")
		v.number(m, "rarity_bonus_pct", 0.0, DataValidatorRules.NO_LIMIT, "metin")
		v.integer(m, "guaranteed_pieces", 0.0, DataValidatorRules.NO_LIMIT, "metin")
		_thresholds(v, m.get("wave_thresholds"))
	var combat: Variant = DataValidator.lookup(balance, "combat")
	var c: Dictionary = combat as Dictionary if combat is Dictionary else {}
	v.integer(c, "crowd_threshold", 1.0, DataValidatorRules.NO_LIMIT, "combat")
	v.integer(c, "skip_stone_level", 0.0, 99.0, "combat")


# Strictly decreasing numbers in 1..99.
static func _thresholds(v: DataValidatorRules, value: Variant) -> void:
	if not value is Array or (value as Array).is_empty():
		v.fail("key 'metin.wave_thresholds' must be a non-empty array of numbers")
		return
	var previous: float = 100.0
	for entry: Variant in (value as Array):
		if not DataValidatorRules.is_number(entry) or float(entry) < 1.0 or float(entry) > 99.0 or float(entry) >= previous:
			v.fail("key 'metin.wave_thresholds' must be strictly decreasing numbers in 1..99, got %s" % JSON.stringify(value))
			return
		previous = float(entry)
