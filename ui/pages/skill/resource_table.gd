class_name ResourceTable
extends VBoxContainer
## Compact list of the resources of a gathering discipline (docs/01_GDD_M36.md §44.2, docs/05_INTERFACES_M36.md §7.ae): one ResourceRow per
## action; a click on a row opens its detail and closes the other (one open at a time, a view setting, not saved). `zone_requested` relays
## the "Vai" of a detail; the page wires it to the combat. Keeps no game state: the skill id, the rows and the open id.

signal zone_requested(area_id: StringName)

var _skill_id: StringName = &""
var _rows: Dictionary[StringName, ResourceRow] = {}
var _open_id: StringName = &""


## Builds the header and one row per action of `skill_id` (call once, after the table entered the tree).
func setup(data: GameData, skill_id: StringName) -> void:
	_skill_id = skill_id
	name = "ResourceTable"
	add_theme_constant_override("separation", 6)
	add_child(_header())
	var index: GuideIndex = GuideIndex.new(data)
	for action: ActionDef in data.actions_for_skill(skill_id):
		var row: ResourceRow = ResourceRow.new()
		add_child(row)
		row.setup(action, data, index)
		row.header_clicked.connect(_on_header_clicked)
		row.zone_requested.connect(func(area_id: StringName) -> void: zone_requested.emit(area_id))
		_rows[action.id] = row


## Rereads every row (the open one stays open).
func redraw(session: GameSession) -> void:
	for row: ResourceRow in _rows.values():
		row.redraw(session)


func row_ids() -> Array[StringName]:
	return _rows.keys()


## Id of the action whose detail is open (`&""` if none).
func open_id() -> StringName:
	return _open_id


func _on_header_clicked(action_id: StringName) -> void:
	_open_id = &"" if _open_id == action_id else action_id
	for id: StringName in _rows:
		_rows[id].set_open(id == _open_id)


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
