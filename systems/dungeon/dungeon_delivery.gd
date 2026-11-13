class_name DungeonDelivery
extends RefCounted
## F-116 for the bag of a dungeon (a copy of the delivery of the Fractures: no refactor of `FractureSystem`): stacks to the
## Bank, pieces through the filter of the Armory, Cards to the CardStore. What does not fit stays in the bag.


## Delivers `bag` in place and returns it: what is left is what waits for room (`DungeonSystem.pending`).
static func deliver(session: GameSession, bag: FractureBag) -> FractureBag:
	for entry: Dictionary in bag.stacks():
		var item_id: StringName = entry["item"]
		if session.bank.can_add(item_id) and session.bank.add(item_id, entry["qty"]).ok:
			bag.remove_stack(item_id)
	for inst: ItemInstance in bag.pieces():
		session.armory.add_drop(inst)
		bag.remove_piece(inst)
	for card: MapCard in bag.cards():
		if session.cards.can_add(1) and session.cards.add(card) > 0:
			bag.remove_card(card)
	return bag
