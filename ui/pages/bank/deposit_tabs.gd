class_name DepositTabs
extends TabContainer
## The two tabs of the Deposit page (docs/05_INTERFACES.md §7.w, docs/01_GDD.md §7): "Oggetti" (the first child, the
## item grid built by BankPage) and "Equipaggiamento" (built here: the pieces of `armory.instances()` not worn).
## Both draw `deposit.capacity()` boxes: the ones of their own items, then `OccupiedCell` nodes for the boxes the other
## tab uses and `EmptyCell` nodes for the free ones. The cells are decorative: the numbers come from the session at
## every `redraw`, no data is copied. A piece cell is the same `InventoryCell` of the Equipment page.

const OBJECTS_TITLE: String = "Oggetti"
const EQUIPMENT_TITLE: String = "Equipaggiamento"
const EQUIPMENT_HINT: String = "Questi pezzi usano le stesse caselle degli oggetti. Si equipaggiano dalla pagina Equipaggiamento."
const EMPTY_TEXT: String = "Nessun pezzo non indossato."
const OCCUPIED_TOOLTIP: String = "Casella usata dall'altra scheda."
const PIECE_CELL_NAME: String = "PieceCell%d"
const EMPTY_CELL: String = "EmptyCell%d"
const OCCUPIED_CELL: String = "OccupiedCell%d"
const CELL_SCENE: PackedScene = preload("res://ui/pages/equipment/inventory_cell.tscn")

var _grid: HFlowContainer = null
var _empty_label: Label = null


func _ready() -> void:
	var tab: PanelContainer = PanelContainer.new()
	tab.name = "EquipmentTab"
	tab.theme_type_variation = &"HudPanel"
	var box: VBoxContainer = VBoxContainer.new()
	tab.add_child(box)
	var hint: Label = Label.new()
	hint.name = "HintLabel"
	hint.text = EQUIPMENT_HINT
	hint.theme_type_variation = &"MutedLabel"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	_empty_label = Label.new()
	_empty_label.name = "EmptyLabel"
	_empty_label.text = EMPTY_TEXT
	_empty_label.theme_type_variation = &"MutedLabel"
	box.add_child(_empty_label)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_grid = HFlowContainer.new()
	_grid.name = "EquipGrid"
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", UiStyle.BANK_GRID_SEPARATION)
	_grid.add_theme_constant_override("v_separation", UiStyle.BANK_GRID_SEPARATION)
	scroll.add_child(_grid)
	add_child(tab)
	set_tab_title(0, OBJECTS_TITLE)
	set_tab_title(get_tab_count() - 1, EQUIPMENT_TITLE)


## The grid of the "Equipaggiamento" tab (for the tests).
func equipment_grid() -> HFlowContainer:
	return _grid


## Redraws the "Equipaggiamento" tab from `session`: one cell per piece not worn, then the other boxes up to the capacity.
func redraw(session: GameSession) -> void:
	if _grid == null:
		return
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var shown: int = 0
	for inst: ItemInstance in session.armory.instances():
		var base: ItemDef = session.data.item(inst.base_id)
		if session.armory.is_worn(inst.uid) or base == null:
			continue
		var cell: InventoryCell = CELL_SCENE.instantiate() as InventoryCell
		cell.name = PIECE_CELL_NAME % inst.uid
		_grid.add_child(cell)
		cell.set_piece(inst, base, false)
		cell.tooltip_text = base.name
		shown += 1
	_empty_label.visible = shown == 0
	var other: int = maxi(0, session.deposit.used() - shown)
	for index: int in other:
		_add_placeholder(OCCUPIED_CELL % index, true)
	for index: int in session.deposit.free_slots():
		_add_placeholder(EMPTY_CELL % index, false)


func _add_placeholder(cell_name: String, occupied: bool) -> void:
	var cell: PanelContainer = PanelContainer.new()
	cell.name = cell_name
	cell.custom_minimum_size = UiStyle.ARMORY_CELL_SIZE
	cell.add_theme_stylebox_override("panel", UiStyle.flat(UiStyle.BG_FIELD,
			UiStyle.GOLD_DIM if occupied else UiStyle.GOLD_FAINT, 1, 3.0))
	if occupied:
		cell.tooltip_text = OCCUPIED_TOOLTIP
	_grid.add_child(cell)


## "Riordina" (GDD §29): `Bank.sort` on the "Oggetti" tab, `Armory.sort` on the "Equipaggiamento" tab (model commands).
func sort_open_tab(session: GameSession) -> void:
	if current_tab == get_tab_count() - 1:
		session.armory.sort()
		redraw(session)
	else:
		session.bank.sort()
