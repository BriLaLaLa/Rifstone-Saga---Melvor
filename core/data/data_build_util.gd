class_name DataBuildUtil
extends RefCounted
## Helpers of GameData (internal, kept out of game_data.gd for its size limit).


## The XpTable of a `*_curve` section of balance.json.
static func curve(balance: Dictionary, key: String) -> XpTable:
	var c: Dictionary = balance[key] as Dictionary
	return XpTable.from_params(float(c["base"]), float(c["growth"]), float(c["linear"]), int(c["max_level"]))


## Actions by `level`, then id.
static func action_before(a: ActionDef, b: ActionDef) -> bool:
	if a.level != b.level:
		return a.level < b.level
	return String(a.id) < String(b.id)


## The list under `key` of a content file, as typed dictionaries.
static func list(content: Variant, key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.assign((content as Dictionary)[key] as Array)
	return result


## {path: top-level object} of the files that load as objects; the others are reported in `errors`.
static func read_files(paths: PackedStringArray, errors: PackedStringArray) -> Dictionary:
	var files: Dictionary = {}
	for path: String in paths:
		var content: Variant = JsonLoader.load_file(path, errors)
		if content is Dictionary:
			files[path] = content
		elif content != null:
			errors.append("%s: the top level is not an object" % path)
	return files
