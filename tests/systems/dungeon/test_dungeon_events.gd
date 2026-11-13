extends GutTest
## F-140 (docs/02_FORMULAS.md §5j): the two events of the dungeon, Trap and Rest, with the numbers of the examples
## (max_hp 800: 160 lost / 99 lost at 100 hp; 280 healed at 300 hp, 100 at 700 hp), the ambush, the forage and the rule that
## nothing lasts beyond the room. Played on a run loaded standing in the room, with a stand-in for the engine.

var _s: GameSession = null
var _engine: DungeonEngineDouble = null
var _traps: Array = []


func before_each() -> void:
	_s = autofree(TestFactory.session(11))
	_engine = DungeonEngineDouble.attach(_s)
	_engine.player_max_hp = 800
	_engine.player_hp = 800
	_traps = []
	_s.events.dungeon_trap_triggered.connect(func(kind: StringName, lost: int) -> void: _traps.append([kind, lost]))


func test_dash_takes_a_fifth_of_the_hp() -> void:
	var room: DungeonRoom = _engine.stand_in(&"trap")
	assert_true(_s.dungeon.choose(0).ok)
	assert_eq(_engine.player_hp, 640)
	assert_eq(_traps, [[room.trap_kind, 160]])
	assert_eq(_s.dungeon.run().phase, &"await", "the room is beaten")


func test_dash_never_kills() -> void:
	_engine.stand_in(&"trap")
	_engine.player_hp = 100
	_s.dungeon.choose(0)
	assert_eq(_engine.player_hp, 1, "min(hp - 1, 160) = 99 lost")
	assert_eq(_traps[0][1], 99)


func test_dash_at_one_hp_costs_nothing() -> void:
	_engine.stand_in(&"trap")
	_engine.player_hp = 1
	_s.dungeon.choose(0)
	assert_eq([_engine.player_hp, _traps[0][1]], [1, 0])


func test_the_dash_pays_the_dust_of_the_trap() -> void:
	_engine.stand_in(&"trap")
	_s.dungeon.choose(0)
	var dust: int = _s.dungeon.run().bag.stacks().filter(func(e: Dictionary) -> bool: return e["item"] == &"rift_dust")[0]["qty"]
	assert_between(dust, 3, 6)


func test_detour_costs_nothing_and_fights_an_ambush() -> void:
	_engine.stand_in(&"trap")
	assert_true(_s.dungeon.choose(1).ok)
	assert_eq(_engine.player_hp, 800)
	assert_true(_traps.is_empty())
	var fight: Dictionary = _engine.rooms[_engine.rooms.size() - 1]
	assert_eq([fight["kind"], (fight["ids"] as Array).size()], [&"ambush", 3])
	assert_eq(_s.dungeon.run().phase, &"fight")
	_engine.clear_room()
	assert_eq(_s.dungeon.run().phase, &"await")
	assert_between(_stack(&"rift_dust"), 3, 6)


func test_rest_heals_a_third_of_the_hp_up_to_the_maximum() -> void:
	_engine.stand_in(&"rest")
	_engine.player_hp = 300
	assert_true(_s.dungeon.choose(0).ok)
	assert_eq(_engine.player_hp, 580, "+280")
	assert_eq(_s.dungeon.run().phase, &"await")
	_engine.stand_in(&"rest")
	_engine.player_hp = 700
	_s.dungeon.choose(0)
	assert_eq(_engine.player_hp, 800, "+100, no more than the maximum")


func test_forage_fights_a_pack_and_finds_a_stash() -> void:
	_engine.stand_in(&"rest")
	_engine.player_hp = 300
	assert_true(_s.dungeon.choose(1).ok)
	assert_eq(_engine.player_hp, 300, "no healing")
	var fight: Dictionary = _engine.rooms[_engine.rooms.size() - 1]
	assert_eq([fight["kind"], (fight["ids"] as Array).size()], [&"forage", 4])
	assert_eq(_stack(&"rift_dust"), 0, "nothing before the fight is won")
	_engine.clear_room()
	assert_between(_stack(&"rift_dust"), 8, 14)
	assert_eq(_s.dungeon.run().phase, &"await")


func test_an_event_has_two_choices_and_no_exit_directions() -> void:
	_engine.stand_in(&"trap")
	var choices: Array = _s.dungeon.state()["choices"]
	assert_eq(choices.map(func(c: Dictionary) -> StringName: return c["id"]), [&"dash", &"detour"])
	assert_eq(choices[0]["direction"], &"")
	_engine.stand_in(&"rest")
	assert_eq((_s.dungeon.state()["choices"] as Array).map(func(c: Dictionary) -> StringName: return c["id"]), [&"rest", &"forage"])


func test_an_event_refuses_a_third_choice_and_allows_leaving() -> void:
	_engine.stand_in(&"trap")
	assert_eq(_s.dungeon.choose(2).reason, Reasons.INVALID_CHOICE)
	assert_true(_s.dungeon.state()["can_leave"])
	assert_true(_s.dungeon.leave().ok)


func test_an_event_leaves_nothing_behind() -> void:
	_engine.stand_in(&"trap")
	_s.dungeon.choose(0)
	assert_eq(_s.modifiers.total(&"max_hp_flat"), 0.0, "no source of the dungeon")


func _stack(item_id: StringName) -> int:
	for entry: Dictionary in _s.dungeon.run().bag.stacks():
		if entry["item"] == item_id:
			return entry["qty"]
	return 0
