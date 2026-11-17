class_name ShopIndex
extends RefCounted
## Lookups over the shop entries (internal to GameData, M26-02; docs/05_INTERFACES_M26.md §4c). Pure functions on the list in file order.


## The entries of a vendor, in file order; empty when there are none.
static func of_vendor(list: Array[ShopEntryDef], vendor: StringName) -> Array[ShopEntryDef]:
	var result: Array[ShopEntryDef] = []
	for entry: ShopEntryDef in list:
		if entry.vendor == vendor:
			result.append(entry)
	return result


## The first entry whose `effect.item` is `item_id`; null (no error) when no entry sells it.
static func selling(list: Array[ShopEntryDef], item_id: StringName) -> ShopEntryDef:
	for entry: ShopEntryDef in list:
		if entry.effect_item != null and entry.effect_item.item_id == item_id:
			return entry
	return null
