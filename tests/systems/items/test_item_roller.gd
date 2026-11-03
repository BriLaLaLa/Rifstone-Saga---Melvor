extends GutTest
## ItemRoller: F-83 chances and rarity roll, F-85 affix rolls, create, instance modifiers.
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


func test_craft_rarity() -> void:
	var a: Vector2 = ItemRoller.craft_chances(0, 0.0, _data)
	assert_almost_eq(a.x, 10.0, 0.001)
	assert_almost_eq(a.y, 1.0, 0.001)
	var b: Vector2 = ItemRoller.craft_chances(50, 20.0, _data)
	assert_almost_eq(b.x, 36.0, 0.001)
	assert_almost_eq(b.y, 7.2, 0.001)
	var c: Vector2 = ItemRoller.craft_chances(99, 0.0, _data)
	assert_almost_eq(c.x, 49.6, 0.001)
	assert_almost_eq(c.y, 10.9, 0.001)
	var d: Vector2 = ItemRoller.craft_chances(99, 1000.0, _data)
	assert_almost_eq(d.y, 100.0, 0.001)
	assert_almost_eq(d.x, 0.0, 0.001)
	var e: Vector2 = ItemRoller.craft_chances(99, 300.0, _data)
	assert_almost_eq(e.x + e.y, 100.0, 0.001)
	var chances := Vector2(36.0, 7.2)
	assert_eq(ItemRoller.roll_rarity(chances, _FixedRng.new(0.05)), &"rare")
	assert_eq(ItemRoller.roll_rarity(chances, _FixedRng.new(0.20)), &"magic")
	assert_eq(ItemRoller.roll_rarity(chances, _FixedRng.new(0.50)), &"common")


func test_item_rarity_pct() -> void:
	var base: Vector2 = ItemRoller.craft_chances(10, 0.0, _data)
	var boosted: Vector2 = ItemRoller.craft_chances(10, 50.0, _data)
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
	assert_eq(mods.size(), 3)
	assert_eq(mods[0].stat, &"accuracy_bonus")
	assert_eq(mods[0].value, 8.0)
	assert_eq(mods[2].stat, &"accuracy_bonus")
	assert_eq(mods[2].value, 9.0)
	assert_eq(mods[2].scope_kind, Modifier.SCOPE_GLOBAL)


func test_tool_affix_scope() -> void:
	var tool: ItemDef = _data.item(&"test_hatchet")
	var inst: ItemInstance = ItemRoller.create(tool, &"magic", 5, _data, RngService.new(2))
	assert_eq(inst.affixes.size(), 1, "only one affix is allowed on the tool slot")
	var mods: Array[Modifier] = ItemRoller.instance_modifiers(inst, _data)
	var affix_mod: Modifier = mods[mods.size() - 1]
	assert_eq(affix_mod.scope_kind, Modifier.SCOPE_SKILL)
	assert_eq(affix_mod.scope_id, &"forestry")
