class_name DataValidatorStones
extends RefCounted
## Part of DataValidator (internal, not API for other modules): `data/combat/rift_stones.json` (M7, M15 rewrite,
## docs/04_DATA_SCHEMA.md §22, F-87, F-125), written with the toolkit of DataValidatorRules.

const STONE_FIELDS: PackedStringArray = ["id", "name", "description", "icon", "area", "level", "xp", "pulse_ms",
	"wave_packs", "shards", "drops", "loot_tables"]
const ICON_DIR: String = "res://assets/icons/monsters/"
const STEP: int = 5  # Z2: one stone type every 5 levels
const DROPS_MAX: int = 8


static func validate(v: DataValidatorRules, files: Dictionary[String, Dictionary],
		areas: Dictionary[String, Dictionary]) -> void:
	var area_entries: Array[Dictionary] = []  # raw area entries, ordered by `order`
	for path: String in areas:
		for a: Variant in (areas[path].get("areas", []) as Array):
			if a is Dictionary and (a as Dictionary).get("id") is String:
				area_entries.append(a as Dictionary)
	area_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("order", 0)) < int(b.get("order", 0)))
	var by_area: Dictionary[StringName, Dictionary] = {}
	for a: Dictionary in area_entries:
		by_area[StringName(a["id"] as String)] = a
	var seen: Dictionary[StringName, bool] = {}
	var levels: Dictionary[StringName, Array] = {}  # area id -> the levels present
	for path: String in files:
		v.at_file(path)
		var list: Array[Dictionary] = DataValidator.entries(v, files[path], "rift_stones")
		for index: int in list.size():
			var e: Dictionary = list[index]
			v.entry("rift stone", index, e, seen, STONE_FIELDS)
			DataValidatorClasses.existing_icon(v, e, ICON_DIR)
			var valid_level: bool = v.integer(e, "level", STEP)
			if valid_level and int(e["level"]) % STEP != 0:
				v.fail("field 'level': must be a multiple of %d, got %d" % [STEP, int(e["level"])])
				valid_level = false
			if v.ref(e, "area", by_area, "area"):
				var area_id := StringName(e["area"] as String)
				_wave_packs(v, e, (by_area[area_id].get("packs", []) as Array).size())
				if valid_level:
					if not levels.has(area_id):
						levels[area_id] = []
					if (levels[area_id] as Array).has(int(e["level"])):
						v.fail("field 'level': '%s' already has a Rift Stone of level %d" % [area_id, int(e["level"])])
					(levels[area_id] as Array).append(int(e["level"]))
			v.integer(e, "xp", 0)
			v.integer(e, "pulse_ms", maxf(v.min_attack_interval_ms, 1))
			v.int_pair(e, "shards", 0, DataValidatorRules.NO_LIMIT, true)
			DataValidatorClasses.drops(v, e)
			if e.get("drops") is Array and (e["drops"] as Array).size() > DROPS_MAX:
				v.fail("field 'drops': at most %d entries, got %d" % [DROPS_MAX, (e["drops"] as Array).size()])
	_pools(v, files, area_entries, levels, int(v.max_character_level) if v.max_character_level != DataValidatorRules.NO_LIMIT else 0)


# `wave_packs`: null (every pack of the area) or indices of the packs of the area.
static func _wave_packs(v: DataValidatorRules, e: Dictionary, pack_count: int) -> void:
	if not e.has("wave_packs"):
		v.fail("missing field 'wave_packs'")
	elif e["wave_packs"] == null:
		return
	elif not e["wave_packs"] is Array:
		v.fail("field 'wave_packs' must be null or an array of integers")
	else:
		for entry: Variant in (e["wave_packs"] as Array):
			if not DataValidatorRules.is_int(entry) or float(entry) < 0.0 or float(entry) > float(pack_count - 1):
				v.fail("field 'wave_packs': %s is not the index of a pack of the area (0..%d)" % [JSON.stringify(entry), pack_count - 1])


# Z2: the levels of an area are exactly the multiples of 5 from ceil5(requirements.character) (at least 5) up to the last
# level of the area (= first level of the next area - 1; the last area: the character cap). Checked for the areas that
# have a character requirement (and a following one that has it too, or the last area).
static func _pools(v: DataValidatorRules, files: Dictionary[String, Dictionary], area_entries: Array[Dictionary],
		levels: Dictionary[StringName, Array], max_level: int) -> void:
	if files.is_empty():
		return
	v.at_file(files.keys()[0])
	for i: int in area_entries.size():
		var area: Dictionary = area_entries[i]
		var area_id := StringName(area["id"] as String)
		var low: int = _character_level(area)
		var high: int = max_level if i == area_entries.size() - 1 else _character_level(area_entries[i + 1]) - 1
		if low < 0 or high < 0 or high < low or not levels.has(area_id):
			continue
		var expected: Array[int] = pool(low, high)
		var present: Array = levels[area_id].duplicate()
		present.sort()
		if present != expected:
			v.fail("area '%s': the Rift Stone levels must be %s, got %s" % [area_id, expected, present])


## Z2: the multiples of 5 in [`low`, `high`], with `low` rounded up to 5 (at least 5) and the highest multiple of 5 not above
## `high` always included.
static func pool(low: int, high: int) -> Array[int]:
	var result: Array[int] = []
	var level: int = maxi(STEP, int(ceil(float(low) / float(STEP))) * STEP)
	while level <= high:
		result.append(level)
		level += STEP
	if result.is_empty():
		result.append(maxi(STEP, (high / STEP) * STEP))
	return result


static func _character_level(area: Dictionary) -> int:
	var req: Variant = area.get("requirements")
	if req is Dictionary and DataValidatorRules.is_number((req as Dictionary).get("character")):
		return int((req as Dictionary)["character"])
	return -1
