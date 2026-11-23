class_name ArmorySave
extends RefCounted
## Reading one piece of the `armory` save (docs/05_INTERFACES.md §6): the checks `Armory.from_save` applies to each entry.

const LOG_CATEGORY: String = "armory"


## The valid instance of `entry`, or null (after a warning) when it is not an object, is an invalid instance, has a bad uid, a uid already in `known`
## or a base that is not a piece. Socket ids that are not stones are dropped with a warning.
static func read_entry(entry: Variant, data: GameData, known: Dictionary) -> ItemInstance:
	if not entry is Dictionary:
		Log.warn(LOG_CATEGORY, "piece dropped (not an object): %s" % str(entry))
		return null
	var inst: ItemInstance = ItemInstance.from_dict(entry, data)
	if inst == null or inst.uid <= 0 or known.has(inst.uid) or not _is_piece(inst.base_id, data):
		Log.warn(LOG_CATEGORY, "piece dropped (invalid, bad uid or duplicate): %s" % str(entry))
		return null
	var stones: Array[StringName] = []
	for stone_id: StringName in inst.sockets:
		if Sockets.is_stone(stone_id, data):
			stones.append(stone_id)
		else:
			Log.warn(LOG_CATEGORY, "piece %d: '%s' is not a stone, dropped from its sockets" % [inst.uid, stone_id])
	inst.sockets = stones
	return inst


static func _is_piece(base_id: StringName, data: GameData) -> bool:
	return data.has_item(base_id) and data.item(base_id).category in Bank.PIECE_CATEGORIES and data.item(base_id).equip != null
