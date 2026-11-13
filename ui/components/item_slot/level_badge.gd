class_name LevelBadge
extends RefCounted
## Small item level shown at the bottom right of an item or piece cell (M16-04). Static helper over a cell
## (`PanelContainer`): it creates the label the first time and keeps no state; the owner passes the level it has just
## read (the `ilvl` of a piece, the character requirement of an item definition). Level 0 hides the badge.

const NODE_NAME: String = "LevelBadge"
const LEVEL_TEXT: String = "Liv %d"


## Shows `level` on `cell` (hidden when `level` <= 0). `left` moves it to the bottom left (the quantity takes the right).
static func show_on(cell: Control, level: int, left: bool = false) -> void:
	var label: Label = cell.get_node_or_null(NODE_NAME) as Label
	if label == null:
		if level <= 0:
			return
		label = _make()
		cell.add_child(label)
	label.visible = level > 0
	label.text = LEVEL_TEXT % level if level > 0 else ""
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT


## Text shown now on `cell` ("" if none), for tests.
static func text_of(cell: Control) -> String:
	var label: Label = cell.get_node_or_null(NODE_NAME) as Label
	return label.text if label != null and label.visible else ""


static func _make() -> Label:
	var label := Label.new()
	label.name = NODE_NAME
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = Control.SIZE_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_END
	label.add_theme_font_size_override("font_size", UiStyle.ITEM_LEVEL_FONT_SIZE)
	label.add_theme_color_override("font_color", UiStyle.TEXT)
	label.add_theme_color_override("font_outline_color", UiStyle.BG_FIELD)
	label.add_theme_constant_override("outline_size", 3)
	return label
