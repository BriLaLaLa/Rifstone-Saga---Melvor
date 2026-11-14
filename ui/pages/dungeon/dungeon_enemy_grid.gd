class_name DungeonEnemyGrid
extends Control
## The enemies of a dungeon room as square cells, all at once, never "xN" nor a compact view (docs/05_INTERFACES.md §7.q): icon, name,
## HP bar, a frame on the current target, grey when dead. The boss of a final stage (`state["stage"]["monster"]`) is a 2x2 cell with
## a gold frame and the "BOSS" tag. The cell side is computed from the number of enemies and the size of the zone (no scroll).
## Presentation only: it reads `combat.get_state()["enemies"]` and keeps its cells; the numbers below are presentation constants.

const MAX_SIDE: int = 120
const MIN_SIDE: int = 64
const GAP: int = 6
const BOSS_SPAN: int = 2
const NAME_SIZE: int = 12
const BOSS_NAME_SIZE: int = 16
const TAG_SIZE: int = 13
const BAR_HEIGHT: int = 6
const CELL_MARGIN: float = 3.0
const CELL_NAME: String = "Cell_%d"

var _ids: Array[StringName] = []
var _boss_index: int = -1
var _cells: Array[Cell] = []


## One cell: only its nodes and three presentation flags.
class Cell extends PanelContainer:
	var icon: TextureRect = null
	var name_label: Label = null
	var tag_label: Label = null
	var bar: ProgressBar = null
	var boss: bool = false
	var dead: bool = false
	var targeted: bool = false


func _init() -> void:
	name = "EnemyGrid"
	clip_contents = true
	resized.connect(_apply_layout)


## Redraws from `state` (`combat.get_state()`); `dungeon_state` = `session.dungeon.state()` (the boss of the stage, if any).
func refresh(session: GameSession, state: Dictionary, dungeon_state: Dictionary) -> void:
	var enemies: Array = state.get("enemies", []) as Array
	var boss_id: StringName = StringName((dungeon_state.get("stage", {}) as Dictionary).get("monster", &""))
	var ids: Array[StringName] = []
	var boss_index: int = -1
	for i: int in enemies.size():
		var enemy: Dictionary = enemies[i]
		ids.append(enemy["monster"])
		if boss_index < 0 and boss_id != &"" and enemy["monster"] == boss_id and not enemy.has("summoned"):
			boss_index = i
	if ids != _ids or boss_index != _boss_index:
		_rebuild(session.data, ids, boss_index)
	var target: int = int(state.get("target", -1))
	for i: int in enemies.size():
		_redraw_cell(_cells[i], enemies[i] as Dictionary, i == target)


## Layout of `count` cells in `area`: `{"side": int, "rects": Array[Rect2]}`, one rect per cell in order; the cell `boss_index`
## (or -1) takes 2x2 slots. Pure function, for the tests.
static func layout(count: int, area: Vector2, boss_index: int = -1) -> Dictionary:
	var rects: Array[Rect2] = []
	if count <= 0:
		return {"side": 0, "rects": rects}
	var has_boss: bool = boss_index >= 0 and boss_index < count
	var span_min: int = BOSS_SPAN if has_boss else 1
	var slots: int = count + (BOSS_SPAN * BOSS_SPAN - 1 if has_boss else 0)
	var best_side: int = -1
	var cols: int = 1
	for candidate: int in range(span_min, slots + 1):
		var rows_c: int = maxi(ceili(float(slots) / candidate), span_min)
		var fit: int = floori(minf((area.x - GAP * (candidate - 1)) / candidate, (area.y - GAP * (rows_c - 1)) / rows_c))
		if fit > best_side:
			best_side = fit
			cols = candidate
	var side: int = clampi(best_side, 1, MAX_SIDE)
	var origin := Vector2(floorf((area.x - (cols * side + (cols - 1) * GAP)) / 2.0), 0.0)
	var taken: Dictionary = {}
	var placed: Array[Vector2i] = []
	placed.resize(count)
	if has_boss:
		placed[boss_index] = Vector2i.ZERO
		for dy: int in BOSS_SPAN:
			for dx: int in BOSS_SPAN:
				taken[Vector2i(dx, dy)] = true
	var slot: int = 0
	for i: int in count:
		if has_boss and i == boss_index:
			continue
		while taken.has(Vector2i(slot % cols, slot / cols)):
			slot += 1
		placed[i] = Vector2i(slot % cols, slot / cols)
		taken[placed[i]] = true
	for i: int in count:
		var span: int = BOSS_SPAN if has_boss and i == boss_index else 1
		var pos := Vector2(origin.x + placed[i].x * (side + GAP), origin.y + placed[i].y * (side + GAP))
		rects.append(Rect2(pos, Vector2.ONE * (span * side + (span - 1) * GAP)))
	return {"side": side, "rects": rects}


func cell(index: int) -> Cell:
	return _cells[index] if index >= 0 and index < _cells.size() else null


func cell_count() -> int:
	return _cells.size()


func boss_cell_index() -> int:
	return _boss_index


func _rebuild(data: GameData, ids: Array[StringName], boss_index: int) -> void:
	for existing: Cell in _cells:
		remove_child(existing)
		existing.queue_free()
	_cells.clear()
	_ids = ids.duplicate()
	_boss_index = boss_index
	for i: int in ids.size():
		var made: Cell = _make_cell(i, i == boss_index)
		made.name_label.text = EnemyView.name_of(data, ids[i])
		made.icon.texture = ItemSlotView.icon_of(EnemyView.icon_of(data, ids[i]))
		add_child(made)
		_cells.append(made)
	_apply_layout()


func _make_cell(index: int, boss: bool) -> Cell:
	var made := Cell.new()
	made.name = CELL_NAME % index
	made.boss = boss
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	made.add_child(box)
	if boss:
		made.tag_label = Label.new()
		made.tag_label.name = "BossTag"
		made.tag_label.text = DungeonTexts.BOSS_LABEL_TEXT
		made.tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		made.tag_label.add_theme_font_size_override("font_size", TAG_SIZE)
		made.tag_label.add_theme_color_override("font_color", UiStyle.GOLD)
		box.add_child(made.tag_label)
	made.icon = TextureRect.new()
	made.icon.name = "Icon"
	made.icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	made.icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	made.icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(made.icon)
	made.name_label = Label.new()
	made.name_label.name = "NameLabel"
	made.name_label.clip_text = true
	made.name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	made.name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	made.name_label.add_theme_font_size_override("font_size", BOSS_NAME_SIZE if boss else NAME_SIZE)
	made.name_label.add_theme_color_override("font_color", UiStyle.GOLD if boss else UiStyle.COMBAT_ENEMY_TEXT)
	box.add_child(made.name_label)
	made.bar = ProgressBar.new()
	made.bar.name = "HpBar"
	made.bar.show_percentage = false
	made.bar.custom_minimum_size.y = BAR_HEIGHT
	UiStyle.style_bar(made.bar, UiStyle.HP)
	box.add_child(made.bar)
	_style(made)
	return made


func _style(target_cell: Cell) -> void:
	var border: Color = UiStyle.COMBAT_ENEMY_BORDER
	var width: int = 1
	if target_cell.boss:
		border = UiStyle.GOLD
		width = 3
	if target_cell.targeted:
		border = UiStyle.GOLD.lightened(0.35) if target_cell.boss else UiStyle.COMBAT_TARGET_BORDER_COLOR
		width = maxi(width, 2)
	target_cell.add_theme_stylebox_override("panel", UiStyle.flat(UiStyle.COMBAT_ENEMY_BG, border, width, CELL_MARGIN))


func _redraw_cell(target_cell: Cell, enemy: Dictionary, targeted: bool) -> void:
	var hp: int = int(enemy["hp"])
	target_cell.bar.max_value = maxf(1.0, float(enemy["max_hp"]))
	target_cell.bar.value = hp
	var dead: bool = hp <= 0
	if dead != target_cell.dead:
		target_cell.dead = dead
		target_cell.modulate.a = UiStyle.COMBAT_DEAD_ALPHA if dead else 1.0
	targeted = targeted and not dead
	if targeted != target_cell.targeted:
		target_cell.targeted = targeted
		_style(target_cell)


func _apply_layout() -> void:
	if _cells.is_empty() or size.x <= 0.0 or size.y <= 0.0:
		return
	var placed: Dictionary = layout(_cells.size(), size, _boss_index)
	var rects: Array = placed["rects"] as Array
	for i: int in _cells.size():
		var rect: Rect2 = rects[i]
		_cells[i].position = rect.position
		_cells[i].size = rect.size
