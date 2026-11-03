class_name MasteryActionRow
extends PanelContainer
## Row of one action with mastery in the MasteryPanel (docs/01_GDD.md §6.1): icon, name, mastery level and bar
## (F-09 table), and a button that makes it the target of the pool spending.
##
## `setup` draws the data; `redraw` reads level and xp from `session.mastery`. Pressing the button emits
## `select_requested`; which action is the target is presentation state of the panel, passed back to `redraw`.
## The row keeps only its ActionDef and its nodes.

signal select_requested(action_id: StringName)

var _action: ActionDef = null

@onready var _icon: TextureRect = %Icon
@onready var _name_label: Label = %NameLabel
@onready var _level_label: Label = %LevelLabel
@onready var _mastery_bar: XpBar = %MasteryBar
@onready var _select_button: Button = %SelectButton


func _ready() -> void:
	_icon.custom_minimum_size = Vector2(UiStyle.MASTERY_ACTION_ICON_SIDE, UiStyle.MASTERY_ACTION_ICON_SIDE)
	_select_button.pressed.connect(_on_select_button_pressed)


## Draws the data of `action` (call it once, after the row entered the tree).
func setup(action: ActionDef) -> void:
	_action = action
	name = String(action.id).to_pascal_case()
	_icon.texture = ItemSlotView.icon_of(action.icon)
	_name_label.text = action.name
	_name_label.tooltip_text = action.name


## Reads the mastery of the action from `session`; `selected` marks the target of the pool spending.
func redraw(session: GameSession, selected: bool) -> void:
	_level_label.text = MasteryTexts.LEVEL_TEXT % NumberFormat.format_int(
			session.mastery.get_mastery_level(_action.id))
	_mastery_bar.set_xp(session.data.mastery_table(), session.mastery.get_mastery_xp(_action.id))
	_select_button.text = MasteryTexts.SELECTED_TEXT if selected else MasteryTexts.SELECT_TEXT
	_select_button.disabled = selected
	if selected:
		_name_label.add_theme_color_override("font_color", UiStyle.GOLD_LIGHT)
	else:
		_name_label.remove_theme_color_override("font_color")


func action_id() -> StringName:
	return _action.id if _action != null else &""


func _on_select_button_pressed() -> void:
	if _action != null:
		select_requested.emit(_action.id)
