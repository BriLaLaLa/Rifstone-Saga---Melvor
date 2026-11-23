class_name ResourceRow
extends PanelContainer
## One row of the ResourceTable (docs/01_GDD_M35.md §42.4, docs/05_INTERFACES_M35.md §7.ac): icon and name with the "Mirata" badge, level,
## stock in the Deposit, "Serve a" (Guide index), sell price, mastery with the next bonus, colour of the node now and "Raccogli questa".
## `setup` draws what comes from the data; `redraw` reads everything else from the session (nothing is computed here: the colour comes
## from `NodeColorPreview`, the focus from `disciplines.focus_of`, the next bonus from `mastery.step_info`). Keeps its action and nodes.

signal focus_requested(action_id: StringName)

const WIDTHS: Array[int] = [200, 48, 64, 0, 86, 150, 140, 124]  # 0 = expands; the header of the table uses the same widths
const ICON_SIZE: Vector2 = Vector2(32, 32)

var _action: ActionDef = null
var _item: ItemDef = null
var _index: GuideIndex = null
var _stock: int = 0
var _bonus_tag: MasteryBonusTag = null
var _badge: Label = null
var _level: Label = null
var _stock_label: Label = null
var _uses: Label = null
var _price: Label = null
var _mastery: Label = null
var _next: Label = null
var _color: Label = null
var _button: Button = null


## Builds the cells for `action`; `index` is the shared Guide index of the data.
func setup(action: ActionDef, data: GameData, index: GuideIndex) -> void:
	_action = action
	_index = index
	_item = data.item(action.outputs[0].item_id) if not action.outputs.is_empty() else null
	name = "ResourceRow_%s" % action.id
	theme_type_variation = &"HudPanel"
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	var title: HBoxContainer = HBoxContainer.new()
	title.add_theme_constant_override("separation", 6)
	var icon: TextureRect = TextureRect.new()
	icon.texture = ItemSlotView.icon_of(action.icon)
	icon.custom_minimum_size = ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title.add_child(icon)
	var names: VBoxContainer = VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label: Label = Label.new()
	name_label.text = action.name
	name_label.clip_text = true
	names.add_child(name_label)
	_badge = Label.new()
	_badge.name = "FocusBadge"
	_badge.text = ResourceTexts.BADGE_TEXT
	_badge.add_theme_color_override("font_color", UiStyle.GOLD)
	names.add_child(_badge)
	title.add_child(names)
	_cell(row, title, 0)
	_level = _label_cell(row, 1)
	_stock_label = _label_cell(row, 2)
	_uses = _label_cell(row, 3)
	_uses.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_price = _label_cell(row, 4)
	var mastery_box: VBoxContainer = VBoxContainer.new()
	var mastery_row: HBoxContainer = HBoxContainer.new()
	_mastery = Label.new()
	mastery_row.add_child(_mastery)
	if action.mastery:
		_bonus_tag = MasteryBonusTag.new()
		mastery_row.add_child(_bonus_tag)
		_bonus_tag.setup(action, data)
	mastery_box.add_child(mastery_row)
	_next = Label.new()
	_next.theme_type_variation = &"MutedLabel"
	_next.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mastery_box.add_child(_next)
	_cell(row, mastery_box, 5)
	_color = _label_cell(row, 6)
	_button = Button.new()
	_button.name = "FocusButton_%s" % action.id
	_button.focus_mode = Control.FOCUS_NONE
	_button.text = ResourceTexts.FOCUS_BUTTON_TEXT
	_button.pressed.connect(func() -> void: focus_requested.emit(_action.id))
	_cell(row, _button, 7)
	if _item != null:
		_price.text = Money.text(_item.value, data.currency())


## Rereads level, stock, mastery, colour and the focus from `session`.
func redraw(session: GameSession) -> void:
	var unlocked: bool = session.skills.meets_requirements({_action.skill_id: _action.level})
	var focused: bool = session.disciplines.focus_of(_action.skill_id) == _action.id
	_badge.visible = focused
	_level.text = ResourceTexts.LEVEL_TEXT % NumberFormat.format_int(_action.level)
	_level.add_theme_color_override("font_color", UiStyle.TEXT if unlocked else UiStyle.BAD)
	_stock = session.bank.get_count(_item.id) if _item != null else 0
	_stock_label.text = NumberFormat.format_int(_stock)
	_uses.text = _uses_text()
	_button.disabled = not unlocked or focused
	_button.text = ResourceTexts.FOCUS_BUTTON_TEXT if unlocked else ResourceTexts.FOCUS_BUTTON_LOCKED_TEXT
	modulate = Color.WHITE if unlocked else UiStyle.TEXT_DISABLED
	_redraw_mastery(session)
	var preview: Dictionary = NodeColorPreview.of(session, _action)
	_color.visible = not preview.is_empty()
	if not preview.is_empty():
		var color_id: StringName = CombatTexts.color_id(preview)
		_color.text = ResourceTexts.COLOR_TEXT % [CombatTexts.NODE_COLOR_NAMES.get(color_id, CombatTexts.NODE_COLOR_UNKNOWN_TEXT),
				NumberFormat.format_number(float(preview.get("xp_pct", 0.0)))]
		_color.add_theme_color_override("font_color", CombatTexts.NODE_COLORS.get(color_id, UiStyle.TEXT))


## True if the row passes the filter (text in the name, optionally only with a stock): read from the last redraw.
func matches(text: String, stock_only: bool) -> bool:
	return (text.is_empty() or _action.name.to_lower().contains(text.to_lower())) and (not stock_only or _stock > 0)


func action_id() -> StringName:
	return _action.id


func _redraw_mastery(session: GameSession) -> void:
	if not _action.mastery:
		_mastery.text = ResourceTexts.NO_MASTERY_TEXT
		_next.text = ""
		return
	var level: int = session.mastery.get_mastery_level(_action.id)
	var info: Dictionary = session.mastery.step_info(_action.skill_id, _action.id)
	_mastery.text = ResourceTexts.MASTERY_TEXT % NumberFormat.format_int(level)
	var next: Dictionary = info.get("next", {}) as Dictionary
	_next.text = ResourceTexts.NEXT_BONUS_TEXT % str(next.get("text", "")) if not next.is_empty() else ""
	_bonus_tag.show_info(info, level)


func _uses_text() -> String:
	if _item == null:
		return ResourceTexts.NO_USE_TEXT
	var summary: String = _index.summary_line(_index.uses_of(_item.id), 3)
	return summary if not summary.is_empty() else ResourceTexts.NO_USE_TEXT


func _label_cell(row: HBoxContainer, column: int) -> Label:
	var label: Label = Label.new()
	_cell(row, label, column)
	return label


func _cell(row: HBoxContainer, node: Control, column: int) -> void:
	if WIDTHS[column] > 0:
		node.custom_minimum_size.x = WIDTHS[column]
	else:
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(node)


## The text of the colour column (empty while it is hidden), for tests.
func color_text() -> String:
	return _color.text if _color.visible else ""
