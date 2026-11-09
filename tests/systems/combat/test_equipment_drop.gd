extends GutTest
## F-121 / F-124 (M14): the drop pool of equipment and blueprints (EquipmentPool, EquipmentDrop) and its use by KillRewards.
## Examples of 02_FORMULAS.md F-121 (L_m 46 -> grades 8-11, L_m 92 -> 14-15, L_m 1 -> 1-2) and F-124 (0.0208%).

var _data: GameData


func before_all() -> void:
	_data = TestFactory.real_data()


func test_candidate_grades_examples() -> void:
	assert_eq(EquipmentDrop.candidate_grades(46, _data), [8, 9, 10, 11] as Array[int])
	assert_eq(EquipmentDrop.candidate_grades(92, _data), [14, 15] as Array[int])
	assert_eq(EquipmentDrop.candidate_grades(1, _data), [1, 2] as Array[int])


func test_example_percentage_of_a_leather_body_grade_9_at_level_46() -> void:
	# 2.5 x (1/10) x (1/4) x (1/3) = 0.0208%
	assert_almost_eq(EquipmentPool.chance_of(&"body_leather_9", 46, _data), 0.020833, 0.0001)
	assert_eq(EquipmentPool.chance_of(&"body_leather_9", 92, _data), 0.0, "grade 9 is not a candidate at level 92")


func test_jewels_and_weapons_have_no_material_division() -> void:
	# a ring of grade 9: 2.5 x (1/10) x (1/4) = 0.0625%
	var ring: StringName = _find(&"ring", 9)
	assert_almost_eq(EquipmentPool.chance_of(ring, 46, _data), 0.0625, 0.0001)


func test_percentages_of_a_level_add_up_to_the_chance() -> void:
	var table: Dictionary[StringName, float] = EquipmentPool.table(46, _data)
	var pieces: float = 0.0
	var blueprints: float = 0.0
	for id: StringName in table:
		if _data.item(id).blueprint != null:
			blueprints += table[id]
		else:
			pieces += table[id]
	assert_almost_eq(pieces, 2.5, 0.0001, "loot.equipment.chance_pct")
	assert_almost_eq(blueprints, 0.4, 0.0001, "loot.blueprint.chance_pct")


func test_the_pool_never_gives_masterworks_legendaries_or_tools() -> void:
	for id: StringName in EquipmentPool.table(60, _data):
		var def: ItemDef = _data.item(id)
		if def.blueprint != null:
			continue
		assert_false(def.equip.masterwork, String(id))
		assert_null(def.equip.legendary, String(id))


func test_roll_returns_a_base_of_the_right_grade_and_is_deterministic() -> void:
	var counts: Dictionary = {}
	var rng := RngService.new(5)
	for i: int in 4000:
		var id: StringName = EquipmentDrop.roll(46, _data, rng)
		if id == &"":
			continue
		var grade: int = _data.item(id).equip.grade
		assert_between(grade, 8, 11, String(id))
		assert_true(_data.is_equipment_pool_base(id))
		counts[id] = int(counts.get(id, 0)) + 1
	var total: int = 0
	for id: StringName in counts:
		total += int(counts[id])
	assert_between(total, 50, 160, "about 2.5% of 4000 = 100")
	var a := RngService.new(9)
	var b := RngService.new(9)
	for i: int in 200:
		assert_eq(EquipmentDrop.roll(46, _data, a), EquipmentDrop.roll(46, _data, b))


func test_order_of_the_rolls_is_chance_then_type_then_material_then_grade() -> void:
	var chance_data: GameData = _data
	var rng := RngService.new(123)
	var ref := RngService.new(123)
	for i: int in 300:
		var id: StringName = EquipmentDrop.roll(46, chance_data, rng)
		if not ref.roll_pct(2.5):
			assert_eq(id, &"")
			continue
		var kinds: Array[StringName] = EquipmentPool.kinds(chance_data)
		var kind: StringName = kinds[ref.pick_weighted(EquipmentPool.weights(kinds, chance_data))]
		var materials: Array[StringName] = EquipmentPool.materials_of(kind, chance_data)
		var material: StringName = &""
		if not materials.is_empty():
			material = materials[ref.randi_range(0, materials.size() - 1)]
		var grades: Array[int] = EquipmentDrop.candidate_grades(46, chance_data)
		var grade: int = grades[ref.randi_range(0, grades.size() - 1)]
		assert_eq(id, EquipmentPool.base_for(kind, material, grade, chance_data))


func test_blueprints_cover_eight_types_and_never_rings_or_necklaces() -> void:
	var kinds: Array[StringName] = EquipmentPool.blueprint_kinds(_data)
	assert_eq(kinds.size(), 8)
	assert_false(kinds.has(&"ring"))
	assert_false(kinds.has(&"neck"))
	var rng := RngService.new(77)
	var seen: int = 0
	for i: int in 20000:
		var id: StringName = EquipmentDrop.roll_blueprint(46, _data, rng)
		if id != &"":
			seen += 1
			var grade: int = _data.item(_data.item(id).blueprint.base_id).equip.grade
			assert_between(grade, 8, 11)
	assert_between(seen, 40, 130, "0.4% of 20000 = 80")


func test_kill_rewards_use_the_pool_and_give_no_piece_from_the_drops() -> void:
	var s: GameSession = autofree(TestFactory.session_no_kit(31, _data))
	var monster: MonsterDef = _data.monster(_data.areas()[0].monster_ids[0])
	for def: DropEntry in monster.drops:
		var item: ItemDef = _data.item(def.item_id)
		assert_null(item.equip, "no equipment in the drops of %s" % monster.id)
		assert_null(item.blueprint)
	var before: int = s.armory.instances().size() + (s.bank.get_count(&"rift_shard") * 0)
	var bag := LootBag.new(s)
	for i: int in 3000:
		KillRewards.grant(s, bag, monster)
	assert_gt(s.armory.instances().size(), before, "pieces came out of the pool (2.5% of 3000 kills)")
	for inst: ItemInstance in s.armory.instances():
		assert_true(_data.is_equipment_pool_base(inst.base_id), "only pool bases")
		assert_false(inst.rarity == &"masterwork" or inst.rarity == &"legendary")


func _find(kind: StringName, grade: int) -> StringName:
	return EquipmentPool.base_for(kind, &"", grade, _data)
