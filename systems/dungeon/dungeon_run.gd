class_name DungeonRun
extends RefCounted
## The state of a dungeon run (docs/05_INTERFACES.md §5.29, F-141): plain data, no signals. The combat engine reads it;
## `DungeonSystem` is the only writer. The hidden map is never saved: it is rebuilt from the seed.

const LOG_CATEGORY: String = "dungeon"
const PHASE_FIGHT: StringName = &"fight"
const PHASE_EVENT: StringName = &"event"
const PHASE_AWAIT: StringName = &"await"
const PHASE_INTRO: StringName = &"intro"
const PHASES: Array[StringName] = [PHASE_FIGHT, PHASE_EVENT, PHASE_AWAIT, PHASE_INTRO]

var dungeon_id: StringName = &""
var seed_value: int = 0
var map: DungeonMap = null
var layer: int = 0
var index: int = 0
var phase: StringName = PHASE_FIGHT
var stage: int = 0  # 0 = outside the boss; 1..3 = the stage in progress or just beaten
var paused: bool = false
var path: Array[Vector2i] = []  # the rooms already beaten (for the UI and the tests)
var bag: FractureBag = FractureBag.new()
var return_area: StringName = &""
var cleared: int = 0


## A new run at the entrance, in the fight phase and not paused.
static func create(def: DungeonDef, seed_value_in: int, return_to: StringName, data: GameData) -> DungeonRun:
	var run := DungeonRun.new()
	run.dungeon_id = def.id
	run.seed_value = seed_value_in
	run.map = DungeonGenerator.generate(def, seed_value_in, data)
	run.return_area = return_to
	return run


func to_save() -> Dictionary:
	var path_out: Array = []
	for cell: Vector2i in path:
		path_out.append([cell.x, cell.y])
	return {"dungeon": String(dungeon_id), "seed": seed_value, "layer": layer, "index": index, "phase": String(phase),
		"stage": stage, "paused": paused, "path": path_out, "return_area": String(return_area), "cleared": cleared,
		"bag": bag.to_save()}


## Null (after a warning) if the dungeon or the phase is unknown or the room is outside the map. The map is rebuilt from the
## seed. A loaded run is always paused (F-144 rule 1), whatever the file says.
static func from_save(d: Dictionary, data: GameData) -> DungeonRun:
	var def: DungeonDef = find_def(StringName(str(d.get("dungeon", ""))), data)
	var seed_raw: Variant = d.get("seed")
	if def == null or not _is_int(seed_raw) or int(seed_raw) < 1:
		Log.warn(LOG_CATEGORY, "saved dungeon run with an unknown dungeon or a bad seed: dropped")
		return null
	var run: DungeonRun = create(def, int(seed_raw), StringName(str(d.get("return_area", ""))), data)
	if not data.has_area(run.return_area):
		run.return_area = &""
	var counts: Array[int] = []
	for key: String in ["layer", "index", "stage", "cleared"]:
		var value: Variant = d.get(key)
		if not _is_int(value) or int(value) < 0:
			Log.warn(LOG_CATEGORY, "saved dungeon run with a bad '%s': dropped" % key)
			return null
		counts.append(int(value))
	run.layer = counts[0]
	run.index = counts[1]
	run.stage = counts[2]
	run.cleared = counts[3]
	run.phase = StringName(str(d.get("phase", "")))
	if not run._fits(def):
		Log.warn(LOG_CATEGORY, "saved dungeon run with a phase or a room that does not fit the map: dropped")
		return null
	run.paused = true
	if d.get("path") is Array:
		for cell: Variant in d["path"] as Array:
			if cell is Array and (cell as Array).size() == 2 and _is_int((cell as Array)[0]) and _is_int((cell as Array)[1]):
				run.path.append(Vector2i(int((cell as Array)[0]), int((cell as Array)[1])))
	if d.get("bag") is Dictionary:
		run.bag.from_save(d["bag"], data)
	return run


## The dungeon `id` of the data; null (without an error) if there is none.
static func find_def(id: StringName, data: GameData) -> DungeonDef:
	for def: DungeonDef in data.dungeons():
		if def.id == id:
			return def
	return null


# The phase, the stage and the room agree with each other and with the map.
func _fits(def: DungeonDef) -> bool:
	var room: DungeonRoom = map.room(layer, index)
	var boss_layer: int = map.layers() - 1
	if not PHASES.has(phase) or room == null or stage > def.stages.size() or (stage > 0) != (layer == boss_layer):
		return false
	if phase == PHASE_INTRO and stage == 0:
		return false
	if phase == PHASE_EVENT and room.kind != &"trap" and room.kind != &"rest":
		return false
	return not (phase == PHASE_AWAIT and layer == boss_layer)


static func _is_int(v: Variant) -> bool:
	return v is int or (v is float and v == floorf(v))
