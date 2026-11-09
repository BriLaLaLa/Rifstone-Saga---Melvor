class_name EquipmentPool
extends RefCounted
## F-121 / F-124 (docs/02_FORMULAS.md §5e): the static description of the drop pool of equipment and blueprints over
## `GameData` (no rolls): candidate grades, piece types, materials and the percentage of every base. `EquipmentDrop`
## (systems/combat) rolls it with an `RngService`; the Guide (`GuideIndex.drops_of`) reads the percentages. Lives in
## `core/` because the Guide must not depend on `systems/`.

const EQUIPMENT_KEY: String = "loot.equipment"
const BLUEPRINT_CHANCE_KEY: String = "loot.blueprint.chance_pct"
const GRADES_KEY: String = "equipment.grade_levels"
const WEAPON_SLOT: StringName = &"weapon"


## `L_m` of a monster: the highest of its three combat levels.
static func monster_level(def: MonsterDef) -> int:
	return maxi(def.attack_level, maxi(def.power_level, def.defence_level))


## Grades `g` (ascending) with `lvl(g) > L_m - level_window` and `lvl(g) <= L_m + level_ahead` (F-121 step 3).
static func candidate_grades(level: int, data: GameData) -> Array[int]:
	var window: int = int(data.balance_value(EQUIPMENT_KEY + ".level_window"))
	var ahead: int = int(data.balance_value(EQUIPMENT_KEY + ".level_ahead"))
	var result: Array[int] = []
	for grade: int in range(1, (data.balance_value(GRADES_KEY) as Array).size() + 1):
		var grade_level: int = data.grade_level(grade)
		if grade_level > level - window and grade_level <= level + ahead:
			result.append(grade)
	return result


## The piece type of a base, a key of `loot.equipment.kind_weights`: the weapon kind, `shield` for an off-hand, else the slot.
static func kind_of(def: ItemDef) -> StringName:
	if def.equip == null:
		return &""
	if def.equip.slot == WEAPON_SLOT or def.equip.kind != &"":
		return def.equip.kind
	return def.equip.slot


## Types of `loot.equipment.kind_weights`, in the order of the data.
static func kinds(data: GameData) -> Array[StringName]:
	var result: Array[StringName] = []
	for key: Variant in (data.balance_value(EQUIPMENT_KEY + ".kind_weights") as Dictionary).keys():
		result.append(StringName(str(key)))
	return result


static func weights(kind_list: Array[StringName], data: GameData) -> Array[int]:
	var table: Dictionary = data.balance_value(EQUIPMENT_KEY + ".kind_weights") as Dictionary
	var result: Array[int] = []
	for kind: StringName in kind_list:
		result.append(int(table[String(kind)]))
	return result


## Weight of `kind` over the sum of the weights of `kind_list`.
static func share(kind: StringName, kind_list: Array[StringName], data: GameData) -> float:
	var list: Array[int] = weights(kind_list, data)
	var total: int = 0
	for weight: int in list:
		total += weight
	return float(list[kind_list.find(kind)]) / float(total)


## Types of the weights table that have at least one blueprint (rings and necklaces have none).
static func blueprint_kinds(data: GameData) -> Array[StringName]:
	var with_blueprint: Dictionary = {}
	for def: ItemDef in data.blueprints():
		if data.has_item(def.blueprint.base_id):
			with_blueprint[kind_of(data.item(def.blueprint.base_id))] = true
	var result: Array[StringName] = []
	for kind: StringName in kinds(data):
		if with_blueprint.has(kind):
			result.append(kind)
	return result


## Materials of the pool bases of `kind`, in the order of the data (empty for weapons and jewels: no material).
static func materials_of(kind: StringName, data: GameData) -> Array[StringName]:
	var result: Array[StringName] = []
	for def: ItemDef in data.items():
		if def.category == &"equipment" and data.is_equipment_pool_base(def.id) and kind_of(def) == kind \
				and def.equip.material != &"" and not result.has(def.equip.material):
			result.append(def.equip.material)
	return result


## The pool base of `kind`, `material` and piece grade `grade`; &"" when there is none.
static func base_for(kind: StringName, material: StringName, grade: int, data: GameData) -> StringName:
	for def: ItemDef in data.items():
		if def.category == &"equipment" and data.is_equipment_pool_base(def.id) and kind_of(def) == kind \
				and def.equip.grade == grade and def.equip.material == material:
			return def.id
	return &""


## The blueprint of the type `kind` that crafts the Masterwork of piece grade `grade`; &"" when there is none.
static func blueprint_for(kind: StringName, grade: int, data: GameData) -> StringName:
	for def: ItemDef in data.blueprints():
		if not data.has_item(def.blueprint.base_id):
			continue
		var base: ItemDef = data.item(def.blueprint.base_id)
		if base.equip != null and kind_of(base) == kind and base.equip.grade == grade:
			return def.id
	return &""


## F-124: every base the pool can give for one kill of a monster of level `level`, with its percentage (0..100):
## pieces `loot.equipment.chance_pct x (weight / sum of weights) x (1 / candidate grades) x (1 / materials, armour and
## shield)` and blueprints `loot.blueprint.chance_pct x (weight / sum of the weights of the types with a blueprint) x
## (1 / candidate grades)`. Item id -> percentage, in the order of the data (pieces first, then blueprints).
static func table(level: int, data: GameData) -> Dictionary[StringName, float]:
	if not (data.has_balance(EQUIPMENT_KEY) and data.has_balance(GRADES_KEY)):
		return {}  # data without a pool (the fixtures of earlier milestones): nothing falls
	var result: Dictionary[StringName, float] = {}
	var grades: Array[int] = candidate_grades(level, data)
	if grades.is_empty():
		return result
	var kind_list: Array[StringName] = kinds(data)
	var shares: Dictionary = {}  # kind -> weight over the sum
	for kind: StringName in kind_list:
		shares[kind] = share(kind, kind_list, data)
	var pool_bases: Array[ItemDef] = []
	var materials: Dictionary = {}  # kind -> materials found among the pool bases (one pass over the items)
	for def: ItemDef in data.items():
		if def.category == &"equipment" and data.is_equipment_pool_base(def.id):
			pool_bases.append(def)
			var list: Array = materials.get_or_add(kind_of(def), [])
			if def.equip.material != &"" and not list.has(def.equip.material):
				list.append(def.equip.material)
	var piece_pct: float = float(data.balance_value(EQUIPMENT_KEY + ".chance_pct"))
	for def: ItemDef in pool_bases:
		var kind: StringName = kind_of(def)
		if shares.has(kind) and grades.has(def.equip.grade):
			result[def.id] = piece_pct * float(shares[kind]) / float(grades.size()) / float(maxi(1, (materials[kind] as Array).size()))
	var blueprint_list: Array[StringName] = blueprint_kinds(data)
	var blueprint_shares: Dictionary = {}
	for kind: StringName in blueprint_list:
		blueprint_shares[kind] = share(kind, blueprint_list, data)
	var blueprint_pct: float = float(data.balance_value(BLUEPRINT_CHANCE_KEY))
	for def: ItemDef in data.blueprints():
		if not data.has_item(def.blueprint.base_id):
			continue
		var base: ItemDef = data.item(def.blueprint.base_id)
		var kind: StringName = kind_of(base)
		if base.equip != null and blueprint_shares.has(kind) and grades.has(base.equip.grade):
			result[def.id] = blueprint_pct * float(blueprint_shares[kind]) / float(grades.size())
	return result


## F-124: the percentage of one base (piece or blueprint) for a monster of level `level`; 0 when it cannot fall.
static func chance_of(base_id: StringName, level: int, data: GameData) -> float:
	return table(level, data).get(base_id, 0.0)
