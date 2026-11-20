class_name WardStrip
extends VBoxContainer
## Ward of the player (GDD M28 §40.3): a thin bar and a line "Riparo N · s" above the HP bar. Draws `get_state().ward`
## against the maximum HP of the same state; hidden while there is no Ward. No state of its own beyond its nodes.

var _label: Label = null
var _bar: ProgressBar = null


func _init() -> void:
	name = "WardStrip"
	visible = false
	add_theme_constant_override("separation", 2)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	add_child(row)
	var icon := TextureRect.new()
	icon.texture = ConditionTexts.icon(ConditionTexts.WARD)
	icon.custom_minimum_size = Vector2.ONE * UiStyle.COMBAT_CONDITION_ICON_SIDE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	_label = Label.new()
	_label.add_theme_color_override("font_color", UiStyle.COMBAT_WARD_COLOR)
	row.add_child(_label)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size.y = UiStyle.COMBAT_WARD_BAR_HEIGHT
	UiStyle.style_bar(_bar, UiStyle.COMBAT_WARD_COLOR)
	add_child(_bar)


## Draws the Ward of `state` (`combat.get_state()`).
func tick(state: Dictionary) -> void:
	var ward: Dictionary = state.get("ward", {})
	visible = not ward.is_empty()
	if visible:
		_bar.max_value = maxf(1.0, maxf(float(state["player_max_hp"]), float(ward["amount"])))
		_bar.value = ward["amount"]
		_label.text = ConditionTexts.ward_text(ward)


## Text of the line, for tests.
func shown_text() -> String:
	return _label.text
