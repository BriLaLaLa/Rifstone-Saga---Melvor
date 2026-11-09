extends GutTest
## F-119 Masterwork (viola) and F-120 legendary (arancione) as rarities of a piece (docs/02_FORMULAS.md, 04 §21): the rarity
## is imposed by the base, the statistics are x`rarity.masterwork.base_mult` (1.25) / x`rarity.legendary.base_mult` (1.4)
## before the refinement, castoni, salvage by the grade of the material, the save, and "never from a drop".
## Content: the M10 fixtures with `mw_test_sword_8` (grade 8, 20-34) and `mw_test_chest_11` (Plates, grade 11, armor 121) and
## their blueprints (BlueprintData); the legendaries from tests/helpers/m14_data.gd.

const BlueprintData := preload("res://tests/systems/actions/blueprint_data.gd")
const SWORD: StringName = &"mw_test_sword_8"
const CHEST: StringName = &"mw_test_chest_11"

var _data: GameData = BlueprintData.data()


func _piece(base_id: StringName, rarity: StringName = &"common", upgrade: int = 0) -> ItemInstance:
	var inst: ItemInstance = ItemRoller.create(_data.item(base_id), rarity, 1, _data, RngService.new(5))
	inst.upgrade = upgrade
	return inst


func _armor(mods: Array[Modifier]) -> float:
	for m: Modifier in mods:
		if m.stat == &"armor":
			return m.value
	return -1.0


func test_the_rarity_is_imposed_by_the_base() -> void:
	assert_eq(ItemRoller.create(_data.item(SWORD), &"common", 1, _data, RngService.new(5)).rarity, &"masterwork")
	assert_eq(ItemRoller.create(_data.item(SWORD), &"rare", 1, _data, RngService.new(5)).rarity, &"masterwork", "the given one is ignored")
	assert_eq(ItemRoller.create(_data.item(&"test_helm"), &"rare", 1, _data, RngService.new(5)).rarity, &"rare", "an ordinary base")
	var legendary_data: GameData = LegendaryKit.session(1).data
	var legendary: ItemInstance = ItemRoller.create(legendary_data.item(&"fx_leg_cap"), &"common", 5, legendary_data, RngService.new(5))
	assert_eq(legendary.rarity, &"legendary")
	assert_true(legendary.affixes.is_empty(), "a legendary has no affixes")


func test_masterwork_has_one_or_two_affixes() -> void:
	var counts: Dictionary[int, int] = {}
	for seed_value: int in 60:
		var inst: ItemInstance = ItemRoller.create(_data.item(SWORD), &"magic", 35, _data, RngService.new(seed_value))
		counts[inst.affixes.size()] = counts.get(inst.affixes.size(), 0) + 1
	assert_eq(counts.keys().size() > 0 and counts.keys().all(func(n: int) -> bool: return n >= 1 and n <= 2), true,
			"1-2 affixes (rarity.masterwork.affix_count): %s" % [counts])
	assert_true(counts.has(1) and counts.has(2), "both happen")


func test_chest_grade_11_armor_121_is_151_25() -> void:
	var mods: Array[Modifier] = ItemRoller.instance_modifiers(_piece(CHEST), _data)
	assert_almost_eq(_armor(mods), 151.25, 0.0001, "121 x 1.25")
	var base_mods: Array[Modifier] = _data.item(CHEST).equip.modifiers
	assert_eq(mods[0].stat, base_mods[0].stat)
	assert_almost_eq(mods[1].value, 6.25, 0.0001, "evasion_bonus 5 x 1.25 (the base modifiers come first)")


func test_sword_grade_8_20_34_is_25_42_5() -> void:
	var span: Vector2 = WeaponMath.damage_range(_piece(SWORD), _data)
	assert_eq(span, Vector2(25.0, 42.5))
	assert_almost_eq(WeaponMath.dps(_piece(SWORD), 0.0, _data), (25.0 + 42.5) / 2.0 / 2.0, 0.0001, "2000 ms")


func test_the_multiplier_comes_before_the_refinement() -> void:
	# base x 1.25 x (1 + 10% x N): +4 -> 121 x 1.25 x 1.4 = 211.75; the weapon 20-34 -> 35-59.5
	assert_almost_eq(_armor(ItemRoller.instance_modifiers(_piece(CHEST, &"masterwork", 4), _data)), 211.75, 0.0001)
	var span: Vector2 = WeaponMath.damage_range(_piece(SWORD, &"masterwork", 4), _data)
	assert_almost_eq(span.x, 35.0, 0.0001)
	assert_almost_eq(span.y, 59.5, 0.0001)


func test_an_ordinary_piece_has_no_multiplier() -> void:
	var rare: ItemInstance = _piece(&"test_helm_high", &"rare")
	assert_eq(_armor(ItemRoller.instance_modifiers(rare, _data)), 4.0)


func test_legendary_multiplier_is_1_4() -> void:
	var legendary_data: GameData = LegendaryKit.session(1).data
	var inst: ItemInstance = ItemRoller.create(legendary_data.item(&"fx_leg_cap"), &"common", 5, legendary_data, RngService.new(5))
	assert_almost_eq(_armor(ItemRoller.instance_modifiers(inst, legendary_data)), 6.0 * 1.4, 0.0001)
	var weapon: ItemInstance = ItemRoller.create(legendary_data.item(&"fx_leg_pierce"), &"common", 5, legendary_data, RngService.new(5))
	var span: Vector2 = WeaponMath.damage_range(weapon, legendary_data)
	assert_almost_eq(span.x, 7.0, 0.0001, "5 x 1.4")
	assert_almost_eq(span.y, 11.2, 0.0001, "8 x 1.4")


func test_masterwork_and_legendary_have_two_sockets() -> void:
	assert_eq(Sockets.count(&"masterwork", 0, _data), 2)
	assert_eq(Sockets.count(&"legendary", 0, _data), 2)
	assert_eq(Sockets.count(&"masterwork", 7, _data), 3, "and one more from +7")


func test_salvage_is_by_the_grade_of_the_material() -> void:
	# The blueprint of the chest asks 12 Plates of the material 6 (4 x 3); 12 x 0.4 = 4.8 -> 4 are given back.
	var components: Dictionary[StringName, int] = Salvage.components(CHEST, _data)
	assert_eq(components, {&"test_plate_6": 4} as Dictionary[StringName, int])
	# shards: shards_by_rarity.masterwork (3) x material grade (6) + refinement
	assert_eq(Salvage.paid(_piece(CHEST, &"masterwork", 2), _data)[Upgrade.SHARD_ITEM], 3 * 6 + 2)
	# the rare components never come back
	assert_false(Salvage.paid(_piece(CHEST), _data).has(&"test_log"))


func test_a_legendary_gives_shards_and_no_component() -> void:
	var legendary_data: GameData = LegendaryKit.session(1).data
	var inst: ItemInstance = ItemRoller.create(legendary_data.item(&"fx_leg_cap"), &"legendary", 5, legendary_data, RngService.new(5))
	var paid: Dictionary[StringName, int] = Salvage.paid(inst, legendary_data)
	assert_eq(paid.keys(), [Upgrade.SHARD_ITEM] as Array)
	assert_eq(paid[Upgrade.SHARD_ITEM], 3 * legendary_data.material_grade(3), "legendary 3 x material grade of the piece grade 3")


func test_the_refinement_cost_follows_the_grade_of_the_material() -> void:
	var s: GameSession = autofree(TestFactory.session(3, _data))
	var uid: int = s.armory.add(_piece(CHEST))
	var cost: Dictionary = Upgrade.cost(0, Upgrade.material_grade(s.armory.get_instance(uid), _data), _data)
	assert_eq(Upgrade.material_grade(s.armory.get_instance(uid), _data), 6, "piece grade 11 -> material 6")
	assert_eq(cost["gold"], 50 * 6)
	assert_eq(cost["ingot"], &"palecinnabar_ingot")


func test_the_save_keeps_rarity_uid_and_upgrade() -> void:
	var s: GameSession = autofree(TestFactory.session(3, _data))
	var uid: int = s.armory.add(_piece(SWORD, &"masterwork", 2))
	var copy: GameSession = autofree(TestFactory.session(4, _data))
	assert_true(copy.from_save(s.to_save(0)).ok)
	var loaded: ItemInstance = copy.armory.get_instance(uid)
	assert_eq(loaded.rarity, &"masterwork")
	assert_eq(loaded.uid, uid)
	assert_eq(loaded.upgrade, 2)
	assert_eq(loaded.to_dict(), s.armory.get_instance(uid).to_dict())


func test_an_instance_whose_rarity_contradicts_its_base_is_rejected() -> void:
	var d: Dictionary = _piece(SWORD).to_dict()
	d["uid"] = 1
	d["rarity"] = "rare"
	assert_null(ItemInstance.from_dict(d, _data), "a Masterwork base is always masterwork")
	d["rarity"] = "masterwork"
	assert_not_null(ItemInstance.from_dict(d, _data))


func test_a_drop_never_makes_a_masterwork_or_a_legendary() -> void:
	var rng := RngService.new(11)
	for i: int in 300:
		var rarity: StringName = ItemRoller.roll_rarity(Vector2(100.0, 100.0), rng)
		assert_false(Rarities.is_fixed(rarity), "only common, magic and rare are rolled")
	assert_false(_data.is_equipment_pool_base(SWORD), "not in the pool of the drops (F-121)")
	assert_false(_data.is_equipment_pool_base(CHEST))
	assert_true(_data.is_equipment_pool_base(&"test_helm"))
	var pool: Array[ItemDef] = BossRewards.piece_bases(_data.character_class(&"test_class"), 8, _data)
	for base: ItemDef in pool:
		assert_false(base.equip.masterwork, "%s is not a boss piece" % base.id)


func test_the_rarities_are_five_in_order() -> void:
	assert_eq(Rarities.ORDER, [&"common", &"magic", &"rare", &"masterwork", &"legendary"] as Array[StringName])
	assert_eq(Rarities.base_mult(&"rare", _data), 1.0)
	assert_eq(Rarities.base_mult(&"masterwork", _data), 1.25)
	assert_eq(Rarities.base_mult(&"legendary", _data), 1.4)
	assert_eq(Rarities.affix_range(&"masterwork", _data), Vector2i(1, 2))
	assert_eq(Rarities.affix_range(&"legendary", _data), Vector2i.ZERO)
	assert_eq(Rarities.affix_range(&"rare", _data), Vector2i(3, 4))
