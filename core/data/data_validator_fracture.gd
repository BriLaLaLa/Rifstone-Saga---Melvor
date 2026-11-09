class_name DataValidatorFracture
extends RefCounted
## Part of DataValidator (internal, not API for other modules): the `fracture` section of balance.json
## (docs/04_DATA_SCHEMA.md §11.4, F-109, F-110, F-113, F-114). Replaces the removed `fractures.*` keys.

const KEYS: PackedStringArray = ["fracture.groups", "fracture.intensity_steps", "fracture.pulse_ms",
	"fracture.mod_count", "fracture.card_rarity", "fracture.card_drop", "fracture.salvage", "fracture.grades"]
const RARITIES: PackedStringArray = ["common", "magic", "rare"]
const MOD_COUNT_MAX: int = 4
const GRADE_COUNT: int = 10
const GRADE_FIELDS: PackedStringArray = ["areas", "level_bonus", "hp_mult", "damage_mult", "reward_mult", "piece_grade",
	"recommended_level"]
const PIECE_GRADE_MAX: int = 8
const RECOMMENDED_LEVEL_MAX: int = 99
const DELTA_WEIGHTS: int = 3  # +0, +1, +2


## True for the section itself and its keys (so that DataValidator does not report them as unknown).
static func is_known_key(path: String) -> bool:
	return path == "fracture" or KEYS.has(path)


## Presence, types and ranges of `fracture` (the areas are checked by `validate_areas`).
static func validate_balance(v: DataValidatorRules, balance: Dictionary) -> void:
	var fracture: Variant = DataValidator.lookup(balance, "fracture")
	if not fracture is Dictionary:
		v.fail("missing key 'fracture'")
		return
	var f: Dictionary = fracture as Dictionary
	for key: String in KEYS:
		if not f.has(key.get_slice(".", 1)):
			v.fail("missing key '%s'" % key)
	if f.has("groups"):
		v.integer(f, "groups", 1, DataValidatorRules.NO_LIMIT, "fracture")
	if f.has("intensity_steps"):
		v.integer(f, "intensity_steps", 1, DataValidatorRules.NO_LIMIT, "fracture")
	if f.has("pulse_ms"):
		v.integer(f, "pulse_ms", maxf(v.min_attack_interval_ms, 1), DataValidatorRules.NO_LIMIT, "fracture")
	if f.has("mod_count"):
		_mod_count(v, v.object(f, "mod_count", "fracture"))
	if f.has("card_rarity"):
		_card_rarity(v, v.object(f, "card_rarity", "fracture"))
	if f.has("card_drop"):
		_card_drop(v, v.object(f, "card_drop", "fracture"))
	if f.has("salvage"):
		_salvage(v, v.object(f, "salvage", "fracture"))
	if f.has("grades"):
		_grades(v, f)


## The areas of `fracture.grades` exist (the area files are validated by DataValidatorClasses).
static func validate_areas(v: DataValidatorRules, balance_files: Dictionary[String, Dictionary],
		area_files: Dictionary[String, Dictionary]) -> void:
	var known: Dictionary[StringName, bool] = {}
	for path: String in area_files:
		for area: Variant in (area_files[path].get("areas", []) as Array):
			if area is Dictionary and (area as Dictionary).get("id") is String:
				known[StringName((area as Dictionary)["id"] as String)] = true
	for path: String in balance_files:
		v.at_file(path)
		var grades: Variant = DataValidator.lookup(balance_files[path], "fracture.grades")
		if not grades is Array:
			continue
		for index: int in (grades as Array).size():
			var row: Variant = (grades as Array)[index]
			if row is Dictionary and (row as Dictionary).get("areas") is Array:
				v.id_list(row as Dictionary, "areas", known, "area", 1, "fracture.grades[%d]" % index)


static func _mod_count(v: DataValidatorRules, mod_count: Dictionary) -> void:
	v.keys(mod_count, RARITIES, "fracture.mod_count")
	for rarity: String in RARITIES:
		if not mod_count.has(rarity):
			v.fail("missing key 'fracture.mod_count.%s'" % rarity)
		elif v.int_pair(mod_count, rarity, 0, MOD_COUNT_MAX, true, "fracture.mod_count") and rarity == "common" \
				and (float(mod_count[rarity][0]) != 0.0 or float(mod_count[rarity][1]) != 0.0):
			v.fail("key 'fracture.mod_count.common' must be [0, 0]")


static func _card_rarity(v: DataValidatorRules, card_rarity: Dictionary) -> void:
	v.keys(card_rarity, ["magic_pct", "rare_pct"], "fracture.card_rarity")
	var total: float = 0.0
	for key: String in ["magic_pct", "rare_pct"]:
		if v.number(card_rarity, key, 0.0, 100.0, "fracture.card_rarity"):
			total += float(card_rarity[key])
	if total > 100.0:
		v.fail("key 'fracture.card_rarity': magic_pct + rare_pct must be <= 100")


static func _card_drop(v: DataValidatorRules, card_drop: Dictionary) -> void:
	v.keys(card_drop, ["monster_pct", "boss_pct", "monster_delta", "boss_delta"], "fracture.card_drop")
	for key: String in ["monster_pct", "boss_pct"]:
		v.number(card_drop, key, 0.0, 100.0, "fracture.card_drop")
	for key: String in ["monster_delta", "boss_delta"]:
		if not card_drop.has(key):
			v.fail("missing key 'fracture.card_drop.%s'" % key)
			continue
		var weights: Variant = card_drop[key]
		var valid: bool = weights is Array and (weights as Array).size() == DELTA_WEIGHTS
		var sum: float = 0.0
		for w: Variant in (weights as Array if weights is Array else []):
			valid = valid and DataValidatorRules.is_int(w) and float(w) >= 0.0
			sum += float(w) if DataValidatorRules.is_number(w) else 0.0
		if not valid or sum < 1.0:
			v.fail("key 'fracture.card_drop.%s' needs %d integer weights >= 0 with a sum >= 1, got %s"
					% [key, DELTA_WEIGHTS, JSON.stringify(weights)])


static func _salvage(v: DataValidatorRules, salvage: Dictionary) -> void:
	v.keys(salvage, ["dust_per_grade", "rarity_mult"], "fracture.salvage")
	v.integer(salvage, "dust_per_grade", 1, DataValidatorRules.NO_LIMIT, "fracture.salvage")
	var mult: Dictionary = v.object(salvage, "rarity_mult", "fracture.salvage")
	v.keys(mult, RARITIES, "fracture.salvage.rarity_mult")
	for rarity: String in RARITIES:
		v.number(mult, rarity, 1.0, DataValidatorRules.NO_LIMIT, "fracture.salvage.rarity_mult")


static func _grades(v: DataValidatorRules, f: Dictionary) -> void:
	var rows: Array[Dictionary] = v.object_list(f, "grades", "fracture")
	if (f["grades"] as Array).size() != GRADE_COUNT:
		v.fail("key 'fracture.grades' needs exactly %d rows (one per grade), got %d" % [GRADE_COUNT, (f["grades"] as Array).size()])
	var previous: Dictionary = {}
	for index: int in rows.size():
		var prefix: String = "fracture.grades[%d]" % index
		var row: Dictionary = rows[index]
		v.keys(row, GRADE_FIELDS, prefix)
		v.id_list(row, "areas", null, "area", 1, prefix)
		v.integer(row, "level_bonus", 0, DataValidatorRules.NO_LIMIT, prefix)
		for key: String in ["hp_mult", "damage_mult", "reward_mult"]:
			v.number(row, key, 1.0, DataValidatorRules.NO_LIMIT, prefix)
		v.integer(row, "piece_grade", 1, PIECE_GRADE_MAX, prefix)
		v.integer(row, "recommended_level", 1, minf(RECOMMENDED_LEVEL_MAX, v.max_character_level), prefix)
		if not previous.is_empty():
			_not_decreasing(v, row, previous, ["piece_grade", "recommended_level"], prefix, false)
			_not_decreasing(v, row, previous, ["hp_mult", "damage_mult", "reward_mult"], prefix, true)
		previous = row


# `fields` of `row` must not be lower than those of `previous`; with `same_areas` only when both rows use the same areas.
static func _not_decreasing(v: DataValidatorRules, row: Dictionary, previous: Dictionary, fields: PackedStringArray,
		prefix: String, same_areas: bool) -> void:
	if same_areas and row.get("areas") != previous.get("areas"):
		return
	for key: String in fields:
		if DataValidatorRules.is_number(row.get(key)) and DataValidatorRules.is_number(previous.get(key)) \
				and float(row[key]) < float(previous[key]):
			v.fail("key '%s.%s' must not decrease from the previous grade" % [prefix, key])
