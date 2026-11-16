class_name TravelMap
extends Control
## Travel strip of the Combat page (docs/01_GDD_M24.md §35.11, 05_INTERFACES_M24.md §7.o): a path, the icon of the
## character moving along it and the target (swords for a fight, the icon of the discipline for a node; grey with a
## "Non appresa" marker when the discipline is not learned).
##
## `refresh(state, data, disciplines)` reads `combat.get_state()` (`travel_ms`, `travel_total_ms`, `next`) and draws:
## the position of the icon is `1 - travel_ms / travel_total_ms`. Visible only while travelling. No game state here.

const HEIGHT: float = 64.0
const ICON_SIDE: float = 40.0
const PATH_THICKNESS: float = 4.0
const EDGE: float = 8.0
const SWORD_ICON: String = "sword"
const PLAYER_ICON: String = "user"

var _path: ColorRect = null
var _icon: TextureRect = null
var _target: TextureRect = null
var _label: Label = null
var _lock: Label = null
var _progress: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(0, HEIGHT)
	_path = ColorRect.new()
	_path.name = "TravelPath"
	_path.color = UiStyle.GOLD_DIM
	_path.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_path)
	_icon = _make_icon("TravelIcon")
	_icon.texture = UiStyle.icon(PLAYER_ICON)
	_target = _make_icon("TravelTarget")
	_label = Label.new()
	_label.name = "TravelLabel"
	_label.theme_type_variation = &"MutedLabel"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_lock = Label.new()
	_lock.name = "TravelLock"
	_lock.text = CombatTexts.TRAVEL_LOCKED_TEXT
	_lock.add_theme_color_override("font_color", UiStyle.BAD)
	_lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lock.visible = false
	add_child(_lock)
	resized.connect(_layout)
	_layout()


## Draws the travel in `state` (combat.get_state()); `disciplines` answers `is_learned(skill_id)`.
func refresh(state: Dictionary, data: GameData, disciplines: Object) -> void:
	var total: int = int(state.get("travel_total_ms", 0))
	var left: int = int(state.get("travel_ms", 0))
	visible = state.get("state", &"") == CombatTexts.STATE_TRAVEL
	_progress = clampf(1.0 - float(left) / float(total), 0.0, 1.0) if total > 0 else 0.0
	var next: Dictionary = state.get("next", {}) as Dictionary
	var skill_id: StringName = StringName(next.get("skill", &""))
	var is_node: bool = StringName(next.get("kind", &"fight")) == &"node" and skill_id != &""
	var skill: SkillDef = data.skill(skill_id) if is_node else null
	var learned: bool = true
	if is_node and skill != null:
		learned = bool(disciplines.call("is_learned", skill_id))
		_target.texture = ItemSlotView.icon_of(skill.icon)
		_label.text = CombatTexts.TRAVEL_NODE_TEXT % skill.name
	else:
		_target.texture = UiStyle.icon(SWORD_ICON)
		_label.text = CombatTexts.TRAVEL_FIGHT_TEXT
	_target.modulate = Color.WHITE if learned else UiStyle.TEXT_DISABLED
	_target.tooltip_text = "" if learned else CombatTexts.TRAVEL_LOCKED_TIP
	_lock.visible = not learned
	_layout()


## Position of the icon along the path, 0 (start) to 1 (target), as last drawn.
func progress() -> float:
	return _progress


func _make_icon(node_name: String) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = node_name
	rect.custom_minimum_size = Vector2(ICON_SIDE, ICON_SIDE)
	rect.size = Vector2(ICON_SIDE, ICON_SIDE)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(rect)
	return rect


func _layout() -> void:
	if _path == null:
		return
	var start_x: float = EDGE
	var end_x: float = maxf(start_x, size.x - EDGE - ICON_SIDE)
	var mid_y: float = (HEIGHT - ICON_SIDE) * 0.5
	_path.position = Vector2(start_x + ICON_SIDE * 0.5, HEIGHT * 0.5 - PATH_THICKNESS * 0.5)
	_path.size = Vector2(maxf(0.0, end_x - start_x), PATH_THICKNESS)
	_icon.position = Vector2(lerpf(start_x, end_x, _progress), mid_y)
	_target.position = Vector2(end_x, mid_y)
	_label.position = Vector2(start_x, 0.0)
	_lock.position = Vector2(maxf(start_x, end_x - _lock.size.x), HEIGHT - 20.0)
