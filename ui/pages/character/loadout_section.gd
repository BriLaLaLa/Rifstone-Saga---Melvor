class_name LoadoutSection
extends VBoxContainer
## One tab of the loadout panel (traits or abilities): the combat warning, the slot header (occupied / open slots,
## free slots in evidence) and the tiles grouped by setup. It only lays out what the panel gives it.

const COLUMNS: int = 3
const GRID_SEPARATION: int = 8
const GROUP_SEPARATION: int = 6
const POINTS_FONT_SIZE: int = 30
const FREE_FONT_SIZE: int = 18
const HEADER_SEPARATION: int = 16
const HEADER_PADDING: float = 10.0

var cards: Array[LoadoutCard] = []
var note: Label = null
var _points: Label = null
var _free: Label = null
var _next: Label = null
var _groups: Array[Dictionary] = []  # {"box": VBoxContainer, "grid": GridContainer, "cards": Array}


func _init() -> void:
	add_theme_constant_override("separation", GRID_SEPARATION)


## Builds the header and the tiles of `entries` (ordered), grouped by the setups that allow them.
func build(entries: Array, class_def: ClassDef, on_chosen: Callable) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	cards.clear()
	_groups.clear()
	note = Label.new()
	note.text = LoadoutTexts.COMBAT_ACTIVE_TEXT
	note.add_theme_color_override("font_color", UiStyle.BAD)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(note)
	_build_header()
	var group_index: Dictionary[String, int] = {}
	for entry: Variant in entries:
		var title: String = _group_title(entry.setups, class_def)
		if not group_index.has(title):
			group_index[title] = _groups.size()
			_groups.append(_new_group(title))
		var card := LoadoutCard.new()
		card.chosen.connect(on_chosen)
		(_groups[group_index[title]]["grid"] as GridContainer).add_child(card)
		(_groups[group_index[title]]["cards"] as Array).append(card)
		cards.append(card)


## Redraws the header: `chosen` of `open` slots occupied, `total` slots at the end of the level table.
func set_slots(chosen: int, open: int, total: int, next_level: int) -> void:
	_points.text = "%d / %d" % [chosen, open]
	var free: int = open - chosen
	_free.text = LoadoutTexts.FREE_SLOTS_TEXT % free if free > 0 else LoadoutTexts.NO_FREE_TEXT
	_free.add_theme_color_override("font_color", UiStyle.GOOD if free > 0 else UiStyle.TEXT_2)
	_next.text = LoadoutTexts.NEXT_SLOT_TEXT % [next_level, open, total] if open < total \
			else LoadoutTexts.ALL_SLOTS_TEXT % total


## Hides the groups whose tiles are all hidden.
func sync_groups() -> void:
	for group: Dictionary in _groups:
		var any: bool = false
		for card: Variant in group["cards"]:
			any = any or (card as LoadoutCard).visible
		(group["box"] as Control).visible = any


func points_text() -> String:
	return _points.text


func free_text() -> String:
	return _free.text


func group_count() -> int:
	return _groups.size()


func _build_header() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.flat(UiStyle.BG_FIELD, UiStyle.GOLD_DIM, 1, HEADER_PADDING))
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", HEADER_SEPARATION)
	panel.add_child(row)
	_points = Label.new()
	_points.add_theme_font_size_override("font_size", POINTS_FONT_SIZE)
	_points.add_theme_color_override("font_color", UiStyle.GOLD_LIGHT)
	row.add_child(_points)
	var caption := VBoxContainer.new()
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(caption)
	var title := Label.new()
	title.text = LoadoutTexts.SLOTS_CAPTION_TEXT
	caption.add_child(title)
	_next = Label.new()
	_next.theme_type_variation = &"MutedLabel"
	caption.add_child(_next)
	_free = Label.new()
	_free.add_theme_font_size_override("font_size", FREE_FONT_SIZE)
	row.add_child(_free)


func _new_group(title: String) -> Dictionary:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", GROUP_SEPARATION)
	add_child(box)
	var header := Label.new()
	header.text = title
	header.theme_type_variation = &"HeaderLabel"
	box.add_child(header)
	box.add_child(HSeparator.new())
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", GRID_SEPARATION)
	grid.add_theme_constant_override("v_separation", GRID_SEPARATION)
	box.add_child(grid)
	return {"box": box, "grid": grid, "cards": []}


static func _group_title(setups: Array[StringName], class_def: ClassDef) -> String:
	if setups.is_empty() or class_def == null:
		return LoadoutTexts.ALL_SETUPS_TEXT
	var names: PackedStringArray = PackedStringArray()
	for setup: SetupDef in class_def.setups:
		if setups.has(setup.id):
			names.append(setup.name)
	return " · ".join(names) if not names.is_empty() else LoadoutTexts.ALL_SETUPS_TEXT
