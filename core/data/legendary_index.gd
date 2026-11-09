class_name LegendaryIndex
extends RefCounted
## The legendary bases (docs/05_INTERFACES.md §5.24) picked out of the item list; no state (helper of GameData).


## Every item with an `equip.legendary`, in the order of the list.
static func all(items: Array[ItemDef]) -> Array[ItemDef]:
	var result: Array[ItemDef] = []
	for def: ItemDef in items:
		if def.equip != null and def.equip.legendary != null:
			result.append(def)
	return result


## The legendaries whose source is `source_type` (&"boss" / &"monolith") `source_id`, in the order of the list.
static func from_source(items: Array[ItemDef], source_type: StringName, source_id: StringName) -> Array[ItemDef]:
	var result: Array[ItemDef] = []
	for def: ItemDef in all(items):
		if def.equip.legendary.source_type == source_type and def.equip.legendary.source_id == source_id:
			result.append(def)
	return result
