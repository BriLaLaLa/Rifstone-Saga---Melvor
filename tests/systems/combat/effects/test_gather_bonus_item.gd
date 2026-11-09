extends GutTest
## F-120 `gather_bonus_item` (legendary tool, hook `on_gather`): `roll_pct(pct)` for +1 of one of `items` (at random) besides
## the product of the cycle: 5%, 200 cycles -> about 10. The cycle itself is in tests/systems/actions/test_gather_effects.gd.


func _ctx(seed_value: int) -> GatherContext:
	var ctx := GatherContext.new()
	ctx.rng = RngService.new(seed_value)
	return ctx


func test_pct_100_gives_one_of_the_items() -> void:
	var ctx: GatherContext = _ctx(3)
	GatherBonusItem.new(&"t", {"items": ["test_resin", "test_sap"], "pct": 100.0}).on_gather(ctx)
	assert_eq(ctx.bonus_items.size(), 1)
	assert_true(ctx.bonus_items[0] in [&"test_resin", &"test_sap"])


func test_pct_0_gives_nothing_and_the_draws_are_the_probability_then_the_item() -> void:
	var none: GatherContext = _ctx(3)
	GatherBonusItem.new(&"t", {"items": ["test_resin"], "pct": 0.0}).on_gather(none)
	assert_true(none.bonus_items.is_empty())
	var ctx: GatherContext = _ctx(11)
	var replica := RngService.new(11)
	var rolled: bool = replica.roll_pct(60.0)
	var pick: int = replica.randi_range(0, 1) if rolled else -1
	GatherBonusItem.new(&"t", {"items": ["test_resin", "test_sap"], "pct": 60.0}).on_gather(ctx)
	assert_eq(ctx.bonus_items.size(), 1 if rolled else 0)
	if rolled:
		assert_eq(ctx.bonus_items[0], [&"test_resin", &"test_sap"][pick])


func test_five_percent_in_200_cycles_is_about_ten() -> void:
	var ctx: GatherContext = _ctx(2024)
	var effect := GatherBonusItem.new(&"t", {"items": ["test_resin"], "pct": 5.0})
	for i: int in 200:
		effect.on_gather(ctx)
	assert_between(ctx.bonus_items.size(), 2, 20, "5% of 200 = 10")
