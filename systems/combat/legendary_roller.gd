class_name LegendaryRoller
extends RefCounted
## F-120 legendary sources (docs/05_INTERFACES.md §5.24): one `roll_pct(chance_pct)` per legendary of a source, in the
## order of the data. Pure logic; the callers deliver the pieces (the bag of the Fracture, the Armory).

const ILVL_FALLBACK: int = 1


## The bases (ids) of the legendaries of `source_type` (&"boss" / &"monolith") `source_id` that dropped. No legendary for
## the source, no draw.
static func roll(source_type: StringName, source_id: StringName, data: GameData, rng: RngService) -> Array[StringName]:
	var result: Array[StringName] = []
	for def: ItemDef in data.legendaries_from(source_type, source_id):
		if rng.roll_pct(def.equip.legendary.chance_pct):
			result.append(def.id)
	return result


## The new pieces (uid 0, rarity legendary, no affixes, `ilvl` = the level of the grade of the piece) that dropped.
static func drops(source_type: StringName, source_id: StringName, data: GameData, rng: RngService) -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	for base_id: StringName in roll(source_type, source_id, data, rng):
		var base: ItemDef = data.item(base_id)
		result.append(ItemRoller.create(base, Rarities.LEGENDARY, maxi(ILVL_FALLBACK, data.grade_level(base.equip.grade)),
				data, rng))
	return result
