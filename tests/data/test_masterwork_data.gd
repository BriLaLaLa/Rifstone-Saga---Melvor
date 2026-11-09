extends GutTest
## M14-05: the Masterwork bases and their blueprints in the real data (F-119, 04_DATA_SCHEMA.md §21): 8 types of Plates x
## 15 grades, values of the normal model of the same slot and grade, one blueprint each, never in a drop.

const TYPES: Array[String] = ["sword", "greatsword", "shield", "head", "body", "legs", "feet", "hands"]

var _data: GameData = null
var _masterworks: Array[ItemDef] = []
var _models: Dictionary = {}


func before_all() -> void:
	_data = GameData.load_from_dirs()
	for item: ItemDef in _data.items():
		if item.category != &"equipment":
			continue
		if item.equip.masterwork:
			_masterworks.append(item)
		elif item.equip.legendary == null:
			_models["%s:%s:%d" % [_kind(item), String(item.equip.material), item.equip.grade]] = item


func _kind(item: ItemDef) -> String:
	return String(item.equip.kind) if item.equip.kind != &"" else String(item.equip.slot)


func test_120_bases_8_types_by_15_grades() -> void:
	assert_eq(_masterworks.size(), 120)
	var seen: Dictionary = {}
	for item: ItemDef in _masterworks:
		seen["%s:%d" % [_kind(item), item.equip.grade]] = true
	for kind: String in TYPES:
		for g: int in range(1, 16):
			assert_true(seen.has("%s:%d" % [kind, g]), "Masterwork %s grade %d" % [kind, g])


func test_a_masterwork_has_the_values_of_the_plate_model_of_its_grade() -> void:
	for item: ItemDef in _masterworks:
		var armour: bool = [&"head", &"body", &"legs", &"feet", &"hands"].has(item.equip.slot) or _kind(item) == "shield"
		var model: ItemDef = _models.get("%s:%s:%d" % [_kind(item), "plate" if armour else "", item.equip.grade])
		assert_not_null(model, "model of %s" % item.id)
		if model == null:
			continue
		assert_eq(item.equip.material, &"plate" if armour else &"", "%s: Plates only (Q75)" % item.id)
		assert_eq(item.equip.requirements, model.equip.requirements, item.id)
		assert_eq(item.equip.modifiers.size(), model.equip.modifiers.size(), item.id)
		for i: int in mini(item.equip.modifiers.size(), model.equip.modifiers.size()):
			assert_eq(item.equip.modifiers[i].stat, model.equip.modifiers[i].stat, item.id)
			assert_eq(item.equip.modifiers[i].value, model.equip.modifiers[i].value, item.id)
		if model.equip.weapon != null:
			assert_eq([item.equip.weapon.dmg_min, item.equip.weapon.dmg_max],
					[model.equip.weapon.dmg_min, model.equip.weapon.dmg_max], item.id)
		assert_gt(item.value, model.value, "%s sells for more than the model" % item.id)
		assert_ne(item.name, model.name, "a Masterwork has a name of its own")
		assert_true(FileAccess.file_exists(item.icon), item.icon)


func test_every_masterwork_has_exactly_one_blueprint_that_creates_it() -> void:
	var count: Dictionary = {}
	for bp: ItemDef in _data.blueprints():
		var base: ItemDef = _data.item(bp.blueprint.base_id)
		assert_true(base.equip.masterwork, "%s creates a Masterwork" % bp.id)
		count[base.id] = int(count.get(base.id, 0)) + 1
		assert_eq(bp.name, "Progetto: " + base.name, bp.id)
	for item: ItemDef in _masterworks:
		assert_eq(int(count.get(item.id, 0)), 1, "one blueprint for %s" % item.id)
	assert_eq(_data.blueprints().size(), 120)


func test_blueprint_cost_is_three_times_the_old_one_plus_two_rare_components() -> void:
	assert_eq(int(_data.balance_value("blueprint.cost_mult")), 3)
	assert_eq(int(_data.balance_value("blueprint.extra_rare")), 2)
	var old_plates: Dictionary = {"sword": 6, "greatsword": 10, "shield": 8, "body": 10, "legs": 8, "head": 6, "feet": 4, "hands": 4}
	for bp: ItemDef in _data.blueprints():
		var base: ItemDef = _data.item(bp.blueprint.base_id)
		assert_eq(bp.blueprint.inputs[0].qty, 3 * int(old_plates[_kind(base)]), bp.id)
		assert_eq(bp.blueprint.rare_components.size(), 2, bp.id)


func test_the_masterworks_are_in_no_drop() -> void:
	var ids: Dictionary = {}
	for item: ItemDef in _masterworks:
		ids[item.id] = true
	for table: LootTableDef in _data.loot_tables():
		for entry: DropEntry in table.entries:
			assert_false(ids.has(entry.item_id), "%s in %s" % [entry.item_id, table.id])
