extends GutTest
## Toasts of the Fractures (M13-05): `fracture_finished` and `card_rejected` become toasts with the texts of FractureTexts.

var _events: GameEvents
var _manager: ToastManager


func before_each() -> void:
	_events = GameEvents.new()
	_manager = ToastManager.new()
	_manager.events = _events
	add_child(_manager)


func after_each() -> void:
	_manager.free()
	_events.free()


func _texts() -> PackedStringArray:
	var texts := PackedStringArray()
	for toast: Node in (_manager.get_node("Stack") as Node).get_children():
		if toast is Toast and not toast.is_queued_for_deletion():
			texts.append((toast as Toast).text())
	return texts


func test_won_lost_and_abandoned_fractures() -> void:
	_events.fracture_finished.emit(&"won", 2, 30, 1, 2)
	_events.fracture_finished.emit(&"died", 2, 5, 1, 2)
	_events.fracture_finished.emit(&"abandoned", 2, 5, 0, 0)
	assert_eq(_texts(), PackedStringArray(["Frattura vinta! 2 pezzi, 1 Carta", "Frattura persa: bottino perduto",
			"Frattura abbandonata"]))


func test_a_card_lost_to_a_full_deposit() -> void:
	_events.card_rejected.emit(3)
	assert_eq(_texts(), PackedStringArray(["Carta persa: Deposito pieno"]))
