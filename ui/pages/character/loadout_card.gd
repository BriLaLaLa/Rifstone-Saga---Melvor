class_name LoadoutCard
extends PanelContainer
## Tile of one trait or ability of the class in the loadout panel (docs/01_GDD.md §19): monogram badge, name, the effect
## in one line and a status line (active / not active / available / locked). The full description shows only on hover
## (tooltip); a click is reported with `chosen(id)` and the panel sends the command (`Loadout.set_trait` / `set_ability`).
## The tile draws what the panel gives it and keeps no game state.

signal chosen(id: StringName)

const STATE_ACTIVE: StringName = &"active"
const STATE_INACTIVE: StringName = &"inactive"
const STATE_AVAILABLE: StringName = &"available"
const STATE_LOCKED: StringName = &"locked"

const MIN_HEIGHT: int = 76
const BADGE_SIDE: int = 48
const PADDING: float = 8.0
const DIM_ALPHA: float = 0.6
const BADGE_FONT_SIZE: int = 20
const SEPARATION: int = 10
const STATE_COLORS: Dictionary[StringName, Color] = {
	STATE_ACTIVE: UiStyle.GOOD,
	STATE_INACTIVE: UiStyle.OFFLINE_WARNING_COLOR,
	STATE_AVAILABLE: UiStyle.GOLD_LIGHT,
	STATE_LOCKED: UiStyle.TEXT_2,
}

var _id: StringName = &""
var _clickable: bool = true
var _state: StringName = STATE_AVAILABLE
var _detail_title: String = ""
var _detail: String = ""
var _badge: PanelContainer = null
var _badge_label: Label = null
var _name: Label = null
var _effect: Label = null
var _status: Label = null


func _init() -> void:
	custom_minimum_size = Vector2(0, MIN_HEIGHT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", SEPARATION)
	add_child(row)
	_badge = PanelContainer.new()
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.custom_minimum_size = Vector2(BADGE_SIDE, BADGE_SIDE)
	_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_badge)
	_badge_label = Label.new()
	_badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge_label.add_theme_font_size_override("font_size", BADGE_FONT_SIZE)
	_badge.add_child(_badge_label)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 1)
	row.add_child(box)
	_name = _line(box, &"")
	_name.add_theme_color_override("font_color", UiStyle.GOLD_LIGHT)
	_effect = _line(box, &"MutedLabel")
	_status = _line(box, &"")
	mouse_entered.connect(_on_hover)
	mouse_exited.connect(_on_leave)


## Draws the tile. `effect` is the one-line effect, `detail` the text of the tooltip, `status` the state line.
func show_entry(id: StringName, title: String, effect: String, detail: String, state: StringName, status: String,
		accent: Color, clickable: bool) -> void:
	_id = id
	_clickable = clickable
	_state = state
	name = "Card_%s" % id
	_name.text = title
	_effect.text = effect
	_detail_title = title
	_detail = detail
	_status.text = status
	_status.add_theme_color_override("font_color", STATE_COLORS[state])
	_badge_label.text = _initials(title)
	var emphasis: bool = state == STATE_ACTIVE or state == STATE_INACTIVE
	_badge.add_theme_stylebox_override("panel", UiStyle.flat(accent.darkened(0.55), accent, 2, 2.0))
	_badge_label.add_theme_color_override("font_color", accent.lightened(0.3))
	modulate.a = DIM_ALPHA if state == STATE_LOCKED else 1.0
	var border: Color = UiStyle.GOLD_FAINT
	if state == STATE_ACTIVE:
		border = UiStyle.GOLD
	elif state == STATE_INACTIVE:
		border = UiStyle.OFFLINE_WARNING_COLOR
	add_theme_stylebox_override("panel", UiStyle.flat(UiStyle.BG_FIELD, border, 2 if emphasis else 1, PADDING))
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if clickable else Control.CURSOR_ARROW


func entry_id() -> StringName:
	return _id


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and _clickable:
		chosen.emit(_id)
		accept_event()


func _on_hover() -> void:
	Tooltips.show_text(_detail_title, _detail, get_global_mouse_position())


func _on_leave() -> void:
	Tooltips.hide_tooltip()


## Up to two capital letters from the first two words of `title`.
static func _initials(title: String) -> String:
	var out: String = ""
	for word: String in title.split(" ", false):
		if out.length() < 2 and word[0].to_upper() != word[0].to_lower():
			out += word[0].to_upper()
	return out


static func _line(parent: Control, variation: StringName) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if variation != &"":
		label.theme_type_variation = variation
	parent.add_child(label)
	return label


# --- For tests ---

func title_text() -> String:
	return _name.text


func effect_text() -> String:
	return _effect.text


func detail_text() -> String:
	return _detail


func state() -> StringName:
	return _state


func state_text() -> String:
	return _status.text


func is_clickable() -> bool:
	return _clickable
