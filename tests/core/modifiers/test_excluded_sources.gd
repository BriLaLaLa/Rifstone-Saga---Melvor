extends GutTest
## M12: ModifierContext.excluded_sources and for_helper (F-101): `total` and `breakdown` ignore the excluded sources,
## the cache keeps the contexts apart, and the default context excludes nothing.

const STAT: StringName = &"skill_interval_pct"
const TOOL: StringName = &"equipment:tool_forestry"

var _service: ModifierService


func before_each() -> void:
	var events: GameEvents = autofree(GameEvents.new())
	var errors: PackedStringArray = []
	var stats: StatRegistry = StatRegistry.from_array([
		{"id": "skill_interval_pct", "name": "Velocità", "format": "pct", "min": -80, "max": 100,
			"description": "d", "formula": "F-03", "test": "a.gd::t"},
	], errors)
	_service = ModifierService.new(stats, events)
	_service.set_source(TOOL, [Modifier.make(STAT, -23.0)] as Array[Modifier])
	_service.set_source(&"mastery_node:n1", [Modifier.make(STAT, -3.0)] as Array[Modifier])


func test_for_helper_excludes_only_the_skill_tool() -> void:
	var ctx: ModifierContext = ModifierContext.for_helper(&"forestry", &"cut_redbirch")
	assert_eq(ctx.skill_id, &"forestry")
	assert_eq(ctx.action_id, &"cut_redbirch")
	assert_eq(ctx.excluded_sources, [TOOL] as Array[StringName])
	assert_eq(ModifierContext.for_action(&"forestry", &"cut_redbirch").excluded_sources.size(), 0)


func test_total_respects_excluded_sources() -> void:
	assert_eq(_service.total(STAT, ModifierContext.for_action(&"forestry", &"cut_redbirch")), -26.0)
	assert_eq(_service.total(STAT, ModifierContext.for_helper(&"forestry", &"cut_redbirch")), -3.0)


func test_cache_does_not_mix_the_two_contexts() -> void:
	var helper: ModifierContext = ModifierContext.for_helper(&"forestry", &"cut_redbirch")
	var player: ModifierContext = ModifierContext.for_action(&"forestry", &"cut_redbirch")
	assert_eq(_service.total(STAT, helper), -3.0)
	assert_eq(_service.total(STAT, player), -26.0)
	assert_eq(_service.total(STAT, helper), -3.0)


func test_the_tool_of_another_skill_is_not_excluded() -> void:
	assert_eq(_service.total(STAT, ModifierContext.for_helper(&"quarrying", &"mine_x")), -26.0)


func test_breakdown_leaves_out_excluded_sources() -> void:
	var rows: Array[Dictionary] = _service.breakdown(STAT, ModifierContext.for_helper(&"forestry", &"cut_redbirch"))
	assert_eq(rows.size(), 1)
	assert_eq(rows[0]["source"], &"mastery_node:n1")


func test_excluded_source_not_registered_is_harmless() -> void:
	_service.clear_source(TOOL)
	assert_eq(_service.total(STAT, ModifierContext.for_helper(&"forestry", &"cut_redbirch")), -3.0)
