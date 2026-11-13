class_name DungeonIndex
extends RefCounted
## Helper of GameData (internal, kept out of game_data.gd for its size limit): the dungeons of data/dungeons/*.json
## (docs/04_DATA_SCHEMA.md §27), by id and in order of `order`, and the ticket of each. The folder is optional while the
## real data has no dungeon yet (DataValidatorDungeon.STRICT_REAL_DATA).

const DIR: String = "dungeons"

var by_id: Dictionary[StringName, DungeonDef] = {}
var list: Array[DungeonDef] = []
var by_ticket: Dictionary[StringName, DungeonDef] = {}


## The `.json` files of `<content_root>/dungeons`; empty, without an error, when the folder does not exist.
static func list_files(content_root: String, errors: PackedStringArray) -> PackedStringArray:
	var dir: String = content_root.path_join(DIR)
	if not DirAccess.dir_exists_absolute(dir):
		return PackedStringArray()
	return JsonLoader.list_json_files(dir, errors)


## `raw` is `{path: top-level object}`; the monsters of every dungeon are added to `monsters` (they are ordinary monsters
## of the game, `GameData.monster(id)`). A Def that cannot be built is reported in `errors`.
func build(raw: Dictionary, monsters: Dictionary[StringName, MonsterDef], errors: PackedStringArray) -> void:
	for path: String in raw:
		var def: DungeonDef = DungeonDef.from_dict(raw[path] as Dictionary)
		if def == null:
			errors.append("%s: dungeon '%s': cannot be built (see the log)" % [path, (raw[path] as Dictionary).get("id")])
			continue
		by_id[def.id] = def
		by_ticket[def.ticket] = def
		list.append(def)
		for monster: MonsterDef in def.monsters:
			monsters[monster.id] = monster
	list.sort_custom(func(a: DungeonDef, b: DungeonDef) -> bool: return a.order < b.order)


func clear() -> void:
	by_id.clear()
	by_ticket.clear()
	list.clear()
