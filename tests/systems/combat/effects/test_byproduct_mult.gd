extends GutTest
## F-120 `byproduct_mult` (legendary tool, hook `on_gather`): the probability of the byproduct of the mastery milestone (F-103)
## x `mult`: 2.0% x 3 -> 6%, at most 100%.


func test_the_effect_multiplies_the_context() -> void:
	var ctx := GatherContext.new()
	ByproductMult.new(&"t", {"mult": 3.0}).on_gather(ctx)
	assert_eq(ctx.byproduct_mult, 3.0)
	ByproductMult.new(&"u", {"mult": 2.0}).on_gather(ctx)
	assert_eq(ctx.byproduct_mult, 6.0, "several multiply")


func test_two_percent_times_three_is_six() -> void:
	var data: GameData = LegendaryKit.session(1).data
	assert_eq(GatheringResolver.byproduct_chance(data), 2.0)
	assert_almost_eq(GatheringResolver.byproduct_chance(data, 3.0), 6.0, 0.0001)
	assert_eq(GatheringResolver.byproduct_chance(data, 80.0), 100.0, "at most 100%")
