class_name DisciplineIndex
extends RefCounted
## Helper of GameData (internal, kept out of game_data.gd for its size limit): the grades and Trainers of
## data/disciplines/trainers.json and the area nodes of data/encounters/nodes.json (docs/04_DATA_SCHEMA_M24.md §29.2-§29.3).
## `nodes.json` is optional while `DataValidatorDisciplines.STRICT_REAL_DATA` is false: without it no area has nodes.

const TRAINERS_FILE: String = "disciplines/trainers.json"
const NODES_FILE: String = "encounters/nodes.json"

var grades: Array[TrainerGradeDef] = []
var trainers: Dictionary[StringName, TrainerDef] = {}
var nodes: Dictionary[StringName, AreaNodesDef] = {}


## The ids of the skills with `discipline` (of `category`, any if empty), in the order of `skills`.
static func ids(skills: Array[SkillDef], category: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for def: SkillDef in skills:
		if def.discipline and (category == &"" or def.category == category):
			result.append(def.id)
	return result


## The `nodes.json` path of `content_root` when the file exists (a one-element list), else an empty list.
static func nodes_files(content_root: String) -> PackedStringArray:
	var path: String = content_root.path_join(NODES_FILE)
	return PackedStringArray([path]) if FileAccess.file_exists(path) else PackedStringArray()


## `trainers_raw` and `nodes_raw` are `{path: top-level object}`; a Def that cannot be built is reported in `errors`.
func build(trainers_raw: Dictionary, nodes_raw: Dictionary, errors: PackedStringArray) -> void:
	for path: String in trainers_raw:
		for d: Variant in (trainers_raw[path]["grades"] as Array):
			var grade: TrainerGradeDef = TrainerGradeDef.from_dict(d as Dictionary)
			if grade == null:
				errors.append("%s: trainer grade '%s': cannot be built (see the log)" % [path, (d as Dictionary).get("id")])
				continue
			grades.append(grade)
		for d: Variant in (trainers_raw[path]["trainers"] as Array):
			var trainer: TrainerDef = TrainerDef.from_dict(d as Dictionary)
			if trainer == null:
				errors.append("%s: trainer '%s': cannot be built (see the log)" % [path, (d as Dictionary).get("skill")])
				continue
			trainers[trainer.skill] = trainer
	for path: String in nodes_raw:
		for d: Variant in (nodes_raw[path]["areas"] as Array):
			var area_nodes: AreaNodesDef = AreaNodesDef.from_dict(d as Dictionary)
			if area_nodes == null:
				errors.append("%s: area nodes '%s': cannot be built (see the log)" % [path, (d as Dictionary).get("area")])
				continue
			nodes[area_nodes.area] = area_nodes


func clear() -> void:
	grades.clear()
	trainers.clear()
	nodes.clear()
