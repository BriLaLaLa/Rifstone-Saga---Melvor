extends GutTest
## M14-05: the equipment of the real data against the table of 02_FORMULAS.md §8.4 (F-118): 15 grades of every slot and
## material, weapons with damage range, armour with Armour/Barrier/evasion, shields with the block chance, rings, amulets.
## The formulas below are the oracle (independent of tools/gen_equipment.gd); the pieces are looked up by their
## characteristics, not by id (ids are free, convention in tools/gen_equipment.gd).

const LEVELS: Array[int] = [1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 60, 70, 80, 90]
const MATERIAL_GRADE: Array[int] = [1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8]
const WEIGHTS: Dictionary = {"body": 0.30, "legs": 0.20, "head": 0.15, "shield": 0.15, "hands": 0.10, "feet": 0.10}
## [armor, barrier, evasion] multipliers of the materials (§8.4).
const MATERIALS: Dictionary = {"plate": [1.0, 0.0, 0.2], "leather": [0.6, 0.4, 1.0], "cloth": [0.3, 1.0, 0.4]}
const ARMOUR_KEYS: Array[String] = ["head", "body", "legs", "feet", "hands", "shield"]

var _data: GameData = null
var _pieces: Dictionary = {}


func before_all() -> void:
	_data = GameData.load_from_dirs()
	for item: ItemDef in _data.items():
		if item.category != &"equipment" or item.equip.masterwork or item.equip.legendary != null:
			continue
		var key: String = _key(item)
		assert_false(_pieces.has(key), "one model per slot, material and grade: %s" % key)
		_pieces[key] = item


func _key(item: ItemDef) -> String:
	var equip: EquipInfo = item.equip
	var kind: String = String(equip.kind) if equip.kind != &"" else String(equip.slot)
	return "%s:%s:%d" % [kind, String(equip.material), equip.grade]


func _piece(kind: String, material: String, grade: int) -> ItemDef:
	var item: ItemDef = _pieces.get("%s:%s:%d" % [kind, material, grade])
	assert_not_null(item, "%s %s grade %d exists" % [kind, material, grade])
	return item


func _mods(item: ItemDef) -> Dictionary:
	var result: Dictionary = {}
	for m: Modifier in item.equip.modifiers:
		assert_false(result.has(m.stat), "%s: one modifier per stat (%s)" % [item.id, m.stat])
		result[String(m.stat)] = m.value
	return result


func test_balance_tables_are_the_ones_of_8_4() -> void:
	var levels: Array = _data.balance_value("equipment.grade_levels") as Array
	for i: int in 15:
		assert_eq(int(levels[i]), LEVELS[i], "level of grade %d" % (i + 1))
	var materials: Array = _data.balance_value("equipment.grade_material") as Array
	for i: int in 15:
		assert_eq(int(materials[i]), MATERIAL_GRADE[i], "material grade of grade %d" % (i + 1))


func test_the_catalogue_has_every_slot_material_and_grade() -> void:
	# 2 weapons + ring + amulet (no material) and 6 armour kinds x 3 materials, 15 grades each
	assert_eq(_pieces.size(), 15 * (4 + 6 * 3))
	for g: int in range(1, 16):
		for kind: String in ["sword", "greatsword", "ring", "neck"]:
			assert_true(_pieces.has("%s::%d" % [kind, g]), "%s grade %d" % [kind, g])
		for kind: String in ARMOUR_KEYS:
			for material: String in MATERIALS:
				assert_true(_pieces.has("%s:%s:%d" % [kind, material, g]),
						"%s %s grade %d" % [kind, material, g])


func test_requirements_follow_the_grade_levels() -> void:
	for key: String in _pieces:
		var item: ItemDef = _pieces[key]
		assert_eq(item.equip.requirements, {&"character": LEVELS[item.equip.grade - 1]} as Dictionary, item.id)


func test_weapons() -> void:
	for g: int in range(1, 16):
		var sword: ItemDef = _piece("sword", "", g)
		var greatsword: ItemDef = _piece("greatsword", "", g)
		var sword_max: int = 6 + 4 * (g - 1)
		var great_max: int = 12 + 8 * (g - 1)
		assert_eq([sword.equip.weapon.dmg_min, sword.equip.weapon.dmg_max], [roundi(0.6 * sword_max), sword_max], sword.id)
		assert_eq([greatsword.equip.weapon.dmg_min, greatsword.equip.weapon.dmg_max], [roundi(0.5 * great_max), great_max], greatsword.id)
		assert_eq(sword.equip.weapon.attack_interval_ms, 2000, sword.id)
		assert_eq(greatsword.equip.weapon.attack_interval_ms, 3200, greatsword.id)
		assert_false(sword.equip.weapon.two_handed)
		assert_true(greatsword.equip.weapon.two_handed)
		assert_eq(sword.equip.weapon.style, &"blade")
		assert_eq(sword.equip.slot, &"weapon")
		assert_eq(_mods(sword), {"accuracy_bonus": 4.0 * g}, sword.id)
		assert_eq(_mods(greatsword), {"accuracy_bonus": 5.0 * g}, greatsword.id)


func test_weapon_examples_of_8_4() -> void:
	assert_eq([_piece("sword", "", 1).equip.weapon.dmg_min, _piece("sword", "", 1).equip.weapon.dmg_max], [4, 6])
	assert_eq([_piece("sword", "", 8).equip.weapon.dmg_min, _piece("sword", "", 8).equip.weapon.dmg_max], [20, 34])
	assert_eq([_piece("sword", "", 15).equip.weapon.dmg_min, _piece("sword", "", 15).equip.weapon.dmg_max], [37, 62])
	assert_eq([_piece("greatsword", "", 1).equip.weapon.dmg_min, _piece("greatsword", "", 1).equip.weapon.dmg_max], [6, 12])
	assert_eq([_piece("greatsword", "", 15).equip.weapon.dmg_min, _piece("greatsword", "", 15).equip.weapon.dmg_max], [62, 124])
	assert_almost_eq((37 + 62) / 2.0 / 2.0, 24.75, 0.001, "DPS of the sword of grade 15")


func test_armour_follows_the_set_budget() -> void:
	for g: int in range(1, 16):
		var level: int = LEVELS[g - 1]
		var set_armor: float = 4.0 + 8.0 * level
		var set_evasion: float = roundf(2.0 + 1.5 * level)
		for kind: String in ARMOUR_KEYS:
			for material: String in MATERIALS:
				var item: ItemDef = _piece(kind, material, g)
				var mult: Array = MATERIALS[material]
				var w: float = WEIGHTS[kind]
				var want: Dictionary = {}
				for pair: Array in [["armor", roundf(set_armor * w * mult[0])], ["barrier", roundf(set_armor * w * mult[1])],
						["evasion_bonus", roundf(set_evasion * w * mult[2])]]:
					if pair[1] > 0.0:
						want[pair[0]] = pair[1]
				if kind == "shield":
					want["block_chance"] = float(5 + floori(10.0 * (g - 1) / 14.0))
				assert_eq(_mods(item), want, "%s (%s grade %d)" % [item.id, material, g])
				assert_eq(item.equip.material, StringName(material), item.id)


func test_armour_examples_of_8_4() -> void:
	# grade 11, level 50: A_set 404, E_set 77
	assert_eq(_mods(_piece("body", "plate", 11)), {"armor": 121.0, "evasion_bonus": 5.0})
	assert_eq(_mods(_piece("body", "leather", 11)), {"armor": 73.0, "barrier": 48.0, "evasion_bonus": 23.0})
	assert_eq(_mods(_piece("body", "cloth", 11)), {"armor": 36.0, "barrier": 121.0, "evasion_bonus": 9.0})
	var armor: float = 0.0
	for kind: String in ["body", "legs", "head", "feet", "hands", "shield"]:
		armor += float(_mods(_piece(kind, "plate", 11))["armor"])
	assert_eq(armor, 404.0, "a complete Plate set with shield gives the whole budget")


func test_plate_has_no_barrier_and_cloth_has_more_barrier_than_armor() -> void:
	for g: int in range(1, 16):
		for kind: String in ["head", "body", "legs", "feet", "hands"]:
			assert_false(_mods(_piece(kind, "plate", g)).has("barrier"), "plate %s %d" % [kind, g])
			var cloth: Dictionary = _mods(_piece(kind, "cloth", g))
			assert_gt(float(cloth.get("barrier", 0.0)), float(cloth.get("armor", 0.0)), "cloth %s %d" % [kind, g])


func test_shields_and_block_chance() -> void:
	for material: String in MATERIALS:
		assert_eq(_mods(_piece("shield", material, 1))["block_chance"], 5.0)
		assert_eq(_mods(_piece("shield", material, 8))["block_chance"], 10.0)
		assert_eq(_mods(_piece("shield", material, 15))["block_chance"], 15.0)
		assert_eq(_piece("shield", material, 3).equip.slot, &"offhand")


func test_rings_and_amulets() -> void:
	for g: int in range(1, 16):
		var ring: ItemDef = _piece("ring", "", g)
		var amulet: ItemDef = _piece("neck", "", g)
		assert_eq(_mods(ring), {"accuracy_bonus": 3.0 * g}, ring.id)
		assert_eq(_mods(amulet), {"max_hp_flat": 6.0 * g + 4.0}, amulet.id)
		assert_eq(ring.equip.material, &"", "rings have no material")
	assert_eq(_mods(_piece("ring", "", 15))["accuracy_bonus"], 45.0)
	assert_eq(_mods(_piece("neck", "", 15))["max_hp_flat"], 94.0)


func test_icons_exist_and_values_grow() -> void:
	for key: String in _pieces:
		var item: ItemDef = _pieces[key]
		assert_true(FileAccess.file_exists(item.icon), "%s icon %s" % [item.id, item.icon])
		assert_gt(item.value, 0, item.id)
	for kind: String in ["sword", "greatsword", "ring", "neck"]:
		for g: int in range(2, 16):
			assert_gt(_piece(kind, "", g).value, _piece(kind, "", g - 1).value, "%s value grows at grade %d" % [kind, g])


func test_the_starting_kit_is_playable_with_grade_one_sword_and_shield() -> void:
	var armory: Array = _data.balance_value("start.armory") as Array
	var by_slot: Dictionary = {}
	for entry: Dictionary in armory:
		by_slot[entry["equip"]] = _data.item(StringName(entry["base"] as String))
	assert_eq(by_slot["weapon"].equip.kind, &"sword")
	assert_eq(by_slot["weapon"].equip.grade, 1)
	assert_eq(by_slot["offhand"].equip.kind, &"shield")
	assert_eq(by_slot["offhand"].equip.grade, 1)
	assert_eq(by_slot["offhand"].equip.material, &"plate")
