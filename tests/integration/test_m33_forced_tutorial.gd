extends GutTest
## M33-04: the forced tutorial on a real session (real data, a real new game, fixed seeds, no helper that learns or equips):
## the forced groups (no rock_ram on any seed), the stops at steps 6 and 8-13, the forced node, the save at every step and in the
## middle of a pause, an old v12 slot with the combat on at step 9, the player who stops the combat from the Map, 12 h = 100 ms = 60 s
## on the paused steps. docs/M33_TUTORIAL_FORZATO.md. The groups follow `data/tutorial/steps.json` (the single definition).

const Play := preload("res://tests/integration/test_tutorial_playthrough.gd")
const AREA: StringName = &"redrock_plains"
const TICK_MS: int = 100
const BLOCK_MS: int = 60_000
const TWELVE_H: int = 12 * 3_600_000
const MAX_TICKS: int = 60000
const SEED_COUNT: int = 60

var _packs: Array[Dictionary] = []  # {step, ids}
var _deaths: int = 0


func _watch(s: GameSession) -> void:
	_packs.clear()
	_deaths = 0
	s.events.encounter_started.connect(func(ids: Array[StringName]) -> void:
		_packs.append({"step": s.tutorial.current_step().id if s.tutorial.is_active() else &"", "ids": ids.duplicate()}))
	s.events.player_died.connect(func() -> void: _deaths += 1)


func _step_pack(s: GameSession, id: StringName) -> Array[StringName]:
	for def: TutorialStepDef in s.data.tutorial_steps():
		if def.id == id:
			return def.force_pack
	return [] as Array[StringName]


func _advance_until(s: GameSession, done: Callable) -> int:
	var ticks: int = 0
	while not done.call() and ticks < MAX_TICKS:
		if not s.combat.is_active() and not s.combat.is_frozen():
			s.combat.start(AREA)
		s.advance(TICK_MS)
		ticks += 1
	assert_lt(ticks, MAX_TICKS, "reached in game time")
	return ticks


func _leave_step(s: GameSession) -> void:
	var index: int = s.tutorial.step_index()
	_advance_until(s, func() -> bool: return s.tutorial.step_index() != index)


## The player's action for the current step (no helper that learns or equips).
func _act(s: GameSession) -> void:
	match s.tutorial.current_step().id:
		&"equipment":
			for inst: ItemInstance in s.armory.instances():
				if inst.base_id == &"emberbronze_greatsword":
					assert_true(s.equipment.equip(inst.uid).ok)
		&"combat_start":
			assert_true(s.combat.start(AREA).ok)
		&"combat_kills", &"combat_eat", &"nodes":
			_leave_step(s)
		&"trainers":
			assert_true(s.disciplines.learn(&"forestry").ok)
		&"mail":
			for message: Dictionary in s.mail.messages():
				s.mail.collect(int(message["id"]))
		_:
			s.tutorial.notify_page_opened(s.tutorial.current_step().page)
			assert_true(s.tutorial.acknowledge().ok)


func _play_to(s: GameSession, stop_id: StringName) -> void:
	var guard: int = 0
	while s.tutorial.is_active() and s.tutorial.current_step().id != stop_id and guard < 40:
		_act(s)
		guard += 1
	assert_eq(s.tutorial.current_step().id, stop_id)


func _reload(old: GameSession) -> GameSession:
	var parsed: Variant = JSON.parse_string(JSON.stringify(old.to_save(1_700_000_000_000)))
	var events: GameEvents = GameEvents.new()
	var s: GameSession = GameSession.new(TestFactory.real_data(), events, 1)
	s.add_child(events)
	assert_true(s.from_save(SaveMigrator.migrate(parsed as Dictionary)).ok, "the slot loads")
	old.free()
	_watch(s)
	return s


func _kills_total(s: GameSession) -> int:
	var total: int = 0
	for count: int in s.combat.total_kills().values():
		total += count
	return total


# ---- the groups: forced, weak, never rock_ram, nobody dies ---------------------------------------------------------------------------------

func test_the_forced_groups_hold_on_60_seeds_no_rock_ram_no_death_the_meal_in_the_first_group() -> void:
	var expected_a: Array[StringName] = []
	var expected_b: Array[StringName] = []
	var expected_c: Array[StringName] = []
	for seed_value: int in SEED_COUNT:
		var s: GameSession = Play.new_game_session(5000 + seed_value)
		_watch(s)
		if seed_value == 0:
			expected_a = _step_pack(s, &"combat_kills")
			expected_b = _step_pack(s, &"combat_eat")
			expected_c = _step_pack(s, &"nodes")
			assert_false(expected_a.is_empty())
			assert_false(expected_b.is_empty())
			assert_false(expected_c.is_empty())
		_play_to(s, &"village")
		var a: int = 0
		var b: int = 0
		for row: Dictionary in _packs:
			var ids: Array = row["ids"]
			assert_false(ids.has(&"rock_ram"), "seed %d: no rock_ram in %s" % [5000 + seed_value, str(ids)])
			if row["step"] == &"combat_kills":
				a += 1
				assert_eq(ids, expected_a, "seed %d: the group of step 5" % (5000 + seed_value))
			elif row["step"] == &"combat_eat":
				b += 1
				assert_eq(ids, expected_b, "seed %d: the group of step 7" % (5000 + seed_value))
			elif row["step"] == &"nodes":
				assert_true(ids == expected_b or ids == expected_c, "seed %d: step 14 serves a forced group" % (5000 + seed_value))
		assert_eq(a, 1, "seed %d: step 5 is one group" % (5000 + seed_value))
		assert_eq(b, 1, "seed %d: the meal comes in the first group of step 7" % (5000 + seed_value))
		assert_eq(_deaths, 0, "seed %d: nobody dies" % (5000 + seed_value))
		s.free()


# ---- the pauses ---------------------------------------------------------------------------------------------------------------------------

func test_the_pause_of_step_6_holds_exactly_the_three_kills_then_avanti_restarts() -> void:
	var s: GameSession = Play.new_game_session(5101)
	_watch(s)
	_play_to(s, &"combat_triangle")
	assert_true(s.combat.is_frozen())
	assert_eq(_kills_total(s), (_step_pack(s, &"combat_kills") as Array).size(), "the whole forced group is dead, no more")
	assert_true(s.combat.force_pack().is_empty(), "step 6 has no group of its own (derived from the step)")
	var rng_state: Variant = s.rng.to_save()
	s.advance(TWELVE_H)
	assert_eq(s.rng.to_save(), rng_state, "no roll during the pause")
	assert_eq(_kills_total(s), 3)
	assert_eq(s.tutorial.current_step().id, &"combat_triangle")
	assert_true(s.tutorial.acknowledge().ok)
	assert_false(s.combat.is_frozen())
	assert_eq(s.tutorial.current_step().id, &"combat_eat")
	assert_eq(s.combat.force_pack(), _step_pack(s, &"combat_eat"), "the group of the meal is armed at once")
	s.free()


func test_steps_8_to_13_stay_paused_and_step_14_restarts_with_the_node_and_the_group_armed() -> void:
	var s: GameSession = Play.new_game_session(5102)
	_play_to(s, &"combat_food")
	var rng_state: Variant = s.rng.to_save()
	for id: StringName in [&"combat_food", &"bank", &"shop", &"rift", &"trainers", &"skill"]:
		assert_eq(s.tutorial.current_step().id, id)
		assert_true(s.combat.is_frozen(), "%s: paused" % id)
		assert_true(s.tutorial.is_combat_frozen())
		s.advance(20_000)
		assert_eq(s.rng.to_save(), rng_state, "%s: no roll" % id)
		_act(s)  # the last one (skill) enters step 14, which restarts the combat
	assert_eq(s.tutorial.current_step().id, &"nodes")
	assert_false(s.combat.is_frozen())
	assert_true(s.combat.is_force_node())
	assert_eq(s.combat.force_pack(), _step_pack(s, &"nodes"))
	assert_true(s.combat.is_guarded())
	_leave_step(s)
	assert_false(s.combat.is_force_node())
	assert_true(s.combat.force_pack().is_empty(), "the group is disarmed with the step")
	assert_false(s.combat.is_guarded())
	assert_false(s.combat.is_frozen())
	s.free()


# ---- the save at every step, in the middle of a pause and of the node -----------------------------------------------------------------

func test_a_save_at_every_step_resumes_with_the_pause_and_the_group_of_the_step() -> void:
	var s: GameSession = Play.new_game_session(5200)
	var steps: Array[TutorialStepDef] = s.data.tutorial_steps()
	for i: int in steps.size():
		var def: TutorialStepDef = steps[i]
		var frozen_before: bool = s.combat.is_frozen()
		s = _reload(s)
		assert_eq(s.tutorial.step_index(), i, "step %d (%s)" % [i + 1, def.id])
		assert_eq(s.combat.is_frozen(), def.freeze_combat, "%s: the pause is derived from the step (was %s)" % [def.id, frozen_before])
		assert_eq(s.combat.force_pack(), def.force_pack, "%s: the group is derived from the step" % def.id)
		assert_eq(s.combat.is_force_node(), def.force_node, "%s: the node flag is derived from the step" % def.id)
		_act(s)
	assert_true(s.tutorial.is_completed())
	assert_false(s.combat.is_frozen())
	assert_true(s.combat.force_pack().is_empty())
	assert_false(s.combat.is_guarded())
	s.free()


func test_a_save_in_the_middle_of_each_pause_resumes_paused_and_ends_the_tutorial() -> void:
	for stop_id: StringName in [&"combat_triangle", &"combat_food", &"trainers"]:
		var s: GameSession = Play.new_game_session(5300)
		_play_to(s, stop_id)
		s.advance(45_000)
		var rng_state: Variant = s.rng.to_save()
		s = _reload(s)
		assert_eq(s.tutorial.current_step().id, stop_id)
		assert_true(s.combat.is_frozen(), "%s: paused after the load" % stop_id)
		s.advance(60_000)
		assert_eq(s.rng.to_save(), rng_state, "%s: no roll after the load" % stop_id)
		_play_to(s, &"finish")
		_act(s)
		assert_true(s.tutorial.is_completed(), "%s: the tutorial ends" % stop_id)
		assert_eq(_deaths, 0)
		s.free()


func test_a_save_in_the_middle_of_the_forced_node_and_after_it_keeps_the_tutorial_going() -> void:
	var s: GameSession = Play.new_game_session(5400)
	_play_to(s, &"nodes")
	_leave_step(s)
	assert_eq(s.tutorial.current_step().id, &"village")
	assert_eq(s.combat.node_skill(), &"forestry", "the node is being worked")
	s = _reload(s)
	assert_eq(s.tutorial.current_step().id, &"village")
	assert_false(s.combat.is_frozen())
	assert_false(s.combat.is_force_node())
	assert_true(s.combat.force_pack().is_empty())
	s.advance(120_000)
	_play_to(s, &"finish")
	_act(s)
	assert_true(s.tutorial.is_completed())
	s.free()


func test_an_old_v12_slot_with_the_combat_on_at_step_9_resumes_paused_and_completes() -> void:
	var s: GameSession = Play.new_game_session(5500)
	_play_to(s, &"bank")
	var d: Dictionary = JSON.parse_string(JSON.stringify(s.to_save(1_700_000_000_000)))
	assert_eq(int(d["format_version"]), 13, "no new save key: still v13")
	assert_true(((d["modules"] as Dictionary)["combat"] as Dictionary).size() > 0)
	s.free()
	var events: GameEvents = GameEvents.new()
	s = GameSession.new(TestFactory.real_data(), events, 1)
	s.add_child(events)
	assert_true(s.from_save(SaveMigrator.migrate(d)).ok)
	assert_eq(s.tutorial.current_step().id, &"bank")
	assert_true(s.combat.is_frozen(), "an old tutorial resumes paused")
	_watch(s)
	_play_to(s, &"nodes")
	assert_false(s.combat.is_frozen())
	_play_to(s, &"finish")
	_act(s)
	assert_true(s.tutorial.is_completed())
	assert_false(s.combat.is_frozen())
	assert_false(s.combat.is_guarded())
	s.free()


# ---- the player who stops the combat from the Map ----------------------------------------------------------------------------------------

func test_stopping_the_combat_at_step_5_and_restarting_finds_the_forced_group() -> void:
	var s: GameSession = Play.new_game_session(5600)
	_watch(s)
	_play_to(s, &"combat_kills")
	_advance_until(s, func() -> bool: return s.tutorial.step_progress() >= 1)
	s.combat.stop()
	assert_false(s.combat.is_active())
	_packs.clear()
	assert_true(s.combat.start(AREA).ok)
	_leave_step(s)
	assert_eq(s.tutorial.current_step().id, &"combat_triangle")
	assert_false(_packs.is_empty())
	assert_eq(_packs[0]["ids"], _step_pack(s, &"combat_kills"), "the restarted combat serves the forced group")
	for row: Dictionary in _packs:
		assert_false((row["ids"] as Array).has(&"rock_ram"))
	_play_to(s, &"finish")
	_act(s)
	assert_true(s.tutorial.is_completed())
	assert_eq(_deaths, 0)
	s.free()


func test_stopping_the_combat_at_step_7_and_restarting_still_gives_the_wound_and_the_meal() -> void:
	var s: GameSession = Play.new_game_session(5601)
	_watch(s)
	_play_to(s, &"combat_eat")
	s.advance(300)
	s.combat.stop()
	_packs.clear()
	assert_true(s.combat.start(AREA).ok)
	_leave_step(s)
	assert_eq(s.tutorial.current_step().id, &"combat_food", "the meal arrives")
	assert_false(_packs.is_empty())
	assert_eq(_packs[0]["ids"], _step_pack(s, &"combat_eat"))
	_play_to(s, &"finish")
	_act(s)
	assert_true(s.tutorial.is_completed())
	assert_eq(_deaths, 0)
	s.free()


func test_stopping_the_combat_before_step_14_and_restarting_finds_the_group_and_the_node() -> void:
	var s: GameSession = Play.new_game_session(5602)
	_watch(s)
	_play_to(s, &"skill")
	s.combat.stop()
	assert_true(s.tutorial.acknowledge().ok)
	assert_eq(s.tutorial.current_step().id, &"nodes")
	assert_false(s.combat.is_active(), "the combat is still stopped at the entry")
	assert_true(s.combat.is_force_node())
	_packs.clear()
	assert_true(s.combat.start(AREA).ok)
	_leave_step(s)
	assert_eq(s.tutorial.current_step().id, &"village", "the forced node is started")
	assert_false(_packs.is_empty())
	assert_eq(_packs[0]["ids"], _step_pack(s, &"nodes"))
	assert_eq(_deaths, 0)
	_play_to(s, &"finish")
	_act(s)
	assert_true(s.tutorial.is_completed())
	s.free()


# ---- 12 h = 100 ms ticks = 60 s blocks (with a reload) on the paused steps -----------------------------------------------------------

func _state(s: GameSession) -> Dictionary:
	var d: Dictionary = s.to_save(0)
	d.erase("play_time_ms")
	return d


func _assert_same(a: GameSession, b: GameSession, what: String) -> void:
	var left: Dictionary = _state(a)
	var right: Dictionary = _state(b)
	for module: Variant in left["modules"] as Dictionary:
		assert_eq((right["modules"] as Dictionary).get(module), (left["modules"] as Dictionary)[module], "%s: module %s" % [what, module])
	assert_eq(right["rng"], left["rng"], "%s: the rng" % what)


func test_twelve_hours_on_the_paused_steps_6_8_and_11_change_nothing_but_the_clock() -> void:
	for stop_id: StringName in [&"combat_triangle", &"combat_food", &"trainers"]:
		var one: GameSession = Play.new_game_session(5700)
		_play_to(one, stop_id)
		var before: Dictionary = (_state(one)["modules"] as Dictionary).duplicate(true)
		var rng_state: Variant = one.rng.to_save()
		var clock: int = one.play_time_ms
		one.advance(TWELVE_H)
		assert_true(one.combat.is_frozen(), "%s: still paused" % stop_id)
		assert_eq(one.tutorial.current_step().id, stop_id)
		assert_eq(one.rng.to_save(), rng_state, "%s: no roll" % stop_id)
		assert_eq(one.play_time_ms - clock, TWELVE_H)
		assert_eq((_state(one)["modules"] as Dictionary)["combat"], before["combat"], "%s: the combat module is the same" % stop_id)
		var ticks: GameSession = Play.new_game_session(5700)
		_play_to(ticks, stop_id)
		for _i: int in TWELVE_H / TICK_MS:
			ticks.advance(TICK_MS)
		var blocks: GameSession = Play.new_game_session(5700)
		_play_to(blocks, stop_id)
		for i: int in TWELVE_H / BLOCK_MS:
			blocks.advance(BLOCK_MS)
			if i == 360:
				blocks = _reload(blocks)
		_assert_same(one, ticks, "%s: block vs ticks" % stop_id)
		_assert_same(one, blocks, "%s: block vs 60 s blocks with a reload" % stop_id)
		one.free()
		ticks.free()
		blocks.free()
