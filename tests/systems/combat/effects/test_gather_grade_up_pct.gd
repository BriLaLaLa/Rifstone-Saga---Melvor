extends GutTest
## F-120 `gather_grade_up_pct` (legendary tool, hook `on_gather`): `roll_pct(pct)` for the product of the next resource of the
## same skill (Trout -> Perch). Nothing is rolled for the last resource of the skill.


func _ctx(seed_value: int, upgraded: ActionDef) -> GatherContext:
	var ctx := GatherContext.new()
	ctx.rng = RngService.new(seed_value)
	ctx.upgraded_action = upgraded
	return ctx


func test_pct_100_with_a_next_resource_grades_up() -> void:
	var ctx: GatherContext = _ctx(3, ActionDef.new())
	GatherGradeUpPct.new(&"t", {"pct": 100.0}).on_gather(ctx)
	assert_true(ctx.grade_up)


func test_pct_0_never_grades_up() -> void:
	var ctx: GatherContext = _ctx(3, ActionDef.new())
	for i: int in 50:
		GatherGradeUpPct.new(&"t", {"pct": 0.0}).on_gather(ctx)
	assert_false(ctx.grade_up)


func test_the_last_resource_has_no_next_and_draws_nothing() -> void:
	var ctx: GatherContext = _ctx(7, null)
	GatherGradeUpPct.new(&"t", {"pct": 100.0}).on_gather(ctx)
	assert_false(ctx.grade_up)
	assert_eq(ctx.rng.randf(), RngService.new(7).randf(), "the generator was not touched")


func test_the_next_resource_is_the_next_action_by_level() -> void:
	var data: GameData = LegendaryKit.session(1).data
	var first: ActionDef = data.action(&"angling_a")
	var second: ActionDef = GatherEffects.next_resource(first, data)
	assert_eq(second.id, &"angling_b")
	assert_null(GatherEffects.next_resource(second, data), "the last one of the skill")
