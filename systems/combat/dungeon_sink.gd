class_name DungeonSink
extends LootSink
## The sink of the drops inside a dungeon (docs/05_INTERFACES.md §5.29): everything goes to the bag of the run (`run.bag`, pieces
## and Cards too), like `FractureSink` but with no change of chance or quantity (no Card of risks here, F-142). The base class
## `drop_chance` and `drop_qty` stay as they are.

var _session: GameSession
var _run: DungeonRun


func _init(session: GameSession, run: DungeonRun) -> void:
	_session = session
	_run = run


func add(item_id: StringName, qty: int) -> bool:
	_run.bag.add_stack(item_id, qty)
	_changed()
	return true


func add_piece(inst: ItemInstance) -> void:
	_run.bag.add_piece(inst)
	_changed()


func add_card(card: MapCard) -> void:
	_run.bag.add_card(card)
	_changed()


## F-32: a Card from a drop table, rarity of F-109 with the global `item_rarity_pct`.
func drop_card(grade: int) -> void:
	var card: MapCard = MapCardRoller.create(grade, _session.cards.roll_rarity(), _session.data, _session.rng)
	if card != null:
		add_card(card)


func _changed() -> void:
	var counts: Dictionary = _run.bag.counts()
	_session.events.dungeon_bag_changed.emit(counts["stacks"], counts["pieces"], counts["cards"])
