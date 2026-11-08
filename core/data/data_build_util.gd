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
