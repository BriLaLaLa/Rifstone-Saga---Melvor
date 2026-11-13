extends GutTest
## The dungeon part of the combat engine alone (docs/05_INTERFACES.md §5.29, F-112, F-141): `await` consumes no time, `intro` runs
## only its own timer, a room of 12, the hp between the rooms, the signals of a stage and its abilities (F-112: heavy strike,
## summon of at most 4, shield), the summoned give nothing, the pause. The fixture dungeon `test_den`, a run built by hand (no
## `DungeonSystem`): the flow with the system is in `test_dungeon_run_on_engine.gd`. Fixed seeds.

var _s: GameSession = null
var _def: DungeonDef = null
var _run: DungeonRun = null
var _log: Array = []


func before_each() -> void:
	_s = autofree(FractureUtil.session(41))
	TestFactory.set_character_level(_s, 90)
	FractureUtil.hero(_s)
	_def = _s.data.dungeon(&"test_den")
	_log = []
	var ev: GameEvents = _s.events
	ev.combat_hit.connect(func(a: int, t: int, hit: bool, dmg: int, _b: bool) -> void: _log.append(["hit", a, t, hit, dmg]))
	ev.encounter_started.connect(func(_m: Array[StringName]) -> void: _log.append(["encounter"]))
	ev.dungeon_room_cleared.connect(func(layer: int, kind: StringName) -> void: _log.append(["room", layer, kind]))
	ev.dungeon_stage_started.connect(func(n: int, id: StringName) -> void: _log.append(["stage_started", n, id]))
	ev.dungeon_stage_cleared.connect(func(n: int) -> void: _log.append(["stage_cleared", n]))
	ev.combat_started.connect(func(a: StringName) -> void: _log.append(["started", a]))


func _start() -> void:
	_run = DungeonRun.create(_def, 5, &"", _s.data)
	assert_true(_s.combat.start_dungeon(_run).ok)


# A player that cannot hurt the boss but does not die: the abilities of a stage can be watched.
func _tank() -> void:
	_s.modifiers.set_source(FractureUtil.SOURCE, [Modifier.make(&"power_bonus", -1000.0), Modifier.make(&"max_hp_flat", 100000.0)])


func _defs(id: StringName, count: int) -> Array[MonsterDef]:
	var result: Array[MonsterDef] = []
	for _i: int in count:
		result.append(_s.data.monster(id))
	return result


func _clear_current_fight() -> void:
	FractureUtil.run_until(_s, func() -> bool: return _s.combat.state() == CombatEngine.STATE_AWAIT, 250, 900_000)


func _names() -> Array:
	return _log.map(func(entry: Array) -> Variant: return entry[0])


func _count(name: String) -> int:
	return _names().count(name)


func _hits_from(attacker: int) -> Array:
	return _log.filter(func(entry: Array) -> bool: return entry[0] == "hit" and entry[1] == attacker)


# --- await -------------------------------------------------------------------------------------------------------------

func test_start_dungeon_waits_for_the_first_room_and_refuses_a_second_run() -> void:
	_start()
	assert_eq(_s.combat.state(), CombatEngine.STATE_AWAIT)
	assert_true(_s.combat.in_dungeon())
	assert_same(_s.combat.dungeon_run(), _run)
	assert_eq(_s.combat.area_id(), &"", "no area in a dungeon")
	assert_eq(_log, [["started", &""]])
	assert_eq(_s.combat.start_dungeon(_run).reason, Reasons.DUNGEON_ACTIVE)
	assert_eq(_s.combat.start(&"test_area").reason, Reasons.DUNGEON_ACTIVE)
	var view: Dictionary = _s.combat.get_state()
	assert_eq(view["state"], CombatEngine.STATE_AWAIT)
	assert_eq(view["dungeon"], {"layer": 0, "kind": &"", "stage": 0, "paused": false, "intro_left_ms": 0})
	assert_eq(view["player_hp"], view["player_max_hp"], "full hp at the start")


func test_nothing_runs_while_the_engine_waits() -> void:
	_start()
	_s.combat.begin_dungeon_room(_defs(&"tden_imp", 2), 0, &"entrance")
	_clear_current_fight()
	assert_eq(_s.combat.state(), CombatEngine.STATE_AWAIT)
	_s.combat.dungeon_adjust_hp(-10)
	var hp: int = _s.combat.get_state()["player_hp"]
	var rng_state: Dictionary = _s.rng.to_save()
	var saved: Dictionary = _s.combat.to_save()
	_log = []
	_s.advance(600_000)
	_s.combat.advance(1_000_000)
	assert_eq(_log, [], "no attack, no event")
	assert_eq(_s.combat.get_state()["player_hp"], hp)
	assert_eq(_s.rng.to_save(), rng_state, "no random number")
	assert_eq(_s.combat.to_save(), saved, "not a timer moved")
	assert_eq(_s.combat.state(), CombatEngine.STATE_AWAIT)


func test_a_room_is_cleared_once_at_the_last_enemy_and_does_not_count_as_a_kill() -> void:
	_start()
	_s.combat.begin_dungeon_room(_defs(&"tden_grunt", 3), 2, &"pack")
	assert_eq(_s.combat.state(), CombatEngine.STATE_ENCOUNTER)
	assert_eq((_s.combat.get_state()["enemies"] as Array).size(), 3)
	_clear_current_fight()
	assert_eq(_log.filter(func(e: Array) -> bool: return e[0] == "room"), [["room", 2, &"pack"]])
	assert_eq(_names().back(), "room", "the last thing that happens")
	assert_eq(_s.combat.kills(&"tden_grunt"), 0, "a monster of a dungeon is not a kill of an area (F-87)")
	assert_gt(_run.bag.counts()["stacks"] + _s.character.get_xp(), 0)
	assert_eq(_s.combat.loot.items(), [] as Array[Dictionary], "nothing in the loot bag of the area")


func test_a_room_of_twelve_resolves_with_the_engine() -> void:
	_start()
	_s.combat.begin_dungeon_room(_defs(&"tden_imp", 12), 1, &"horde")
	assert_eq((_s.combat.get_state()["enemies"] as Array).size(), 12, "more than max_pack_size")
	assert_gt(12, int(_s.data.balance_value("combat.max_pack_size")))
	_clear_current_fight()
	assert_eq(_s.combat.state(), CombatEngine.STATE_AWAIT)
	assert_eq(_count("room"), 1)


func test_an_empty_room_is_cleared_at_once() -> void:
	_start()
	_s.combat.begin_dungeon_room([] as Array[MonsterDef], 3, &"pack")
	assert_push_error("has no monsters")
	assert_eq(_s.combat.state(), CombatEngine.STATE_AWAIT)
	assert_eq(_log.filter(func(e: Array) -> bool: return e[0] == "room"), [["room", 3, &"pack"]])


func test_the_hp_stay_between_rooms_and_adjust_respects_the_floor_and_the_maximum() -> void:
	_start()
	var max_hp: int = _s.combat.get_state()["player_max_hp"]
	assert_eq(_s.combat.dungeon_adjust_hp(-50), -50)
	assert_eq(_s.combat.dungeon_adjust_hp(-max_hp * 10), -(max_hp - 50 - 1), "never under floor_hp (1)")
	assert_eq(_s.combat.get_state()["player_hp"], 1)
	assert_eq(_s.combat.dungeon_adjust_hp(-5, 1), 0)
	assert_eq(_s.combat.dungeon_adjust_hp(100), 100)
	_s.combat.begin_dungeon_room(_defs(&"tden_imp", 1), 1, &"pack")
	assert_eq(_s.combat.get_state()["player_hp"], 101, "the next room does not heal")
	assert_eq(_s.combat.dungeon_adjust_hp(-5, 500), 0, "a floor above the hp changes nothing")
	assert_eq(_s.combat.dungeon_adjust_hp(max_hp * 10), max_hp - 101, "never over the maximum")


func test_no_trait_or_ability_changes_in_a_dungeon() -> void:
	_start()
	assert_eq(_s.loadout.set_trait(0, &"").reason, Reasons.COMBAT_ACTIVE, "between the rooms too")
	assert_eq(_s.loadout.set_ability(0, &"").reason, Reasons.COMBAT_ACTIVE)
	_s.combat.begin_dungeon_room(_defs(&"tden_imp", 1), 1, &"pack")
	assert_eq(_s.loadout.set_trait(0, &"").reason, Reasons.COMBAT_ACTIVE)


func test_the_pause_stops_the_fight_and_resuming_continues_it() -> void:
	_start()
	_s.combat.begin_dungeon_room(_defs(&"tden_guard", 2), 1, &"pack")
	_s.combat.set_dungeon_paused(true)
	var saved: Dictionary = _s.combat.to_save()
	_s.advance(120_000)
	assert_eq(_s.combat.to_save(), saved, "nothing moved")
	assert_true(_s.combat.get_state()["dungeon"]["paused"])
	_s.combat.set_dungeon_paused(false)
	_clear_current_fight()
	assert_eq(_count("room"), 1)


# --- intro and the stages ---------------------------------------------------------------------------------------------

func test_the_intro_runs_only_its_own_timer() -> void:
	_start()
	_s.combat.begin_dungeon_stage(_def.stages[0])
	var view: Dictionary = _s.combat.get_state()
	assert_eq(view["state"], CombatEngine.STATE_INTRO)
	assert_eq(view["enemies"], [], "no enemy during the scene")
	assert_eq(view["dungeon"]["stage"], 1)
	assert_eq(view["dungeon"]["intro_left_ms"], 3500)
	_log = []
	_s.advance(3499)
	assert_eq(_s.combat.state(), CombatEngine.STATE_INTRO)
	assert_eq(_s.combat.get_state()["dungeon"]["intro_left_ms"], 1)
	assert_eq(_log, [], "nobody attacks during the scene")
	_s.advance(1)
	assert_eq(_s.combat.state(), CombatEngine.STATE_ENCOUNTER)
	assert_eq(_names(), ["encounter", "stage_started"])
	assert_eq(_log[1], ["stage_started", 1, &"tden_right_hand"])
	assert_eq((_s.combat.get_state()["enemies"] as Array).size(), 3, "the monster of the stage and its two escorts")
	assert_eq((_s.combat.get_state()["enemies"] as Array)[0]["monster"], &"tden_right_hand")
	assert_eq(_s.combat.get_state()["dungeon"]["intro_left_ms"], 0)


func test_the_intro_is_the_same_in_one_step_or_in_many() -> void:
	_start()
	_s.combat.begin_dungeon_stage(_def.stages[2])
	_s.advance(5500 + 4000)
	var twin: GameSession = autofree(FractureUtil.session(41))
	TestFactory.set_character_level(twin, 90)
	FractureUtil.hero(twin)
	assert_true(twin.combat.start_dungeon(DungeonRun.create(_def, 5, &"", twin.data)).ok)
	twin.combat.begin_dungeon_stage(_def.stages[2])
	for _i: int in 95:
		twin.advance(100)
	assert_eq(twin.combat.to_save(), _s.combat.to_save())
	assert_eq(twin.rng.to_save(), _s.rng.to_save())


func test_a_stage_ends_with_stage_cleared_and_no_room_signal() -> void:
	_start()
	_s.combat.begin_dungeon_stage(_def.stages[0])
	_clear_current_fight()
	assert_eq(_log.filter(func(e: Array) -> bool: return e[0] == "stage_started" or e[0] == "stage_cleared" or e[0] == "room"),
			[["stage_started", 1, &"tden_right_hand"], ["stage_cleared", 1]])
	assert_eq(_names().back(), "stage_cleared")
	assert_eq(_s.combat.state(), CombatEngine.STATE_AWAIT)


func test_the_heavy_strike_of_the_first_stage_comes_every_9000_ms_after_the_base_attack() -> void:
	_start()
	_tank()
	_s.combat.begin_dungeon_stage(_def.stages[0])
	_s.advance(3500)
	_log = []
	for _step: int in 8:
		_s.advance(1000)
	var before: int = _hits_from(0).size()
	assert_eq(before, 3, "base attacks of the monster at 2400, 4800, 7200")
	assert_eq(_s.combat.to_save()["dungeon"]["boss"]["ability_ms"], 1000)
	_log = []
	_s.advance(1000)
	var at_9000: Array = _hits_from(0)
	assert_eq(at_9000.size(), 1, "the ability, with no base attack at that instant")
	assert_true(at_9000[0][3], "a heavy strike always hits")
	assert_eq(_s.combat.to_save()["dungeon"]["boss"]["ability_ms"], 9000, "the timer starts again")


func test_the_strategist_summons_two_every_10000_ms_and_never_more_than_four() -> void:
	_start()
	_tank()
	_s.combat.begin_dungeon_stage(_def.stages[1])
	_s.advance(3500)
	var summoned: Callable = func() -> int:
		return (_s.combat.get_state()["enemies"] as Array).filter(func(e: Dictionary) -> bool: return e.get("summoned", false)).size()
	assert_eq((_s.combat.get_state()["enemies"] as Array).size(), 4, "the strategist and three slingers")
	assert_eq(summoned.call(), 0)
	_s.advance(9999)
	assert_eq(summoned.call(), 0)
	_s.advance(1)
	assert_eq(summoned.call(), 2)
	_s.advance(10000)
	assert_eq(summoned.call(), 4)
	_s.advance(30000)
	assert_eq(summoned.call(), 4, "max_alive 4")
	assert_eq((_s.combat.get_state()["enemies"] as Array).size(), 8)


func test_the_king_shields_himself_for_the_set_time() -> void:
	_start()
	_tank()
	_s.combat.begin_dungeon_stage(_def.stages[2])
	_s.advance(5500)
	assert_eq((_s.combat.get_state()["enemies"] as Array).size(), 1, "the king enters alone")
	_s.advance(13999)
	assert_eq(_s.combat.to_save()["dungeon"]["boss"]["shield"], 0)
	_s.advance(1)
	var boss: Dictionary = _s.combat.to_save()["dungeon"]["boss"]
	assert_eq(boss["shield"], floori(700.0 * 20.0 / 100.0), "shield_pct 20 of 700 hp")
	assert_eq(boss["shield_ms"], 6000)
	_s.advance(6000)
	assert_eq(_s.combat.to_save()["dungeon"]["boss"]["shield"], 0, "it wears off after duration_ms")


func test_the_shield_takes_the_damage_first_and_only_for_the_stage_monster() -> void:
	_start()
	var dc := DungeonCombat.new(_s)
	dc.begin(_run)
	dc.begin_stage(_def.stages[2])
	var king: Encounter.Enemy = dc.stage_encounter().enemies[0]
	assert_eq(dc.absorb(king, 30), 30, "no shield yet")
	dc.shield = 100
	dc.shield_ms = 6000
	assert_eq(dc.absorb(king, 30), 0)
	assert_eq(dc.shield, 70)
	assert_eq(dc.absorb(king, 100), 30)
	assert_eq(dc.shield, 0)
	dc.shield = 50
	var other := Encounter.Enemy.new(_s.data.monster(&"tden_guard"), _s.data)
	assert_eq(dc.absorb(other, 40), 40, "an escort is not shielded")


func test_summoned_enemies_give_no_xp_gold_or_drops_and_the_others_do() -> void:
	_start()
	var dc := DungeonCombat.new(_s)
	dc.begin(_run)
	var enemy := Encounter.Enemy.new(_s.data.monster(&"tden_guard"), _s.data)
	enemy.summoned = true
	var xp: int = _s.character.get_xp()
	var gold: int = _s.wallet.get_gold()
	assert_false(dc.reward(enemy))
	assert_eq(_s.character.get_xp(), xp)
	assert_eq(_s.wallet.get_gold(), gold)
	assert_eq(_run.bag.counts(), {"stacks": 0, "pieces": 0, "cards": 0})
	enemy.summoned = false
	assert_false(dc.reward(enemy), "never a kill of an area")
	assert_gte(_s.character.get_xp(), xp, "xp by F-130, which may be nothing for a monster far under the character")
	assert_gt(_s.wallet.get_gold(), gold)
