class_name DataValidatorM14
extends RefCounted
## Part of DataValidator (internal, not API for other modules): the M14 (Alpha) rules of weapons, armour materials and
## the balance keys `equipment.*`, `combat.armor.*`, `combat.unarmed.dmg_*` (docs/04_DATA_SCHEMA.md §21, F-117, F-118).

const GRADE_COUNT: int = 15
const MATERIAL_GRADE_MAX: int = 8
const MATERIALS: PackedStringArray = ["plate", "leather", "cloth"]
const ARMOUR_SLOTS: PackedStringArray = ["head", "body", "legs", "feet", "hands"]
const SHIELD_KIND: String = "shield"
const WEIGHT_SLOTS: PackedStringArray = ["body", "legs", "head", "offhand", "hands", "feet"]
const MATERIAL_FIELDS: PackedStringArray = ["armor", "barrier", "evasion"]
const BUDGET_KEYS: PackedStringArray = ["armor", "evasion"]
const REQUIRED_KEYS: PackedStringArray = [
	"equipment.grade_levels", "equipment.grade_material", "equipment.slot_weights", "equipment.set_budget",
	"combat.armor.k", "combat.armor.level_offset", "combat.armor.cap_pct", "combat.armor.materials",
	"combat.unarmed.dmg_min", "combat.unarmed.dmg_max",
]
const SECTIONS: PackedStringArray = ["equipment", "combat.armor"]
const WEIGHT_SUM_TOLERANCE: float = 1e-6
const CAP_PCT_MAX: float = 95.0  # format limit of combat.armor.cap_pct (F-117)


## True for the sections and the keys of M14 (so that DataValidator does not report them as unknown).
static func is_known_key(path: String) -> bool:
	return SECTIONS.has(path) or REQUIRED_KEYS.has(path)


# --- balance.json ------------------------------------------------------------------------------------------------

static func validate_balance(v: DataValidatorRules, balance: Dictionary) -> void:
	for key: String in REQUIRED_KEYS:
		if DataValidator.lookup(balance, key) == null:
			v.fail("missing key '%s'" % key)
	var equipment: Variant = DataValidator.lookup(balance, "equipment")
	if equipment is Dictionary:
		var e: Dictionary = equipment as Dictionary
		_int_list(v, e.get("grade_levels"), "equipment.grade_levels", 1, int(v.max_character_level), true)
		_int_list(v, e.get("grade_material"), "equipment.grade_material", 1, MATERIAL_GRADE_MAX, false)
		_slot_weights(v, e.get("slot_weights"))
		_set_budget(v, e.get("set_budget"))
	var armor: Variant = DataValidator.lookup(balance, "combat.armor")
	if armor is Dictionary:
		_armor(v, armor as Dictionary)
	var unarmed: Variant = DataValidator.lookup(balance, "combat.unarmed")
	if unarmed is Dictionary:
		_dmg_pair(v, unarmed as Dictionary, "combat.unarmed", true)


# GRADE_COUNT integers in [low, high], strictly increasing (levels) or non-decreasing (material grades).
static func _int_list(v: DataValidatorRules, value: Variant, key: String, low: int, high: int, strict: bool) -> void:
	if value == null:
		return
	if not value is Array or (value as Array).size() != GRADE_COUNT:
		v.fail("key '%s' needs exactly %d integers, got %s" % [key, GRADE_COUNT, JSON.stringify(value)])
		return
	var previous: int = low - 1 if strict else low
	for entry: Variant in value as Array:
		if not DataValidatorRules.is_int(entry) or int(entry) < low or int(entry) > high \
				or (int(entry) <= previous if strict else int(entry) < previous):
			v.fail("key '%s' must be integers in %d..%d, %s, got %s" % [key, low, high,
					"increasing" if strict else "non-decreasing", JSON.stringify(value)])
			return
		previous = int(entry)


static func _slot_weights(v: DataValidatorRules, value: Variant) -> void:
	if value == null:
		return
	if not value is Dictionary:
		v.fail("key 'equipment.slot_weights' must be an object, got %s" % JSON.stringify(value))
		return
	var weights: Dictionary = value as Dictionary
	v.keys(weights, WEIGHT_SLOTS, "equipment.slot_weights")
	var sum: float = 0.0
	for slot: String in WEIGHT_SLOTS:
		if v.number(weights, slot, 0.0, 1.0, "equipment.slot_weights"):
			sum += float(weights[slot])
	if absf(sum - 1.0) > WEIGHT_SUM_TOLERANCE and weights.size() >= WEIGHT_SLOTS.size():
		v.fail("key 'equipment.slot_weights' must sum to 1, got %s" % str(sum))


# `{"armor": [base, per_level], "evasion": [base, per_level]}`.
static func _set_budget(v: DataValidatorRules, value: Variant) -> void:
	if value == null:
		return
	if not value is Dictionary:
		v.fail("key 'equipment.set_budget' must be an object, got %s" % JSON.stringify(value))
		return
	var budget: Dictionary = value as Dictionary
	v.keys(budget, BUDGET_KEYS, "equipment.set_budget")
	for key: String in BUDGET_KEYS:
		var pair: Variant = budget.get(key)
		if not pair is Array or (pair as Array).size() != 2 or not DataValidatorRules.is_number((pair as Array)[0]) \
				or not DataValidatorRules.is_number((pair as Array)[1]) or float((pair as Array)[0]) < 0.0 \
				or float((pair as Array)[1]) < 0.0:
			v.fail("key 'equipment.set_budget.%s' must be [base, per_level] of numbers >= 0, got %s" % [key,
					JSON.stringify(pair)])


static func _armor(v: DataValidatorRules, armor: Dictionary) -> void:
	v.keys(armor, ["k", "level_offset", "cap_pct", "materials"], "combat.armor")
	if armor.has("k"):
		v.number(armor, "k", 0.0, DataValidatorRules.NO_LIMIT, "combat.armor", true)
	if armor.has("level_offset"):
		v.number(armor, "level_offset", 0.0, DataValidatorRules.NO_LIMIT, "combat.armor")
	if armor.has("cap_pct"):
		v.number(armor, "cap_pct", 0.0, CAP_PCT_MAX, "combat.armor", true)
	if not armor.has("materials"):
		return
	var materials: Dictionary = v.object(armor, "materials", "combat.armor")
	v.keys(materials, MATERIALS, "combat.armor.materials")
	for material: String in MATERIALS:
		var row: Dictionary = v.object(materials, material, "combat.armor.materials")
		v.keys(row, MATERIAL_FIELDS, "combat.armor.materials.%s" % material)
		for field: String in MATERIAL_FIELDS:
			v.number(row, field, 0.0, DataValidatorRules.NO_LIMIT, "combat.armor.materials.%s" % material)


# `dmg_min`/`dmg_max` integers >= 0 with min <= max (`allow_zero`) or >= 1 (a weapon).
static func _dmg_pair(v: DataValidatorRules, d: Dictionary, prefix: String, allow_zero: bool) -> void:
	var low: float = 0.0 if allow_zero else 1.0
	var min_ok: bool = v.integer(d, "dmg_min", low, DataValidatorRules.NO_LIMIT, prefix)
	var max_ok: bool = v.integer(d, "dmg_max", low, DataValidatorRules.NO_LIMIT, prefix)
	if min_ok and max_ok and float(d["dmg_min"]) > float(d["dmg_max"]):
		v.fail("field '%s.dmg_min' must be <= '%s.dmg_max'" % [prefix, prefix])


# --- items -------------------------------------------------------------------------------------------------------

## The weapon object of an item with slot `weapon`: `dmg_min`/`dmg_max` (F-22), min <= max, both >= 1.
static func validate_weapon(v: DataValidatorRules, weapon: Dictionary) -> void:
	_dmg_pair(v, weapon, "equip.weapon", false)


## `equip.material`: required for armour slots and shields, forbidden otherwise (docs/04_DATA_SCHEMA.md §21).
static func validate_material(v: DataValidatorRules, equip: Dictionary, slot: String, kind: String) -> void:
	var needs: bool = ARMOUR_SLOTS.has(slot) or kind == SHIELD_KIND
	if needs:
		v.one_of(equip, "material", MATERIALS, "equip")
	elif equip.has("material"):
		v.fail("field 'equip.material' is allowed only for armour slots and shields")
