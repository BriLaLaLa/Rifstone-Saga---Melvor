class_name DataValidatorAreas
extends RefCounted
## Part of DataValidator (internal, not API for other modules): the rules of the narrow areas of M17
## (docs/04_DATA_SCHEMA.md §8, docs/02_FORMULAS.md §8.5): `level_min`, `level_max`, `map_pos` and the pack rules per area.
## They apply when at least one area has `level_min` (the old format of the fixtures stays valid); then every area must have
## the three fields. Written with the toolkit of DataValidatorRules.

const LEVEL_FIRST: int = 1
const SPAN_MAX: int = 9  # level_max - level_min
const MAP_DISTANCE_MIN: float = 0.08
const MEAN_SIZE_MIN: float = 3.0
const MEAN_SIZE_MAX: float = 5.0
const EDGE_SIZE_SHARE_MAX: float = 0.06  # the weight of the packs of size 1 and of the largest size, each, over the total


## Reads `combat.pack_size_weights` into `v.pack_size_weights` when it is a list of integers (the balance rules report the rest).
static func collect_pack_weights(v: DataValidatorRules, balance: Dictionary) -> void:
	var combat: Variant = balance.get("combat")
	if not combat is Dictionary or not (combat as Dictionary).get("pack_size_weights") is Array:
		return
	var weights: Array[int] = []
	for w: Variant in ((combat as Dictionary)["pack_size_weights"] as Array):
		if not DataValidatorRules.is_int(w):
			return
		weights.append(int(w))
	v.pack_size_weights = weights


static func validate(v: DataValidatorRules, files: Dictionary[String, Dictionary]) -> void:
	var areas: Array[Dictionary] = []
	for path: String in files:
		for a: Variant in (files[path].get("areas", []) as Array):
			if a is Dictionary:
				areas.append(a as Dictionary)
	var narrow: bool = false
	for a: Dictionary in areas:
		narrow = narrow or a.has("level_min")
	if not narrow or files.is_empty():
		return
	v.at_file(files.keys()[0])
	areas.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("order", 0)) < int(b.get("order", 0)))
	var previous_max: int = LEVEL_FIRST - 1
	var positions: Array[Vector2] = []
	var names: Array[String] = []
	for i: int in areas.size():
		var a: Dictionary = areas[i]
		v.at_entry("area", i, a)
		var ok: bool = _levels(v, a)
		if ok:
			var level_min: int = int(a["level_min"])
			if level_min != previous_max + 1:
				v.fail("field 'level_min': %d, the area must start at %d (contiguous areas from level %d)" % [level_min, previous_max + 1, LEVEL_FIRST])
			previous_max = int(a["level_max"])
			_requirement(v, a, level_min)
			_monster_levels(v, a, level_min, previous_max)
		_map_pos(v, a, positions, names)
		_packs(v, a)
	if not areas.is_empty() and previous_max != int(v.max_character_level):
		if v.max_character_level != DataValidatorRules.NO_LIMIT:
			v.fail("the last area ends at level %d, it must end at character_curve.max_level (%d)" % [previous_max, int(v.max_character_level)])


static func _levels(v: DataValidatorRules, a: Dictionary) -> bool:
	var top: float = v.max_character_level
	var ok: bool = v.integer(a, "level_min", 1, top)
	ok = v.integer(a, "level_max", 1, top) and ok
	if ok and int(a["level_min"]) > int(a["level_max"]):
		v.fail("field 'level_min': %d is above level_max %d" % [int(a["level_min"]), int(a["level_max"])])
		return false
	if ok and int(a["level_max"]) - int(a["level_min"]) > SPAN_MAX:
		v.fail("fields 'level_min'/'level_max': the area covers more than %d levels" % (SPAN_MAX + 1))
		return false
	return ok


static func _requirement(v: DataValidatorRules, a: Dictionary, level_min: int) -> void:
	var req: Variant = a.get("requirements")
	if not req is Dictionary or not DataValidatorRules.is_number((req as Dictionary).get("character")) \
			or int((req as Dictionary)["character"]) != level_min:
		v.fail("field 'requirements.character' must be level_min (%d)" % level_min)


# Every monster of the packs has the level F-130 gives it (highest of its three levels) inside [level_min, level_max].
static func _monster_levels(v: DataValidatorRules, a: Dictionary, level_min: int, level_max: int) -> void:
	var checked: Dictionary[StringName, bool] = {}
	for pack: Variant in (a.get("packs", []) as Array):
		if not pack is Dictionary or not (pack as Dictionary).get("monsters") is Array:
			continue
		for id: Variant in ((pack as Dictionary)["monsters"] as Array):
			var key := StringName(str(id))
			if checked.has(key) or not v.monsters.has(key):
				continue
			checked[key] = true
			var level: int = 0
			for field: String in ["attack_level", "power_level", "defence_level"]:
				if DataValidatorRules.is_number(v.monsters[key].get(field)):
					level = maxi(level, int(v.monsters[key][field]))
			if level < level_min or level > level_max:
				v.fail("monster '%s' has level %d, outside the levels %d-%d of the area" % [key, level, level_min, level_max])


static func _map_pos(v: DataValidatorRules, a: Dictionary, positions: Array[Vector2], names: Array[String]) -> void:
	var pos: Variant = a.get("map_pos")
	if not pos is Array or (pos as Array).size() != 2 or not DataValidatorRules.is_number((pos as Array)[0]) \
			or not DataValidatorRules.is_number((pos as Array)[1]) \
			or float((pos as Array)[0]) < 0.0 or float((pos as Array)[0]) > 1.0 \
			or float((pos as Array)[1]) < 0.0 or float((pos as Array)[1]) > 1.0:
		v.fail("field 'map_pos' must be [x, y], two numbers in 0..1")
		return
	var point := Vector2(float((pos as Array)[0]), float((pos as Array)[1]))
	for i: int in positions.size():
		if positions[i].distance_to(point) < MAP_DISTANCE_MIN:
			v.fail("field 'map_pos': closer than %s to the area '%s'" % [MAP_DISTANCE_MIN, names[i]])
	positions.append(point)
	names.append(str(a.get("id", "")))


# Packs: every size 1..max_pack_size is present, the weights per size are `combat.pack_size_weights`, the weighted mean size is
# MEAN_SIZE_MIN..MEAN_SIZE_MAX and the packs of size 1 and of the largest size are at most EDGE_SIZE_SHARE_MAX of the total each.
static func _packs(v: DataValidatorRules, a: Dictionary) -> void:
	if v.max_pack_size == DataValidatorRules.NO_LIMIT or not a.get("packs") is Array:
		return
	var biggest: int = int(v.max_pack_size)
	var by_size: Dictionary[int, int] = {}
	for pack: Variant in (a["packs"] as Array):
		if not pack is Dictionary or not (pack as Dictionary).get("monsters") is Array \
				or not DataValidatorRules.is_int((pack as Dictionary).get("weight")):
			return  # already reported by the pack rules
		var size: int = ((pack as Dictionary)["monsters"] as Array).size()
		by_size[size] = by_size.get(size, 0) + int((pack as Dictionary)["weight"])
	var total: int = 0
	var weighted: float = 0.0
	for size: int in by_size:
		total += by_size[size]
		weighted += float(size * by_size[size])
	for size: int in range(1, biggest + 1):
		if not by_size.has(size):
			v.fail("field 'packs': no pack of %d monsters (every size 1..%d is needed)" % [size, biggest])
		elif v.pack_size_weights.size() == biggest and by_size[size] != v.pack_size_weights[size - 1]:
			v.fail("field 'packs': the packs of %d monsters weigh %d, combat.pack_size_weights says %d" % [size, by_size[size], v.pack_size_weights[size - 1]])
	if total <= 0:
		return
	var mean: float = weighted / float(total)
	if mean < MEAN_SIZE_MIN or mean > MEAN_SIZE_MAX:
		v.fail("field 'packs': the weighted mean size is %.2f, it must be %s-%s" % [mean, MEAN_SIZE_MIN, MEAN_SIZE_MAX])
	for size: int in [1, biggest]:
		if float(by_size.get(size, 0)) > EDGE_SIZE_SHARE_MAX * float(total):
			v.fail("field 'packs': the packs of %d monsters are %.1f%% of the weight, at most %.0f%%" % [size, 100.0 * by_size.get(size, 0) / total, 100.0 * EDGE_SIZE_SHARE_MAX])
