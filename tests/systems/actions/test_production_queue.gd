extends GutTest
## The production queue (M24-03, docs/05_INTERFACES_M24.md §5.32): F-157 durations and estimates, the order of the refusals of
## `enqueue`, queue_full, cancel/move, the end of jobs, a project consuming at the head, recipes to discover.

const FORGING: StringName = &"forging"
const SMELT: StringName = &"smelt_emberbronze"
const PLATE: StringName = &"forge_emberbronze_plate"
const ORE: StringName = &"emberbronze_ore"
const INGOT: StringName = &"emberbronze_ingot"

var _s: GameSession = null
var _q: ActionRunner = null


func before_each() -> void:
	_s = autofree(TestFactory.session_no_kit(1, TestFactory.real_data()))
	_s.modifiers.clear_all()
	_q = _s.actions


func _ten_percent_faster() -> void:
	_s.modifiers.set_source(&"test", [Modifier.make(&"skill_interval_pct", -10.0)] as Array[Modifier])


## F-157: Lingotto 2.000 ms at -10% -> 1.800; 50 ingots 90.000; Piastra 2.400 -> 2.160, 20 -> 43.200; queue 133.200; 600 ms done -> 132.600.
func test_f157_estimates() -> void:
	_ten_percent_faster()
	TestFactory.give(_s, ORE, 200)
	TestFactory.give(_s, INGOT, 200)
	assert_eq(_q.current_interval_ms(SMELT), 1800)
	assert_eq(_q.current_interval_ms(PLATE), 2160)
	assert_true(_q.enqueue(FORGING, SMELT, 50).ok)
	assert_true(_q.enqueue(FORGING, PLATE, 20).ok)
	assert_eq(_q.estimate_ms(0), 90000)
	assert_eq(_q.estimate_ms(1), 43200)
	assert_eq(_q.estimate_ms(), 133200)
	_s.advance(600)
	assert_eq(_q.estimate_ms(), 132600)


## F-157: "until the ingredients run out" with 37 ores (2 per cycle) -> 18 cycles -> 32.400 ms.
func test_f157_estimate_of_a_repeat_job() -> void:
	_ten_percent_faster()
	TestFactory.give(_s, ORE, 37)
	assert_true(_q.enqueue(FORGING, SMELT, 1, true).ok)
	assert_eq(_q.estimate_ms(), 32400)


func test_f157_counts_limits() -> void:
	TestFactory.give(_s, ORE, 10)
	assert_eq(_q.enqueue(FORGING, SMELT, 0).reason, Reasons.INVALID_AMOUNT)
	assert_eq(_q.enqueue(FORGING, SMELT, 10000).reason, Reasons.INVALID_AMOUNT)
	assert_true(_q.enqueue(FORGING, SMELT, 9999).ok)
	assert_true(_q.enqueue(FORGING, SMELT, -5, true).ok, "the count is not checked with repeat")


func test_the_sixth_job_is_queue_full() -> void:
	TestFactory.give(_s, ORE, 100)
	for i: int in 5:
		assert_true(_q.enqueue(FORGING, SMELT, 1).ok)
	watch_signals(_s.events)
	assert_eq(_q.enqueue(FORGING, SMELT, 1).reason, Reasons.QUEUE_FULL)
	assert_eq(_q.enqueue_blueprint(&"nope").reason, Reasons.QUEUE_FULL)
	assert_eq(_q.jobs().size(), 5)
	assert_signal_not_emitted(_s.events, "production_queue_changed")


func test_enqueue_refusals_in_order() -> void:
	assert_eq(_q.enqueue(&"nope", SMELT, 1).reason, Reasons.UNKNOWN_ID)
	assert_eq(_q.enqueue(FORGING, &"nope", 1).reason, Reasons.UNKNOWN_ID)
	assert_eq(_q.enqueue(&"quarrying", SMELT, 1).reason, Reasons.UNKNOWN_ID, "action of another skill")
	assert_eq(_q.enqueue(&"forestry", &"cut_redbirch", 1).reason, Reasons.UNKNOWN_ID, "gathering is not a job")
	assert_eq(_q.enqueue(FORGING, &"blueprint_craft", 1).reason, Reasons.UNKNOWN_ID, "single-cycle action")
	_s.disciplines.new_game()
	assert_eq(_q.enqueue(FORGING, SMELT, 0).reason, Reasons.NOT_LEARNED, "before the amount")
	assert_eq(_q.enqueue_blueprint(&"nope").reason, Reasons.NOT_LEARNED)
	TestFactory.learn_discipline(_s, FORGING)
	assert_eq(_q.enqueue(FORGING, &"smelt_stormzinc", 1).reason, Reasons.LEVEL_TOO_LOW)
	assert_eq(_q.enqueue(FORGING, SMELT, 0).reason, Reasons.INVALID_AMOUNT)
	assert_eq(_q.jobs().size(), 0, "nothing changed")


func test_a_recipe_to_discover_is_refused_until_learned() -> void:
	var s: GameSession = autofree(TestFactory.session())
	TestFactory.give(s, &"test_sap", 5)
	assert_eq(s.actions.enqueue(&"test_craft_b", &"craft_secret", 1).reason, Reasons.RECIPE_UNKNOWN)
	TestFactory.give(s, &"recipe_secret", 1)
	assert_true(s.disciplines.learn_recipe(&"recipe_secret").ok)
	assert_true(s.actions.enqueue(&"test_craft_b", &"craft_secret", 1).ok)


func test_jobs_run_one_after_the_other_in_the_same_step() -> void:
	TestFactory.give(_s, ORE, 20)
	_q.enqueue(FORGING, SMELT, 1)
	_q.enqueue(FORGING, SMELT, 1)
	watch_signals(_s.events)
	_s.advance(2500)
	assert_signal_emit_count(_s.events, "action_completed", 1)
	assert_eq(_q.jobs().size(), 1)
	assert_eq(_q.current()["elapsed_ms"], 500, "the time left went to the next job")
	assert_signal_emit_count(_s.events, "action_started", 1, "the second job started")
	assert_signal_emitted_with_parameters(_s.events, "action_stopped", [&"queue", FORGING, Reasons.JOB_DONE])


func test_the_end_of_a_job_emits_stopped_then_changed_then_started() -> void:
	TestFactory.give(_s, ORE, 20)
	_q.enqueue(FORGING, SMELT, 1)
	_q.enqueue(FORGING, SMELT, 1)
	var order: Array[String] = []
	_s.events.action_stopped.connect(func(_l: StringName, _sk: StringName, _r: StringName) -> void: order.append("stopped"))
	_s.events.production_queue_changed.connect(func() -> void: order.append("changed"))
	_s.events.action_started.connect(func(_l: StringName, _sk: StringName, _a: StringName) -> void: order.append("started"))
	_s.advance(2000)
	assert_eq(order, ["stopped", "changed", "started"])


func test_missing_inputs_end_the_job_and_the_next_one_goes_on() -> void:
	TestFactory.give(_s, INGOT, 4)
	_q.enqueue(FORGING, SMELT, 3)
	_q.enqueue(FORGING, PLATE, 1)
	_s.advance(2400)
	assert_eq(_s.bank.get_count(&"emberbronze_plate"), 1)
	assert_eq(_q.stop_reasons_log(), [Reasons.MISSING_INPUTS, Reasons.JOB_DONE] as Array[StringName])


func test_cancel_the_head_starts_the_next_and_cancel_other() -> void:
	TestFactory.give(_s, ORE, 20)
	_q.enqueue(FORGING, SMELT, 1)
	_q.enqueue(FORGING, SMELT, 2)
	_q.enqueue(FORGING, SMELT, 3)
	assert_eq(_q.cancel(5).reason, Reasons.INVALID_AMOUNT)
	assert_eq(_q.cancel(-1).reason, Reasons.INVALID_AMOUNT)
	watch_signals(_s.events)
	assert_true(_q.cancel(2).ok)
	assert_eq(_q.jobs().size(), 2)
	assert_signal_not_emitted(_s.events, "action_stopped", "a job that never started does not stop")
	assert_true(_q.cancel(0).ok)
	assert_signal_emitted_with_parameters(_s.events, "action_stopped", [&"queue", FORGING, Reasons.STOPPED_BY_USER])
	assert_eq(_q.jobs()[0]["remaining"], 2)
	assert_signal_emitted(_s.events, "action_started")


func test_move() -> void:
	TestFactory.give(_s, ORE, 20)
	TestFactory.give(_s, INGOT, 20)
	_q.enqueue(FORGING, SMELT, 1)
	_q.enqueue(FORGING, SMELT, 2)
	_q.enqueue(FORGING, PLATE, 3)
	assert_eq(_q.move(0, 1).reason, Reasons.INVALID_AMOUNT, "the head does not move")
	assert_eq(_q.move(2, 0).reason, Reasons.INVALID_AMOUNT, "nothing goes to the head")
	assert_eq(_q.move(2, 3).reason, Reasons.INVALID_AMOUNT)
	watch_signals(_s.events)
	assert_true(_q.move(2, 1).ok)
	assert_eq(_q.jobs()[1]["action"], PLATE)
	assert_eq(_q.jobs()[2]["remaining"], 2)
	assert_signal_emit_count(_s.events, "production_queue_changed", 1)
	assert_true(_q.move(1, 1).ok)
	assert_signal_emit_count(_s.events, "production_queue_changed", 1, "no move, no signal")


func test_the_combat_does_not_stop_the_queue_and_the_reverse() -> void:
	TestFactory.give(_s, ORE, 20)
	_q.enqueue(FORGING, SMELT, 5)
	var area: StringName = _s.data.areas()[0].id
	assert_true(_s.combat.start(area).ok)
	assert_true(_q.is_running())
	_s.advance(2000)
	assert_eq(_s.skills.get_xp(FORGING), 8)
	assert_true(_s.combat.is_active())
	_q.cancel(0)
	assert_true(_s.combat.is_active())


func test_a_project_consumes_when_it_becomes_the_head() -> void:
	TestFactory.learn_discipline(_s, FORGING)
	var bp: ItemDef = _cheapest_blueprint()
	if bp == null:
		pending("no blueprint in the data")
		return
	for entry: ItemQty in BlueprintCraft.inputs(bp):
		TestFactory.give(_s, entry.item_id, entry.qty)
	TestFactory.give(_s, bp.id, 1)
	TestFactory.give(_s, ORE, 4)
	TestFactory.set_level(_s, FORGING, BlueprintCraft.required_level(bp, _s.data))
	_q.enqueue(FORGING, SMELT, 1)
	assert_true(_q.enqueue_blueprint(bp.id).ok)
	assert_eq(_s.bank.get_count(bp.id), 1, "nothing consumed by the enqueue: the project is not the head")
	assert_eq(_q.jobs()[1]["consumed"], false)
	_s.advance(2000)
	assert_eq(_s.bank.get_count(bp.id), 0, "consumed when it became the head")
	assert_eq(_q.jobs()[0]["consumed"], true)
	assert_gt(int(_q.jobs()[0]["duration_ms"]), 0)
	assert_true(_q.cancel(0).ok)
	assert_eq(_s.bank.get_count(bp.id), 1, "given back")


func test_a_project_whose_materials_vanished_ends_with_missing_inputs() -> void:
	TestFactory.learn_discipline(_s, FORGING)
	var bp: ItemDef = _cheapest_blueprint()
	if bp == null:
		pending("no blueprint in the data")
		return
	for entry: ItemQty in BlueprintCraft.inputs(bp):
		TestFactory.give(_s, entry.item_id, entry.qty)
	TestFactory.give(_s, bp.id, 1)
	TestFactory.give(_s, ORE, 2)
	TestFactory.set_level(_s, FORGING, BlueprintCraft.required_level(bp, _s.data))
	_q.enqueue(FORGING, SMELT, 1)
	assert_true(_q.enqueue_blueprint(bp.id).ok)
	_s.bank.remove(bp.id, 1)
	_s.advance(2000)
	assert_false(_q.is_running())
	assert_eq(_q.stop_reasons_log(), [Reasons.JOB_DONE, Reasons.MISSING_INPUTS] as Array[StringName])


func _cheapest_blueprint() -> ItemDef:
	var best: ItemDef = null
	for item: ItemDef in _s.data.items():
		if item.is_blueprint() and (best == null or BlueprintCraft.required_level(item, _s.data) < BlueprintCraft.required_level(best, _s.data)):
			best = item
	return best
