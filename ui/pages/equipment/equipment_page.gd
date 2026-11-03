class_name EquipmentPage
extends Page
## Equipment page (docs/01_GDD.md §9), route `equipment`: the 12 slots (tools included) with the worn piece (name in
## the rarity color, "+N" of the upgrade) and "Rimuovi", the weapon setup derived from the pair of weapons, the
## chosen food (heal, quantity in the bank, "Togli") and the summary of the stats with the sources of each one
## (`modifiers.breakdown`).
##
## Every redraw reads the session: `equipment.get_uid` / `setup_def` / `get_food`, `armory.get_instance`,
## `bank.get_count`, the stat names, formats and totals from `data.stats` and `modifiers`. Actions are equipment
## commands (`unequip`, `set_food`); a refused command shows its reason. The summary lists the stats that have at
## least one source in the global context. Equipping happens from the Armory page. The page keeps only references
## to its own nodes.

const TITLE_TEXT: String = "Equipaggiamento"
const SLOTS_TITLE_TEXT: String = "Slot"
const FOOD_TITLE_TEXT: String = "Cibo"
const SETUP_TITLE_TEXT: String = "Assetto"
const UNARMED_TEXT: String = "Mani nude"
const STATS_TITLE_TEXT: String = "Statistiche"
const EMPTY_SLOT_TEXT: String = "Vuoto"
const NO_FOOD_TEXT: String = "Nessun cibo scelto"
const FOOD_HEAL_TEXT: String = "Cura %s punti vita"
const FOOD_COUNT_TEXT: String = "In bank: %s"
const FOOD_EXHAUSTED_TEXT: String = "Esaurito"
const REMOVE_TEXT: String = "Rimuovi"
const CLEAR_FOOD_TEXT: String = "Togli"
const REFUSED_TEXTS: Dictionary[StringName, String] = {
	Reasons.UNKNOWN_ID: "Voce non valida.",
	Reasons.SLOT_EMPTY: "Lo slot è già vuoto.",
	Reasons.COMBAT_ACTIVE: "Non puoi cambiare arma durante il combattimento.",
	Reasons.ARMORY_FULL: "L'Armeria è piena: non c'è posto per il pezzo.",
	Reasons.NOT_FOOD: "Questo oggetto non è un cibo.",
	Reasons.NOT_ENOUGH_ITEMS: "Non ci sono abbastanza oggetti.",
}
const REFUSED_TEXT_DEFAULT: String = "Operazione non riuscita."
const MARGIN: int = 16
const SECTION_SEPARATION: int = 12
const ROW_SEPARATION: int = 12
const SLOT_NAME_WIDTH: int = 190
const CELL_SIZE := Vector2(48, 48)
const BUTTON_WIDTH: int = 110
const ROW_NAME: String = "Row_%s"

var _session: GameSession = null
## Slot id -> {"cell": ItemSlotView, "name": Label, "button": Button} (presentation references).
var _slot_rows: Dictionary[StringName, Dictionary] = {}
var _setup_label: Label = null
var _food_cell: ItemSlotView = null
var _food_name: Label = null
var _food_info: Label = null
var _food_button: Button = null

@onready var _margin: MarginContainer = %Margin
@onready var _content: VBoxContainer = %Content
@onready var _main: HBoxContainer = %Main
@onready var _left: VBoxContainer = %Left
@onready var _title_label: Label = %TitleLabel
@onready var _message_label: Label = %MessageLabel
@onready var _slots_box: VBoxContainer = %SlotsBox
@onready var _food_box: VBoxContainer = %FoodBox
@onready var _setup_box: VBoxContainer = %SetupBox
@onready var _stats_title: Label = %StatsTitle
@onready var _stats_text: RichTextLabel = %StatsText


func _ready() -> void:
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		_margin.add_theme_constant_override(side, MARGIN)
	for box: Container in [_content, _main, _left, _slots_box, _setup_box, _food_box]:
		box.add_theme_constant_override("separation", SECTION_SEPARATION)
	_title_label.text = TITLE_TEXT
	_stats_title.text = STATS_TITLE_TEXT
	_message_label.add_theme_color_override("font_color", UiStyle.BAD)


## Draws the equipment of `session` and follows its changes.
func bind(session: GameSession) -> void:
	unbind()
	_session = session
	_session.events.equipment_changed.connect(_on_equipment_changed)
	_session.events.food_changed.connect(_on_food_changed)
	_session.events.modifiers_changed.connect(_on_modifiers_changed)
	_session.events.bank_changed.connect(_on_bank_changed)
	_session.events.armory_changed.connect(_on_armory_changed)
	_build()
	_refresh()


## Disconnects every event connected in `bind`.
func unbind() -> void:
	if _session != null and is_instance_valid(_session):
		var events: GameEvents = _session.events
		if events.equipment_changed.is_connected(_on_equipment_changed):
			events.equipment_changed.disconnect(_on_equipment_changed)
		if events.food_changed.is_connected(_on_food_changed):
			events.food_changed.disconnect(_on_food_changed)
		if events.modifiers_changed.is_connected(_on_modifiers_changed):
			events.modifiers_changed.disconnect(_on_modifiers_changed)
		if events.armory_changed.is_connected(_on_armory_changed):
			events.armory_changed.disconnect(_on_armory_changed)
		if events.bank_changed.is_connected(_on_bank_changed):
			events.bank_changed.disconnect(_on_bank_changed)
	_session = null


func _exit_tree() -> void:
	unbind()


# --- Build (once per bind) --------------------------------------------------------------------------------------

func _build() -> void:
	for box: Container in [_slots_box, _setup_box, _food_box]:
		for child: Node in box.get_children():
			box.remove_child(child)
			child.queue_free()
	_slot_rows.clear()
	_section_title(_slots_box, SLOTS_TITLE_TEXT)
	for slot: StringName in Equipment.SLOTS:
		_slot_rows[slot] = _new_slot_row(slot)
	_section_title(_setup_box, SETUP_TITLE_TEXT)
	_setup_label = Label.new()
	_setup_label.name = "SetupLabel"
	_setup_box.add_child(_setup_label)
	_section_title(_food_box, FOOD_TITLE_TEXT)
	_build_food_row()


func _section_title(parent: Container, text: String) -> void:
	var label: Label = Label.new()
	label.theme_type_variation = &"HeaderLabel"
	label.text = text
	parent.add_child(label)


func _new_row(parent: Container, row_name: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = row_name
	row.add_theme_constant_override("separation", ROW_SEPARATION)
	parent.add_child(row)
	return row


func _new_cell(row: HBoxContainer) -> ItemSlotView:
	var cell: ItemSlotView = preload("res://ui/components/item_slot/item_slot.tscn").instantiate() as ItemSlotView
	cell.name = "Cell"
	cell.custom_minimum_size = CELL_SIZE
	row.add_child(cell)
	return cell


func _new_button(row: HBoxContainer, text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.x = BUTTON_WIDTH
	row.add_child(button)
	return button


func _new_slot_row(slot: StringName) -> Dictionary:
	var row: HBoxContainer = _new_row(_slots_box, ROW_NAME % slot)
	var slot_label: Label = Label.new()
	slot_label.name = "SlotLabel"
	slot_label.text = EquipmentStatsText.slot_text(slot, _session.data)
	slot_label.theme_type_variation = &"MutedLabel"
	slot_label.custom_minimum_size.x = SLOT_NAME_WIDTH
	row.add_child(slot_label)
	var cell: ItemSlotView = _new_cell(row)
	var item_label: Label = Label.new()
	item_label.name = "ItemLabel"
	item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(item_label)
	var button: Button = _new_button(row, REMOVE_TEXT)
	button.name = "RemoveButton"
	button.pressed.connect(_on_remove_pressed.bind(slot))
	return {"cell": cell, "name": item_label, "button": button}


func _build_food_row() -> void:
	var row: HBoxContainer = _new_row(_food_box, ROW_NAME % "food")
	_food_cell = _new_cell(row)
	var info: VBoxContainer = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	_food_name = Label.new()
	_food_name.name = "FoodName"
	info.add_child(_food_name)
	_food_info = Label.new()
	_food_info.name = "FoodInfo"
	_food_info.theme_type_variation = &"MutedLabel"
	info.add_child(_food_info)
	_food_button = _new_button(row, CLEAR_FOOD_TEXT)
	_food_button.name = "ClearFoodButton"
	_food_button.pressed.connect(_on_clear_food_pressed)


# --- Refresh (reads the session) --------------------------------------------------------------------------------

func _refresh() -> void:
	if _session == null:
		return
	for slot: StringName in _slot_rows:
		_refresh_slot(slot)
	var setup: SetupDef = _session.equipment.setup_def()
	_setup_label.text = setup.name if setup != null else UNARMED_TEXT
	_refresh_food()
	_stats_text.text = EquipmentStatsText.summary(_session)


func _refresh_slot(slot: StringName) -> void:
	var row: Dictionary = _slot_rows[slot]
	var inst: ItemInstance = _session.armory.get_instance(_session.equipment.get_uid(slot))
	var item: ItemDef = _item_of(inst.base_id) if inst != null else null
	var cell: ItemSlotView = row["cell"]
	var name_label: Label = row["name"]
	if item == null:
		cell.clear()
		name_label.text = EMPTY_SLOT_TEXT
		name_label.remove_theme_color_override("font_color")
	else:
		cell.set_item(item, 0)
		name_label.text = ArmoryTexts.piece_name(inst, item)
		name_label.add_theme_color_override("font_color", UiStyle.rarity_color(inst.rarity))
	(row["button"] as Button).disabled = item == null


func _refresh_food() -> void:
	var item: ItemDef = _item_of(_session.equipment.get_food())
	_food_button.disabled = item == null
	if item == null:
		_food_cell.clear()
		_food_name.text = NO_FOOD_TEXT
		_food_info.text = ""
		return
	var count: int = _session.bank.get_count(item.id)
	_food_cell.set_item(item, count)
	_food_name.text = item.name
	var stock: String = FOOD_COUNT_TEXT % NumberFormat.format_int(count) if count > 0 else FOOD_EXHAUSTED_TEXT
	_food_info.text = "%s. %s" % [FOOD_HEAL_TEXT % NumberFormat.format_int(item.food_heal), stock]


# --- Actions ----------------------------------------------------------------------------------------------------

func _show_result(result: CommandResult) -> void:
	_message_label.visible = not result.ok
	if not result.ok:
		_message_label.text = REFUSED_TEXTS.get(result.reason, REFUSED_TEXT_DEFAULT)
	_refresh()


func _on_remove_pressed(slot: StringName) -> void:
	if _session != null:
		_show_result(_session.equipment.unequip(slot))


func _on_clear_food_pressed() -> void:
	if _session != null:
		_show_result(_session.equipment.set_food(&""))


func _on_equipment_changed(_slot_id: StringName, _uid: int) -> void:
	_refresh()


func _on_food_changed(_item_id: StringName) -> void:
	_refresh()


func _on_modifiers_changed() -> void:
	_refresh()


func _on_armory_changed(_uid: int, _change: StringName) -> void:
	_refresh()


func _on_bank_changed(_item_id: StringName, _new_count: int, _delta: int) -> void:
	_refresh()


## The definition of `item_id`; null for the empty id (the data logs an error for unknown ids).
func _item_of(item_id: StringName) -> ItemDef:
	return _session.data.item(item_id) if item_id != &"" else null
