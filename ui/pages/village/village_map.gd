class_name VillageMap
extends Control
## Map view of the Village page (docs/01_GDD.md §32, docs/05_INTERFACES.md §7.r): one node (Button) per building placed
## at its `map_pos` (0..1) with icon, name and a status line, the border coloured by `VillageNodeState`. A click emits
## `building_selected`. Display only: it reads the village and the session on every `refresh` and keeps only its nodes.
## Same scheme as `CombatMap` (copied, not shared): a building without a valid `map_pos` goes in a row by its order.

signal building_selected(building_id: StringName)

const LOG_CATEGORY: String = "ui.village_map"
const NODE_SIZE := Vector2(150.0, 72.0)
const ICON_SIZE: int = 24
const ICON_DIR: String = "res://assets/icons/ui/%s.svg"
const BORDER_WIDTH: int = 1
const BORDER_WIDTH_SELECTED: int = 3
const CORNER: float = 6.0
const FIELD_PADDING := Vector2(8.0, 8.0)

var _field: Control = null
var _ids: Array[StringName] = []
var _defs: Dictionary[StringName, Object] = {}
var _nodes: Dictionary[StringName, Button] = {}


func _ready() -> void:
	_ensure_field()


## Creates one node per building id, placed at the `map_pos` of its definition.
func setup(definitions: Object, building_ids: Array[StringName]) -> void:
	_ensure_field()
	for node: Button in _nodes.values():
		_field.remove_child(node)
		node.queue_free()
	_nodes.clear()
	_defs.clear()
	_ids = building_ids.duplicate()
	for i: int in _ids.size():
		var def: Object = definitions.call("village_building", _ids[i])
		if def == null:
			continue
		_defs[_ids[i]] = def
		var node: Button = Button.new()
		node.name = "Node_%s" % _ids[i]
		node.focus_mode = Control.FOCUS_NONE
		node.clip_text = false
		node.expand_icon = true
		node.add_theme_constant_override("icon_max_width", ICON_SIZE)
		node.icon = _icon_of(str(def.get("icon")))
		node.pressed.connect(building_selected.emit.bind(_ids[i]))
		_place(node, _position_of(def, i))
		_field.add_child(node)
		_nodes[_ids[i]] = node


## Updates text, border and selection of every node from the village and the session.
func refresh(village: Object, _session: GameSession, selected: StringName) -> void:
	for id: StringName in _nodes:
		var def: Object = _defs[id]
		var level: int = village.level(id)
		var reason: StringName = VillageNodeState.REASON_OK
		var can: CommandResult = village.can_upgrade(id)
		if not can.ok:
			reason = can.reason
		var state: StringName = VillageNodeState.of(level, village.max_level(), bool(def.get("buildable")), reason)
		var node: Button = _nodes[id]
		node.text = "%s\n%s" % [str(def.get("name")), _status_text(state, level, village, id)]
		_style(node, state, id == selected)


## Node of the building `id`, for tests.
func node(id: StringName) -> Button:
	return _nodes.get(id)


## State of the node of `id` as drawn by the last `refresh`, for tests.
func state_of(id: StringName) -> StringName:
	var node: Button = _nodes.get(id)
	return StringName(node.get_meta(&"state", &"")) if node != null else &""


func _ensure_field() -> void:
	if _field != null:
		return
	_field = Control.new()
	_field.name = "Field"
	add_child(_field)
	_field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_field.offset_left = NODE_SIZE.x / 2.0 + FIELD_PADDING.x
	_field.offset_right = -(NODE_SIZE.x / 2.0 + FIELD_PADDING.x)
	_field.offset_top = NODE_SIZE.y / 2.0 + FIELD_PADDING.y
	_field.offset_bottom = -(NODE_SIZE.y / 2.0 + FIELD_PADDING.y)


func _position_of(def: Object, index: int) -> Vector2:
	var pos: Variant = def.get("map_pos")
	if pos is Vector2 and pos.x >= 0.0 and pos.x <= 1.0 and pos.y >= 0.0 and pos.y <= 1.0:
		return pos
	Log.warn(LOG_CATEGORY, "building '%s' has no valid map_pos, placed in a row" % def.get("id"))
	return Vector2((index + 0.5) / maxi(1, _ids.size()), 0.5)


func _place(node: Button, pos: Vector2) -> void:
	node.anchor_left = pos.x
	node.anchor_right = pos.x
	node.anchor_top = pos.y
	node.anchor_bottom = pos.y
	node.offset_left = -NODE_SIZE.x / 2.0
	node.offset_right = NODE_SIZE.x / 2.0
	node.offset_top = -NODE_SIZE.y / 2.0
	node.offset_bottom = NODE_SIZE.y / 2.0


func _status_text(state: StringName, level: int, village: Object, id: StringName) -> String:
	match state:
		VillageNodeState.PLACEHOLDER:
			return VillageTexts.COMING_SOON_TEXT
		VillageNodeState.MAXED:
			return VillageTexts.MAXED_TEXT
		VillageNodeState.LOCKED:
			var required: int = int(village.next_cost(id).get("requires_woodwright", 0))
			return VillageTexts.REQUIRES_WOODWRIGHT_TEXT % required
		VillageNodeState.UNBUILT:
			return VillageTexts.NODE_UNBUILT_TEXT
		VillageNodeState.READY:
			return VillageTexts.NODE_BUILDABLE_TEXT if level == 0 else VillageTexts.NODE_UPGRADABLE_TEXT
		_:
			return VillageTexts.LEVEL_TEXT % [level, village.max_level()]


func _style(node: Button, state: StringName, selected: bool) -> void:
	node.set_meta(&"state", state)
	var border: Color = UiStyle.GOLD_DIM
	match state:
		VillageNodeState.READY:
			border = UiStyle.GOLD_LIGHT
		VillageNodeState.BUILT, VillageNodeState.MAXED:
			border = UiStyle.GOLD
		VillageNodeState.LOCKED:
			border = UiStyle.BAD
	var width: int = BORDER_WIDTH_SELECTED if selected else BORDER_WIDTH
	var fill: Color = UiStyle.BG_BUTTON_PRESSED if selected else UiStyle.BG_BUTTON
	node.add_theme_stylebox_override("normal", UiStyle.flat(fill, border, width, CORNER))
	node.add_theme_stylebox_override("hover", UiStyle.flat(UiStyle.BG_BUTTON_HOVER, UiStyle.GOLD_LIGHT, width, CORNER))
	node.add_theme_stylebox_override("pressed", UiStyle.flat(UiStyle.BG_BUTTON_PRESSED, border, width, CORNER))
	node.modulate = Color(1, 1, 1, 0.55) if state == VillageNodeState.PLACEHOLDER else Color.WHITE


func _icon_of(icon_name: String) -> Texture2D:
	var path: String = ICON_DIR % icon_name
	if not icon_name.is_empty() and ResourceLoader.exists(path):
		return load(path) as Texture2D
	return load(UiStyle.MISSING_ICON) as Texture2D
