class_name LootIndex
extends RefCounted
## Helper of GameData (internal, kept out of game_data.gd for its size limit): the loot tables of
## data/combat/loot_tables.json (M12). The file is mandatory (a CONTENT_FILES section).

const FILE: String = "combat/loot_tables.json"

var by_id: Dictionary[StringName, LootTableDef] = {}
var list: Array[LootTableDef] = []


## Builds from the raw top-level object of the file ({} when the file does not exist); a Def that cannot be built is
## reported in `errors`.
func build(raw: Dictionary, errors: PackedStringArray) -> void:
	for path: String in raw:
		for d: Variant in (raw[path]["tables"] as Array):
			var def: LootTableDef = LootTableDef.from_dict(d as Dictionary)
			if def == null:
				errors.append("%s: loot table '%s': cannot be built (see the log)" % [path, (d as Dictionary).get("id")])
				continue
			by_id[def.id] = def
			list.append(def)


func clear() -> void:
	by_id.clear()
	list.clear()
