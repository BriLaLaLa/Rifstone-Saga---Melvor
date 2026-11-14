class_name DungeonRevealBanner
extends PanelContainer
## Overlay at the top of the Dungeon page: a narrative line for a few seconds after the player enters a room (docs/05_INTERFACES.md
## §7.q, "Rivelazione"). Presentation only: a local timer, never saved; it does not take clicks and does not move the layout.

const FADE_SEC: float = 0.4
const TOP_MARGIN: float = 8.0
const FONT_SIZE: int = 22
const PADDING: float = 12.0

var _label: Label = null
var _tween: Tween = null
var _showing: bool = false


func _init() -> void:
	name = "RevealBanner"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	offset_top = TOP_MARGIN
	add_theme_stylebox_override("panel", UiStyle.flat(UiStyle.COMBAT_ENEMY_BG, UiStyle.GOLD, 2, PADDING))
	_label = Label.new()
	_label.name = "RevealLabel"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	add_child(_label)


## Shows the text of the room `kind` for `duration_ms`, replacing the one on screen.
func show_kind(kind: StringName, duration_ms: int) -> void:
	clear()
	_label.text = DungeonTexts.reveal_text(kind)
	_showing = true
	modulate.a = 1.0
	visible = true
	_tween = create_tween()
	_tween.tween_interval(maxf(0.0, float(duration_ms) / 1000.0 - FADE_SEC))
	_tween.tween_property(self, "modulate:a", 0.0, FADE_SEC)
	_tween.tween_callback(clear)


## Hides the banner at once.
func clear() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	_showing = false
	visible = false


func is_showing() -> bool:
	return _showing


func shown_text() -> String:
	return _label.text if _showing else ""
