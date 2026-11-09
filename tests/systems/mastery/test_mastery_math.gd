extends GutTest
## MasteryMath: F-10 mastery per cycle, F-12 pool share, F-13 pool cap, F-15 node cost.
## The F-10 parameters come from the real balance.json (shared by the fixtures).

const ARTISAN_SKILL: StringName = &"forging"
const GATHERING_SKILL: StringName = &"forestry"

var _data: GameData


func before_all() -> void:
	_data = TestFactory.fixture_data()


## F-10 examples: t 3, L 1, R 1/792 -> 3; t 3, L 50, R 0.25 -> 20; t 3, L 99, R 1.0 -> 41;
## t 2.5, L 10, R 0.05, pct 5 -> 5.
func test_f10_examples() -> void:
	assert_eq(MasteryMath.mastery_xp(3000, 1, 1.0 / 792.0, 0.0, _data), 3)
	assert_eq(MasteryMath.mastery_xp(3000, 50, 0.25, 0.0, _data), 20)
	assert_eq(MasteryMath.mastery_xp(3000, 99, 1.0, 0.0, _data), 41)
	assert_eq(MasteryMath.mastery_xp(2500, 10, 0.05, 5.0, _data), 5)


## Stat effect of mastery_xp_pct (02_FORMULAS.md §11): t 3, L 50, R 0.25 gives 20 at 0%, 30 at +50%, 40 at +100%.
func test_mastery_xp_pct() -> void:
	assert_eq(MasteryMath.mastery_xp(3000, 50, 0.25, 0.0, _data), 20)
	assert_eq(MasteryMath.mastery_xp(3000, 50, 0.25, 50.0, _data), 30)
	assert_eq(MasteryMath.mastery_xp(3000, 50, 0.25, 100.0, _data), 40)


func test_mastery_xp_is_at_least_one() -> void:
	assert_eq(MasteryMath.mastery_xp(250, 1, 0.0, 0.0, _data), 1)


## F-12 examples: mxp 3 -> 1; mxp 20 -> 4; mxp 41 -> 8; mxp 2 -> 0.
func test_f12_examples() -> void:
	var share: float = float(_data.balance_value("mastery.pool_share_pct"))
	assert_eq(MasteryMath.pool_gain(3, share), 1)
	assert_eq(MasteryMath.pool_gain(20, share), 4)
	assert_eq(MasteryMath.pool_gain(41, share), 8)
	assert_eq(MasteryMath.pool_gain(2, share), 0)


## F-13 example: 8 actions -> 2,400,000.
func test_f13_example() -> void:
	var per_item: int = int(_data.balance_value("mastery.pool_cap_per_item"))
	assert_eq(MasteryMath.pool_cap(8, per_item), 2400000)
	assert_eq(MasteryMath.pool_cap(0, per_item), 0)


## F-15 examples: cap 2,400,000 at 10% -> 240,000; at 7.5% -> 180,000.
func test_f15_examples() -> void:
	assert_eq(MasteryMath.node_cost(2400000, 10.0), 240000)
	assert_eq(MasteryMath.node_cost(2400000, 7.5), 180000)
	assert_eq(MasteryMath.node_cost(10, 5.0), 1)
