class_name OfflineSummaryView
extends Control
## "Mentre eri via" summary (docs/01_GDD.md §12): time away and simulated, xp and levels, items, combat, Armory
## pieces, stop reasons with their time. It draws one OfflineSummary and the names from GameData; it keeps no game
## state. `closed` is emitted by the button (or Esc) and the view frees itself.

signal closed

const SCENE: PackedScene = preload("res://ui/screens/offline/offline_summary_view.tscn")
const CAP_KEY: String = "offline.cap_ms"

var _summary: OfflineSummary = null
var _data: GameData = null

@onready var _dim: ColorRect = %Dim
@onready var _title: Label = %TitleLabel
@onready var _rows: VBoxContainer = %Rows
@onready var _close: Button = %CloseButton


## Shows `summary` over `parent`. Names are read from `data`. Returns the view.
static func open(parent: Node, summary: OfflineSummary, data: GameData) -> OfflineSummaryView:
	var view: OfflineSummaryView = SCENE.instantiate()
	view._summary = summary
	view._data = data
	parent.add_child(view)
	return view


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.color = UiStyle.OFFLINE_DIM
	_title.text = OfflineTexts.SUMMARY_TITLE
	_close.text = OfflineTexts.CLOSE_BUTTON
	_close.pressed.connect(_on_close_pressed)
	_redraw()
	_close.grab_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_close_pressed()


## Texts of the rows now drawn, for tests and accessibility.
func shown_lines() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for child: Node in _rows.get_children():
		if child is Label:
			lines.append((child as Label).text)
	return lines


func _redraw() -> void:
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	if _summary == null:
		return
	var cap_ms: int = int(_data.balance_value(CAP_KEY)) if _data != null else _summary.elapsed_ms
	_line(OfflineTexts.SIMULATED_LINE % [OfflineTexts.duration(_summary.elapsed_ms), OfflineTexts.duration(cap_ms)])
	if _summary.capped:
		_line(OfflineTexts.CAPPED_LINE, UiStyle.OFFLINE_WARNING_COLOR)
	if _summary.is_empty():
		_line(OfflineTexts.NOTHING_HAPPENED, UiStyle.TEXT_2)
		return
	_section(OfflineTexts.SECTION_PROGRESS, _progress_lines())
	_section(OfflineTexts.SECTION_ITEMS, _item_lines())
	_section(OfflineTexts.SECTION_COMBAT, _combat_lines())
	_section(OfflineTexts.SECTION_FRACTURES, _fracture_lines())
	_section(OfflineTexts.SECTION_DUNGEON, _dungeon_lines())
	_section(OfflineTexts.SECTION_ARMORY, _armory_lines())
	_section(OfflineTexts.SECTION_STOPS, _stop_lines(), UiStyle.OFFLINE_WARNING_COLOR)


func _progress_lines() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var keys: Array[StringName] = []
	for key: StringName in _summary.xp:
		keys.append(key)
	for key: StringName in _summary.levels:
		if not keys.has(key):
			keys.append(key)
	keys.sort_custom(func(a: StringName, b: StringName) -> bool: return _source_name(a) < _source_name(b))
	for key: StringName in keys:
		var name_text: String = _source_name(key)
		var gained: String = NumberFormat.format_int(_summary.xp.get(key, 0))
		if _summary.levels.has(key):
			var span: Vector2i = _summary.levels[key]
			if _summary.xp.has(key):
				lines.append(OfflineTexts.XP_LEVEL_LINE % [name_text, gained, span.x, span.y])
			else:
				lines.append(OfflineTexts.LEVEL_ONLY_LINE % [name_text, span.x, span.y])
		else:
			lines.append(OfflineTexts.XP_LINE % [name_text, gained])
	return lines


func _item_lines() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if _summary.gold_delta > 0:
		lines.append(OfflineTexts.GOLD_GAINED_LINE % NumberFormat.format_int(_summary.gold_delta))
	elif _summary.gold_delta < 0:
		lines.append(OfflineTexts.GOLD_SPENT_LINE % NumberFormat.format_int(-_summary.gold_delta))
	for id: StringName in _sorted_by_name(_summary.items.keys()):
		var amount: int = _summary.items[id]
		if amount > 0:
			lines.append(OfflineTexts.ITEM_GAINED_LINE % [_item_name(id), NumberFormat.format_int(amount)])
		else:
			lines.append(OfflineTexts.ITEM_CONSUMED_LINE % [_item_name(id), NumberFormat.format_int(-amount)])
	for id: StringName in _sorted_by_name(_summary.bank_rejected.keys()):
		lines.append(OfflineTexts.ITEM_REJECTED_LINE % [_item_name(id),
				NumberFormat.format_int(_summary.bank_rejected[id])])
	return lines


func _combat_lines() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for id: StringName in _sorted_by_name(_summary.kills.keys()):
		lines.append(OfflineTexts.KILLS_LINE % [_monster_name(id), NumberFormat.format_int(_summary.kills[id])])
	if _summary.deaths > 0:
		lines.append(OfflineTexts.DEATHS_LINE % NumberFormat.format_int(_summary.deaths))
	if _summary.food_eaten > 0:
		lines.append(OfflineTexts.FOOD_LINE % NumberFormat.format_int(_summary.food_eaten))
	return lines


func _fracture_lines() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for entry: Dictionary in _summary.fractures:
		lines.append(OfflineTexts.fracture_line(entry))
	return lines


func _dungeon_lines() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if _summary.dungeon_frozen:
		lines.append(OfflineTexts.dungeon_line())
	return lines


func _armory_lines() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if _summary.pieces_stored > 0:
		lines.append(OfflineTexts.PIECES_STORED_LINE % NumberFormat.format_int(_summary.pieces_stored))
	if _summary.pieces_dismantled > 0:
		lines.append(OfflineTexts.PIECES_DISMANTLED_LINE % NumberFormat.format_int(_summary.pieces_dismantled))
	if _summary.pieces_rejected > 0:
		lines.append(OfflineTexts.PIECES_REJECTED_LINE % NumberFormat.format_int(_summary.pieces_rejected))
	return lines


func _stop_lines() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for i: int in _summary.stop_reasons.size():
		var text: String = OfflineTexts.reason_text(_summary.stop_reasons[i])
		if i < _summary.stop_times_ms.size():
			text = OfflineTexts.STOP_LINE % [text, OfflineTexts.duration(_summary.stop_times_ms[i])]
		lines.append(text)
	return lines


func _section(title: String, lines: PackedStringArray, color: Color = UiStyle.TEXT) -> void:
	if lines.is_empty():
		return
	var header: Label = Label.new()
	header.text = title
	header.theme_type_variation = &"HeaderLabel"
	_rows.add_child(header)
	for text: String in lines:
		_line(text, color)


func _line(text: String, color: Color = UiStyle.TEXT) -> void:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	_rows.add_child(label)


func _sorted_by_name(ids: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for id: Variant in ids:
		result.append(id as StringName)
	result.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return result


func _source_name(id: StringName) -> String:
	if id == CharacterSystem.SAVE_KEY:
		return OfflineTexts.CHARACTER_NAME
	if _data != null:
		for skill: SkillDef in _data.skills():
			if skill.id == id:
				return skill.name
	return String(id)


func _item_name(id: StringName) -> String:
	if _data != null and _data.has_item(id):
		return _data.item(id).name
	return String(id)


func _monster_name(id: StringName) -> String:
	if _data != null and _data.has_monster(id):
		return _data.monster(id).name
	return String(id)


func _on_close_pressed() -> void:
	closed.emit()
	queue_free()
