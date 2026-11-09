class_name ArmorySort
extends RefCounted
## Order of the pieces of the Armory for "Riordina" (docs/05_INTERFACES.md §5.24): slot (the order of `Equipment.SLOTS`),
## grade descending, rarity descending, uid. Pure function over the instances and the data.


## The uids of `items` (uid -> instance) in the sorted order.
static func sorted_uids(items: Dictionary[int, ItemInstance], data: GameData) -> Array[int]:
	var uids: Array[int] = []
	uids.assign(items.keys())
	uids.sort_custom(func(a: int, b: int) -> bool: return _before(items[a], items[b], data))
	return uids


static func _before(inst_a: ItemInstance, inst_b: ItemInstance, data: GameData) -> bool:
	var equip_a: EquipInfo = data.item(inst_a.base_id).equip
	var equip_b: EquipInfo = data.item(inst_b.base_id).equip
	var slot_a: int = Equipment.SLOTS.find(equip_a.slot)
	var slot_b: int = Equipment.SLOTS.find(equip_b.slot)
	if slot_a != slot_b:
		return slot_a < slot_b
	if equip_a.grade != equip_b.grade:
		return equip_a.grade > equip_b.grade
	var rarity_a: int = Rarities.ORDER.find(inst_a.rarity)
	var rarity_b: int = Rarities.ORDER.find(inst_b.rarity)
	if rarity_a != rarity_b:
		return rarity_a > rarity_b
	return inst_a.uid < inst_b.uid
