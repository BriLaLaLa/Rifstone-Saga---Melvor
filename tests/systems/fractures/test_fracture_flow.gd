extends GutTest
## The flow of a Fracture in the combat engine (F-50, docs/01_GDD.md §17.2, docs/05_INTERFACES.md §5.23) on the fixtures with
## `fracture.groups` = 3: groups with BETWEEN, the boss, win / death / abandon, the way back, no automatic opening,
## no Rift Stone, the bag of the Fracture instead of the loot bag, and advance(1000) = ten advance(100).

const AREA: StringName = &"test_area"
const STONE_AREA: StringName = &"test_stone_area"

var _s: GameSession = null
var _log: Array = []


func before_each() -> void:
	_s = autofree(FractureUtil.session(77))
	FractureUtil.hero(_s)
	_log = []
	var ev: GameEvents = _s.events
	ev.fracture_opened.connect(func(g: int) -> void: _log.append(["opened", g]))
	ev.fracture_group_cleared.connect(func(i: int, t: int) -> void: _log.append(["cleared", i, t]))
	ev.fracture_boss_started.connect(func(b: StringName) -> void: _log.append(["boss", b]))
	ev.fracture_finished.connect(func(o: StringName, g: int, n: int, c: int, p: int) -> void: _log.append(["finished", o, g, n, c, p]))
	ev.encounter_started.connect(func(_m: Array[StringName]) -> void: _log.append(["encounter"]))
	ev.combat_started.connect(func(a: StringName) -> void: _log.append(["started", a]))
	ev.combat_stopped.connect(func(r: StringName) -> void: _log.append(["stopped", r]))
	ev.player_died.connect(func() -> void: _log.append(["died"]))


func _open(grade: int = 1) -> int:
	var uid: int = FractureUtil.card(_s, grade)
	assert_true(_s.fractures.open(uid).ok)
	return uid


func _over() -> bool:
	return not _s.combat.in_fracture()


func _names() -> Array:
	var names: Array = []
	for entry: Array in _log:
		names.append(entry[0])
	return names


func test_nothing_opens_a_fracture_by_itself() -> void:
	_s.combat.start(AREA)
	_s.advance(3_600_000 * 2)
	_s.advance(100)
	assert_false(_s.fractures.is_active())
	assert_false(_s.combat.in_fracture())
	assert_false(_names().has("opened"))


func test_open_consumes_the_card_and_starts_the_first_group() -> void:
	var uid: int = FractureUtil.card(_s, 1)
	assert_true(_s.fractures.open(uid).ok)
	assert_false(_s.cards.has(uid), "the Card is consumed at once")
	assert_true(_s.combat.in_fracture())
	assert_eq(_s.combat.state(), CombatEngine.STATE_ENCOUNTER)
	assert_eq(_s.combat.area_id(), &"", "no area inside a Fracture")
	var fracture: Dictionary = _s.combat.get_state()["fracture"]
	assert_eq(fracture["group"], 1)
	assert_eq(fracture["groups"], 3)
	assert_false(fracture["boss"])
	assert_eq(_s.combat.fracture_run().grade, 1)
	assert_eq(_names().slice(0, 4), ["opened", "started", "encounter"])


func test_three_groups_then_the_boss_then_the_win() -> void:
	_open()
	FractureUtil.run_until(_s, _over)
	var events: Array = _log.filter(func(e: Array) -> bool: return e[0] in ["cleared", "boss", "finished", "opened"])
	assert_eq(events, [["opened", 1], ["cleared", 1, 3], ["cleared", 2, 3], ["cleared", 3, 3], ["boss", &"boss_grade_1"],
		["finished", &"won", 1, 3, 0, 0]])
	var encounters: int = _names().count("encounter")
	assert_eq(encounters, 4, "three groups and the boss")
	assert_false(_s.fractures.is_active())


func test_between_the_groups_the_state_is_between() -> void:
	_open()
	var seen: Array = []
	_s.events.encounter_cleared.connect(func() -> void: seen.append(_s.combat.state()))
	FractureUtil.run_until(_s, _over)
	assert_eq(seen.size(), 3, "one encounter_cleared per group; the boss ends the Fracture")
	for state: StringName in seen:
		assert_eq(state, CombatEngine.STATE_BETWEEN)


func test_the_boss_is_alone_in_its_encounter() -> void:
	_open()
	var boss_seen: Array = []
	_s.events.encounter_started.connect(func(ids: Array[StringName]) -> void:
		if _s.combat.fracture_run().boss_started:
			boss_seen.append(ids))
	FractureUtil.run_until(_s, _over)
	assert_eq(boss_seen, [[&"boss_grade_1"]])


func test_the_fight_in_the_area_stops_and_comes_back() -> void:
	_s.combat.start(AREA)
	_s.combat.loot.add(&"test_twig", 3)
	_open()
	assert_true(_names().has("stopped"))
	assert_eq(_log.filter(func(e: Array) -> bool: return e[0] == "stopped")[0][1], Reasons.REPLACED)
	assert_eq(_s.combat.fracture_run().return_area, AREA)
	FractureUtil.run_until(_s, _over)
	assert_eq(_s.combat.area_id(), AREA, "back to the area")
	assert_true(_s.combat.in_encounter())
	assert_eq(_s.combat.get_state()["player_hp"], _s.combat.player_stats().max_hp)
	assert_eq(_s.combat.loot.items(), [{"item": &"test_twig", "qty": 3}] as Array[Dictionary], "the loot bag is as it was")


func test_without_an_area_the_fight_stops_with_the_reason() -> void:
	_open()
	FractureUtil.run_until(_s, _over)
	assert_false(_s.combat.is_active())
	assert_eq(_s.combat.stop_reasons_log().back(), Reasons.FRACTURE_WON)


func test_the_loot_goes_to_the_fracture_bag_not_to_the_loot_bag() -> void:
	_s.combat.start(AREA)
	_open()
	var bag: FractureBag = _s.combat.fracture_run().bag
	FractureUtil.run_until(_s, func() -> bool: return bag.stacks().size() > 0 or _over())
	assert_true(_s.combat.loot.items().is_empty(), "the loot bag does not change")
	assert_gt(bag.stacks().size(), 0, "shards and drops are in the bag of the Fracture")


func test_gold_and_xp_are_immediate_and_not_at_risk() -> void:
	_open()
	var gold: int = _s.wallet.get_gold()
	var xp: int = _s.character.get_xp()
	FractureUtil.run_until(_s, func() -> bool: return _s.character.get_xp() > xp)
	assert_gt(_s.wallet.get_gold(), gold)
	_s.fractures.abandon()
	assert_gt(_s.character.get_xp(), xp, "the xp stays after an abandon")
	assert_gt(_s.wallet.get_gold(), gold)


func test_abandon_loses_the_bag_and_the_card_is_gone() -> void:
	var uid: int = _open()
	var lost: Array = []
	_s.events.fracture_loot_lost.connect(func(a: int, b: int, c: int) -> void: lost.append([a, b, c]))
	FractureUtil.run_until(_s, func() -> bool: return _s.combat.fracture_run().bag.stacks().size() > 0)
	var result: CommandResult = _s.fractures.abandon()
	assert_true(result.ok)
	assert_false(_s.fractures.is_active())
	assert_eq(lost.size(), 1)
	assert_gt(lost[0][0], 0)
	assert_false(_s.cards.has(uid))
	assert_eq(_s.bank.get_count(&"rift_shard"), 0, "nothing delivered")
	assert_eq(_log.filter(func(e: Array) -> bool: return e[0] == "finished")[0][1], &"abandoned")
	assert_false(_s.combat.is_active())
	assert_eq(_s.combat.stop_reasons_log().back(), Reasons.FRACTURE_ABANDONED)


func test_abandon_goes_back_to_the_area() -> void:
	_s.combat.start(AREA)
	_open()
	assert_true(_s.fractures.abandon().ok)
	assert_eq(_s.combat.area_id(), AREA)
	assert_eq(_s.combat.get_state()["player_hp"], _s.combat.player_stats().max_hp)


func test_stop_during_a_fracture_is_an_abandon() -> void:
	_open()
	_s.combat.stop(Reasons.STOPPED_BY_USER)
	assert_false(_s.fractures.is_active())
	assert_false(_s.combat.is_active())
	assert_eq(_log.filter(func(e: Array) -> bool: return e[0] == "finished")[0][1], &"abandoned")
	assert_eq(_s.combat.stop_reasons_log().back(), Reasons.STOPPED_BY_USER)


func test_death_loses_the_bag_and_the_card_and_restores_hp() -> void:
	_s.combat.start(AREA)
	_open()
	_s.events.fracture_group_cleared.connect(func(i: int, _t: int) -> void:
		if i == 1:
			FractureUtil.weakling(_s))
	var spent: int = FractureUtil.run_until(_s, _over, 100, 600_000)
	assert_lt(spent, 600_000, "the player dies")
	var finished: Array = _log.filter(func(e: Array) -> bool: return e[0] == "finished")[0]
	assert_eq(finished[1], &"died")
	assert_eq(finished[3], 1, "died at the second group: one group was cleared")
	assert_true(_names().has("died"))
	assert_false(_s.fractures.is_active())
	assert_eq(_s.combat.deaths(), 1)
	assert_eq(_s.combat.area_id(), AREA, "back to the area")
	assert_eq(_s.combat.get_state()["player_hp"], _s.combat.player_stats().max_hp)


func test_no_stone_and_no_kill_count_inside_a_fracture() -> void:
	_s.combat.start(STONE_AREA)
	_open()
	var appeared: Array = []
	_s.events.rift_stone_appeared.connect(func(_id: StringName) -> void: appeared.append(true))
	var before: Dictionary = (_s.combat.to_save()["stone"] as Dictionary).duplicate()
	FractureUtil.run_until(_s, _over)
	assert_true(appeared.is_empty())
	assert_eq(_s.combat.to_save()["stone"], before, "F-87 counted nothing inside the Fracture")
	assert_eq(_s.combat.kills(&"boss_grade_1"), 0, "the boss is not a monster of the data")


func test_loadout_and_equipment_are_locked_all_the_time() -> void:
	var blade: int = TestFactory.give_piece(_s, &"test_blade")
	_open()
	assert_eq(_s.equipment.equip(blade).reason, Reasons.COMBAT_ACTIVE, "while the fight is on")
	var seen: Array = []
	_s.events.encounter_cleared.connect(func() -> void: seen.append(_s.equipment.equip(blade).reason))
	FractureUtil.run_until(_s, _over)
	assert_eq(seen[0], Reasons.COMBAT_ACTIVE, "also in BETWEEN")
	assert_true(_s.equipment.equip(blade).ok, "free again after the Fracture")


func test_start_of_an_area_is_refused_inside_a_fracture() -> void:
	_open()
	assert_eq(_s.combat.start(AREA).reason, Reasons.FRACTURE_ACTIVE)
	assert_eq(_s.combat.start_fracture(_s.combat.fracture_run()).reason, Reasons.FRACTURE_ACTIVE)


func test_advance_in_steps_gives_the_same_result() -> void:
	var one: GameSession = autofree(FractureUtil.session(5))
	var ten: GameSession = autofree(FractureUtil.session(5))
	for s: GameSession in [one, ten]:
		FractureUtil.hero(s)
		s.combat.start(AREA)
		assert_true(s.fractures.open(FractureUtil.card(s, 1, [["assault", 4], ["pulses", 3]])).ok)
	for _i: int in 40:
		one.advance(1000)
		for _j: int in 10:
			ten.advance(100)
	assert_eq(one.combat.to_save(), ten.combat.to_save())
	assert_eq(one.fractures.to_save(), ten.fractures.to_save())
	assert_eq(one.rng.to_save(), ten.rng.to_save())
	assert_eq(one.bank.to_save(), ten.bank.to_save())
