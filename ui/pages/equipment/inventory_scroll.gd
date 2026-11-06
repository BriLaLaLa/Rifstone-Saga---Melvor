class_name InventoryScroll
extends ScrollContainer
## Scroll area of the inventory grid. Dropping a piece dragged from a worn slot on it means "Rimuovi": it emits
## `unequip_dropped(slot)` and the page sends the command. Pieces dragged from the inventory itself are not accepted.
## (The cells forward the same drop through their own `unequip_dropped`, since they take the mouse.)

signal unequip_dropped(slot: StringName)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return PieceDrag.is_piece(data) and PieceDrag.from_of(data) != &""


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	unequip_dropped.emit(PieceDrag.from_of(data))
