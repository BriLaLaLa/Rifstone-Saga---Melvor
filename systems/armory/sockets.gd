class_name Sockets
extends RefCounted
## F-89 sockets (docs/02_FORMULAS.md, docs/01_GDD.md §26): pure functions over the `sockets` section of balance.json.
## No state: `Armory.socket_stone` and `Armory.clear_socket` change the piece.

const BY_RARITY_KEY: String = "sockets.by_rarity"
const BONUS_AT_KEY: String = "sockets.bonus_at_upgrade"


## F-89: `sockets.by_rarity[rarity]` plus one from refinement `sockets.bonus_at_upgrade`.
static func count(rarity: StringName, upgrade: int, data: GameData) -> int:
	var by_rarity: Dictionary = data.balance_value(BY_RARITY_KEY) as Dictionary
	var base: int = int(by_rarity.get(String(rarity), 0))
	return base + (1 if upgrade >= int(data.balance_value(BONUS_AT_KEY)) else 0)


## The stones of `inst` that count: its first `count(...)` entries (a refinement lost after a failed attempt can leave
## more stones than sockets; they stay in the piece, inactive, and work again when the level is regained).
static func active(inst: ItemInstance, data: GameData) -> Array[StringName]:
	var result: Array[StringName] = []
	if inst.sockets.is_empty():
		return result
	var limit: int = count(inst.rarity, inst.upgrade, data)
	for i: int in mini(limit, inst.sockets.size()):
		result.append(inst.sockets[i])
	return result


## True when `item_id` is a stone item.
static func is_stone(item_id: StringName, data: GameData) -> bool:
	return data.has_item(item_id) and data.item(item_id).category == &"stone"
