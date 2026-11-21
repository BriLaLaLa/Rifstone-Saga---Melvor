class_name BagFill
extends RefCounted
## Test and screenshot helper (M29-02): opens a Fracture on a session of the real data and puts things in its bag through the
## model, as the drops do: three stacks of items, one rare piece with affixes and one rare Card, then emits the bag signal.


## Opens a grade-1 Fracture and fills its bag. Returns false if the Fracture does not open.
static func open_and_fill(s: GameSession) -> bool:
	var uid: int = s.cards.create(1, &"common")
	if uid <= 0 or not s.fractures.open(uid).ok:
		return false
	add_drops(s)
	return true


static func add_drops(s: GameSession) -> void:
	var bag: FractureBag = s.fractures.run().bag
	var added: int = 0
	for def: ItemDef in s.data.items():
		if added >= 3:
			break
		if def.category == &"material":
			bag.add_stack(def.id, 3 + added * 40)
			added += 1
	for def: ItemDef in s.data.items():
		if def.equip != null and def.equip.legendary == null:
			var piece_uid: int = s.armory.create(def.id, &"rare", 10)
			if piece_uid > 0:
				bag.add_piece(s.armory.get_instance(piece_uid))
				break
	bag.add_card(MapCardRoller.create(2, &"rare", s.data, s.rng))
	var counts: Dictionary = bag.counts()
	s.events.fracture_bag_changed.emit(counts["stacks"], counts["pieces"], counts["cards"])
