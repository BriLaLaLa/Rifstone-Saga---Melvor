extends GutTest
## F-138 (docs/02_FORMULAS.md §5j): the weights of the room types by level and the composition of a room.

var _data: GameData
var _def: DungeonDef


func before_all() -> void:
	_data = TestFactory.fixture_data()
	_def = _data.dungeon(&"test_den")


func _weight(layer: int, kind: StringName = &"") -> int:
	var total: int = 0
	for type: DungeonRoomType in _def.room_types:
		if type.min_layer <= layer and (kind == &"" or type.id == kind):
			total += type.weight
	return total


# --- weights (the example of F-138) ------------------------------------------------------------------------------

func test_weights_by_level() -> void:
	assert_eq(_weight(1), 60, "pack 30, horde 16, trap 14")
	assert_eq(_weight(2), 84, "plus elite 14 and rest 10")
	assert_eq(_weight(3), 94, "plus miniboss 10")
	assert_almost_eq(float(_weight(1, &"pack")) / float(_weight(1)), 0.5, 1e-9)
	assert_almost_eq(float(_weight(3, &"miniboss")) / float(_weight(3)), 10.0 / 94.0, 1e-9)


func test_types_respect_their_minimum_level_over_1000_seeds() -> void:
	var minimum: Dictionary[StringName, int] = {}
	for type: DungeonRoomType in _def.room_types:
		minimum[type.id] = type.min_layer
	var counts: Dictionary[StringName, int] = {}
	for seed_value: int in range(1, 1001):
		var map: DungeonMap = DungeonGenerator.generate(_def, seed_value, _data)
		for layer: int in range(1, _def.forks + 1):
			for index: int in map.width(layer):
				var kind: StringName = map.room(layer, index).kind
				counts[kind] = counts.get(kind, 0) + 1
				if layer < minimum[kind]:
					fail_test("seed %d: a %s at level %d (from %d)" % [seed_value, kind, layer, minimum[kind]])
					return
	for kind: StringName in minimum:
		assert_gt(counts.get(kind, 0), 0, "every type shows up: %s" % kind)
	assert_true(true)


func test_the_first_level_is_half_packs() -> void:
	var packs: int = 0
	var total: int = 0
	for seed_value: int in range(1, 1501):
		var map: DungeonMap = DungeonGenerator.generate(_def, seed_value, _data)
		for index: int in map.width(1):
			total += 1
			packs += 1 if map.room(1, index).kind == &"pack" else 0
	assert_almost_eq(float(packs) / float(total), 0.5, 0.04)


# --- composition -------------------------------------------------------------------------------------------------

func test_pack_is_3_to_6_monsters_from_its_pool() -> void:
	var rng := RngService.new(11)
	var pool: Array[StringName] = _def.room_type(&"pack").pool_monsters
	var sizes: Dictionary[int, bool] = {}
	for _i: int in 200:
		var monsters: Array[StringName] = DungeonGenerator.compose(_def, &"pack", rng)
		assert_between(monsters.size(), 3, 6)
		sizes[monsters.size()] = true
		for id: StringName in monsters:
			assert_true(pool.has(id))
	assert_eq(sizes.size(), 4, "every size 3, 4, 5, 6 appears")


func test_horde_is_12_monsters_beyond_the_pack_limit() -> void:
	var monsters: Array[StringName] = DungeonGenerator.compose(_def, &"horde", RngService.new(3))
	assert_eq(monsters.size(), 12)
	assert_gt(monsters.size(), int(_data.balance_value("combat.max_pack_size")))
	var pool: Array[StringName] = _def.room_type(&"horde").pool_monsters
	for id: StringName in monsters:
		assert_true(pool.has(id))


func test_elite_and_miniboss_are_fixed() -> void:
	assert_eq(DungeonGenerator.compose(_def, &"elite", RngService.new(1)), [&"tden_gorilla"] as Array[StringName])
	assert_eq(DungeonGenerator.compose(_def, &"miniboss", RngService.new(1)),
			[&"tden_lead", &"tden_guard", &"tden_guard"] as Array[StringName])


func test_fixed_compositions_consume_no_roll() -> void:
	var rng := RngService.new(9)
	var expected: float = RngService.new(9).randf()
	DungeonGenerator.compose(_def, &"elite", rng)
	DungeonGenerator.compose(_def, &"miniboss", rng)
	assert_eq(rng.randf(), expected)


func test_entrance_ambush_and_forage_sizes() -> void:
	var rng := RngService.new(5)
	assert_eq(DungeonGenerator.compose(_def, &"entrance", rng).size(), 6)
	assert_eq(DungeonGenerator.compose(_def, &"ambush", rng).size(), 3)
	assert_eq(DungeonGenerator.compose(_def, &"forage", rng).size(), 4)


func test_rooms_without_monsters() -> void:
	var rng := RngService.new(5)
	for kind: StringName in [&"trap", &"rest", &"boss"]:
		assert_eq(DungeonGenerator.compose(_def, kind, rng).size(), 0, String(kind))


func test_composition_is_a_function_of_the_generator() -> void:
	var a: Array[StringName] = DungeonGenerator.compose(_def, &"pack", RngService.new(21))
	var b: Array[StringName] = DungeonGenerator.compose(_def, &"pack", RngService.new(21))
	assert_eq(a, b)
