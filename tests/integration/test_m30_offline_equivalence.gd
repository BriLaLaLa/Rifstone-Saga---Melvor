extends GutTest
## M30-05: the tutorial and the starter quests do not depend on how the time is cut (docs/05_INTERFACES_M30.md §5.41-§5.42, docs/01_GDD_M30.md
## §41.10). A real session on the real data with the tutorial in the middle (step "nodes": a node must start) and a scripted player that only
## reacts to the model's events (Avanti on the reading steps, "Ritira" on the mail step): 12 h in one block = 100 ms ticks = blocks of 60 s
## with a save and a reload half way. The tutorial ends inside the block (otherwise `since_ms` of the step entered in the block would
## differ: it is the clock at the start of the chunk), so `to_save()` is the same and `tutorial_completed` comes at the same kill.

const Sim := preload("res://tools/sim_combat.gd")
const Play := preload("res://tests/integration/test_tutorial_playthrough.gd")
const AREA: StringName = &"redrock_plains"
const HOUR_MS: int = 3_600_000
const TWELVE_H: int = 12 * HOUR_MS
const TICK_MS: int = 100
const BLOCK_MS: int = 60_000
const SEED: int = 3040

var _kills_at_completion: Array[int] = []


## A new game brought to the step "nodes" with the player's own commands, the fight running, a level 40 character with its gear (no test modifier: those are not in the slot file and a reload would lose them).
func _prepared() -> GameSession:
	var s: GameSession = autofree(Play.new_game_session(SEED))
	for step_id: StringName in [&"welcome", &"character"]:
		assert_eq(s.tutorial.current_step().id, step_id)
		assert_true(s.tutorial.acknowledge().ok)
	for inst: ItemInstance in s.armory.instances():
		if inst.base_id == &"emberbronze_greatsword":
			assert_true(s.equipment.equip(inst.uid).ok)
	assert_true(s.combat.start(AREA).ok)
	var guard: int = 0
	while s.tutorial.current_step().id != &"combat_triangle" and guard < 20000:
		s.advance(TICK_MS)
		guard += 1
	for step_id: StringName in [&"combat_triangle", &"combat_food", &"bank", &"shop", &"rift"]:
		assert_eq(s.tutorial.current_step().id, step_id)
		assert_true(s.tutorial.acknowledge().ok)
	assert_true(s.disciplines.learn(&"forestry").ok)
	assert_true(s.tutorial.acknowledge().ok)  # the "skill" step
	assert_eq(s.tutorial.current_step().id, &"nodes")
	var grade: int = Sim.auto_grade(s.data, 40)  # real gear of the level (persisted), never a test modifier
	TestFactory.set_character_level(s, 40)
	Sim._equip_set(s, grade, &"sword_shield")
	var food: StringName = Sim.food_for_grade(s.data, grade)
	s.bank.add(food, 3000)
	s.equipment.set_food(food)
	_attach(s)
	return s


func _kills(s: GameSession) -> int:
	var total: int = 0
	for count: int in s.combat.total_kills().values():
		total += count
	return total


## The scripted player: it reads the steps (Avanti) and collects the gift. It acts only on the model's own events.
func _attach(s: GameSession) -> void:
	s.events.tutorial_step_changed.connect(func(step_id: StringName, _i: int, _t: int) -> void:
		var def: TutorialStepDef = s.tutorial.current_step()
		if def == null:
			return
		if step_id == &"mail":
			for message: Dictionary in s.mail.messages():
				s.mail.collect(int(message["id"]))
		elif s.tutorial.can_acknowledge():
			s.tutorial.notify_page_opened(def.page)
			s.tutorial.acknowledge())
	s.events.tutorial_completed.connect(func() -> void: _kills_at_completion.append(_kills(s)))


func _state(s: GameSession) -> Dictionary:
	var d: Dictionary = s.to_save(0)
	d.erase("play_time_ms")  # the clock of the chunk; the rest of the file must be the same
	return d


func _reload(old: GameSession) -> GameSession:
	var parsed: Variant = JSON.parse_string(JSON.stringify(old.to_save(1_700_000_000_000)))
	var events: GameEvents = GameEvents.new()
	var s: GameSession = autofree(GameSession.new(TestFactory.real_data(), events, 1))
	s.add_child(events)
	assert_true(s.from_save(SaveMigrator.migrate(parsed as Dictionary)).ok)
	_attach(s)
	return s


func _assert_same(a: GameSession, b: GameSession, what: String) -> void:
	var left: Dictionary = _state(a)
	var right: Dictionary = _state(b)
	var modules_a: Dictionary = left["modules"]
	var modules_b: Dictionary = right["modules"]
	for module: Variant in modules_a:
		assert_eq(modules_b.get(module), modules_a[module], "%s: module %s" % [what, module])
	assert_eq(right["rng"], left["rng"], "%s: the rng" % what)


func test_twelve_hours_in_one_block_in_ticks_and_in_blocks_with_a_reload_give_the_same_tutorial_and_quests() -> void:
	var one: GameSession = _prepared()
	var one_kills_at: Array[int] = []
	_kills_at_completion.clear()
	one.advance(TWELVE_H)
	one_kills_at.assign(_kills_at_completion)
	assert_true(one.tutorial.is_completed(), "the tutorial ends inside the block")
	assert_eq(one_kills_at.size(), 1, "tutorial_completed once")
	assert_true(one.tutorial.starter.is_enabled())
	assert_gt(one.tutorial.starter.claimable().size(), 0, "the quests of the combat are done in the same block")

	_kills_at_completion.clear()
	var ticks: GameSession = _prepared()
	_kills_at_completion.clear()
	for _i: int in TWELVE_H / TICK_MS:
		ticks.advance(TICK_MS)
	assert_eq(_kills_at_completion, one_kills_at, "ticks: tutorial_completed at the same kill")
	_assert_same(one, ticks, "block vs ticks")

	var blocks: GameSession = _prepared()
	_kills_at_completion.clear()
	for i: int in TWELVE_H / BLOCK_MS:
		blocks.advance(BLOCK_MS)
		if i == (TWELVE_H / BLOCK_MS) / 2:
			blocks = _reload(blocks)
	assert_eq(_kills_at_completion, one_kills_at, "blocks with a reload: tutorial_completed at the same kill")
	_assert_same(one, blocks, "block vs 60 s blocks with a reload")


func test_a_step_entered_inside_a_block_keeps_a_valid_valve_clock() -> void:
	# The tutorial still running after the block (no scripted player): the step is entered at the clock of the chunk, never in the future.
	var s: GameSession = autofree(Play.new_game_session(SEED + 1))
	s.tutorial.acknowledge()
	s.tutorial.acknowledge()
	for inst: ItemInstance in s.armory.instances():
		if inst.base_id == &"emberbronze_greatsword":
			s.equipment.equip(inst.uid)
	s.combat.start(AREA)
	s.modifiers.set_source(&"test:hero", [Modifier.make(&"power_bonus", 100000.0), Modifier.make(&"max_hp_flat", 100000.0)])
	s.advance(HOUR_MS)
	assert_eq(s.tutorial.current_step().id, &"combat_triangle", "three kills, then the reading step waits")
	var saved: Dictionary = (s.to_save(0)["modules"] as Dictionary)["tutorial"]
	assert_between(int(saved["since_ms"]), 0, s.play_time_ms, "since_ms is a clock the session has already lived")
	assert_true(s.tutorial.can_acknowledge())
	assert_false(s.tutorial.can_skip_step(), "an Avanti step never shows the valve")
