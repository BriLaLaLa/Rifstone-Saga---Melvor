class_name StatRegistry
extends RefCounted
## The registered stats (docs/04_DATA_SCHEMA.md §2) and the limits of their totals (F-05).
##
## Built from the already-parsed `stats` array of `data/config/stats.json` (GameData does the file reading);
## this class never touches the disk. Malformed entries are reported in `errors` and left out.

const FORMATS: Array[String] = ["pct", "flat", "flag"]
const TEXT_FIELDS: Array[String] = ["name", "description", "formula", "test"]

# stat id -> {name, format, min, max, description, formula, test}
var _stats: Dictionary[StringName, Dictionary] = {}


static func from_array(stats: Array, errors: PackedStringArray) -> StatRegistry:
	var registry := StatRegistry.new()
	for index: int in stats.size():
		var entry: Variant = stats[index]
		if not entry is Dictionary:
			errors.append("stats[%d]: not an object" % index)
			continue
		registry._add(entry as Dictionary, index, errors)
	return registry


func has(stat: StringName) -> bool:
	return _stats.has(stat)


func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in _stats:
		result.append(id)
	return result


## A copy of the stat definition; empty (and an error) for an unknown stat.
func info(stat: StringName) -> Dictionary:
	if not _stats.has(stat):
		Log.error("modifiers", "info of unknown stat '%s'" % stat)
		return {}
	return _stats[stat].duplicate()


## Limits a total to the stat's [min, max]; an unknown stat is an error and the value is returned unchanged.
func clamp_total(stat: StringName, value: float) -> float:
	if not _stats.has(stat):
		Log.error("modifiers", "clamp_total of unknown stat '%s'" % stat)
		return value
	var def: Dictionary = _stats[stat]
	return clampf(value, float(def["min"]), float(def["max"]))


func _add(entry: Dictionary, index: int, errors: PackedStringArray) -> void:
	var raw_id: Variant = entry.get("id")
	if not raw_id is String or (raw_id as String).is_empty():
		errors.append("stats[%d]: missing or empty 'id'" % index)
		return
	var id := StringName(raw_id as String)
	var where: String = "stats[%d] '%s'" % [index, id]
	if _stats.has(id):
		errors.append("%s: duplicate id" % where)
		return
	var count_before: int = errors.size()
	for field: String in TEXT_FIELDS:
		if not entry.get(field) is String or (entry.get(field) as String).is_empty():
			errors.append("%s: missing or empty '%s'" % [where, field])
	var format: Variant = entry.get("format")
	if not format is String or not FORMATS.has(format as String):
		errors.append("%s: 'format' must be one of %s" % [where, FORMATS])
	var low: Variant = entry.get("min")
	var high: Variant = entry.get("max")
	if not _is_number(low) or not _is_number(high):
		errors.append("%s: 'min' and 'max' must be numbers" % where)
	elif float(low) >= float(high):
		errors.append("%s: 'min' must be lower than 'max'" % where)
	if errors.size() > count_before:
		return
	_stats[id] = {
		"name": entry["name"], "format": entry["format"], "min": float(low), "max": float(high),
		"description": entry["description"], "formula": entry["formula"], "test": entry["test"],
	}


static func _is_number(v: Variant) -> bool:
	return v is float or v is int
