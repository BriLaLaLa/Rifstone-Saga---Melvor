class_name ForgeBench
extends VBoxContainer
## "Banco del fabbro" section of the Forging page (docs/UI_GDR.md): the player picks a piece (worn or in the Armory) and
## works it with the three tabs Raffina (RefineBox), Castoni (SocketBox) and Valute (CurrencyBox). The commands are the
## same as before the move (`armory.upgrade`, `socket_stone`, `clear_socket`, `use_currency`); a refused command shows
## its reason in Italian and changes nothing.
##
## It keeps the session reference and presentation state only (the uid picked). Every redraw reads the armory, the
## equipment and the bank; the redraw is driven by the events connected in `bind` and disconnected in `unbind`.

const TITLE_TEXT: String = "Banco del fabbro"
const HINT_TEXT: String = "Scegli un pezzo, indossato o nell'Armeria: poi raffinalo, incastona le pietre o usa le valute."
const WORN_TEXT: String = "Indossati"
const ARMORY_TEXT: String = "Nell'Armeria"
const EMPTY_TEXT: String = "Nessun pezzo da lavorare: forgia o compra dei pezzi."
const NOTHING_PICKED_TEXT: String = "Nessun pezzo scelto."
const CELL_NAME: String = "Cell%d"
const SEPARATION: int = 8

var _session: GameSession = null
var _uid: int = 0
## Piece the refine box was last opened for (a new piece unticks the Seal).
var _refine_uid: int = 0

var _worn_title: Label = null
var _worn_grid: HFlowContainer = null
var _armory_title: Label = null
var _armory_grid: HFlowContainer = null
var _empty_label: Label = null
var _piece_name: Label = null
var _piece_subtitle: Label = null
var _tabs: TabContainer = null
var _refine_box: RefineBox = null
var _socket_box: SocketBox = null
var _currency_box: CurrencyBox = null
var _message_label: Label = null


func _ready() -> void:
	add_theme_constant_override("separation", SEPARATION)
	_add_label(TITLE_TEXT, &"TitleLabel")
	_add_label(HINT_TEXT, &"MutedLabel")
	_worn_title = _add_label(WORN_TEXT, &"HeaderLabel")
	_worn_grid = _add_grid()
	_armory_title = _add_label(ARMORY_TEXT, &"HeaderLabel")
	_armory_grid = _add_grid()
	_empty_label = _add_label(EMPTY_TEXT, &"MutedLabel")
	_piece_name = _add_label("", &"HeaderLabel")
	_piece_name.name = "PieceName"
	_piece_subtitle = _add_label("", &"MutedLabel")
	_piece_subtitle.name = "PieceSubtitle"
	_tabs = TabContainer.new()
	_tabs.name = "Tabs"
	_tabs.custom_minimum_size.y = UiStyle.PIECE_TABS_MIN_HEIGHT
	add_child(_tabs)
	_refine_box = _tab_box(RefineBox.new(), "RefineBox") as RefineBox
	_socket_box = _tab_box(SocketBox.new(), "SocketBox") as SocketBox
	_currency_box = _tab_box(CurrencyBox.new(), "CurrencyBox") as CurrencyBox
	for i: int in ArmoryTexts.BENCH_TAB_TITLES.size():
		_tabs.set_tab_title(i, ArmoryTexts.BENCH_TAB_TITLES[i])
	_message_label = _add_label("", &"")
	_message_label.name = "MessageLabel"
	_message_label.visible = false
	_refine_box.refine_requested.connect(_on_refine_requested)
	_socket_box.stone_requested.connect(_on_stone_requested)
	_socket_box.clear_requested.connect(_on_clear_requested)
	_currency_box.currency_requested.connect(_on_currency_requested)


## Draws the bench for `session` and follows its changes.
func bind(session: GameSession) -> void:
	unbind()
	_session = session
	for sig: Signal in _signals(session.events):
		sig.connect(_redraw_from_event)
	session.events.item_upgraded.connect(_on_item_upgraded)
	_redraw()


## Disconnects every event connected in `bind`.
func unbind() -> void:
	if _session != null and is_instance_valid(_session):
		for sig: Signal in _signals(_session.events):
			if sig.is_connected(_redraw_from_event):
				sig.disconnect(_redraw_from_event)
		if _session.events.item_upgraded.is_connected(_on_item_upgraded):
			_session.events.item_upgraded.disconnect(_on_item_upgraded)
	_session = null
	_uid = 0


func _exit_tree() -> void:
	unbind()


## Picks the piece `uid` to work on (0 = none).
func select(uid: int) -> void:
	_uid = uid
	_message_label.visible = false
	_redraw()


## Uid of the piece on the bench; 0 if none.
func selected_uid() -> int:
	return _uid


func _signals(events: GameEvents) -> Array[Signal]:
	return [events.armory_changed, events.equipment_changed, events.bank_changed, events.gold_changed,
			events.item_salvaged]


func _redraw_from_event(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	_redraw()


func _redraw() -> void:
	if _session == null or not is_inside_tree():
		return
	var worn: int = _fill_grids()
	_worn_title.visible = worn > 0
	_worn_grid.visible = worn > 0
	var in_armory: int = _armory_grid.get_child_count()
	_armory_title.visible = in_armory > 0
	_armory_grid.visible = in_armory > 0
	_empty_label.visible = worn + in_armory == 0
	var inst: ItemInstance = _session.armory.get_instance(_uid) if _uid != 0 else null
	var base: ItemDef = _session.data.item(inst.base_id) if inst != null else null
	if base == null or base.equip == null or _is_unique_tool(_uid):
		_uid = 0
		_piece_name.text = NOTHING_PICKED_TEXT
		_piece_name.remove_theme_color_override("font_color")
		_piece_subtitle.text = ""
		_tabs.visible = false
		return
	_piece_name.text = ArmoryTexts.piece_name(inst, base)
	_piece_name.add_theme_color_override("font_color", UiStyle.rarity_color(inst.rarity))
	_piece_subtitle.text = ArmoryTexts.card_subtitle(inst, base, _session.data)
	_tabs.visible = true
	_refine_box.show_for(_session, _uid, _refine_uid != _uid)
	_refine_uid = _uid
	_refine_box.visible = true
	_socket_box.show_for(_session, _uid)
	_currency_box.show_for(_session, _uid)


## Rebuilds the two grids (worn pieces, pieces in the Armory); returns how many worn pieces are shown.
func _fill_grids() -> int:
	for grid: HFlowContainer in [_worn_grid, _armory_grid]:
		for child: Node in grid.get_children():
			grid.remove_child(child)
			child.queue_free()
	var worn: int = 0
	for inst: ItemInstance in _session.armory.instances():
		var base: ItemDef = _session.data.item(inst.base_id)
		if base == null or base.equip == null or _is_unique_tool(inst.uid):
			continue
		var is_worn: bool = _session.armory.is_worn(inst.uid)
		var cell: InventoryCell = EquipmentInventory.CELL_SCENE.instantiate() as InventoryCell
		cell.name = CELL_NAME % inst.uid
		(_worn_grid if is_worn else _armory_grid).add_child(cell)
		cell.set_piece(inst, base, inst.uid == _uid)
		cell.pressed.connect(select)
		worn += 1 if is_worn else 0
	return worn


## Unique tools stay in their slot and are refined from the page of their skill (M10).
func _is_unique_tool(uid: int) -> bool:
	return _session.equipment.slot_of(uid).begins_with(EquipmentStatsText.TOOL_SLOT_PREFIX)


# --- Commands -----------------------------------------------------------------------------------------------------

func _send(command: Callable, refused_text: Callable) -> void:
	if _session == null or _uid == 0:
		return
	_message_label.visible = false
	var result: CommandResult = command.call() as CommandResult
	if not result.ok:
		_message_label.visible = true
		_message_label.add_theme_color_override("font_color", UiStyle.BAD)
		_message_label.text = refused_text.call(result.reason) as String
	_redraw()


func _on_refine_requested(use_seal: bool) -> void:
	_send(func() -> CommandResult: return _session.armory.upgrade(_uid, use_seal), EquipmentMessages.refused)


func _on_stone_requested(stone_id: StringName) -> void:
	_send(func() -> CommandResult: return _session.armory.socket_stone(_uid, stone_id), SocketTexts.refused)


func _on_clear_requested(index: int) -> void:
	_send(func() -> CommandResult: return _session.armory.clear_socket(_uid, index), SocketTexts.refused)


func _on_currency_requested(currency_id: StringName) -> void:
	_send(func() -> CommandResult: return _session.armory.use_currency(_uid, currency_id), SocketTexts.refused)


func _on_item_upgraded(uid: int, success: bool, new_level: int) -> void:
	_message_label.text = EquipmentMessages.upgraded_text(_session, uid, success, new_level)
	_message_label.add_theme_color_override("font_color", UiStyle.GOOD if success else UiStyle.GOLD_LIGHT)
	_message_label.visible = true


# --- Building blocks ----------------------------------------------------------------------------------------------

func _add_label(text: String, variation: StringName) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if variation != &"":
		label.theme_type_variation = variation
	add_child(label)
	return label


func _add_grid() -> HFlowContainer:
	var grid: HFlowContainer = HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", UiStyle.ARMORY_GRID_SEPARATION)
	grid.add_theme_constant_override("v_separation", UiStyle.ARMORY_GRID_SEPARATION)
	add_child(grid)
	return grid


func _tab_box(box: VBoxContainer, box_name: String) -> VBoxContainer:
	var tab: VBoxContainer = VBoxContainer.new()
	tab.name = box_name + "Tab"
	_tabs.add_child(tab)
	box.name = box_name
	tab.add_child(box)
	return box
