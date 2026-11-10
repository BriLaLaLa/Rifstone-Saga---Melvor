class_name CrowdView
extends VBoxContainer
## Compact enemy view of the crowded combat (docs/METIN.md Z6): the Rift Stone fixed on top with its HP bar and the wave
## marks, then one row per monster type ("Name ×N", HP bar of the target of the type) in a scrolling list. No card per
## enemy. Hit numbers are added up per type and shown once per frame. Reads only `combat.get_state()` and the data; it
## keeps its nodes and the presentation cache of the last frame (row order, index to type, numbers waiting).

const GROUP_ROW_HEIGHT: float = 26.0
const MARK_WIDTH: float = 2.0

var _row_ids: Array[StringName] = []
var _rows: Dictionary[StringName, Dictionary] = {}
var _index_type: Array[StringName] = []
var _pending: Dictionary[StringName, int] = {}
var _marks: Array[ColorRect] = []

var _stone_box: VBoxContainer = null
var _stone_name: Label = null
var _stone_bar: ProgressBar = null
var _stone_hp: Label = null
var _stone_marks: Control = null
var _list: VBoxContainer = null


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_stone_box = VBoxContainer.new()
	_stone_name = Label.new()
	_stone_name.add_theme_color_override("font_color", UiStyle.COMBAT_STONE_TEXT)
	_stone_name.theme_type_variation = &"HeaderLabel"
	_stone_box.add_child(_stone_name)
	var holder := Control.new()
	holder.custom_minimum_size.y = UiStyle.COMBAT_TARGET_BAR_HEIGHT + 4
	_stone_bar = ProgressBar.new()
	_stone_bar.show_percentage = false
	UiStyle.style_bar(_stone_bar, UiStyle.COMBAT_STONE_BORDER)
	holder.add_child(_stone_bar)
	_stone_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stone_marks = Control.new()
	_stone_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_stone_marks)
	_stone_marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stone_box.add_child(holder)
	_stone_hp = Label.new()
	_stone_hp.theme_type_variation = &"MutedLabel"
	_stone_box.add_child(_stone_hp)
	add_child(_stone_box)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	add_child(scroll)


## Redraws from `state` (`combat.get_state()`); also sends the numbers added up since the last frame.
func refresh(session: GameSession, state: Dictionary) -> void:
	var enemies: Array = state["enemies"]
	var target: int = int(state["target"])
	var counts: Dictionary[StringName, int] = {}
	var front: Dictionary[StringName, int] = {}
	var order: Array[StringName] = []
	_index_type.clear()
	for i: int in enemies.size():
		var id: StringName = enemies[i]["monster"]
		_index_type.append(id)
		if EnemyView.is_stone(session.data, id) or int(enemies[i]["hp"]) <= 0:
			continue
		if not counts.has(id):
			counts[id] = 0
			order.append(id)
			front[id] = i
		counts[id] += 1
		if i == target:
			front[id] = i
	_draw_stone(session.data, state.get("stone", {}))
	if order != _row_ids:
		_rebuild(order)
	for id: StringName in order:
		var row: Dictionary = _rows[id]
		var enemy: Dictionary = enemies[front[id]]
		var label: Label = row["name"]
		label.text = CrowdTexts.group_text(EnemyView.name_of(session.data, id), counts[id])
		label.add_theme_color_override("font_color",
				UiStyle.COMBAT_TARGET_BORDER_COLOR if front[id] == target else UiStyle.COMBAT_ENEMY_TEXT)
		var bar: ProgressBar = row["bar"]
		bar.max_value = maxf(1.0, float(enemy["max_hp"]))
		bar.value = float(enemy["hp"])
	_flush()


## Adds `damage` to the number of the type of the enemy at `index` (shown at the next refresh).
func add_hit(index: int, damage: int) -> void:
	if index >= 0 and index < _index_type.size():
		_pending[_index_type[index]] = _pending.get(_index_type[index], 0) + damage


## Type id of the enemy at `index` in the last frame (empty if none).
func type_at(index: int) -> StringName:
	return _index_type[index] if index >= 0 and index < _index_type.size() else &""


## Number of rows (types alive), for tests.
func row_count() -> int:
	return _row_ids.size()


func has_stone() -> bool:
	return _stone_box.visible


func clear_effects() -> void:
	_pending.clear()
	for row: Dictionary in _rows.values():
		HitNumbers.clear(row["floaters"])


func _draw_stone(data: GameData, stone: Dictionary) -> void:
	_stone_box.visible = not stone.is_empty()
	if stone.is_empty():
		return
	var id: StringName = stone["id"]
	_stone_name.text = CrowdTexts.STONE_TEXT % [EnemyView.name_of(data, id), int(stone["level"])]
	_stone_bar.max_value = maxf(1.0, float(stone["max_hp"]))
	_stone_bar.value = float(stone["hp"])
	_stone_hp.text = CrowdTexts.STONE_HP_TEXT % [NumberFormat.format_int(int(stone["hp"])),
			NumberFormat.format_int(int(stone["max_hp"]))]
	var thresholds: Array[int] = []
	for value: int in StoneFight.thresholds(data):
		if value < 100:
			thresholds.append(value)
	if _marks.size() != thresholds.size():
		for mark: ColorRect in _marks:
			mark.queue_free()
		_marks.clear()
		for value: int in thresholds:
			var mark := ColorRect.new()
			mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mark.anchor_left = value / 100.0
			mark.anchor_right = value / 100.0
			mark.anchor_bottom = 1.0
			mark.offset_right = MARK_WIDTH
			_stone_marks.add_child(mark)
			_marks.append(mark)
	var fired: Array = stone.get("fired", [])
	for i: int in thresholds.size():
		_marks[i].color = UiStyle.TEXT_2 if fired.has(thresholds[i]) else UiStyle.GOLD_LIGHT


func _rebuild(order: Array[StringName]) -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_rows.clear()
	_row_ids = order.duplicate()
	for id: StringName in order:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.custom_minimum_size.x = 240.0
		row.add_child(label)
		var slot := Control.new()
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.custom_minimum_size.y = GROUP_ROW_HEIGHT
		var bar := ProgressBar.new()
		bar.show_percentage = false
		UiStyle.style_bar(bar, UiStyle.HP)
		slot.add_child(bar)
		bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var floaters := Control.new()
		floaters.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(floaters)
		floaters.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.add_child(slot)
		_list.add_child(row)
		_rows[id] = {"name": label, "bar": bar, "floaters": floaters}


## One number per type and frame: the sum of the hits of the frame.
func _flush() -> void:
	for id: StringName in _pending:
		if _rows.has(id) and _pending[id] > 0:
			HitNumbers.spawn(_rows[id]["floaters"], CombatTexts.HIT_TEXT % NumberFormat.format_int(_pending[id]),
					UiStyle.TEXT, false)
	_pending.clear()
