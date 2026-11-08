extends GutTest
## ModifierService: F-05 totals, replacing sources, unknown stats, breakdown, batches and modifiers_changed.

var _events: GameEvents
var _service: ModifierService


func before_each() -> void:
	_events = autofree(GameEvents.new())
	var errors: PackedStringArray = []
	var stats: StatRegistry = StatRegistry.from_array([
		_stat("skill_interval_pct", -80, 100),
		_stat("skill_xp_pct", 0, 1000),
		_stat("test_flat_stat", 0, 10000),
	], errors)
	assert_eq(errors.size(), 0, str(errors))
	_service = ModifierService.new(stats, _events)
	watch_signals(_events)


## F-05 example of docs/02_FORMULAS.md.
func test_f05_example() -> void:
	_service.set_source(&"a", [Modifier.make(&"skill_interval_pct", -3.0)] as Array[Modifier])
	_service.set_source(&"b", [Modifier.make(&"skill_interval_pct", -5.0, &"skill", &"forestry")] as Array[Modifier])
	_service.set_source(&"c", [
		Modifier.make(&"skill_interval_pct", -2.0, &"action", &"cut_ashoak"),
		Modifier.make(&"skill_interval_pct", -10.0, &"skill", &"quarrying"),
	] as Array[Modifier])
	assert_eq(_service.total(&"skill_interval_pct", ModifierContext.for_action(&"forestry", &"cut_ashoak")), -10.0)
	assert_eq(_service.total(&"skill_interval_pct", ModifierContext.for_action(&"forestry", &"cut_redbirch")), -8.0)


func test_f05_sum_is_limited_to_min() -> void:
	_service.set_source(&"a", [Modifier.make(&"skill_interval_pct", -95.0)] as Array[Modifier])
	assert_eq(_service.total(&"skill_interval_pct"), -80.0)


func test_total_is_limited_to_max() -> void:
	_service.set_source(&"a", [Modifier.make(&"skill_interval_pct", 150.0)] as Array[Modifier])
	assert_eq(_service.total(&"skill_interval_pct"), 100.0)


func test_null_context_is_global() -> void:
	_service.set_source(&"a", [
		Modifier.make(&"skill_xp_pct", 3.0),
		Modifier.make(&"skill_xp_pct", 5.0, &"skill", &"forestry"),
	] as Array[Modifier])
	assert_eq(_service.total(&"skill_xp_pct"), 3.0)
	assert_eq(_service.total(&"skill_xp_pct", ModifierContext.global_ctx()), 3.0)
	assert_eq(_service.total(&"skill_xp_pct", ModifierContext.for_skill(&"forestry")), 8.0)


func test_total_without_excludes_sources_and_limits() -> void:
	var no_source: Array[StringName] = []
	var offhand: Array[StringName] = [&"equipment:offhand"]
	var weapon: Array[StringName] = [&"equipment:weapon"]
	_service.set_source(&"equipment:weapon", [Modifier.make(&"skill_xp_pct", 600.0)] as Array[Modifier])
	_service.set_source(&"equipment:offhand", [Modifier.make(&"skill_xp_pct", 300.0)] as Array[Modifier])
	_service.set_source(&"ring", [Modifier.make(&"skill_xp_pct", 5.0, &"skill", &"forestry")] as Array[Modifier])
	assert_eq(_service.total(&"skill_xp_pct"), 900.0)
	assert_eq(_service.total_without(&"skill_xp_pct", null, offhand), 600.0)
	assert_eq(_service.total_without(&"skill_xp_pct", ModifierContext.for_skill(&"forestry"), weapon), 305.0)
	_service.set_source(&"extra", [Modifier.make(&"skill_xp_pct", 700.0)] as Array[Modifier])
	assert_eq(_service.total_without(&"skill_xp_pct", null, offhand), 1000.0, "limited to the stat maximum")
	assert_eq(_service.total_without(&"skill_xp_pct", null, no_source), _service.total(&"skill_xp_pct"))


func test_total_without_modifiers_is_zero() -> void:
	assert_eq(_service.total(&"test_flat_stat"), 0.0)


func test_set_source_replaces() -> void:
	var mods: Array[Modifier] = [Modifier.make(&"test_flat_stat", 10.0)]
	_service.set_source(&"shop:extra_slots", mods)
	_service.set_source(&"shop:extra_slots", mods)
	assert_eq(_service.total(&"test_flat_stat"), 10.0)
	_service.set_source(&"shop:extra_slots", [Modifier.make(&"test_flat_stat", 20.0)] as Array[Modifier])
	assert_eq(_service.total(&"test_flat_stat"), 20.0)


func test_unknown_stat_is_error_and_ignored() -> void:
	_service.set_source(&"a", [
		Modifier.make(&"no_such_stat", 5.0),
		Modifier.make(&"test_flat_stat", 4.0),
	] as Array[Modifier])
	assert_push_error(1)
	assert_eq(_service.total(&"test_flat_stat"), 4.0)
	assert_eq(_service.breakdown(&"test_flat_stat").size(), 1)


func test_total_of_unknown_stat_is_error_and_zero() -> void:
	assert_eq(_service.total(&"no_such_stat"), 0.0)
	assert_push_error(1)


func test_clear_source_removes_contribution() -> void:
	_service.set_source(&"a", [Modifier.make(&"test_flat_stat", 4.0)] as Array[Modifier])
	_service.set_source(&"b", [Modifier.make(&"test_flat_stat", 6.0)] as Array[Modifier])
	assert_eq(_service.total(&"test_flat_stat"), 10.0, "cached before the change")
	_service.clear_source(&"a")
	assert_false(_service.has_source(&"a"))
	assert_true(_service.has_source(&"b"))
	assert_eq(_service.total(&"test_flat_stat"), 6.0)


func test_clear_all_removes_everything() -> void:
	_service.set_source(&"a", [Modifier.make(&"test_flat_stat", 4.0)] as Array[Modifier])
	_service.set_source(&"b", [Modifier.make(&"skill_xp_pct", 6.0)] as Array[Modifier])
	_service.clear_all()
	assert_false(_service.has_source(&"a"))
	assert_false(_service.has_source(&"b"))
	assert_eq(_service.total(&"test_flat_stat"), 0.0)
	assert_eq(_service.total(&"skill_xp_pct"), 0.0)


func test_breakdown_lists_applicable_sources_unclamped() -> void:
	_service.set_source(&"equipment:weapon", [
		Modifier.make(&"skill_interval_pct", -50.0),
		Modifier.make(&"skill_interval_pct", -10.0, &"skill", &"forestry"),
	] as Array[Modifier])
	_service.set_source(&"mastery_node:n1", [Modifier.make(&"skill_interval_pct", -40.0)] as Array[Modifier])
	var other: Array[Modifier] = [Modifier.make(&"skill_interval_pct", -5.0, &"skill", &"quarrying")]
	_service.set_source(&"shop:other", other)
	_service.set_source(&"shop:xp", [Modifier.make(&"skill_xp_pct", 5.0)] as Array[Modifier])
	var rows: Array[Dictionary] = _service.breakdown(&"skill_interval_pct", ModifierContext.for_skill(&"forestry"))
	assert_eq(rows, [
		{"source": &"equipment:weapon", "value": -60.0},
		{"source": &"mastery_node:n1", "value": -40.0},
	] as Array[Dictionary])
	assert_eq(_service.total(&"skill_interval_pct", ModifierContext.for_skill(&"forestry")), -80.0)


func test_each_change_emits_modifiers_changed() -> void:
	_service.set_source(&"a", [Modifier.make(&"test_flat_stat", 4.0)] as Array[Modifier])
	_service.clear_source(&"a")
	assert_signal_emit_count(_events, "modifiers_changed", 2)


func test_noop_clears_do_not_emit() -> void:
	_service.clear_source(&"missing")
	_service.clear_all()
	assert_signal_emit_count(_events, "modifiers_changed", 0)


func test_batch_emits_once() -> void:
	_service.begin_batch()
	_service.clear_all()
	_service.set_source(&"a", [Modifier.make(&"test_flat_stat", 4.0)] as Array[Modifier])
	_service.set_source(&"b", [Modifier.make(&"test_flat_stat", 6.0)] as Array[Modifier])
	assert_signal_emit_count(_events, "modifiers_changed", 0, "suspended inside the batch")
	assert_eq(_service.total(&"test_flat_stat"), 10.0, "totals are current inside the batch")
	_service.end_batch()
	assert_signal_emit_count(_events, "modifiers_changed", 1)


func test_nested_batches_emit_once_at_the_outermost_end() -> void:
	_service.begin_batch()
	_service.begin_batch()
	_service.set_source(&"a", [Modifier.make(&"test_flat_stat", 4.0)] as Array[Modifier])
	_service.end_batch()
	assert_signal_emit_count(_events, "modifiers_changed", 0)
	_service.end_batch()
	assert_signal_emit_count(_events, "modifiers_changed", 1)


func test_empty_batch_does_not_emit() -> void:
	_service.begin_batch()
	_service.end_batch()
	assert_signal_emit_count(_events, "modifiers_changed", 0)


func test_end_batch_without_begin_is_error() -> void:
	_service.end_batch()
	assert_push_error(1)
	assert_signal_emit_count(_events, "modifiers_changed", 0)


func _stat(id: String, low: float, high: float) -> Dictionary:
	return {
		"id": id, "name": "Nome %s" % id, "format": "pct", "min": low, "max": high,
		"description": "Effetto.", "formula": "F-05", "test": "tests/x.gd::test_y",
	}
