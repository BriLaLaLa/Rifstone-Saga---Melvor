extends GutTest
## F-123 (M14, Q72): the cap of the risk points of a Card, `cap(g) = 40 + 10 x (g - 1)`, with the real modifiers of
## F-111. Examples of 02_FORMULAS.md F-123.

var _data: GameData = null


func before_all() -> void:
	_data = TestFactory.real_data()


func _mod(id: StringName) -> MapModDef:
	return _data.map_mod(id)


func test_cap_by_grade() -> void:
	assert_eq(MapCardRoller.risk_cap(1, _data), 40.0)
	assert_eq(MapCardRoller.risk_cap(5, _data), 80.0)
	assert_eq(MapCardRoller.risk_cap(10, _data), 130.0)


func test_risk_points_use_the_unit_of_the_risk_type() -> void:
	assert_eq(MapCardRoller.risk_points(_mod(&"brutal"), 10, _data), 45.0, "unit 1")
	assert_eq(MapCardRoller.risk_points(_mod(&"hordes"), 10, _data), 40.0, "pack_bonus 2 x 20")
	assert_eq(MapCardRoller.risk_points(_mod(&"pulses"), 10, _data), 25.0, "pulse 5 x 5")
	assert_eq(MapCardRoller.risk_points(_mod(&"hordes"), 0, _data), 20.0)


func test_example_brutal_step_10_is_reduced_to_step_8_with_39_points() -> void:
	var step: int = MapCardRoller.fitting_step(_mod(&"brutal"), 10, 40.0, _data)
	assert_eq(step, 8)
	assert_eq(MapCardRoller.risk_points(_mod(&"brutal"), step, _data), 39.0, "15 + round(30 x 8/10)")


func test_example_sturdy_and_assault_make_24_plus_15() -> void:
	assert_eq(MapCardRoller.risk_points(_mod(&"sturdy"), 1, _data), 24.0)
	var room: float = 40.0 - 24.0
	var step: int = MapCardRoller.fitting_step(_mod(&"assault"), 2, room, _data)
	assert_eq(step, 2)
	assert_eq(MapCardRoller.risk_points(_mod(&"assault"), step, _data), 15.0, "10 + round(25 x 0.2)")


func test_a_candidate_that_does_not_fit_even_at_step_0_is_refused() -> void:
	assert_eq(MapCardRoller.fitting_step(_mod(&"sturdy"), 5, 1.0, _data), -1)


func test_a_grade_1_rare_card_never_goes_over_40_points() -> void:
	for seed_value: int in 1000:
		var card: MapCard = MapCardRoller.create(1, &"rare", _data, RngService.new(seed_value))
		assert_lte(MapCardRoller.total_risk_points(card.mods, _data), 40.0 + 1e-9, "seed %d" % seed_value)
		assert_gte(card.mods.size(), 1)


func test_every_grade_stays_within_its_cap() -> void:
	for grade: int in range(1, 11):
		for seed_value: int in 40:
			var card: MapCard = MapCardRoller.create(grade, &"rare", _data, RngService.new(seed_value))
			assert_lte(MapCardRoller.total_risk_points(card.mods, _data), MapCardRoller.risk_cap(grade, _data) + 1e-9)


func test_the_draw_order_is_unchanged_when_nothing_is_reduced() -> void:
	# A magic Card of grade 10 (cap 130) never reaches the cap with 1-2 modifiers: choice and step draws only, as in F-109.
	var rng := RngService.new(77)
	var card: MapCard = MapCardRoller.create(10, &"magic", _data, rng)
	var ref := RngService.new(77)
	var count: int = ref.randi_range(1, 2)
	for i: int in count:
		var candidates: Array[MapModDef] = []
		var weights: Array[int] = []
		for def: MapModDef in _data.map_mods():
			var used_risk: bool = false
			for j: int in i:
				used_risk = used_risk or _mod(card.mods[j].mod_id).risk.type == def.risk.type
			if def.min_grade <= 10 and not used_risk:
				candidates.append(def)
				weights.append(def.weight)
		var picked: MapModDef = candidates[ref.pick_weighted(weights)]
		assert_eq(card.mods[i].mod_id, picked.id)
		assert_eq(card.mods[i].step, ref.randi_range(0, 10))
	assert_eq(rng.randf(), ref.randf(), "no other draw consumed")


func test_the_reward_follows_the_reduced_step() -> void:
	var rolled := MapModRoll.make(&"brutal", MapCardRoller.fitting_step(_mod(&"brutal"), 10, 40.0, _data))
	var card := MapCard.new()
	card.base_id = &"fracture_card_1"
	card.grade = 1
	card.rarity = &"magic"
	card.mods = [rolled] as Array[MapModRoll]
	var effects: Array[Dictionary] = MapCardRoller.effects(card, _data)
	assert_eq(effects[0]["risk"], 39.0)
	assert_eq(effects[0]["reward"], _mod(&"brutal").reward.value_at(8, 10), "the reward is at the reduced step 8")
