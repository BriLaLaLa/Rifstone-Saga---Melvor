extends GutTest
## M33-02 (docs/M33_TUTORIAL_FORZATO.md §3.2): the forced pack and the guard of the combat engine, on the real data.

const AREA: StringName = &"redrock_plains"
const BOAR: StringName = &"plains_boar"
const RAT: StringName = &"ember_rat"


## A session on the real data; with `tutorial_step` the tutorial is at that step. `setup`: sword_shield | greatsword | dual_swords.
static func session(seed_value: int, tutorial_step: String = "", setup: StringName = &"sword_shield") -> GameSession:
	var s: GameSession = TestFactory.session(seed_value, TestFactory.real_data(), false, tutorial_step != "")
	if setup == &"greatsword":
		for inst: ItemInstance in s.armory.instances():
			if inst.base_id == &"emberbronze_greatsword":
				s.equipment.equip(inst.uid)
	elif setup == &"dual_swords":
		s.equipment.equip(TestFactory.give_piece(s, &"emberbronze_sword"), &"offhand")
	if tutorial_step != "":
		s.tutorial.from_save({"completed": false, "step": tutorial_step, "progress": 0, "since_ms": 0, "visited": []})
	return s


static func ids(list: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(list)
	return result


static func run_to_travel(s: GameSession) -> void:
	var spent: int = 0
	while s.combat.get_state()["state"] != CombatEngine.STATE_TRAVEL and spent < 600_000 and s.combat.is_active():
		s.advance(500)
		spent += 500


func test_the_forced_pack_is_exactly_the_data_on_200_seeds_with_no_roll() -> void:
	for seed_value: int in 200:
		var s: GameSession = autofree(session(seed_value, "combat_kills"))
		var seen: Array = []
		s.events.encounter_started.connect(func(monsters: Array[StringName]) -> void: seen.append(monsters))
		var rng_before: String = JSON.stringify(s.rng.to_save())
		assert_true(s.combat.start(AREA).ok)
		assert_eq(seen.size(), 1)
		assert_eq(seen[0], ids([BOAR, RAT, BOAR]), "seed %d" % seed_value)
		assert_false((seen[0] as Array).has(&"rock_ram"), "seed %d" % seed_value)
		assert_eq(JSON.stringify(s.rng.to_save()), rng_before, "seed %d: no draw for the pack" % seed_value)


func test_the_pack_is_the_same_at_every_encounter_while_armed_and_gone_after() -> void:
	var s: GameSession = autofree(session(3))
	s.combat.set_force_pack(AREA, ids([BOAR]))
	assert_eq(s.combat.force_pack(), ids([BOAR]))
	var seen: Array = []
	s.events.encounter_started.connect(func(monsters: Array[StringName]) -> void: seen.append(monsters))
	s.combat.start(AREA)
	assert_true(s.combat.is_guarded())
	var spent: int = 0
	while seen.size() < 3 and spent < 600_000:
		s.advance(1000)
		spent += 1000
		if not s.combat.is_active():
			s.combat.start(AREA)
	assert_gte(seen.size(), 3)
	for monsters: Array in seen:
		assert_eq(monsters, ids([BOAR]))
	s.combat.set_force_pack(&"", [] as Array[StringName])
	assert_true(s.combat.force_pack().is_empty())
	assert_false(s.combat.is_guarded())


func test_another_area_gets_no_effect_and_new_game_and_load_clear() -> void:
	var s: GameSession = autofree(session(3))
	s.combat.set_force_pack(&"whisper_wood", ids([&"whisper_wolf"]))
	s.combat.start(AREA)
	assert_false(s.combat.is_guarded(), "the pack is for another area")
	s.combat.set_force_pack(AREA, ids([BOAR]))
	assert_true(s.combat.is_guarded())
	s.combat.new_game()
	assert_true(s.combat.force_pack().is_empty())
	s.combat.set_force_pack(AREA, ids([BOAR]))
	s.combat.from_save({})
	assert_true(s.combat.force_pack().is_empty(), "never saved, cleared by a load")


func test_a_waiting_miniboss_stays_waiting_while_the_pack_is_armed() -> void:
	var s: GameSession = autofree(session(9))
	s.combat.start(AREA)
	var d: Dictionary = s.combat.to_save()
	d["miniboss_pending"] = true
	s.combat.from_save(d)
	s.combat.set_force_pack(AREA, ids([BOAR]))
	var seen: Array = []
	s.events.encounter_started.connect(func(monsters: Array[StringName]) -> void: seen.append(monsters))
	var spent: int = 0
	while seen.is_empty() and spent < 900_000:
		s.advance(1000)
		spent += 1000
	assert_false(seen.is_empty())
	assert_eq(seen[0], ids([BOAR]), "the forced pack wins over the miniboss")
	assert_true(s.combat.to_save()["miniboss_pending"], "the miniboss is still waiting")


func test_without_the_tutorial_nothing_changes() -> void:
	var a: GameSession = autofree(session(14))
	var b: GameSession = autofree(session(14))
	assert_true(a.combat.force_pack().is_empty())
	assert_false(a.combat.is_guarded())
	a.combat.start(AREA)
	b.combat.start(AREA)
	a.advance(120_000)
	b.advance(120_000)
	assert_eq(JSON.stringify(a.combat.to_save()), JSON.stringify(b.combat.to_save()))
	assert_eq(JSON.stringify(a.rng.to_save()), JSON.stringify(b.rng.to_save()))


func test_the_pack_turns_a_journey_to_a_node_into_a_fight_without_a_roll() -> void:
	var found: bool = false
	for seed_value: int in 60:
		var s: GameSession = autofree(session(seed_value))
		TestFactory.learn_discipline(s, &"forestry")
		s.combat.start(AREA)
		run_to_travel(s)
		if s.combat.get_state()["state"] != CombatEngine.STATE_TRAVEL or s.combat.get_state()["next"]["kind"] != EncounterCycle.NODE:
			continue
		found = true
		var rng_before: String = JSON.stringify(s.rng.to_save())
		s.combat.set_force_pack(AREA, ids([BOAR]))
		assert_eq(s.combat.get_state()["next"]["kind"], EncounterCycle.FIGHT, "seed %d" % seed_value)
		assert_eq(JSON.stringify(s.rng.to_save()), rng_before)
		break
	assert_true(found, "some seed travels to a node")


func test_force_node_on_a_journey_replaces_it_with_the_forced_node_without_a_roll() -> void:
	var found: bool = false
	for seed_value: int in 60:
		var s: GameSession = autofree(session(seed_value))
		s.disciplines.new_game()
		TestFactory.learn_discipline(s, &"quarrying")
		s.combat.start(AREA)
		run_to_travel(s)
		if s.combat.get_state()["state"] != CombatEngine.STATE_TRAVEL or s.combat.get_state()["next"]["kind"] != EncounterCycle.FIGHT:
			continue
		found = true
		var rng_before: String = JSON.stringify(s.rng.to_save())
		s.combat.set_force_node(true)
		assert_eq(s.combat.get_state()["next"]["kind"], EncounterCycle.NODE, "seed %d" % seed_value)
		assert_eq(s.combat.get_state()["next"]["skill"], &"quarrying", "seed %d" % seed_value)
		assert_eq(JSON.stringify(s.rng.to_save()), rng_before)
		break
	assert_true(found, "some seed travels to a fight")


func test_no_usable_discipline_changes_nothing() -> void:
	var s: GameSession = autofree(session(5))
	s.disciplines.new_game()
	s.combat.start(AREA)
	run_to_travel(s)
	var before: Dictionary = (s.combat.get_state()["next"] as Dictionary).duplicate()
	s.combat.set_force_node(true)
	assert_eq(s.combat.get_state()["next"], before)


func test_the_guard_beats_a_waiting_miniboss_for_the_forced_node() -> void:
	var s: GameSession = autofree(session(9))
	s.disciplines.new_game()
	TestFactory.learn_discipline(s, &"forestry")
	s.combat.start(AREA)
	var d: Dictionary = s.combat.to_save()
	d["miniboss_pending"] = true
	s.combat.from_save(d)
	s.combat.set_force_node(true)
	s.combat.set_force_pack(AREA, ids([BOAR]))
	run_to_travel(s)
	assert_eq(s.combat.get_state()["state"], CombatEngine.STATE_TRAVEL)
	assert_eq(s.combat.get_state()["next"]["kind"], EncounterCycle.NODE, "the node wins over the miniboss")
	assert_eq(s.combat.get_state()["next"]["skill"], &"forestry")
	assert_true(s.combat.to_save()["miniboss_pending"], "the miniboss still waits")
	s.combat.set_force_node(false)
	s.combat.set_force_pack(&"", [] as Array[StringName])
	assert_false(s.combat.is_guarded())
