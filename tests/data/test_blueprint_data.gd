extends GutTest
## M10-04, M14-05: the real content of the loot reform (02_FORMULAS.md §8.2 projects, F-94, F-119, §9; 04_DATA_SCHEMA.md §5, §21):
## components, the 120 blueprints of the Masterworks, the rare components, the starting kit. The tables below are the oracle.

const METALS: PackedStringArray = [
	"emberbronze", "ashlead", "stormzinc", "duskcobalt", "glimmerite", "palecinnabar", "emberheart", "riftite",
]
const WOODS: PackedStringArray = [
	"redbirch", "ashpine", "thornalder", "duskelm", "shardcedar", "veilcypress", "emberlarch", "riftspruce",
]
## [base suffix, plates of the grade, wood component suffix ("" = none), wood component qty].
const BASES: Array[Array] = [
	["sword", 6, "grip", 2], ["greatsword", 10, "grip", 2], ["shield", 8, "shieldcore", 2], ["body", 10, "", 0],
	["legs", 8, "", 0], ["head", 6, "", 0], ["feet", 4, "", 0], ["hands", 4, "", 0],
]
const AREAS: PackedStringArray = ["redrock_plains", "whisper_wood", "cracked_mines", "rift_threshold"]
const GRADE_LEVELS: Array[int] = [1, 10, 20, 30, 45, 60, 75, 90]
const PLATE_XP: Array[int] = [19, 33, 52, 76, 110, 153, 206, 278]  # floor(2 x smelting xp x 1.2)

var _data: GameData = null


func before_all() -> void:
	_data = GameData.load_from_dirs()


func _count(category: StringName) -> int:
	var n: int = 0
	for item: ItemDef in _data.items():
		if item.category == category:
			n += 1
	return n


# --- counts ----------------------------------------------------------------------------------------------------------

func test_real_data_is_valid() -> void:
	assert_eq(_data.errors, PackedStringArray())


func test_counts_of_the_new_categories() -> void:
	assert_eq(_count(&"blueprint"), 120, "8 bases x 15 grades")
	assert_eq(_count(&"component"), 32, "8 plates, 8 grips, 8 shield cores, 8 handles")
	assert_eq(_count(&"tool"), 12, "3 unique tools and 9 legendary tools")
	assert_eq(_count(&"equipment"), 480, "30 weapons, 30 jewels, 270 armour pieces, 120 Masterworks, 30 legendaries")
	assert_eq(_data.blueprints().size(), 120)


func test_components_follow_8_2() -> void:
	var ore_values: Array[int] = [1, 3, 6, 10, 18, 30, 50, 85]
	for n: int in range(1, 9):
		var plate: ItemDef = _data.item(StringName(METALS[n - 1] + "_plate"))
		assert_eq(plate.category, &"component", plate.id)
		assert_eq(plate.value, 7 * ore_values[n - 1], "%s value" % plate.id)
		assert_true(FileAccess.file_exists(plate.icon), plate.icon)
		for suffix: String in ["grip", "shieldcore", "handle"]:
			var item: ItemDef = _data.item(StringName("%s_%s" % [WOODS[n - 1], suffix]))
			assert_eq(item.category, &"component", item.id)
		var recipe: ActionDef = _data.action(StringName("forge_%s_plate" % METALS[n - 1]))
		assert_eq(recipe.level, GRADE_LEVELS[n - 1])
		assert_eq(recipe.interval_ms, 2400)
		assert_eq(recipe.xp, PLATE_XP[n - 1])
		assert_true(recipe.mastery, "Q26: the plates give mastery like the smelting")
		assert_eq(recipe.inputs.size(), 1)
		assert_eq(recipe.inputs[0].item_id, StringName(METALS[n - 1] + "_ingot"))
		assert_eq(recipe.inputs[0].qty, 2)
		assert_eq(recipe.outputs[0].item_id, plate.id)


func test_woodwright_recipes_make_components_and_the_two_bags() -> void:
	var bags: int = 0
	for action: ActionDef in _data.actions_for_skill(&"woodwright"):
		var category: StringName = _data.item(action.outputs[0].item_id).category
		bags += 1 if category == &"bag" else 0
		assert_true(category == &"component" or category == &"bag", action.id)
	assert_eq(bags, 2, "M12: Borsa di tela and Borsa rinforzata")
	assert_eq(_data.actions_for_skill(&"woodwright").size(), 26)


func test_tool_upgrade_items_are_the_components_of_the_grades() -> void:
	var plates: Array = _data.balance_value("tool_upgrade.plate_items") as Array
	var handles: Array = _data.balance_value("tool_upgrade.handle_items") as Array
	for n: int in 8:
		assert_eq(plates[n], METALS[n] + "_plate")
		assert_eq(handles[n], WOODS[n] + "_handle")


# --- blueprints (M14, F-119) ---------------------------------------------------------------------------------------------

func test_blueprints_follow_the_table_of_8_2_times_the_cost_multiplier() -> void:
	var mult: int = int(_data.balance_value("blueprint.cost_mult"))
	assert_eq(mult, 3)
	var grades: Array = _data.balance_value("equipment.grade_material") as Array
	for g: int in range(1, 16):
		var m: int = int(grades[g - 1])
		for row: Array in BASES:
			var base_id := StringName("mw_%s_%d" % [row[0], g])
			var bp: ItemDef = _data.blueprint_for_base(base_id)
			assert_not_null(bp, "blueprint of %s" % base_id)
			if bp == null:
				continue
			assert_eq(bp.id, StringName("bp_%s" % base_id))
			assert_eq(bp.value, 0)
			assert_eq(bp.blueprint.grade, m, "%s: the grade of the material" % bp.id)
			assert_true(_data.item(base_id).equip.masterwork, "%s crafts a Masterwork" % bp.id)
			assert_true(FileAccess.file_exists(bp.icon), bp.icon)
			var expected: Array[ItemQty] = [_qty("%s_plate" % METALS[m - 1], row[1] * mult)]
			if row[2] != "":
				expected.append(_qty("%s_%s" % [WOODS[m - 1], row[2]], row[3] * mult))
			assert_eq(bp.blueprint.inputs.size(), expected.size(), "%s inputs" % bp.id)
			for i: int in mini(expected.size(), bp.blueprint.inputs.size()):
				assert_eq(bp.blueprint.inputs[i].item_id, expected[i].item_id, "%s input %d" % [bp.id, i])
				assert_eq(bp.blueprint.inputs[i].qty, expected[i].qty, "%s input %d qty" % [bp.id, i])
			assert_eq(bp.blueprint.rare_components.size(), 2, "%s: two rare components (Q68)" % bp.id)
			if bp.blueprint.rare_components.size() == 2:
				assert_ne(bp.blueprint.rare_components[0].item_id, bp.blueprint.rare_components[1].item_id, bp.id)
				for rare: ItemQty in bp.blueprint.rare_components:
					assert_eq(rare.qty, 3)


func _qty(item: String, qty: int) -> ItemQty:
	var result := ItemQty.new()
	result.item_id = StringName(item)
	result.qty = qty
	return result


func test_blueprint_craft_action_and_forging_level_modifier() -> void:
	var action: ActionDef = _data.action(&"blueprint_craft")
	assert_true(action.single)
	assert_false(action.mastery)
	assert_eq(action.skill_id, &"forging")
	var forging: SkillDef = _data.skill(&"forging")
	assert_eq(forging.level_modifiers.size(), 1)
	assert_eq(forging.level_modifiers[0].stat, &"upgrade_success_pct")
	assert_eq(forging.level_modifiers[0].per_level, 0.4)


# --- rare components ---------------------------------------------------------------------------------------------------

## The area whose monsters give the rare components of a piece grade (by the level of the grade: 1-3, 4-7, 8-11, 12-15).
func _area_index_of_grade(g: int) -> int:
	return 0 if g <= 3 else (1 if g <= 7 else (2 if g <= 11 else 3))


func test_rare_components_are_materials_dropped_in_the_area_of_their_grade() -> void:
	for g: int in range(1, 16):
		var area_index: int = _area_index_of_grade(g)
		var monster_drops: Dictionary = {}
		for monster_id: StringName in _data.area(StringName(AREAS[area_index])).monster_ids:
			for drop: DropEntry in _data.monster(monster_id).drops:
				monster_drops[drop.item_id] = drop.chance_pct
		var bp: ItemDef = _data.blueprint_for_base(StringName("mw_sword_%d" % g))
		for rare: ItemQty in bp.blueprint.rare_components:
			assert_eq(_data.item(rare.item_id).category, &"material", rare.item_id)
			assert_true(monster_drops.has(rare.item_id), "%s drops in %s (grade %d)" % [rare.item_id, AREAS[area_index], g])
			if monster_drops.has(rare.item_id):
				assert_between(float(monster_drops[rare.item_id]), 15.0, 40.0, "%s chance" % rare.item_id)


# --- the starting kit (Q51) --------------------------------------------------------------------------------------------

func test_start_kit_uses_existing_grade_one_items() -> void:
	var armory: Array = _data.balance_value("start.armory") as Array
	var slots: Array = []
	for entry: Dictionary in armory:
		var base: ItemDef = _data.item(StringName(entry["base"] as String))
		assert_eq(base.category, &"equipment")
		assert_eq(base.equip.grade, 1)
		slots.append(entry["equip"])
	assert_eq(slots, ["weapon", "", "offhand"])
	var food: ItemDef = _data.item(StringName(_data.balance_value("start.food") as String))
	assert_eq(food.food_heal, 20)
	assert_true(_data.shop_entry(&"auto_eat_1") != null)
	assert_eq(_data.shop_entry(&"auto_eat_1").cost_gold, 2000, "kept in the shop data, owned from the start")


func test_every_drop_material_has_a_source() -> void:
	var dropped: Dictionary = {}
	for a: int in 4:
		for monster_id: StringName in _area_monster_ids(a):
			for drop: DropEntry in _data.monster(monster_id).drops:
				dropped[drop.item_id] = true
		for drop: DropEntry in _data.rift_stone_for_area(StringName(AREAS[a])).drops:
			dropped[drop.item_id] = true
	# M12: the raw materials of the loot tables and the byproducts of the milestones are sources of their own
	for table: LootTableDef in _data.loot_tables():
		for entry: DropEntry in table.entries:
			dropped[entry.item_id] = true
	for skill: SkillDef in _data.skills():
		for action: ActionDef in _data.actions_for_skill(skill.id):
			for output: ItemQty in action.outputs:
				dropped[output.item_id] = true
			for milestone: MilestoneDef in action.milestones:
				dropped[milestone.item] = true
	for item: ItemDef in _data.items():
		if item.category == &"material" and item.sort_order >= 700:
			assert_true(dropped.has(item.id), "%s is an orphan" % item.id)


func _area_monster_ids(area_index: int) -> Array[StringName]:
	return _data.area(StringName(AREAS[area_index])).monster_ids
