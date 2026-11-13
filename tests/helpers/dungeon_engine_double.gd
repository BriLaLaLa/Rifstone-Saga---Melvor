class_name DungeonEngineDouble
extends RefCounted
## Not a test (GUT only runs `test_*.gd`): a stand-in for the combat engine with only the dungeon methods of
## docs/05_INTERFACES.md §5.29, for the tests of `DungeonSystem` (M22-04). It records the calls and plays the engine's part
## by hand: `clear_room`, `end_intro`, `clear_stage`, `die`. `DungeonSystem.use_engine(double)` plugs it in.
## The fixture dungeon has a test-only legendary through `data_with_pool(true)` (source `dungeon`, `chance_pct` 100).

const PreRun := preload("res://tests/helpers/gut_pre_run.gd")
const ROOT: String = "res://tests/fixtures/data"
const SKIPPED_DIRS: PackedStringArray = ["m10", "m14"]
const LEGENDARY_ID: StringName = &"test_den_legendary"

static var _cache: Dictionary[bool, GameData] = {}

var session: GameSession
var calls: Array = []  # ["start"], ["room", layer, kind, [ids]], ["stage", stage_id], ["pause", bool], ["abandon", outcome]
var rooms: Array[Dictionary] = []  # {"layer", "kind", "ids"} of every room fight begun
var player_hp: int = 1000
var player_max_hp: int = 1000
var intro_left_ms: int = 0
var returned_to: Array[StringName] = []  # the area the engine goes back to after a won / left run
var start_result: CommandResult = null

var _stage: DungeonStageDef = null


func _init(for_session: GameSession) -> void:
	session = for_session
	session.events.dungeon_finished.connect(_on_finished)


## A double plugged into `s` (a session of the fixtures): a level 40 character, `tickets` tickets in the Bank, a roomy Deposit.
static func attach(s: GameSession, tickets: int = 3, roomy: bool = true) -> DungeonEngineDouble:
	s.character.add_xp(2_000_000)
	s.bank.add(&"test_den_ticket", tickets)
	if roomy:
		TestFactory.make_roomy(s)
	var engine := DungeonEngineDouble.new(s)
	s.dungeon.use_engine(engine)
	return engine


## Opens `test_den` and clears the entrance room.
func open_and_clear_entrance() -> void:
	assert(session.dungeon.open(&"test_den").ok, "open failed")
	clear_room()


## Loads a run (as a save would) standing in a room of `kind` found by scanning seeds, below the last fork level, in `phase`,
## and resumes it. Returns the room.
func stand_in(kind: StringName, phase: StringName = &"event", dungeon_id: StringName = &"test_den") -> DungeonRoom:
	var def: DungeonDef = session.data.dungeon(dungeon_id)
	for seed_value: int in range(1, 5000):
		var map: DungeonMap = DungeonGenerator.generate(def, seed_value, session.data)
		for layer: int in range(1, def.forks):
			for k: int in map.width(layer):
				if map.room(layer, k).kind == kind:
					session.dungeon.from_save({"run": {"dungeon": String(dungeon_id), "seed": seed_value, "layer": layer, "index": k,
							"phase": String(phase), "stage": 0, "paused": true, "path": [], "return_area": "", "cleared": layer,
							"bag": {}}})
					assert(session.dungeon.resume().ok)
					return map.room(layer, k)
	assert(false, "no room of kind %s in 5000 seeds" % kind)
	return null


## Plays the run to the end of the forks with `choose(0)` and clears every room; events take their first choice.
func walk_to_boss() -> void:
	while session.dungeon.is_active() and session.dungeon.run().stage == 0:
		match session.dungeon.run().phase:
			&"await":
				session.dungeon.choose(0)
			&"event":
				session.dungeon.choose(0)
			&"fight":
				clear_room()


# --- the methods of §5.29 -----------------------------------------------------------------------------------------------

func start_dungeon(run: DungeonRun) -> CommandResult:
	calls.append(["start"])
	return start_result if start_result != null else CommandResult.success()


func begin_dungeon_room(defs: Array[MonsterDef], layer: int, kind: StringName) -> void:
	var ids: Array[StringName] = []
	for def: MonsterDef in defs:
		ids.append(def.id)
	calls.append(["room", layer, kind, ids])
	rooms.append({"layer": layer, "kind": kind, "ids": ids})


func begin_dungeon_stage(stage: DungeonStageDef) -> void:
	calls.append(["stage", stage.id])
	_stage = stage
	intro_left_ms = stage.intro_ms


func dungeon_adjust_hp(delta: int, floor_hp: int = 1) -> int:
	var before: int = player_hp
	player_hp = clampi(player_hp + delta, mini(floor_hp, player_hp), player_max_hp)
	return player_hp - before


func set_dungeon_paused(paused: bool) -> void:
	calls.append(["pause", paused])


func abandon_dungeon(outcome: StringName) -> void:
	calls.append(["abandon", outcome])
	if session.dungeon.run() != null:
		session.events.dungeon_finished.emit(outcome, session.dungeon.run().cleared, session.dungeon.run().bag.pieces().size())


func get_state() -> Dictionary:
	return {"player_hp": player_hp, "player_max_hp": player_max_hp, "dungeon": {"intro_left_ms": intro_left_ms}}


# --- the engine's part, by hand -------------------------------------------------------------------------------------------

## The last enemy of the room being fought is dead.
func clear_room() -> void:
	var last: Dictionary = rooms[rooms.size() - 1]
	session.events.dungeon_room_cleared.emit(last["layer"], last["kind"])


## The scene of the stage is over: the stage fights.
func end_intro() -> void:
	intro_left_ms = 0
	session.events.dungeon_stage_started.emit(session.dungeon.run().stage, _stage.monster_id)


func clear_stage() -> void:
	session.events.dungeon_stage_cleared.emit(session.dungeon.run().stage)


func die() -> void:
	session.events.dungeon_finished.emit(&"died", session.dungeon.run().cleared, session.dungeon.run().bag.pieces().size())


func _on_finished(outcome: StringName, _rooms: int, _pieces: int) -> void:
	if outcome == &"won" or outcome == &"left":
		returned_to.append(session.dungeon.run().return_area if session.dungeon.run() != null else &"")


# --- data ------------------------------------------------------------------------------------------------------------------

## The fixtures with a complete drop pool at the level of the dungeon (the only piece type of grade 11 is the plate body, so the weights make it
## pool draws only that) and, with `legendary`, a legendary of the source `{"type": "dungeon", "id": "test_den", "chance_pct": 100}`.
## Built once per run under user://.
static func data_with_pool(legendary: bool = false) -> GameData:
	if _cache.has(legendary):
		return _cache[legendary]
	var dir: String = PreRun.test_dir("dungeon_pool_data_%s" % legendary)
	_copy(ROOT, dir)
	if legendary:
		var item: Dictionary = {"id": String(LEGENDARY_ID), "name": "Leggendario di prova", "category": "equipment",
				"icon": "res://assets/icons/items/test_helm.png", "value": 10, "sort_order": 990, "description": "Del Covo di prova.",
				"equip": {"slot": "body", "grade": 3, "material": "plate", "requirements": {}, "modifiers": [{"stat": "armor", "value": 10}],
					"legendary": {"source": {"type": "dungeon", "id": "test_den", "chance_pct": 100},
						"effects": [{"type": "kill_heal_pct", "pct": 2}]}}}
		_write(dir.path_join("items/equipment_legendary.json"), JSON.stringify({"items": [item]}))
	var config: String = PreRun.test_dir("dungeon_pool_config_%s" % legendary)
	DirAccess.make_dir_recursive_absolute(config)
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TestFactory.CONFIG_ROOT.path_join("balance.json")))
	((balance["loot"] as Dictionary)["equipment"] as Dictionary)["level_window"] = 5  # only the grade of level 50 (11) is in reach
	((balance["loot"] as Dictionary)["equipment"] as Dictionary)["kind_weights"] = {"sword": 1, "greatsword": 1, "shield": 1, "head": 1, "body": 1000000, "legs": 1, "feet": 1, "hands": 1, "ring": 1, "neck": 1}
	_write(config.path_join("balance.json"), JSON.stringify(balance))
	_write(config.path_join("stats.json"), FileAccess.get_file_as_string(TestFactory.CONFIG_ROOT.path_join("stats.json")))
	var loaded: GameData = GameData.load_from_dirs(dir, config)
	assert(loaded.is_valid(), "dungeon pool test data is not valid: %s" % "\n".join(loaded.errors))
	_cache[legendary] = loaded
	return loaded


static func data_with_legendary() -> GameData:
	return data_with_pool(true)


static func _copy(from: String, to: String) -> void:
	DirAccess.make_dir_recursive_absolute(to)
	for dir: String in DirAccess.get_directories_at(from):
		if not SKIPPED_DIRS.has(dir):
			_copy(from.path_join(dir), to.path_join(dir))
	for file_name: String in DirAccess.get_files_at(from):
		if file_name.ends_with(".json"):
			_write(to.path_join(file_name), FileAccess.get_file_as_string(from.path_join(file_name)))


static func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
