class_name DungeonGenerator
extends RefCounted
## Pure logic of the dungeons (docs/05_INTERFACES.md §5.29): the hidden map from a seed (F-137) and the composition of a
## room (F-138). No state, no signals; every number comes from the DungeonDef and `balance.json`.

const TIE_EPSILON: float = 1e-9  # two distances this close are a tie (lowest index wins)


## F-137: the map of `def` for `seed_value`. The rolls are in a fixed order (widths, exits level by level, types) on a
## local `RngService.new(seed_value)`: the same seed always gives the same map. `data` is unused for now (the directions are
## computed when the exits are read); it is part of the contract of the interface.
static func generate(def: DungeonDef, seed_value: int, _data: GameData) -> DungeonMap:
	var rng := RngService.new(seed_value)
	var map := DungeonMap.new()
	map.dungeon_id = def.id
	map.seed_value = seed_value
	var forks: int = def.forks
	var levels: Array[Array] = _levels(def, rng)
	for layer: int in forks + 1:
		_exits(levels, layer, forks, def, rng)
	for layer: int in range(1, forks + 1):
		_types(levels[layer] as Array, layer, def, rng)
	for level: Array in levels:
		var typed: Array[DungeonRoom] = []
		typed.assign(level)
		map.add_layer(typed)
	return map


## F-138: the ids of the monsters of a room, drawn with `rng` (the generator of the slot, when the room is entered).
## `kind` is a room type id (`pack`, `horde`, `elite`, `miniboss`), `&"entrance"`, `&"ambush"` (trap) or `&"forage"` (rest).
## `trap`, `rest` and the boss have no composition (empty). A fixed composition is returned as it is.
static func compose(def: DungeonDef, kind: StringName, rng: RngService) -> Array[StringName]:
	var result: Array[StringName] = []
	var type: DungeonRoomType = null
	match kind:
		&"entrance":
			type = def.entrance
		&"ambush":
			type = def.trap_ambush
		&"forage":
			type = def.rest_forage
		&"trap", &"rest", &"boss":
			return result
		_:
			type = def.room_type(kind)
	if type == null:
		Log.error("dungeon", "dungeon '%s' has no room type '%s'" % [def.id, kind])
		return result
	if not type.fixed.is_empty():
		result.assign(type.fixed)
		return result
	if type.size_max <= 0 or type.pool_monsters.is_empty():
		return result
	var count: int = type.size_min if type.size_min == type.size_max else rng.randi_range(type.size_min, type.size_max)
	for _i: int in count:
		result.append(type.pool_monsters[rng.pick_weighted(type.pool_weights)])
	return result


# Step 1: the levels with their rooms and positions: 1 room at the entrance and at the boss, `2 + pick_weighted` between.
static func _levels(def: DungeonDef, rng: RngService) -> Array[Array]:
	var widths: Array[int] = [1]
	for _i: int in def.forks:
		widths.append(2 + rng.pick_weighted(def.width_weights))
	widths.append(1)
	var levels: Array[Array] = []
	for layer: int in widths.size():
		var rooms: Array[DungeonRoom] = []
		for k: int in widths[layer]:
			var room := DungeonRoom.new()
			room.layer = layer
			room.index = k
			room.x = (float(k) + 0.5) / float(widths[layer])
			room.kind = DungeonRoom.KIND_ENTRANCE if layer == 0 else (DungeonRoom.KIND_BOSS if layer == widths.size() - 1 else &"")
			rooms.append(room)
		levels.append(rooms)
	return levels


# Step 2 for `layer`: the exits of its rooms (the `d` nearest rooms of the next level), then the rooms of the next level that
# nobody leads to are removed and the indices renumbered (their `x` stays). The last fork level leads to the boss, no roll.
static func _exits(levels: Array[Array], layer: int, forks: int, def: DungeonDef, rng: RngService) -> void:
	var rooms: Array = levels[layer]
	var next_rooms: Array = levels[layer + 1]
	if layer == forks:
		for room: DungeonRoom in rooms:
			room.exits = [0] as Array[int]
		return
	var next_x: Array[float] = []
	for next_room: DungeonRoom in next_rooms:
		next_x.append(next_room.x)
	var reached: Dictionary[int, bool] = {}
	for room: DungeonRoom in rooms:
		var count: int = mini(next_rooms.size(), 2 + rng.pick_weighted(def.exit_weights))
		room.exits = nearest(room.x, next_x, count)
		for exit_index: int in room.exits:
			reached[exit_index] = true
	var kept: Array[DungeonRoom] = []
	var renumbered: Dictionary[int, int] = {}
	for k: int in next_rooms.size():
		if reached.has(k):
			renumbered[k] = kept.size()
			kept.append(next_rooms[k] as DungeonRoom)
	for room: DungeonRoom in rooms:
		var fixed: Array[int] = []
		for exit_index: int in room.exits:
			fixed.append(renumbered[exit_index])
		room.exits = fixed
	for k: int in kept.size():
		kept[k].index = k
	levels[layer + 1] = kept


## F-137 point 2: the `count` positions of `next_x` nearest to `x` (a tie: the lowest index), as indices from left to right.
static func nearest(x: float, next_x: Array[float], count: int) -> Array[int]:
	var order: Array[int] = []
	for k: int in next_x.size():
		order.append(k)
	order.sort_custom(func(a: int, b: int) -> bool:
		var da: float = absf(next_x[a] - x)
		var db: float = absf(next_x[b] - x)
		return a < b if absf(da - db) < TIE_EPSILON else da < db)
	var picked: Array[int] = []
	picked.assign(order.slice(0, count))
	picked.sort()
	return picked


# Step 3 for one level: the type of every room (one miniboss per level at most); a trap draws its kind too.
static func _types(rooms: Array, layer: int, def: DungeonDef, rng: RngService) -> void:
	var has_miniboss: bool = false
	for room: DungeonRoom in rooms:
		var candidates: Array[DungeonRoomType] = []
		var weights: Array[int] = []
		for type: DungeonRoomType in def.room_types:
			if type.min_layer <= layer and not (has_miniboss and type.id == &"miniboss"):
				candidates.append(type)
				weights.append(type.weight)
		var chosen: DungeonRoomType = candidates[rng.pick_weighted(weights)]
		room.kind = chosen.id
		has_miniboss = has_miniboss or chosen.id == &"miniboss"
		if chosen.id == &"trap":
			var equal: Array[int] = []
			equal.resize(def.trap_kinds.size())
			equal.fill(1)
			room.trap_kind = def.trap_kinds[rng.pick_weighted(equal)]
