class_name ItemEffects
extends RefCounted
## The effects of the legendaries worn (F-120): helper of `Equipment.item_effects`. No state.


## The effects of the worn legendaries in the order of `Equipment.SLOTS`, each with the source `equipment:<slot>`.
static func of_worn(worn: Dictionary[StringName, int], armory: Armory, data: GameData) -> Array[ItemEffectDef]:
	var result: Array[ItemEffectDef] = []
	for slot: StringName in Equipment.SLOTS:
		var inst: ItemInstance = armory.get_instance(worn.get(slot, 0))
		if inst == null or not data.has_item(inst.base_id):
			continue
		var equip: EquipInfo = data.item(inst.base_id).equip
		if equip == null or equip.legendary == null:
			continue
		for effect: ItemEffectDef in equip.legendary.effects:
			result.append(effect.with_source(StringName(Equipment.SOURCE_PREFIX + String(slot))))
	return result
