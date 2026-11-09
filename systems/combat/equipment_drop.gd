class_name EquipmentDrop
extends RefCounted
## F-121 (docs/02_FORMULAS.md §5e, 05_INTERFACES.md §5.24): the rolls of the drop pool of equipment and blueprints. Every
## kill can give any slot of the grade near the level of the monster, with no fixed model list. The static description
## (grades, types, materials, percentages) is `EquipmentPool` in core/; `KillRewards` rolls the rarity (F-84) and
## the affixes (F-85) of the piece that falls.


## Grades `g` with `lvl(g) > L_m - level_window` and `lvl(g) <= L_m + level_ahead` (F-121 step 3).
static func candidate_grades(monster_level: int, data: GameData) -> Array[int]:
	return EquipmentPool.candidate_grades(monster_level, data)


## F-121: the base id of the piece that falls, &"" when nothing falls. Order of the rolls on `rng`: chance, type,
## material (armour and shield only), grade.
static func roll(monster_level: int, data: GameData, rng: RngService) -> StringName:
	if not rng.roll_pct(float(data.balance_value(EquipmentPool.EQUIPMENT_KEY + ".chance_pct"))):
		return &""
	var kinds: Array[StringName] = EquipmentPool.kinds(data)
	var kind: StringName = kinds[rng.pick_weighted(EquipmentPool.weights(kinds, data))]
	var materials: Array[StringName] = EquipmentPool.materials_of(kind, data)
	var material: StringName = &""
	if not materials.is_empty():
		material = materials[rng.randi_range(0, materials.size() - 1)]
	var grades: Array[int] = candidate_grades(monster_level, data)
	if grades.is_empty():
		return &""
	return EquipmentPool.base_for(kind, material, grades[rng.randi_range(0, grades.size() - 1)], data)


## F-121: the blueprint that falls, &"" when nothing falls. Order: chance, type (only the types that have a blueprint),
## grade. Rings and necklaces have no blueprint.
static func roll_blueprint(monster_level: int, data: GameData, rng: RngService) -> StringName:
	if not rng.roll_pct(float(data.balance_value(EquipmentPool.BLUEPRINT_CHANCE_KEY))):
		return &""
	var kinds: Array[StringName] = EquipmentPool.blueprint_kinds(data)
	if kinds.is_empty():
		return &""
	var kind: StringName = kinds[rng.pick_weighted(EquipmentPool.weights(kinds, data))]
	var grades: Array[int] = candidate_grades(monster_level, data)
	if grades.is_empty():
		return &""
	return EquipmentPool.blueprint_for(kind, grades[rng.randi_range(0, grades.size() - 1)], data)
