class_name BankPageLinks
extends RefCounted
## Commands the bank page sends to other modules (Altar sockets, Armory stone sockets, bag slots), extracted from
## `BankPage`. Each returns the Italian refusal text, or "" when the command succeeded. Holds no state.


## "Incastona" on an infusion: the first free socket of the Altar.
static func socket_infusion(session: GameSession, item_id: StringName) -> String:
	for i: int in session.rift.socket_total():
		if session.rift.is_unlocked(i) and session.rift.get_socket(i) == &"":
			return text_of(session.rift.socket(i, item_id), RiftTexts.refused)
	return RiftTexts.NO_FREE_SOCKET_TEXT


## "Incastona" on a stone: the piece chosen in the panel.
static func socket_stone(session: GameSession, item_id: StringName, uid: int) -> String:
	return text_of(session.armory.socket_stone(uid, item_id), SocketTexts.refused)


## "Metti nello slot" on a bag: the first free bag slot.
static func equip_bag_in_free_slot(session: GameSession, item_id: StringName) -> String:
	var slot: int = session.deposit.bags().find(&"")
	if slot < 0:
		return BagTexts.NO_FREE_SLOT_TEXT
	return equip_bag(session, slot, item_id)


static func equip_bag(session: GameSession, slot_index: int, item_id: StringName) -> String:
	return text_of(session.bank.equip_bag(slot_index, item_id), BagTexts.refused)


static func unequip_bag(session: GameSession, slot_index: int) -> String:
	return text_of(session.bank.unequip_bag(slot_index), BagTexts.refused)


static func text_of(result: CommandResult, worded: Callable) -> String:
	return "" if result.ok else worded.call(result.reason) as String
