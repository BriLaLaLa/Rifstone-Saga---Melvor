extends GutTest
## F-167 (color and chance) and F-168 (split of the xp) on the examples of docs/02_FORMULAS_M26.md; thresholds of forge_ashlead_plate 20/30/40.

const PPM: int = 1000000
const ASHLEAD: Dictionary = {&"yellow": 20, &"green": 30, &"grey": 40}


func test_chance_examples_of_forge_ashlead_plate() -> void:
	var cases: Array = [[15, &"orange", 1000000], [20, &"yellow", 1000000], [25, &"yellow", 750000], [29, &"yellow", 550000],
			[30, &"green", 500000], [35, &"green", 250000], [39, &"green", 50000], [40, &"grey", 0], [99, &"grey", 0]]
	for c: Array in cases:
		assert_eq(ProfessionMath.color_id(ASHLEAD, c[0]), c[1], "color at %d" % c[0])
		assert_eq(ProfessionMath.chance_ppm(ASHLEAD, c[0]), c[2], "chance at %d" % c[0])


func test_duskcobalt_gap_and_riftite_orange() -> void:
	var dusk: Dictionary = {&"yellow": 40, &"green": 50, &"grey": 60}
	assert_eq(ProfessionMath.color_id(dusk, 44), &"yellow")
	assert_eq(ProfessionMath.chance_ppm(dusk, 44), 800000)
	var riftite: Dictionary = {&"yellow": 100, &"green": 110, &"grey": 120}
	assert_eq(ProfessionMath.color_id(riftite, 99), &"orange")
	assert_eq(ProfessionMath.chance_ppm(riftite, 99), PPM)


func test_no_colors_is_the_xp_of_today() -> void:
	assert_eq(ProfessionMath.color_id({}, 50), &"")
	assert_eq(ProfessionMath.chance_ppm({}, 50), PPM)


func test_split_xp_examples() -> void:
	assert_eq(ProfessionMath.split_xp(33, 750000, 0), Vector2i(24, 750000))
	assert_eq(ProfessionMath.split_xp(33, 750000, 750000), Vector2i(25, 500000))
	assert_eq(ProfessionMath.split_xp(8, 250000, 0), Vector2i(2, 0))
	assert_eq(ProfessionMath.split_xp(33, 0, 123), Vector2i(0, 123))
	assert_eq(ProfessionMath.split_xp(33, PPM, 0), Vector2i(33, 0))


func test_invalid_input_is_an_error_and_zero() -> void:
	assert_eq(ProfessionMath.split_xp(-1, 1, 0), Vector2i.ZERO)
	assert_eq(ProfessionMath.split_xp(1, 1, -1), Vector2i.ZERO)
	assert_eq(ProfessionMath.split_xp(1, 1, PPM), Vector2i.ZERO)
	assert_push_error(3)
