extends GutTest
## M30-05: the whole tutorial on a real session (real data, a new game with the tutorial active, no helper that learns or equips):
## for each of the 21 steps the player's action is done on the model, the step ends and the next one begins; at the end
## `tutorial_completed` and the starter quests are active (docs/01_GDD_M30.md §41.4, docs/05_INTERFACES_M30.md §5.41).

const AREA: StringName = &"redrock_plains"
const TICK_MS: int = 100
const MAX_TICKS: int = 60000  # 100 minutes of game time: a step that does not end by then is a trap

var _changes: Array[StringName] = []
var _completed_at: Array[int] = []


## A real new game as the title screen makes it: only new_game(), not the factory's `learn_all`.
static func new_game_session(seed_value: int = 3005) -> GameSession:
	var events: GameEvents = GameEvents.new()
	var s: GameSession = GameSession.new(TestFactory.real_data(), events, seed_value)
	s.add_child(events)
	s.new_game()
	return s


func _watch(s: GameSession) -> void:
	_changes.clear()
	_completed_at.clear()
	s.events.tutorial_step_changed.connect(func(step_id: StringName, _i: int, _t: int) -> void: _changes.append(step_id))
	s.events.tutorial_completed.connect(func() -> void: _completed_at.append(s.play_time_ms))


## Advances in ticks until `done` is true; restarts the fight when it stopped (the page area stays usable for that). Returns the ticks used.
func _advance_until(s: GameSession, done: Callable) -> int:
	var ticks: int = 0
	while not done.call() and ticks < MAX_TICKS:
		if not s.combat.is_active():
			s.combat.start(AREA)
		s.advance(TICK_MS)
		ticks += 1
	return ticks


func _greatsword_uid(s: GameSession) -> int:
	for inst: ItemInstance in s.armory.instances():
		if inst.base_id == &"emberbronze_greatsword":
			return inst.uid
	return 0


## The player's action for the current step. Returns false when the step id has no action here (a test bug).
func _act(s: GameSession, id: StringName) -> void:
	match id:
		&"equipment":
			var uid: int = _greatsword_uid(s)
			assert_gt(uid, 0, "the Spadone is in the Armory of a new game")
			assert_true(s.equipment.equip(uid).ok)
		&"combat_start":
			assert_true(s.combat.start(AREA).ok)
		&"combat_kills":
			var step_index: int = s.tutorial.step_index()
			var ticks: int = _advance_until(s, func() -> bool: return s.tutorial.step_index() != step_index)
			assert_lt(ticks, MAX_TICKS, "three kills happen")
		&"trainers":
			assert_true(s.disciplines.learn(&"forestry").ok)
		&"nodes":
			var step_index: int = s.tutorial.step_index()
			var ticks: int = _advance_until(s, func() -> bool: return s.tutorial.step_index() != step_index)
			assert_lt(ticks, MAX_TICKS, "a node starts within the time of the valve")
		&"mail":
			var collected: bool = false
			for message: Dictionary in s.mail.messages():
				if s.mail.collect(int(message["id"])).ok:
					collected = true
					break
			assert_true(collected, "the gift of step 17 is in the Mail")
		_:
			s.tutorial.notify_page_opened(StringName(s.tutorial.current_step().page))
			assert_true(s.tutorial.can_acknowledge(), "step %s ends with Avanti" % id)
			assert_true(s.tutorial.acknowledge().ok)


func test_new_game_starts_the_tutorial_with_nothing_learned() -> void:
	var s: GameSession = autofree(new_game_session())
	assert_true(s.tutorial.is_active())
	assert_eq(s.tutorial.step_index(), 0)
	assert_eq(s.tutorial.step_count(), 21)
	assert_true(s.disciplines.learned(&"gathering").is_empty(), "no discipline at the start (step 11 is reachable)")
	assert_false(s.tutorial.starter.is_enabled(), "the starter quests wait for the end")


func test_every_step_ends_with_the_players_action_and_opens_the_next() -> void:
	var s: GameSession = autofree(new_game_session())
	_watch(s)
	var steps: Array[TutorialStepDef] = s.data.tutorial_steps()
	for i: int in steps.size():
		var def: TutorialStepDef = steps[i]
		assert_eq(s.tutorial.step_index(), i, "step %d (%s) is the current one" % [i + 1, def.id])
		assert_eq(s.tutorial.current_step().id, def.id)
		_act(s, def.id)
		if i < steps.size() - 1:
			assert_eq(s.tutorial.step_index(), i + 1, "step %d (%s) ended and the next began" % [i + 1, def.id])
			assert_eq(_changes.size(), i + 1)
			assert_eq(_changes[i], steps[i + 1].id)
	assert_true(s.tutorial.is_completed())
	assert_eq(_completed_at.size(), 1, "tutorial_completed once")
	assert_true(s.tutorial.starter.is_enabled(), "the starter quests are active at the end")
	assert_eq(s.tutorial.step_index(), s.tutorial.step_count())


func test_the_gift_of_the_mail_step_arrives_on_entering_and_pays_3000_copper() -> void:
	var s: GameSession = autofree(new_game_session())
	var steps: Array[TutorialStepDef] = s.data.tutorial_steps()
	var mail_index: int = -1
	for i: int in steps.size():
		if steps[i].id == &"mail":
			mail_index = i
	assert_gt(mail_index, 0)
	assert_eq(s.mail.count(), 0, "a new game has an empty Mail")
	for i: int in mail_index:
		_act(s, steps[i].id)
	assert_eq(s.tutorial.current_step().id, &"mail")
	assert_eq(s.mail.count(), 1, "the gift arrived on entering the step")
	var before: int = s.wallet.get_gold()
	var result: CommandResult = s.mail.collect(int(s.mail.messages()[0]["id"]))
	assert_true(result.ok)
	assert_eq(s.wallet.get_gold() - before, 3000)
	assert_eq(s.mail.collected_total(), 1)


func test_the_valve_opens_after_the_stuck_time_only_on_a_step_without_ack() -> void:
	var s: GameSession = autofree(new_game_session())
	assert_false(s.tutorial.can_skip_step(), "an Avanti step never has the valve")
	s.tutorial.acknowledge()
	s.tutorial.acknowledge()  # character -> equipment (event step)
	assert_eq(s.tutorial.current_step().id, &"equipment")
	assert_false(s.tutorial.can_skip_step(), "not stuck yet")
	assert_false(s.tutorial.skip_step().ok)
	s.play_time_ms += s.data.tutorial_stuck_ms()
	assert_true(s.tutorial.can_skip_step())
	assert_true(s.tutorial.skip_step().ok)
	assert_eq(s.tutorial.current_step().id, &"combat_start", "skip_step passes to the next step, nothing more")
	assert_false(s.combat.is_active(), "and does nothing else")
