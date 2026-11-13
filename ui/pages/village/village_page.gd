class_name VillagePage
extends Page
## Village page (docs/01_GDD.md §30, docs/05_INTERFACES.md §7.t), route `village`: one box per building of
## `village.buildings()` (the buildable ones and the "In arrivo" placeholders) in a grid that wraps.
## The upgrade is the `village.upgrade` command (one call per click); a refusal shows its reason in Italian.
## The page redraws from the village, bank, wallet and skills getters on `village_upgraded`, `bank_changed`,
## `gold_changed` and `level_up`. Two views of the same state (docs/01_GDD.md §32): Map (default; `VillageMap` and a
## detail panel with the box of the selected building) and List (the grid). The view and the selection are local to
## the page and not saved; "Apri" asks for the building's page with `page_requested`. Only references to own nodes.

signal page_requested(page_id: StringName)

const OPEN_BUTTON_NAME: String = "OpenButton"
const BOX_SCENE: PackedScene = preload("res://ui/pages/village/village_box.tscn")
const VILLAGE_FIELD: StringName = &"village"
const UPGRADED_SIGNAL: StringName = &"village_upgraded"
const MARGIN: int = 16
const SECTION_SEPARATION: int = 12
const GRID_SEPARATION: int = 12

var _session: GameSession = null
## The session's Village (5.27), used through its contract signatures only; a duck-typed reference so that the page
## can also be bound to a stub with the same signatures.
var _village: Object = null
var _boxes: Dictionary[StringName, VillageBox] = {}
var _definitions: Object = null
## View state (not game state): the selected building and the detail widgets.
var _selected: StringName = &""
var _detail_box: VillageBox = null
var _open_button: Button = null

@onready var _margin: MarginContainer = %Margin
@onready var _content: VBoxContainer = %Content
@onready var _title_label: Label = %TitleLabel
@onready var _gold_label: Label = %GoldLabel
@onready var _message_label: Label = %MessageLabel
@onready var _map_button: Button = %MapButton
@onready var _list_button: Button = %ListButton
@onready var _map_view: HBoxContainer = %MapView
@onready var _map: VillageMap = %Map
@onready var _detail: VBoxContainer = %Detail
@onready var _list_scroll: ScrollContainer = %Scroll
@onready var _grid: GridContainer = %Grid


func _ready() -> void:
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		_margin.add_theme_constant_override(side, MARGIN)
	_content.add_theme_constant_override("separation", SECTION_SEPARATION)
	_grid.add_theme_constant_override("h_separation", GRID_SEPARATION)
	_grid.add_theme_constant_override("v_separation", GRID_SEPARATION)
	_title_label.text = VillageTexts.TITLE_TEXT
	_message_label.add_theme_color_override("font_color", UiStyle.BAD)
	var group: ButtonGroup = ButtonGroup.new()
	_map_button.button_group = group
	_list_button.button_group = group
	_map_button.text = VillageTexts.VIEW_MAP_TEXT
	_list_button.text = VillageTexts.VIEW_LIST_TEXT
	_map_button.button_pressed = true
	_map_button.pressed.connect(_show_view.bind(true))
	_list_button.pressed.connect(_show_view.bind(false))
	_map.building_selected.connect(_on_building_selected)


## Draws the village of `session` (nothing if the session has none yet) and follows its changes.
func bind(session: GameSession) -> void:
	bind_with(session, session.get(VILLAGE_FIELD), session.data)


## Same as `bind`, with the village and the source of the building definitions (`village_building(id)`) given:
## used by `bind` and by the smoke test with a stub of the same signatures.
func bind_with(session: GameSession, village: Object, definitions: Object) -> void:
	unbind()
	_session = session
	_village = village
	if _village == null:
		return
	var events: GameEvents = _session.events
	events.bank_changed.connect(_on_bank_changed)
	events.gold_changed.connect(_on_gold_changed)
	events.level_up.connect(_on_level_up)
	if events.has_signal(UPGRADED_SIGNAL):
		events.connect(UPGRADED_SIGNAL, _on_village_upgraded)
	_definitions = definitions
	_build_boxes(definitions)
	var ids: Array[StringName] = _village.buildings()
	_map.setup(definitions, ids)
	_selected = ids[0] if not ids.is_empty() else &""
	_build_detail()
	_refresh()


## Disconnects every event connected in `bind`.
func unbind() -> void:
	if _session != null and is_instance_valid(_session):
		var events: GameEvents = _session.events
		if events.bank_changed.is_connected(_on_bank_changed):
			events.bank_changed.disconnect(_on_bank_changed)
		if events.gold_changed.is_connected(_on_gold_changed):
			events.gold_changed.disconnect(_on_gold_changed)
		if events.level_up.is_connected(_on_level_up):
			events.level_up.disconnect(_on_level_up)
		if events.has_signal(UPGRADED_SIGNAL) and events.is_connected(UPGRADED_SIGNAL, _on_village_upgraded):
			events.disconnect(UPGRADED_SIGNAL, _on_village_upgraded)
	_session = null
	_village = null
	_definitions = null


func _exit_tree() -> void:
	unbind()


func _build_boxes(definitions: Object) -> void:
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_boxes.clear()
	for building_id: StringName in _village.buildings():
		var def: Object = definitions.call("village_building", building_id)
		if def == null:
			continue
		var box: VillageBox = BOX_SCENE.instantiate()
		_grid.add_child(box)
		box.setup(def)
		box.upgrade_requested.connect(_on_upgrade_requested)
		_boxes[building_id] = box


func _refresh() -> void:
	if _session == null or _village == null:
		return
	_gold_label.text = VillageTexts.GOLD_TEXT % NumberFormat.format_int(_session.wallet.get_gold())
	for box: VillageBox in _boxes.values():
		box.refresh(_village, _session)
	_map.refresh(_village, _session, _selected)
	if _detail_box != null:
		_detail_box.refresh(_village, _session)
	if _open_button != null:
		_open_button.disabled = _village.level(_selected) < 1
		_open_button.tooltip_text = VillageTexts.OPEN_LOCKED_TEXT if _open_button.disabled else ""


func _on_upgrade_requested(building_id: StringName) -> void:
	if _village == null:
		return
	var result: CommandResult = _village.upgrade(building_id)
	_message_label.visible = not result.ok
	if not result.ok:
		_message_label.text = VillageTexts.refused(result.reason)
	_refresh()


func _on_village_upgraded(_building_id: StringName, _new_level: int) -> void:
	_refresh()


func _on_bank_changed(_item_id: StringName, _new_count: int, _delta: int) -> void:
	_refresh()


func _on_gold_changed(_new_amount: int, _delta: int) -> void:
	_refresh()


func _on_level_up(_skill_id: StringName, _new_level: int) -> void:
	_refresh()


func _show_view(map_view: bool) -> void:
	_map_view.visible = map_view
	_list_scroll.visible = not map_view


func _on_building_selected(building_id: StringName) -> void:
	_selected = building_id
	_build_detail()
	_refresh()


## Recreates the detail panel for `_selected`: a VillageBox (same component as the list) and, for a building with a
## page, the "Apri" button.
func _build_detail() -> void:
	for child: Node in _detail.get_children():
		_detail.remove_child(child)
		child.queue_free()
	_detail_box = null
	_open_button = null
	var def: Object = _definitions.call("village_building", _selected) if _definitions != null else null
	if def == null:
		return
	_detail_box = BOX_SCENE.instantiate()
	_detail.add_child(_detail_box)
	_detail_box.setup(def)
	_detail_box.name = "Detail_%s" % _selected
	_detail_box.upgrade_requested.connect(_on_upgrade_requested)
	var raw_page: Variant = def.get("page")
	var page: StringName = StringName(raw_page) if raw_page != null else &""
	if page == &"":
		return
	_open_button = Button.new()
	_open_button.name = OPEN_BUTTON_NAME
	_open_button.focus_mode = Control.FOCUS_NONE
	_open_button.text = VillageTexts.OPEN_TEXTS.get(page, VillageTexts.OPEN_DEFAULT_TEXT)
	_open_button.pressed.connect(func() -> void: page_requested.emit(page))
	_detail.add_child(_open_button)
