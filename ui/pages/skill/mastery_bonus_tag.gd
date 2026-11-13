class_name MasteryBonusTag
extends Button
## "Bonus" label at the top right of an action card (M16-05): not an action button, a flat gold word that opens a small
## summary of the mastery bonuses of the action, the ones reached now and the ones still to unlock (F-122 steps from
## `MasterySystem.step_info`, plus the three milestones of a gathering resource).
##
## `setup` builds the popup once; `show_info` redraws it from what the card has just read from the session. The tag keeps
## only its nodes and the milestones of the action definition (data, read only).

const TAG_TEXT: String = "Bonus"
const TAG_TOOLTIP: String = "Bonus di maestria di questa azione"
const TITLE_TEXT: String = "Bonus di maestria · %s"
const MILESTONES_TITLE: String = "Traguardi della risorsa"
const MILESTONE_BYPRODUCT_TEXT: String = "Livello %d: sottoprodotto %s"
const MILESTONE_MODIFIERS_TEXT: String = "Livello %d: %s"
const REACHED_SUFFIX: String = " (raggiunto)"
const POPUP_NAME: String = "BonusPopup"

var _action: ActionDef = null
var _data: GameData = null
var _popup: PopupPanel = null
var _title: Label = null
var _step_row: MasteryStepRow = null
var _milestones: Label = null


func _init() -> void:
	name = "BonusTag"
	text = TAG_TEXT
	flat = true
	focus_mode = Control.FOCUS_NONE
	tooltip_text = TAG_TOOLTIP
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_color_override("font_color", UiStyle.GOLD)
	add_theme_color_override("font_hover_color", UiStyle.GOLD_LIGHT)
	add_theme_color_override("font_pressed_color", UiStyle.GOLD_LIGHT)
	pressed.connect(_on_pressed)


func setup(action: ActionDef, data: GameData) -> void:
	_action = action
	_data = data
	_popup = PopupPanel.new()
	_popup.name = POPUP_NAME
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_title = Label.new()
	_title.theme_type_variation = &"HeaderLabel"
	_title.text = TITLE_TEXT % action.name
	box.add_child(_title)
	_step_row = MasteryStepRow.new()
	_step_row.name = "MasteryStepRow"
	_step_row.setup(data)
	_step_row.custom_minimum_size.x = UiStyle.MASTERY_BONUS_POPUP_WIDTH
	box.add_child(_step_row)
	_milestones = Label.new()
	_milestones.name = "MilestoneLabel"
	_milestones.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_milestones.custom_minimum_size.x = UiStyle.MASTERY_BONUS_POPUP_WIDTH
	_milestones.visible = not action.milestones.is_empty()
	box.add_child(_milestones)
	_popup.add_child(box)
	add_child(_popup)


## Redraws the summary: `info` is `mastery.step_info`, `level` the mastery level of the action.
func show_info(info: Dictionary, level: int) -> void:
	if _step_row == null:
		return
	_step_row.show_info(info)
	var lines: PackedStringArray = PackedStringArray([MILESTONES_TITLE])
	for milestone: MilestoneDef in _action.milestones:
		var line: String
		if milestone.type == MilestoneDef.TYPE_BYPRODUCT:
			var item: ItemDef = _data.item(milestone.item)
			line = MILESTONE_BYPRODUCT_TEXT % [milestone.at, item.name if item != null else String(milestone.item)]
		else:
			line = MILESTONE_MODIFIERS_TEXT % [milestone.at, LoadoutDescribe.modifiers_text(milestone.modifiers, _data)]
		lines.append(line + (REACHED_SUFFIX if level >= milestone.at else ""))
	_milestones.text = "\n".join(lines)


## Text of the whole summary now (the step lines, then the milestones), for tests.
func summary_text() -> String:
	if _step_row == null:
		return ""
	return _step_row.shown_text() + ("\n" + _milestones.text if _milestones.visible else "")


func popup_node() -> PopupPanel:
	return _popup


func _on_pressed() -> void:
	if _popup == null:
		return
	var below: Vector2i = Vector2i(get_global_rect().position) + Vector2i(0, int(size.y))
	_popup.popup_on_parent(Rect2i(below, Vector2i.ZERO))
