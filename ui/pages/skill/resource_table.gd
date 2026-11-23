class_name ResourceTable
extends VBoxContainer
## Table of the resources of a gathering discipline (docs/01_GDD_M35.md §42.4, docs/05_INTERFACES_M35.md §7.ac), in place of the cards:
## one ResourceRow per action, the "Automatico" button, a text filter and "Solo con scorta". A press on "Raccogli questa" or "Automatico"
## emits `focus_requested`; the page sends `disciplines.set_focus` and shows the refusal. Keeps no game state: the skill id, the rows and
## the filter widgets (the filter is a view setting, not saved).

signal focus_requested(skill_id: StringName, action_id: StringName)

var _skill_id: StringName = &""
var _rows: Dictionary[StringName, ResourceRow] = {}
var _auto: Button = null
var _hint: Label = null
var _filter: LineEdit = null
var _stock_only: CheckBox = null
var _empty: Label = null


## Builds the toolbar, the header and one row per action of `skill_id` (call once, after the table entered the tree).
func setup(data: GameData, skill_id: StringName) -> void:
	_skill_id = skill_id
	name = "ResourceTable"
	add_theme_constant_override("separation", 6)
	var bar: HBoxContainer = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	_auto = Button.new()
	_auto.name = "AutoButton"
	_auto.toggle_mode = true
	_auto.focus_mode = Control.FOCUS_NONE
	_auto.text = ResourceTexts.AUTO_BUTTON_TEXT
	_auto.pressed.connect(func() -> void: focus_requested.emit(_skill_id, &""))
	bar.add_child(_auto)
	_filter = LineEdit.new()
	_filter.name = "FilterEdit"
	_filter.placeholder_text = ResourceTexts.FILTER_PLACEHOLDER
	_filter.custom_minimum_size.x = 220
	_filter.clear_button_enabled = true
	_filter.text_changed.connect(func(_t: String) -> void: _apply_filter())
	bar.add_child(_filter)
	_stock_only = CheckBox.new()
	_stock_only.name = "StockOnly"
	_stock_only.text = ResourceTexts.STOCK_ONLY_TEXT
	_stock_only.focus_mode = Control.FOCUS_NONE
	_stock_only.toggled.connect(func(_on: bool) -> void: _apply_filter())
	bar.add_child(_stock_only)
	add_child(bar)
	_hint = Label.new()
	_hint.name = "FocusHint"
	_hint.theme_type_variation = &"MutedLabel"
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_hint)
	add_child(_header())
	var index: GuideIndex = GuideIndex.new(data)
	for action: ActionDef in data.actions_for_skill(skill_id):
		var row: ResourceRow = ResourceRow.new()
		add_child(row)
		row.setup(action, data, index)
		row.focus_requested.connect(func(action_id: StringName) -> void: focus_requested.emit(_skill_id, action_id))
		_rows[action.id] = row
	_empty = Label.new()
	_empty.name = "NoRows"
	_empty.text = ResourceTexts.NO_ROWS_TEXT
	_empty.visible = false
	add_child(_empty)


## Rereads every row, the focus state and applies the filter.
func redraw(session: GameSession) -> void:
	var focus: StringName = session.disciplines.focus_of(_skill_id)
	_auto.set_pressed_no_signal(focus == &"")
	_hint.text = ResourceTexts.AUTO_HINT_TEXT if focus == &"" else ResourceTexts.FOCUS_HINT_TEXT
	for row: ResourceRow in _rows.values():
		row.redraw(session)
	_apply_filter()


func row_ids() -> Array[StringName]:
	return _rows.keys()


func _header() -> Control:
	var header: HBoxContainer = HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 8)
	for column: int in ResourceTexts.COLUMNS.size():
		var label: Label = Label.new()
		label.name = "Column%d" % column
		label.text = ResourceTexts.COLUMNS[column]
		label.theme_type_variation = &"MutedLabel"
		if ResourceRow.WIDTHS[column] > 0:
			label.custom_minimum_size.x = ResourceRow.WIDTHS[column]
		else:
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(label)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)  # the rows sit in a panel with its own inner margin
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_child(header)
	return margin


func _apply_filter() -> void:
	var shown: int = 0
	for row: ResourceRow in _rows.values():
		row.visible = row.matches(_filter.text, _stock_only.button_pressed)
		shown += 1 if row.visible else 0
	_empty.visible = shown == 0
