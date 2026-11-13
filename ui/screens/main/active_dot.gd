class_name ActiveDot
extends ColorRect
## Small pulsing dot on the left of a sidebar entry whose work is running now (M16-06, V9): the skill action in
## progress or the combat. Presentation only: the sidebar tells it to show or hide; it keeps its tween.

const SIDE: float = 7.0
const LEFT: float = 1.0
const PULSE_MIN_ALPHA: float = 0.25
const PULSE_SEC: float = 0.8

var _tween: Tween = null


func _init() -> void:
	name = "ActiveDot"
	color = UiStyle.GOOD
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = LEFT
	offset_right = LEFT + SIDE
	offset_top = -SIDE / 2.0
	offset_bottom = SIDE / 2.0
	visible = false


## Shows the dot (and starts the pulse) or hides it (and stops the pulse).
func set_active(active: bool) -> void:
	if active == visible and (not active or is_pulsing()):
		return
	visible = active
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	modulate.a = 1.0
	if active and is_inside_tree():
		_tween = create_tween().set_loops()
		_tween.tween_property(self, "modulate:a", PULSE_MIN_ALPHA, PULSE_SEC)
		_tween.tween_property(self, "modulate:a", 1.0, PULSE_SEC)


func is_pulsing() -> bool:
	return _tween != null and _tween.is_valid()


func _enter_tree() -> void:
	if visible and not is_pulsing():
		set_active(false)
		set_active(true)
