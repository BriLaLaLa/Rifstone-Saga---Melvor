extends GutTest
## M10-04: the real content of the loot reform (02_FORMULAS.md §8.2 projects, F-94, §9; 04_DATA_SCHEMA.md §5, §18):
## components, the 64 blueprints, the rare components and their drop plan, the starting kit. The tables below are the oracle.

const METALS: PackedStringArray = [
	"emberbronze", "ashlead", "stormzinc", "duskcobalt", "glimmerite", "palecinnabar", "emberheart", "riftite",
]
const WOODS: PackedStringArray = [
	"redbirch", "ashpine", "thornalder", "duskelm", "shardcedar", "veilcypress", "emberlarch", "riftspruce",
]
## [base suffix, plates of the grade, wood component suffix ("" = none), wood component qty].
const BASES: Array[Array] = [
	["sword", 6, "grip", 2], ["greatsword", 10, "grip", 2], ["shield", 8, "shieldcore", 2], ["cuirass", 10, "", 0],
	["greaves", 8, "", 0], ["helm", 6, "", 0], ["boots", 4, "", 0], ["gauntlets", 4, "", 0],
]
## One rare component per grade (a drop of a monster of the area of the grade), 3 per blueprint.
const RARE: PackedStringArray = [
	"boar_tusk", "scorched_fur", "wolf_fang", "troll_moss", "golem_core", "crawler_carapace", "wraith_veil", "knight_plate",
]
const AREAS: PackedStringArray = ["redrock_plains", "whisper_wood", "cracked_mines", "rift_threshold"]
## Kills per hour measured with tools/sim_combat.gd (scope=all, sword and shield, grade of the area), M10-04.
const KILLS_PER_HOUR: Array[float] = [208.0, 117.0, 83.0, 65.0]
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
	assert_eq(_count(&"blueprint"), 64, "8 bases x 8 grades")
	assert_eq(_count(&"component"), 32, "8 plates, 8 grips, 8 shield cores, 8 handles")
	assert_eq(_count(&"tool"), 3)
	assert_eq(_count(&"equipment"), 80, "the 64 bases of the blueprints and 16 rings and amulets")
	assert_eq(_data.blueprints().size(), 64)


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


func test_woodwright_recipes_make_components() -> void:
	for action: ActionDef in _data.actions_for_skill(&"woodwright"):
		assert_eq(_data.item(action.outputs[0].item_id).category, &"component", action.id)
	assert_eq(_data.actions_for_skill(&"woodwright").size(), 24)


func test_tool_upgrade_items_are_the_components_of_the_grades() -> void:
	var plates: Array = _data.balance_value("tool_upgrade.plate_items") as Array
	var handles: Array = _data.balance_value("tool_upgrade.handle_items") as Array
	for n: int in 8:
		assert_eq(plates[n], METALS[n] + "_plate")
		assert_eq(handles[n], WOODS[n] + "_handle")


# --- blueprints ----------------------------------------------------------------------------------------------------------

func test_blueprints_follow_the_table_of_8_2() -> void:
	for n: int in range(1, 9):
		for row: Array in BASES:
			var base_id := StringName("%s_%s" % [METALS[n - 1], row[0]])
			var bp: ItemDef = _data.blueprint_for_base(base_id)
			assert_not_null(bp, "blueprint of %s" % base_id)
			if bp == null:
				continue
			assert_eq(bp.id, StringName("bp_%s" % base_id))
			assert_eq(bp.value, 0)
			assert_eq(bp.blueprint.grade, n, "%s grade" % bp.id)
			assert_eq(_data.item(base_id).equip.grade, n)
			assert_true(FileAccess.file_exists(bp.icon), bp.icon)
			var expected: Array[ItemQty] = [_qty("%s_plate" % METALS[n - 1], row[1])]
			if row[2] != "":
				expected.append(_qty("%s_%s" % [WOODS[n - 1], row[2]], row[3]))
			assert_eq(bp.blueprint.inputs.size(), expected.size(), "%s inputs" % bp.id)
			for i: int in mini(expected.size(), bp.blueprint.inputs.size()):
				assert_eq(bp.blueprint.inputs[i].item_id, expected[i].item_id, "%s input %d" % [bp.id, i])
				assert_eq(bp.blueprint.inputs[i].qty, expected[i].qty, "%s input %d qty" % [bp.id, i])
			assert_eq(bp.blueprint.rare_component.item_id, StringName(RARE[n - 1]), "%s rare component" % bp.id)
			assert_eq(bp.blueprint.rare_component.qty, 3)


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


# --- rare components and drop plan -------------------------------------------------------------------------------------

func _area_monster_ids(area_index: int) -> Array[StringName]:
	return _data.area(StringName(AREAS[area_index])).monster_ids


func test_rare_components_are_materials_dropped_in_the_area_of_their_grade() -> void:
	for n: int in range(1, 9):
		var area_index: int = (n - 1) / 2  # an area of grade g (1, 3, 5, 7) leaves the grades g and g + 1
		var item: ItemDef = _data.item(StringName(RARE[n - 1]))
		assert_eq(item.category, &"material", item.id)
		var sources: int = 0
		for monster_id: StringName in _area_monster_ids(area_index):
			for drop: DropEntry in _data.monster(monster_id).drops:
				if drop.item_id == item.id:
					sources += 1
					assert_between(drop.chance_pct, 15.0, 40.0, "%s from %s" % [item.id, monster_id])
		assert_gte(sources, 1, "%s drops in %s" % [item.id, AREAS[area_index]])


func test_every_area_has_a_drop_plan_for_its_two_grades() -> void:
	for a: int in 4:
		var grades: Array[int] = [2 * a + 1, 2 * a + 2]
		var seen: Dictionary = {}
		var sources: Array = []
		for monster_id: StringName in _area_monster_ids(a):
			sources.append(_data.monster(monster_id).drops)
		sources.append(_data.rift_stone_for_area(StringName(AREAS[a])).drops)
		for drops: Array in sources:
			assert_lte(drops.size(), 4)
			for drop: DropEntry in drops:
				var item: ItemDef = _data.item(drop.item_id)
				if item.category == &"blueprint":
					assert_true(grades.has(item.blueprint.grade), "%s in %s" % [item.id, AREAS[a]])
					assert_eq([drop.qty_min, drop.qty_max], [1, 1])
					assert_false(seen.has(item.id), "%s is dropped once per area" % item.id)
					seen[item.id] = true
		assert_eq(seen.size(), 7, "7 blueprints in %s (the 4-entry limit of a monster leaves no room for 16)" % AREAS[a])


func test_a_rift_stone_in_three_leaves_a_blueprint() -> void:
	for a: int in 4:
		var stone: RiftStoneDef = _data.rift_stone_for_area(StringName(AREAS[a]))
		var found: int = 0
		for drop: DropEntry in stone.drops:
			if _data.item(drop.item_id).category == &"blueprint":
				found += 1
				assert_eq(drop.chance_pct, 33.0)
		assert_eq(found, 1, stone.id)


func test_blueprints_arrive_about_once_an_hour_from_the_monsters() -> void:
	# Q49: about one blueprint an hour in the area of the player's level (kills/hour measured by sim_combat).
	for a: int in 4:
		var area: AreaDef = _data.area(StringName(AREAS[a]))
		var occurrences: Dictionary = {}
		var total: float = 0.0
		for pack: PackDef in area.packs:
			for monster_id: StringName in pack.monster_ids:
				occurrences[monster_id] = float(occurrences.get(monster_id, 0.0)) + float(pack.weight)
				total += float(pack.weight)
		var per_kill: float = 0.0
		for monster_id: StringName in occurrences:
			for drop: DropEntry in _data.monster(monster_id).drops:
				if _data.item(drop.item_id).category == &"blueprint":
					per_kill += float(occurrences[monster_id]) / total * drop.chance_pct / 100.0
		assert_between(per_kill * KILLS_PER_HOUR[a], 0.6, 1.2, "blueprints/hour in %s" % AREAS[a])


func test_pieces_drop_every_20_to_40_minutes_in_each_area() -> void:
	for a: int in 4:
		var area: AreaDef = _data.area(StringName(AREAS[a]))
		var occurrences: Dictionary = {}
		var total: float = 0.0
		for pack: PackDef in area.packs:
			for monster_id: StringName in pack.monster_ids:
				occurrences[monster_id] = float(occurrences.get(monster_id, 0.0)) + float(pack.weight)
				total += float(pack.weight)
		var per_kill: float = 0.0
		for monster_id: StringName in occurrences:
			for drop: DropEntry in _data.monster(monster_id).drops:
				if _data.item(drop.item_id).category == &"equipment":
					per_kill += float(occurrences[monster_id]) / total * drop.chance_pct / 100.0
		assert_between(per_kill * KILLS_PER_HOUR[a], 1.5, 3.0, "pieces/hour in %s" % AREAS[a])


func test_nothing_but_pieces_materials_and_blueprints_drops() -> void:
	for a: int in 4:
		for monster_id: StringName in _area_monster_ids(a):
			for drop: DropEntry in _data.monster(monster_id).drops:
				var category: StringName = _data.item(drop.item_id).category
				assert_true([&"material", &"equipment", &"blueprint"].has(category), "%s drops %s" % [monster_id, drop.item_id])
				assert_ne(category, &"tool")


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
