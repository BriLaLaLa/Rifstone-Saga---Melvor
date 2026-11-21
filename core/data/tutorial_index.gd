class_name TutorialIndex
extends RefCounted
## Helper of GameData (internal): the tutorial steps and the starter quests (docs/04_DATA_SCHEMA_M30.md §34), in file order.

const STEPS_FILE: String = "tutorial/steps.json"
const QUESTS_FILE: String = "tutorial/starter_quests.json"

var stuck_ms: int = 0
var always_open: Array[StringName] = []
var steps: Array[TutorialStepDef] = []
var steps_by_id: Dictionary[StringName, TutorialStepDef] = {}
var groups: Array[Dictionary] = []
var quests: Array[StarterQuestDef] = []
var quests_by_id: Dictionary[StringName, StarterQuestDef] = {}
var final_reward: StarterFinalDef = null  # M31


## `raw_steps` / `raw_quests` are `{path: top-level object}` of the single files; what cannot be built goes to `errors`.
func build(raw_steps: Dictionary, raw_quests: Dictionary, errors: PackedStringArray) -> void:
	for path: String in raw_steps:
		var file: Dictionary = raw_steps[path] as Dictionary
		stuck_ms = int(file["stuck_ms"])
		for entry: Variant in file["always_open"] as Array:
			always_open.append(StringName(str(entry)))
		for d: Dictionary in DataBuildUtil.list(file, "steps"):
			var def: TutorialStepDef = TutorialStepDef.from_dict(d)
			if def == null:
				errors.append("%s: step '%s': cannot be built (see the log)" % [path, d.get("id")])
				continue
			steps.append(def)
			steps_by_id[def.id] = def
	for path: String in raw_quests:
		var file: Dictionary = raw_quests[path] as Dictionary
		if file.get("final_reward") is Dictionary:
			final_reward = StarterFinalDef.from_dict(file["final_reward"] as Dictionary)
			if final_reward == null:
				errors.append("%s: final_reward: cannot be built (see the log)" % path)
		for g: Dictionary in DataBuildUtil.list(file, "groups"):
			groups.append({"id": StringName(str(g["id"])), "title": str(g["title"])})
		for d: Dictionary in DataBuildUtil.list(file, "quests"):
			var def: StarterQuestDef = StarterQuestDef.from_dict(d)
			if def == null:
				errors.append("%s: starter quest '%s': cannot be built (see the log)" % [path, d.get("id")])
				continue
			quests.append(def)
			quests_by_id[def.id] = def


func clear() -> void:
	stuck_ms = 0
	always_open.clear()
	steps.clear()
	steps_by_id.clear()
	groups.clear()
	quests.clear()
	quests_by_id.clear()
	final_reward = null
