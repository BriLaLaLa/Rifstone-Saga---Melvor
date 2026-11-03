class_name BankPage
extends Page
## Bank page (docs/01_GDD.md §7), route `bank`: a grid of ItemSlotView cells, one per stack of `bank.stacks()` in the
## bank's order, and the counter "used / capacity" of the slots. Hovering a cell shows the item tooltip (ItemSlotView).
##
## Every redraw reads the session: the stacks from `bank.stacks()`, the counter from `bank.used()` and
## `bank.capacity()`. It redraws on `bank_changed` and `bank_capacity_changed`; the quantity a cell draws is the one of
## its last `set_item` (presentation copy of ItemSlotView, never read back). A stack that reaches 0 frees its cell.
## Only a view: selling, locking, sorting and moving stacks come with the full bank (M2-04).
## It keeps no game state: only the session reference and its nodes.

const ITEM_SLOT_SCENE: PackedScene = preload("res://ui/components/item_slot/item_slot.tscn")
const TITLE_TEXT: String = "Bank"
const SLOTS_TEXT: String = "Caselle: %s / %s"
const FULL_TEXT: String = "La bank è piena: i nuovi oggetti non entrano."
const EMPTY_TEXT: String = "La bank è vuota."
const STACK_ITEM_KEY: String = "item"
const STACK_COUNT_KEY: String = "count"
const STACK_LOCKED_KEY: String = "locked"
const CELL_NAME: String = "Cell%d"

var _session: GameSession = null

@onready var _title_label: Label = %TitleLabel
@onready var _slots_label: Label = %SlotsLabel
@onready var _full_label: Label = %FullLabel
@onready var _empty_label: Label = %EmptyLabel
@onready var _grid: HFlowContainer = %Grid


func _ready() -> void:
	_title_label.text = TITLE_TEXT
	_full_label.text = FULL_TEXT
	_full_label.add_theme_color_override("font_color", UiStyle.BAD)
	_full_label.visible = false
	_empty_label.text = EMPTY_TEXT


## Draws the bank of `session` and follows its changes.
func bind(session: GameSession) -> void:
	unbind()
	_session = session
	_session.events.bank_changed.connect(_on_events_bank_changed)
	_session.events.bank_capacity_changed.connect(_on_events_bank_capacity_changed)
	_redraw()


## Disconnects every event connected in `bind`.
func unbind() -> void:
	if _session != null and is_instance_valid(_session):
		var events: GameEvents = _session.events
		if events.bank_changed.is_connected(_on_events_bank_changed):
			events.bank_changed.disconnect(_on_events_bank_changed)
		if events.bank_capacity_changed.is_connected(_on_events_bank_capacity_changed):
			events.bank_capacity_changed.disconnect(_on_events_bank_capacity_changed)
	_session = null


func _exit_tree() -> void:
	unbind()


func _redraw() -> void:
	_redraw_cells()
	_redraw_counter()


## One cell per stack, in the bank's order: existing cells are reused, extra ones are removed.
func _redraw_cells() -> void:
	var stacks: Array[Dictionary] = _session.bank.stacks()
	var cells: Array[Node] = _grid.get_children()
	for index: int in range(stacks.size(), cells.size()):
		_grid.remove_child(cells[index])
		cells[index].queue_free()
	for index: int in stacks.size():
		var cell: ItemSlotView = null
		if index < cells.size():
			cell = cells[index] as ItemSlotView
		else:
			cell = ITEM_SLOT_SCENE.instantiate() as ItemSlotView
			cell.name = CELL_NAME % index
			_grid.add_child(cell)
		var stack: Dictionary = stacks[index]
		cell.set_item(_session.data.item(stack[STACK_ITEM_KEY]), stack[STACK_COUNT_KEY], stack[STACK_LOCKED_KEY])
	_empty_label.visible = stacks.is_empty()


func _redraw_counter() -> void:
	var used: int = _session.bank.used()
	var capacity: int = _session.bank.capacity()
	_slots_label.text = SLOTS_TEXT % [NumberFormat.format_int(used), NumberFormat.format_int(capacity)]
	_full_label.visible = used >= capacity


func _on_events_bank_changed(_item_id: StringName, _new_count: int, _delta: int) -> void:
	_redraw()


func _on_events_bank_capacity_changed(_used: int, _capacity: int) -> void:
	_redraw()
