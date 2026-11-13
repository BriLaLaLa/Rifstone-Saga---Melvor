class_name VillageIndex
extends RefCounted
## Helper of GameData (internal, kept out of game_data.gd for its size limit): the buildings of
## data/village/buildings.json (docs/04_DATA_SCHEMA.md §24), by id and in order of `order`.

const FILE: String = "village/buildings.json"

var by_id: Dictionary[StringName, VillageBuildingDef] = {}
var list: Array[VillageBuildingDef] = []


## `raw` is `{path: top-level object}` of the single file; a Def that cannot be built is reported in `errors`.
func build(raw: Dictionary, errors: PackedStringArray) -> void:
	for path: String in raw:
		for d: Variant in (raw[path]["buildings"] as Array):
			var def: VillageBuildingDef = VillageBuildingDef.from_dict(d as Dictionary)
			if def == null:
				errors.append("%s: building '%s': cannot be built (see the log)" % [path, (d as Dictionary).get("id")])
				continue
			by_id[def.id] = def
			list.append(def)
	list.sort_custom(func(a: VillageBuildingDef, b: VillageBuildingDef) -> bool: return a.order < b.order)


func clear() -> void:
	by_id.clear()
	list.clear()
