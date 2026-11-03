class_name CustomTooltip
extends PanelContainer
## The single tooltip panel (display only): a title, body lines and an italic footer, kept inside the viewport.
##
## Ported from the previous game's tooltip component. Changes: the input is an `ItemDef` plus a quantity instead of
## a loose item dictionary (lines built by ItemTooltipLines, labels and formats from the stat registry); rarity
## colors, upgrade levels, bonus tiers, player level lookups and the hard-coded stat list are gone; the look comes
## from the theme (`TooltipPanel` variation) instead of a code-built stylebox; the separators live in the scene.
## Sizes, offsets and font sizes are `UiStyle.TOOLTIP_*` (presentation constants live only in ui_style.gd).
## It is owned by the `Tooltips` autoload (tooltip_manager.gd), which is the API the rest of the UI uses.

var _is_shown: bool = false

@onready var _title_label: RichTextLabel = %TitleLabel
@onready var _title_separator: HSeparator = %TitleSeparator
@onready var _body_label: RichTextLabel = %BodyLabel
@onready var _footer_separator: HSeparator = %FooterSeparator
@onready var _footer_label: RichTextLabel = %FooterLabel


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.x = UiStyle.TOOLTIP_MIN_WIDTH


## Item tooltip: name, category and quantity, then the lines of ItemTooltipLines.body, then the description.
func setup_item(item: ItemDef, count: int, data: GameData) -> void:
	var title: String = "[center][font_size=%d][color=#%s][b]%s[/b][/color][/font_size]" % [
		UiStyle.TOOLTIP_TITLE_FONT_SIZE, UiStyle.TEXT.to_html(false), ItemTooltipLines.escape(item.name)]
	title += "\n[font_size=%d][color=#%s]%s[/color][/font_size][/center]" % [
		UiStyle.TOOLTIP_SUBTITLE_FONT_SIZE, UiStyle.TEXT_2.to_html(false), ItemTooltipLines.subtitle(item, count)]
	var lines: PackedStringArray = ItemTooltipLines.body(item, data)
	var footer: String = ""
	if not item.description.is_empty():
		footer = "[font_size=%d][color=#%s][i]%s[/i][/color][/font_size]" % [UiStyle.TOOLTIP_FOOTER_FONT_SIZE,
				UiStyle.TEXT_2.to_html(false), ItemTooltipLines.escape(item.description)]
	_fill(title, "\n".join(lines), footer)


## Text tooltip (skills, buttons...): gold title and a body; `body` may contain BBCode.
func setup_text(title: String, body: String) -> void:
	var title_text: String = ""
	if not title.is_empty():
		title_text = "[font_size=%d][color=#%s][b]%s[/b][/color][/font_size]" % [
			UiStyle.TOOLTIP_TITLE_FONT_SIZE, UiStyle.GOLD_LIGHT.to_html(false), ItemTooltipLines.escape(title)]
	_fill(title_text, body, "")


## Shows the tooltip near `cursor_pos` (global), offset by `UiStyle.TOOLTIP_MOUSE_OFFSET` and clamped inside the viewport.
func show_at(cursor_pos: Vector2) -> void:
	visible = true
	_is_shown = true
	var pos: Vector2 = cursor_pos + UiStyle.TOOLTIP_MOUSE_OFFSET
	if is_inside_tree():
		_resize_and_place.call_deferred(pos)
		return
	_place(pos)


## Hides the tooltip and clears its texts.
func hide_tooltip() -> void:
	visible = false
	_is_shown = false
	_title_label.text = ""
	_body_label.text = ""
	_footer_label.text = ""


func is_shown() -> bool:
	return _is_shown


## Title text without BBCode (for tests and accessibility).
func title_text() -> String:
	return _title_label.get_parsed_text()


## Body text without BBCode, one line per row.
func body_text() -> String:
	return _body_label.get_parsed_text()


## Footer text without BBCode.
func footer_text() -> String:
	return _footer_label.get_parsed_text()


func _fill(title: String, body: String, footer: String) -> void:
	_title_label.text = title
	_title_label.visible = not title.is_empty()
	_body_label.text = "" if body.is_empty() else "[font_size=%d]%s[/font_size]" % [UiStyle.TOOLTIP_BODY_FONT_SIZE, body]
	_body_label.visible = not body.is_empty()
	_title_separator.visible = _title_label.visible and _body_label.visible
	_footer_label.text = footer
	_footer_label.visible = not footer.is_empty()
	_footer_separator.visible = _footer_label.visible and (_title_label.visible or _body_label.visible)


## Two passes: first the labels take the width, then the real height is measured (fit_content labels).
func _resize_and_place(pos: Vector2) -> void:
	if not _is_shown or not is_inside_tree():
		return
	modulate.a = 0.0
	_auto_resize()
	await get_tree().process_frame
	if not _is_shown or not is_inside_tree():
		return
	_auto_resize()
	_place(pos)
	modulate.a = 1.0


func _auto_resize() -> void:
	custom_minimum_size = Vector2(UiStyle.TOOLTIP_MIN_WIDTH, 0)
	size = Vector2(UiStyle.TOOLTIP_MIN_WIDTH, 0)
	size = get_combined_minimum_size()


func _place(pos: Vector2) -> void:
	var screen_size: Vector2 = get_viewport_rect().size if is_inside_tree() else size
	var limit: Vector2 = screen_size - size - Vector2(UiStyle.TOOLTIP_SCREEN_MARGIN, UiStyle.TOOLTIP_SCREEN_MARGIN)
	var x: float = maxf(minf(pos.x, limit.x), UiStyle.TOOLTIP_SCREEN_MARGIN)
	var y: float = maxf(minf(pos.y, limit.y), UiStyle.TOOLTIP_SCREEN_MARGIN)
	global_position = Vector2(x, y)
