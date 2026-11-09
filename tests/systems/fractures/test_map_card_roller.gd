extends GutTest
## MapCardRoller (F-109): rarity chances and boundaries, number and choice of modifiers, intensity and values, order of the
## draws on the rng with a fixed seed, `extend_mods` (no duplicates), `effects`. Fixture: the 12 modifiers of F-111.

const SEED: int = 4242

var _data: GameData = null


## A rng whose `randf` returns a fixed value (for the boundaries of F-109).
class FixedRng:
	extends RngService
	var value: float = 0.0

	func _init(fixed: float) -> void:
		super(1)
		value = fixed

	func randf() -> float:
		return value


func before_all() -> void:
	_data = TestFactory.fixture_data()


func _mod_ids(card: MapCard) -> Array[StringName]:
	var ids: Array[StringName] = []
	for roll: MapModRoll in card.mods:
		ids.append(roll.mod_id)
	return ids


func _risk_types(card: MapCard) -> Array[StringName]:
	var types: Array[StringName] = []
	for roll: MapModRoll in card.mods:
		types.append(_data.map_mod(roll.mod_id).risk.type)
	return types


# --- F-109: rarity ---------------------------------------------------------------------------------------------------

func test_rarity_chances_example_plus_50() -> void:
	assert_eq(MapCardRoller.rarity_chances(50.0, _data), Vector2(37.5, 9.0), "F-109 example: +50% -> 37,5 and 9")
	assert_eq(MapCardRoller.rarity_chances(0.0, _data), Vector2(25.0, 6.0))


func test_rarity_boundaries_with_one_randf() -> void:
	# base: rare 6, magic 25 -> r < 6 rare, r < 31 magic, else common (r is randf * 100).
	assert_eq(MapCardRoller.roll_rarity(0.0, _data, FixedRng.new(0.059)), &"rare")
	assert_eq(MapCardRoller.roll_rarity(0.0, _data, FixedRng.new(0.061)), &"magic")
	assert_eq(MapCardRoller.roll_rarity(0.0, _data, FixedRng.new(0.309)), &"magic")
	assert_eq(MapCardRoller.roll_rarity(0.0, _data, FixedRng.new(0.311)), &"common")


func test_rarity_uses_exactly_one_draw() -> void:
	var rng := RngService.new(SEED)
	var reference := RngService.new(SEED)
	MapCardRoller.roll_rarity(0.0, _data, rng)
	reference.randf()
	assert_eq(rng.randf(), reference.randf(), "one randf consumed")


func test_rarity_distribution_follows_f109() -> void:
	var rng := RngService.new(SEED)
	var counts: Dictionary = {&"common": 0, &"magic": 0, &"rare": 0}
	for i: int in 4000:
		counts[MapCardRoller.roll_rarity(0.0, _data, rng)] += 1
	assert_between(counts[&"rare"] / 4000.0, 0.04, 0.08, "6% rare")
	assert_between(counts[&"magic"] / 4000.0, 0.22, 0.28, "25% magic")


# --- F-109: modifiers ------------------------------------------------------------------------------------------------

func test_common_card_has_no_modifiers() -> void:
	var card: MapCard = MapCardRoller.create(3, &"common", _data, RngService.new(SEED))
	assert_eq(card.grade, 3)
	assert_eq(card.base_id, &"fracture_card_3")
	assert_eq(card.rarity, &"common")
	assert_eq(card.uid, 0)
	assert_eq(card.mods.size(), 0)


func test_mod_counts_by_rarity() -> void:
	for seed_value: int in 40:
		var magic: MapCard = MapCardRoller.create(5, &"magic", _data, RngService.new(seed_value))
		assert_between(magic.mods.size(), 1, 2, "magic 1-2")
		var rare: MapCard = MapCardRoller.create(5, &"rare", _data, RngService.new(seed_value))
		assert_between(rare.mods.size(), 3, 4, "rare 3-4")


func test_order_of_the_draws_is_count_then_choice_and_step() -> void:
	var rng := RngService.new(SEED)
	var card: MapCard = MapCardRoller.create(1, &"magic", _data, rng)
	# The same draws by hand: the number, then per modifier the weighted choice among the grade 1 candidates and the step.
	var ref := RngService.new(SEED)
	var count: int = ref.randi_range(1, 2)
	var picked: Array[StringName] = []
	var steps: Array[int] = []
	var risks: Array[StringName] = []
	for i: int in count:
		var candidates: Array[MapModDef] = []
		var weights: Array[int] = []
		for def: MapModDef in _data.map_mods():
			if def.min_grade <= 1 and not picked.has(def.id) and not risks.has(def.risk.type):
				candidates.append(def)
				weights.append(def.weight)
		var def: MapModDef = candidates[ref.pick_weighted(weights)]
		picked.append(def.id)
		risks.append(def.risk.type)
		steps.append(ref.randi_range(0, 10))
	assert_eq(_mod_ids(card), picked)
	for i: int in count:
		assert_eq(card.mods[i].step, steps[i])
	assert_eq(rng.randf(), ref.randf(), "no other draw consumed")


func test_grade_1_candidates_have_min_grade_1() -> void:
	for seed_value: int in 30:
		for roll: MapModRoll in MapCardRoller.create(1, &"rare", _data, RngService.new(seed_value)).mods:
			assert_eq(_data.map_mod(roll.mod_id).min_grade, 1, "only min_grade 1 at grade 1")


func test_rare_grade_5_has_four_distinct_risk_types() -> void:
	for seed_value: int in 30:
		var card: MapCard = MapCardRoller.create(5, &"rare", _data, RngService.new(seed_value))
		var types: Array[StringName] = _risk_types(card)
		for t: StringName in types:
			assert_eq(types.count(t), 1, "risk types are unique on a Card")
		var ids: Array[StringName] = _mod_ids(card)
		for id: StringName in ids:
			assert_eq(ids.count(id), 1, "modifier ids are unique on a Card")


func test_steps_stay_in_range() -> void:
	for seed_value: int in 30:
		for roll: MapModRoll in MapCardRoller.create(8, &"rare", _data, RngService.new(seed_value)).mods:
			assert_between(roll.step, 0, 10)


func test_create_rejects_a_grade_without_base() -> void:
	assert_null(MapCardRoller.create(0, &"common", _data, RngService.new(SEED)))
	assert_null(MapCardRoller.create(11, &"common", _data, RngService.new(SEED)))
	assert_push_error(2)


# --- F-109: values -----------------------------------------------------------------------------------------------------

func test_value_example_sturdy() -> void:
	var card := MapCard.new()
	card.grade = 1
	card.mods = [MapModRoll.make(&"sturdy", 5)] as Array[MapModRoll]
	var effect: Dictionary = MapCardRoller.effects(card, _data)[0]
	assert_eq(effect["risk_type"], &"monster_hp_pct")
	assert_eq(effect["risk"], 40.0, "step 5: +40% PV")
	assert_eq(effect["reward_type"], &"loot_qty_pct")
	assert_eq(effect["reward"], 10.0, "step 5: +10% quantity")
	card.mods[0].step = 0
	assert_eq(MapCardRoller.effects(card, _data)[0]["risk"], 20.0)
	assert_eq(MapCardRoller.effects(card, _data)[0]["reward"], 5.0)
	card.mods[0].step = 10
	assert_eq(MapCardRoller.effects(card, _data)[0]["risk"], 60.0)
	assert_eq(MapCardRoller.effects(card, _data)[0]["reward"], 15.0)


# --- extend_mods --------------------------------------------------------------------------------------------------------

func test_extend_keeps_the_old_modifiers_and_adds_without_duplicates() -> void:
	for seed_value: int in 30:
		var card: MapCard = MapCardRoller.create(6, &"magic", _data, RngService.new(seed_value))
		var before: Array[StringName] = _mod_ids(card)
		var extended: Array[MapModRoll] = MapCardRoller.extend_mods(card, &"rare", _data, RngService.new(seed_value + 100))
		assert_gte(extended.size(), before.size())
		assert_between(extended.size(), 3, 4, "the draw is the total of the rarity")
		for i: int in before.size():
			assert_eq(extended[i].mod_id, before[i], "old modifiers first and unchanged")
		var ids: Array[StringName] = []
		for roll: MapModRoll in extended:
			assert_false(ids.has(roll.mod_id), "no duplicate id")
			ids.append(roll.mod_id)
		assert_eq(card.mods.size(), before.size(), "the card itself is not changed")


func test_effects_skip_nothing_and_follow_the_card() -> void:
	var card: MapCard = MapCardRoller.create(6, &"rare", _data, RngService.new(SEED))
	assert_eq(MapCardRoller.effects(card, _data).size(), card.mods.size())
