class_name RecipeRow
extends Button
## One line of the recipe list: small icon, name, and on the right how many the player can make now "(N)", the level
## when the recipe is locked by level, or "Da scoprire". Read only: the list tells it what to draw.

const ICON_SIDE: float = 24.0
const ROW_HEIGHT: float = 32.0
const SEPARATION: int = 8

var _icon: TextureRect = null
var _name_label: Label = null
var _side_label: Label = null
var _action_id: StringName = &""


func _init() -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(0, ROW_HEIGHT)
	var line := HBoxContainer.new()
	line.name = "Line"
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_left = SEPARATION
	line.offset_right = -SEPARATION
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", SEPARATION)
	add_child(line)
	_icon = TextureRect.new()
	_icon.name = "Icon"
	_icon.custom_minimum_size = Vector2(ICON_SIDE, ICON_SIDE)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(_icon)
	_name_label = Label.new()
	_name_label.name = "Name"
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(_name_label)
	_side_label = Label.new()
	_side_label.name = "Side"
	_side_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(_side_label)


func setup(action: ActionDef) -> void:
	_action_id = action.id
	name = "Row_%s" % action.id
	_name_label.text = action.name
	tooltip_text = action.name
	_icon.texture = ItemSlotView.icon_of(action.icon)


func action_id() -> StringName:
	return _action_id


## `known`: the recipe is discovered; `unlocked`: the level is reached; `craftable`: units makeable with the bank now.
func show_state(known: bool, unlocked: bool, craftable: int, level: int) -> void:
	var color: Color = UiStyle.TEXT
	var side: String = ""
	var side_color: Color = UiStyle.TEXT_2
	if not known:
		color = UiStyle.TEXT_DISABLED
		side = QueueTexts.LOCKED_TEXT
		side_color = UiStyle.GOLD_LIGHT
	elif not unlocked:
		color = UiStyle.TEXT_DISABLED
		side = ProfessionTexts.LEVEL_SHORT_TEXT % NumberFormat.format_int(level)
		side_color = UiStyle.BAD
	elif craftable > 0:
		side = ProfessionTexts.CRAFTABLE_TEXT % NumberFormat.format_int(craftable)
		side_color = UiStyle.GOLD
	else:
		color = UiStyle.TEXT_2
	_name_label.add_theme_color_override("font_color", color)
	_side_label.text = side
	_side_label.add_theme_color_override("font_color", side_color)
	_icon.modulate = Color.WHITE if known and unlocked else UiStyle.TEXT_DISABLED


## A special entry (blueprints, bench): the name only, in gold.
func setup_special(page_id: StringName, label: String) -> void:
	name = "Page_%s" % page_id
	_name_label.text = label
	_name_label.add_theme_color_override("font_color", UiStyle.GOLD_LIGHT)
	_icon.visible = false
