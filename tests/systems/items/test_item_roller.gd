extends GutTest
## ItemRoller: F-84 chances and rarity roll, F-85 affix rolls, F-91/F-92 blueprint pieces, create, instance modifiers.
## Fixture affixes: test_keen (weapon/offhand), test_mighty (weapon/head/body, tier 2 step 2 from ilvl 30),
## test_nimble (armour), test_woodsman (tool_forestry).

var _data: GameData = TestFactory.fixture_data()
var _blade: ItemDef = _data.item(&"test_blade")


# A generator that returns a fixed float, to hit the thresholds of the F-83 example.
class _FixedRng extends RngService:
	var value: float = 0.0

	func _init(v: float) -> void:
		super(1)
		value = v

	func randf() -> float:
		return value


const BlueprintData := preload("res://tests/systems/actions/blueprint_data.gd")


func test_roll_rarity() -> void:
	var chances := Vector2(36.0, 7.2)
	assert_eq(ItemRoller.roll_rarity(chances, _FixedRng.new(0.05)), &"rare")
	assert_eq(ItemRoller.roll_rarity(chances, _FixedRng.new(0.20)), &"magic")
	assert_eq(ItemRoller.roll_rarity(chances, _FixedRng.new(0.50)), &"common")


## F-91 (M14): p_two = min(100, (10 + 0.5 L) x k), k = 1 + item_rarity_pct / 100; the piece is always a Masterwork.
func test_masterwork_affix_count() -> void:
	assert_almost_eq(ItemRoller.blueprint_two_affix_chance(1, 0.0, _data), 10.5, 0.0001)
	assert_almost_eq(ItemRoller.blueprint_two_affix_chance(50, 0.0, _data), 35.0, 0.0001)
	assert_almost_eq(ItemRoller.blueprint_two_affix_chance(50, 20.0, _data), 42.0, 0.0001)
	assert_almost_eq(ItemRoller.blueprint_two_affix_chance(99, 0.0, _data), 59.5, 0.0001)
	assert_almost_eq(ItemRoller.blueprint_two_affix_chance(99, 100.0, _data), 100.0, 0.0001)
	assert_almost_eq(ItemRoller.blueprint_rare_chance(50, 0.0, _data), 35.0, 0.0001, "the name of M10 still answers")
	# p_two 35: r 20 -> 2 affixes, r 50 -> 1 affix, r 99.9 -> 1 affix; the rarity is always masterwork
	var bp: ItemDef = _blueprint(1)
	var bp_data: GameData = BlueprintData.data()
	var two: ItemInstance = ItemRoller.create_from_blueprint(bp, 50, 0.0, &"", bp_data, _FixedRng.new(0.20))
	assert_eq(two.rarity, &"masterwork")
	assert_eq(two.affixes.size(), 2)
	var one: ItemInstance = ItemRoller.create_from_blueprint(bp, 50, 0.0, &"", bp_data, _FixedRng.new(0.50))
	assert_eq(one.rarity, &"masterwork")
	assert_eq(one.affixes.size(), 1)
	assert_eq(ItemRoller.create_from_blueprint(bp, 50, 0.0, &"", bp_data, _FixedRng.new(0.999)).affixes.size(), 1)
	var inst: ItemInstance = ItemRoller.create_from_blueprint(bp, 50, 0.0, &"", bp_data, RngService.new(5))
	assert_eq(inst.uid, 0)
	assert_eq(inst.base_id, &"test_blade")
	assert_eq(inst.ilvl, 1)
	assert_between(inst.affixes.size(), 1, 2)


## F-92: the chosen affix comes first at a fixed grade min(2, unlocked), counts in the affix number.
func test_chosen_affix() -> void:
	var bp_data: GameData = BlueprintData.data()
	var base: ItemDef = bp_data.item(&"test_blade")
	# ilvl 20: keen has tiers from ilvl 1, 20, 45 -> 2 unlocked; mighty (1, 30) -> 1
	var ids: Array[StringName] = []
	for def: AffixDef in ItemRoller.chosen_affix_candidates(base, 20, bp_data):
		ids.append(def.id)
	assert_eq(ids, [&"test_keen", &"test_mighty"] as Array[StringName])
	assert_eq(ItemRoller.chosen_affix_candidates(bp_data.item(&"test_helm"), 1, bp_data).size(), 2)
	var grade5: ItemDef = _blueprint(3, &"test_blade_5")  # piece grade 5 = level 20 = ilvl 20 (the material grade is 3)
	for seed_value: int in 30:
		var inst: ItemInstance = ItemRoller.create_from_blueprint(grade5, 60, 0.0, &"test_keen", bp_data,
				RngService.new(seed_value))
		assert_eq(inst.ilvl, 20)
		assert_eq(inst.affixes[0].affix_id, &"test_keen")
		assert_eq(inst.affixes[0].tier, 2)
		assert_between(inst.affixes[0].value, 7.0, 12.0)
		assert_between(inst.affixes.size(), 1, 2)
		var seen: Array[StringName] = []
		for roll: AffixRoll in inst.affixes:
			assert_false(seen.has(roll.affix_id), "no duplicate of the chosen affix")
			seen.append(roll.affix_id)
	# grade 1 (ilvl 1): grade 1 of the affix; tier 2 of a single-tier ceiling is capped to the unlocked ones
	var low: ItemInstance = ItemRoller.create_from_blueprint(_blueprint(1), 60, 0.0, &"test_keen", bp_data,
			RngService.new(3))
	assert_eq(low.affixes[0].tier, 1)
	assert_between(low.affixes[0].value, 3.0, 6.0)


## Order of the draws: the number of affixes (one randf), value of the chosen affix, then the others (choice, grade, value).
func test_chosen_affix_draw_order() -> void:
	var bp_data: GameData = BlueprintData.data()
	var grade5: ItemDef = _blueprint(3, &"test_blade_5")
	var rng := RngService.new(11)
	var replica := RngService.new(11)
	var got: ItemInstance = ItemRoller.create_from_blueprint(grade5, 60, 0.0, &"test_keen", bp_data, rng)
	var two: bool = replica.randf() * 100.0 < ItemRoller.blueprint_two_affix_chance(60, 0.0, bp_data)
	var tier: AffixTier = bp_data.affix(&"test_keen").tiers[1]
	var steps: int = floori((tier.max - tier.min) / tier.step + 0.000001)
	var value: float = snappedf(tier.min + replica.randi_range(0, steps) * tier.step, 0.000001)
	assert_eq(got.rarity, &"masterwork")
	assert_almost_eq(got.affixes[0].value, value, 0.0001)
	assert_eq(got.affixes.size(), 2 if two else 1)
	if two:
		assert_eq(got.affixes[1].affix_id, &"test_mighty")  # the only other weapon affix: one weighted pick


## A hand-made blueprint of material `grade` for the base `base_id` (the fixture files hold only a few).
func _blueprint(grade: int, base_id: StringName = &"test_blade") -> ItemDef:
	var bp := ItemDef.new()
	bp.id = &"bp_hand_made"
	bp.category = &"blueprint"
	bp.blueprint = BlueprintInfo.new()
	bp.blueprint.base_id = base_id
	bp.blueprint.grade = grade
	return bp


func test_item_rarity_pct() -> void:
	var base: Vector2 = ItemRoller.drop_chances(&"monster", 0.0, _data)
	var boosted: Vector2 = ItemRoller.drop_chances(&"monster", 50.0, _data)
	assert_almost_eq(boosted.x, base.x * 1.5, 0.001)
	assert_almost_eq(boosted.y, base.y * 1.5, 0.001)


func test_affix_rolls() -> void:
	var rng := RngService.new(7)
	assert_eq(ItemRoller.roll_affixes(_blade, &"common", 50, _data, rng).size(), 0)
	for i: int in 40:
		var magic: Array[AffixRoll] = ItemRoller.roll_affixes(_blade, &"magic", 50, _data, rng)
		assert_between(magic.size(), 1, 2)
		var rare: Array[AffixRoll] = ItemRoller.roll_affixes(_blade, &"rare", 50, _data, rng)
		assert_eq(rare.size(), 2, "the weapon slot allows only 2 affixes")
		var ids: Array[StringName] = []
		for r: AffixRoll in rare:
			assert_false(ids.has(r.affix_id), "no repeated affix")
			ids.append(r.affix_id)
			var tier: AffixTier = _data.affix(r.affix_id).tiers[r.tier - 1]
			assert_between(r.value, tier.min, tier.max)
			assert_true(tier.min_ilvl <= 50)


func test_affix_tiers_unlocked_by_ilvl() -> void:
	var rng := RngService.new(3)
	for i: int in 60:
		for r: AffixRoll in ItemRoller.roll_affixes(_blade, &"rare", 25, _data, rng):
			var max_tier: int = 2 if r.affix_id == &"test_keen" else 1
			assert_true(r.tier <= max_tier, "ilvl 25 unlocks tier 2 of keen only")
	assert_eq(ItemRoller.roll_affixes(_blade, &"rare", 0, _data, rng).size(), 0)


func test_affix_step_values() -> void:
	var rng := RngService.new(11)
	var seen: Dictionary = {}
	for i: int in 200:
		for r: AffixRoll in ItemRoller.roll_affixes(_blade, &"rare", 30, _data, rng):
			if r.affix_id == &"test_mighty" and r.tier == 2:
				seen[r.value] = true
	assert_eq(seen.keys().size(), 3, "6, 8, 10")
	for v: Variant in seen.keys():
		assert_true([6.0, 8.0, 10.0].has(v))


func test_same_seed_same_instance() -> void:
	var a: ItemInstance = ItemRoller.create(_blade, &"rare", 50, _data, RngService.new(99))
	var b: ItemInstance = ItemRoller.create(_blade, &"rare", 50, _data, RngService.new(99))
	assert_eq(a.to_dict(), b.to_dict())
	assert_eq(a.uid, 0)
	assert_eq(a.upgrade, 0)


func test_draw_order() -> void:
	var rng := RngService.new(5)
	var mirror := RngService.new(5)
	var inst: ItemInstance = ItemRoller.create(_blade, &"magic", 1, _data, rng)
	var count: int = mirror.randi_range(1, 2)
	assert_eq(inst.affixes.size(), count)
	var weights: Array[int] = [10, 8]
	var first: int = mirror.pick_weighted(weights)
	assert_eq(inst.affixes[0].affix_id, [&"test_keen", &"test_mighty"][first])
	mirror.randi_range(0, 0)
	var tier: AffixTier = _data.affix(inst.affixes[0].affix_id).tiers[0]
	assert_eq(inst.affixes[0].value, tier.min + mirror.randi_range(0, int(tier.max - tier.min)))


func test_instance_modifiers() -> void:
	var inst := ItemInstance.new()
	inst.base_id = &"test_blade"
	inst.affixes.append(AffixRoll.make(&"test_keen", 2, 9.0))
	var mods: Array[Modifier] = ItemRoller.instance_modifiers(inst, _data)
	assert_eq(mods.size(), 2, "M14: a weapon has no power_bonus, its damage is dmg_min-dmg_max")
	assert_eq(mods[0].stat, &"accuracy_bonus")
	assert_eq(mods[0].value, 8.0)
	assert_eq(mods[1].stat, &"accuracy_bonus")
	assert_eq(mods[1].value, 9.0)
	assert_eq(mods[1].scope_kind, Modifier.SCOPE_GLOBAL)


func test_tool_affix_scope() -> void:
	var tool: ItemDef = _data.item(&"unique_hatchet")
	var inst: ItemInstance = ItemRoller.create(tool, &"magic", 5, _data, RngService.new(2))
	assert_eq(inst.affixes.size(), 1, "only one affix is allowed on the tool slot")
	var mods: Array[Modifier] = ItemRoller.instance_modifiers(inst, _data)
	var affix_mod: Modifier = mods[mods.size() - 1]
	assert_eq(affix_mod.scope_kind, Modifier.SCOPE_SKILL)
	assert_eq(affix_mod.scope_id, &"forestry")


func test_instance_modifiers_upgrade_multiplier() -> void:
	# F-86: base modifiers x (1 + upgrade.mod_pct_per_level x N / 100) (10): +3 -> x1.3; affixes do not change.
	var inst := ItemInstance.new()
	inst.base_id = &"test_blade"
	inst.upgrade = 3
	inst.affixes.append(AffixRoll.make(&"test_keen", 2, 9.0))
	var mods: Array[Modifier] = ItemRoller.instance_modifiers(inst, _data)
	assert_eq(mods.size(), 2)
	assert_almost_eq(mods[0].value, 8.0 * 1.3, 0.0001, "accuracy_bonus x1.3")
	assert_eq(mods[1].value, 9.0, "the affix keeps its value")
	inst.upgrade = 0
	assert_eq(ItemRoller.instance_modifiers(inst, _data)[0].value, 8.0, "+0 leaves the base")
	inst.upgrade = 9
	assert_almost_eq(ItemRoller.instance_modifiers(inst, _data)[0].value, 8.0 * 1.9, 0.0001, "+9 -> x1.9")


func test_drop_rarity() -> void:
	var a: Vector2 = ItemRoller.drop_chances(&"monster", 0.0, _data)
	assert_almost_eq(a.x, 20.0, 0.001)
	assert_almost_eq(a.y, 3.0, 0.001)
	var b: Vector2 = ItemRoller.drop_chances(&"monster", 50.0, _data)  # F-84 example
	assert_almost_eq(b.x, 30.0, 0.001)
	assert_almost_eq(b.y, 4.5, 0.001)
	var c: Vector2 = ItemRoller.drop_chances(&"rift_stone", 0.0, _data)
	assert_almost_eq(c.x, 40.0, 0.001)
	assert_almost_eq(c.y, 12.0, 0.001)
	var d: Vector2 = ItemRoller.drop_chances(&"rift_stone", 1000.0, _data)  # clamped like F-83
	assert_almost_eq(d.y, 100.0, 0.001)
	assert_almost_eq(d.x, 0.0, 0.001)
	var e: Vector2 = ItemRoller.drop_chances(&"rift_stone", 300.0, _data)
	assert_almost_eq(e.x + e.y, 100.0, 0.001)
	assert_eq(ItemRoller.roll_rarity(b, _FixedRng.new(0.04)), &"rare", "same roll as F-83")
	assert_eq(ItemRoller.roll_rarity(b, _FixedRng.new(0.20)), &"magic")
	assert_eq(ItemRoller.roll_rarity(b, _FixedRng.new(0.50)), &"common")
