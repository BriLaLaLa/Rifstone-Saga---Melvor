class_name MapIndex
extends RefCounted
## Helper of GameData (internal, kept out of game_data.gd for its size limit): the Fracture data of M13
## (docs/04_DATA_SCHEMA.md §11) - the Card bases by grade, the modifiers of data/maps/map_mods.json, the bosses of
## data/maps/bosses.json and the rows of `fracture.grades` (F-110). Empty lists are valid (the files may be empty).

const MODS_FILE: String = "maps/map_mods.json"
const BOSSES_FILE: String = "maps/bosses.json"

var bases: Dictionary[int, ItemDef] = {}
var mods: Array[MapModDef] = []
var mods_by_id: Dictionary[StringName, MapModDef] = {}
var bosses: Array[BossDef] = []
var bosses_by_id: Dictionary[StringName, BossDef] = {}
var boss_by_grade: Dictionary[int, BossDef] = {}
var grade_by_number: Dictionary[int, FractureGradeDef] = {}


## Builds from the items, the raw top-level objects of the two files ({path: object}) and the balance; a Def that
## cannot be built is reported in `errors`.
func build(items: Array[ItemDef], raw_mods: Dictionary, raw_bosses: Dictionary, balance: Dictionary,
		errors: PackedStringArray) -> void:
	for item: ItemDef in items:
		if item.is_map():
			bases[item.map_grade] = item
	for path: String in raw_mods:
		for d: Variant in (raw_mods[path]["mods"] as Array):
			var mod: MapModDef = MapModDef.from_dict(d as Dictionary)
			if mod == null:
				errors.append("%s: map mod '%s': cannot be built (see the log)" % [path, (d as Dictionary).get("id")])
				continue
			mods.append(mod)
			mods_by_id[mod.id] = mod
	for path: String in raw_bosses:
		for d: Variant in (raw_bosses[path]["bosses"] as Array):
			var boss: BossDef = BossDef.from_dict(d as Dictionary)
			if boss == null:
				errors.append("%s: boss '%s': cannot be built (see the log)" % [path, (d as Dictionary).get("id")])
				continue
			bosses.append(boss)
			bosses_by_id[boss.id] = boss
			boss_by_grade[boss.grade] = boss
	var rows: Array = DataValidator.lookup(balance, "fracture.grades") as Array
	for index: int in rows.size():
		var row: FractureGradeDef = FractureGradeDef.from_dict(rows[index] as Dictionary, index + 1)
		if row == null:
			errors.append("balance.json: fracture grade %d: cannot be built (see the log)" % (index + 1))
		else:
			grade_by_number[row.grade] = row


func clear() -> void:
	bases.clear()
	mods.clear()
	mods_by_id.clear()
	bosses.clear()
	bosses_by_id.clear()
	boss_by_grade.clear()
	grade_by_number.clear()
