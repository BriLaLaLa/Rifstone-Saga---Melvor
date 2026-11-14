extends GutTest
## F-137 (docs/02_FORMULAS.md §5j): the hidden map of a dungeon: the directions of the exits (the three examples of the
## formula), the properties over 1.000 seeds and the same map from the same seed.

const SEEDS: int = 1000
const PINNED_77: String = "0.0@0.5000:entrance::[0, 1]|1.0@0.3750:trap:pit:[0, 1]|1.1@0.6250:pack::[0, 1, 2]|2.0@0.1667:pack::[0, 1]|2.1@0.5000:elite::[0, 1]|2.2@0.8333:pack::[1, 2]|3.0@0.1667:horde::[0, 1]|3.1@0.5000:trap:vines:[0, 1]|3.2@0.8333:pack::[0, 1]|4.0@0.2500:miniboss::[0, 1, 2, 3]|4.1@0.7500:elite::[1, 2, 3]|5.0@0.1250:miniboss::[0]|5.1@0.3750:horde::[0]|5.2@0.6250:horde::[0]|5.3@0.8750:rest::[0]|6.0@0.5000:boss::[]"

var _data: GameData
var _def: DungeonDef


func before_all() -> void:
	_data = TestFactory.fixture_data()
	_def = _data.dungeon(&"test_den")


func _xs(count: int) -> Array[float]:
	var result: Array[float] = []
	for k: int in count:
		result.append((float(k) + 0.5) / float(count))
	return result


func _directions(x: float, next_x: Array[float], count: int) -> Array[StringName]:
	var result: Array[StringName] = []
	for index: int in DungeonGenerator.nearest(x, next_x, count):
		result.append(DungeonMap.direction_of(next_x[index] - x, _data))
	return result


# --- the examples of F-137 ---------------------------------------------------------------------------------------

func test_example_room_at_the_right_edge_has_no_exit_to_the_right() -> void:
	var next_x: Array[float] = _xs(2)  # 0.25, 0.75
	assert_eq(DungeonGenerator.nearest(0.875, next_x, 2), [0, 1] as Array[int])
	assert_almost_eq(next_x[0] - 0.875, -0.625, 1e-9)
	assert_almost_eq(next_x[1] - 0.875, -0.125, 1e-9)
	assert_eq(_directions(0.875, next_x, 2), [&"far_left", &"slight_left"] as Array[StringName])


func test_example_room_at_the_left_edge() -> void:
	var next_x: Array[float] = _xs(3)  # 0.1667, 0.5, 0.8333
	assert_eq(DungeonGenerator.nearest(0.125, next_x, 2), [0, 1] as Array[int])
	assert_almost_eq(next_x[0] - 0.125, 0.0417, 1e-4)
	assert_almost_eq(next_x[1] - 0.125, 0.375, 1e-9)
	assert_eq(_directions(0.125, next_x, 2), [&"forward", &"right"] as Array[StringName])


func test_example_tie_goes_to_the_lowest_index() -> void:
	var next_x: Array[float] = _xs(4)  # 0.125, 0.375, 0.625, 0.875
	assert_eq(DungeonGenerator.nearest(0.5, next_x, 3), [0, 1, 2] as Array[int])
	assert_eq(_directions(0.5, next_x, 3), [&"left", &"slight_left", &"slight_right"] as Array[StringName])


func test_direction_bands_at_their_borders() -> void:
	var expected: Dictionary = {-0.9: &"far_left", -0.55: &"far_left", -0.5: &"left", -0.30: &"left", -0.2: &"slight_left",
		-0.10: &"forward", 0.0: &"forward", 0.10: &"forward", 0.2: &"slight_right", 0.30: &"right", 0.4: &"right",
		0.55: &"far_right", 0.9: &"far_right"}
	for dx: float in expected:
		assert_eq(DungeonMap.direction_of(dx, _data), expected[dx], "dx %s" % dx)


func test_no_band_holds_two_exits_of_the_same_room() -> void:
	# the rooms of a level are at least 0.25 apart and no band is wider than 0.25
	var all_directions: Dictionary[StringName, bool] = {}
	for width: int in [2, 3, 4]:
		for from_width: int in [1, 2, 3, 4]:
			for k: int in from_width:
				var xs: Array[float] = _xs(width)
				var from_x: float = (float(k) + 0.5) / float(from_width)
				for count: int in range(2, width + 1):
					var seen: Dictionary[StringName, bool] = {}
					for direction: StringName in _directions(from_x, xs, count):
						assert_false(seen.has(direction), "%d rooms from x %s, %d exits" % [width, from_x, count])
						seen[direction] = true
						all_directions[direction] = true
	assert_gt(all_directions.size(), 3)


# --- properties over 1.000 seeds ---------------------------------------------------------------------------------

func test_properties_over_1000_seeds() -> void:
	var forks: int = _def.forks
	var failures: PackedStringArray = []
	for seed_value: int in range(1, SEEDS + 1):
		var map: DungeonMap = DungeonGenerator.generate(_def, seed_value, _data)
		failures.append_array(_check_map(map, forks, seed_value))
		if failures.size() > 5:
			break
	assert_eq(failures, PackedStringArray(), "map properties")


func _check_map(map: DungeonMap, forks: int, seed_value: int) -> PackedStringArray:
	var errors: PackedStringArray = []
	var tag: String = "seed %d" % seed_value
	if map.layers() != forks + 2 or map.width(0) != 1 or map.width(forks + 1) != 1:
		errors.append("%s: levels %d, entrance %d, boss %d" % [tag, map.layers(), map.width(0), map.width(forks + 1)])
		return errors
	for layer: int in range(1, forks + 1):
		if map.width(layer) < 2 or map.width(layer) > 4:
			errors.append("%s: level %d has %d rooms" % [tag, layer, map.width(layer)])
		var minibosses: int = 0
		for index: int in map.width(layer):
			minibosses += 1 if map.room(layer, index).kind == &"miniboss" else 0
		if minibosses > 1:
			errors.append("%s: level %d has %d minibosses" % [tag, layer, minibosses])
	# exits: 2-4 with distinct directions; the last fork level leads to the boss only
	for layer: int in forks:
		for index: int in map.width(layer):
			var exits: Array[Dictionary] = map.exits_of(layer, index, _data)
			var seen: Dictionary[StringName, bool] = {}
			for exit: Dictionary in exits:
				seen[exit["direction"] as StringName] = true
			if exits.size() < 2 or exits.size() > 4 or seen.size() != exits.size():
				errors.append("%s: room %d/%d has %d exits, %d directions" % [tag, layer, index, exits.size(), seen.size()])
	for index: int in map.width(forks):
		var to_boss: Array[int] = [0]
		if map.room(forks, index).exits != to_boss:
			errors.append("%s: a room of the last fork does not lead to the boss" % tag)
	if not map.room(forks + 1, 0).exits.is_empty() or map.room(forks + 1, 0).kind != &"boss" or map.room(0, 0).kind != &"entrance":
		errors.append("%s: entrance or boss malformed" % tag)
	# reachable from the entrance, and every room reaches the boss
	var reached: Dictionary[Vector2i, bool] = {Vector2i(0, 0): true}
	for layer: int in forks + 1:
		for index: int in map.width(layer):
			if reached.has(Vector2i(layer, index)):
				for exit_index: int in map.room(layer, index).exits:
					reached[Vector2i(layer + 1, exit_index)] = true
	for layer: int in map.layers():
		for index: int in map.width(layer):
			if not reached.has(Vector2i(layer, index)):
				errors.append("%s: room %d/%d is not reachable" % [tag, layer, index])
			if layer < forks + 1 and map.room(layer, index).exits.is_empty():
				errors.append("%s: room %d/%d is a dead end" % [tag, layer, index])
	return errors


func test_rooms_total_is_forks_plus_two() -> void:
	var map: DungeonMap = DungeonGenerator.generate(_def, 77, _data)
	assert_eq(map.layers(), _def.forks + 2)
	assert_eq(map.layers(), 7)


func test_the_same_seed_gives_the_same_map() -> void:
	for seed_value: int in [1, 42, 99999, 2147483647]:
		var a: DungeonMap = DungeonGenerator.generate(_def, seed_value, _data)
		var b: DungeonMap = DungeonGenerator.generate(_def, seed_value, _data)
		assert_eq(_describe(a), _describe(b), "seed %d" % seed_value)
		assert_eq(a.seed_value, seed_value)
		assert_eq(a.dungeon_id, &"test_den")


func test_different_seeds_give_different_maps() -> void:
	var seen: Dictionary[String, bool] = {}
	for seed_value: int in range(1, 41):
		seen[_describe(DungeonGenerator.generate(_def, seed_value, _data))] = true
	assert_gt(seen.size(), 30)


func test_generating_does_not_touch_other_generators() -> void:
	var rng := RngService.new(5)
	var expected: float = RngService.new(5).randf()
	DungeonGenerator.generate(_def, 5, _data)
	assert_eq(rng.randf(), expected, "the map uses its own local generator")


func test_an_exit_has_only_index_and_direction() -> void:
	var exits: int = 0
	for seed_value: int in range(1, 60):
		var map: DungeonMap = DungeonGenerator.generate(_def, seed_value, _data)
		for layer: int in _def.forks:
			for index: int in map.width(layer):
				for exit: Dictionary in map.exits_of(layer, index, _data):
					exits += 1
					var keys: Array = exit.keys()
					keys.sort()
					assert_eq(keys, ["direction", "index"], "no hint and no kind (M22-09)")
	assert_gt(exits, 0)


func test_the_map_of_a_fixed_seed_is_the_one_from_before_the_hints_were_removed() -> void:
	# The hint rolls were the last of the generator: removing them leaves widths, exits, types and trap kinds as they were.
	assert_eq(_describe(DungeonGenerator.generate(_def, 77, _data)), PINNED_77)


func test_a_trap_has_its_kind_and_other_rooms_none() -> void:
	var traps: int = 0
	for seed_value: int in range(1, 200):
		var map: DungeonMap = DungeonGenerator.generate(_def, seed_value, _data)
		for layer: int in map.layers():
			for index: int in map.width(layer):
				var room: DungeonRoom = map.room(layer, index)
				if room.kind == &"trap":
					traps += 1
					assert_true(_def.trap_kinds.has(room.trap_kind))
				else:
					assert_eq(room.trap_kind, &"")
	assert_gt(traps, 0)


func test_room_lookup_outside_the_map_is_null() -> void:
	var map: DungeonMap = DungeonGenerator.generate(_def, 3, _data)
	assert_null(map.room(-1, 0))
	assert_null(map.room(0, 1))
	assert_null(map.room(map.layers(), 0))
	assert_eq(map.width(99), 0)
	assert_eq(map.exits_of(99, 0, _data).size(), 0)
	assert_eq(map.exits_of(map.layers() - 1, 0, _data).size(), 0, "the boss has no exit")


func _describe(map: DungeonMap) -> String:
	var parts: PackedStringArray = []
	for layer: int in map.layers():
		for index: int in map.width(layer):
			var room: DungeonRoom = map.room(layer, index)
			parts.append("%d.%d@%.4f:%s:%s:%s" % [layer, index, room.x, room.kind, room.trap_kind, room.exits])
	return "|".join(parts)
