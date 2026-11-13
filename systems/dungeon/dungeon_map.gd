class_name DungeonMap
extends RefCounted
## The hidden map of a dungeon run (docs/05_INTERFACES.md §5.29, F-137): levels of rooms, rebuilt from the seed
## (`DungeonGenerator.generate`), never saved. The UI never reads it (it sees only direction and hint of an exit).

const DIRECTIONS: Array[StringName] = [&"far_left", &"left", &"slight_left", &"forward", &"slight_right", &"right", &"far_right"]
const BANDS_KEY: String = "dungeon.direction_bands"

var dungeon_id: StringName = &""
var seed_value: int = 0
var _layers: Array[Array] = []  # Array of Array[DungeonRoom], level 0 (entrance) .. last (boss)


## The number of levels: `forks + 2` (entrance, the forks, boss).
func layers() -> int:
	return _layers.size()


## The rooms of `layer` (0 outside the map).
func width(layer: int) -> int:
	return _layers[layer].size() if layer >= 0 and layer < _layers.size() else 0


## The room at `layer`, `index`; null outside the map.
func room(layer: int, index: int) -> DungeonRoom:
	if layer < 0 or layer >= _layers.size() or index < 0 or index >= _layers[layer].size():
		return null
	return _layers[layer][index] as DungeonRoom


## The exits of a room, from left to right: `{"index", "direction", "hint"}`; `hint` is the phrase of the type of the room
## behind the exit, or "" when that room has no hint. Empty for an unknown room and for the boss.
func exits_of(layer: int, index: int, data: GameData) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var from: DungeonRoom = room(layer, index)
	var def: DungeonDef = data.dungeon(dungeon_id)
	if from == null or def == null:
		return result
	for exit_index: int in from.exits:
		var target: DungeonRoom = room(layer + 1, exit_index)
		if target == null:
			continue
		var phrase: String = ""
		if target.hint and def.room_type(target.kind) != null:
			phrase = def.room_type(target.kind).hint
		result.append({"index": exit_index, "direction": direction_of(target.x - from.x, data), "hint": phrase})
	return result


## F-137: the direction of an exit from its lateral shift `dx`, with the bands of `balance.dungeon.direction_bands`.
static func direction_of(dx: float, data: GameData) -> StringName:
	var raw: Variant = data.balance_value(BANDS_KEY)
	var bands: Array = raw as Array if raw is Array else []
	if bands.size() != DIRECTIONS.size() - 1:
		return &"forward"
	if dx <= float(bands[0]):
		return DIRECTIONS[0]
	if dx <= float(bands[1]):
		return DIRECTIONS[1]
	if dx < float(bands[2]):
		return DIRECTIONS[2]
	if dx <= float(bands[3]):
		return DIRECTIONS[3]
	if dx < float(bands[4]):
		return DIRECTIONS[4]
	if dx < float(bands[5]):
		return DIRECTIONS[5]
	return DIRECTIONS[6]


## Appends a level (used by DungeonGenerator only).
func add_layer(rooms: Array[DungeonRoom]) -> void:
	_layers.append(rooms)
