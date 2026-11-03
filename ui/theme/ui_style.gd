class_name UiStyle
extends RefCounted
## UI style D (elegant dark fantasy): palette, fonts, frames, presentation constants and global theme builder.
## Regenerate the theme with: godot --headless --path . -s tools/build_ui_theme.gd
## (writes THEME_PATH, which project.godot uses as gui/theme/custom).
## Type variations to use on nodes (theme_type_variation):
##   Label: "TitleLabel" (large gold Cinzel), "HeaderLabel" (small gold Cinzel), "MutedLabel" (secondary text)
##   PanelContainer/Panel: "HudPanel" (overlay panels), "WindowPanel" (windows), "SlotPanel" (item slots)
##   Button: "IconButton" (square, gold icon), "AccentButton" (main action), "ListButton" (list row)
## Presentation constants live only here (09_CONVENTIONS.md §1); game design numbers live in data/.

const THEME_PATH := "res://ui/theme/riftstone_idle_theme.tres"
const FONT_DIR := "res://assets/fonts/"
const FRAME_DIR := "res://assets/ui/frames/"
const ICON_DIR := "res://assets/icons/ui/"
## Original placeholder icon, used when a requested UI icon does not exist.
const MISSING_ICON := "res://assets/icons/ui/missing.svg"

# --- presentation constants ---
const TOAST_MAX_VISIBLE: int = 4
const TOAST_GROUP_MS: int = 1000
const TOAST_LIFETIME_MS: int = 4000
const TOAST_EDGE_MARGIN: int = 16
const TOAST_STACK_SEPARATION: int = 6
const TOAST_FADE_IN_SEC: float = 0.2
const TOAST_FADE_OUT_SEC: float = 0.3
const BANNER_MS: int = 2000
const SIDEBAR_WIDTH: int = 260
const TOP_BAR_HEIGHT: int = 56
const WINDOW_MIN_SIZE := Vector2i(1280, 720)
## Tooltip (Tooltips / CustomTooltip): CanvasLayer above every other layer of the UI.
const TOOLTIP_LAYER: int = 100
## Space between the cursor and the tooltip corner.
const TOOLTIP_MOUSE_OFFSET := Vector2(15, -10)
## Minimum distance of the tooltip from the viewport edges.
const TOOLTIP_SCREEN_MARGIN: int = 10
const TOOLTIP_MIN_WIDTH: int = 280
const TOOLTIP_TITLE_FONT_SIZE: int = 18
const TOOLTIP_SUBTITLE_FONT_SIZE: int = 13
const TOOLTIP_BODY_FONT_SIZE: int = 15
const TOOLTIP_FOOTER_FONT_SIZE: int = 14
## GameWindow: free space kept around the window when it is first placed, and minimum distance from the top.
const WINDOW_PLACE_MARGIN: float = 40.0
const WINDOW_PLACE_TOP: float = 10.0
## Part of the title bar that must stay inside the parent area while dragging a GameWindow.
const WINDOW_DRAG_KEEP_VISIBLE := Vector2(80, 40)
const WINDOW_HEADER_SEPARATION: int = 8
const WINDOW_CLOSE_BUTTON_SIDE: int = 32
## Main menu and slot screen: panel widths, height of their buttons and fields, size of the menu title.
const MENU_PANEL_WIDTH: int = 520
const SLOT_PANEL_WIDTH: int = 820
const MENU_BUTTON_HEIGHT: int = 44
const MENU_TITLE_FONT_SIZE: int = 36
## ConfirmDialog: initial size (the text wraps inside it).
const DIALOG_SIZE := Vector2i(460, 0)
## Bank page: outer margin, space between its sections, grid spacing, cell size, item panel, search field.
const BANK_MARGIN: int = 16
const BANK_SECTION_SEPARATION: int = 12
const BANK_GRID_SEPARATION: int = 8
const BANK_CELL_SIZE := Vector2(48, 48)
const BANK_PANEL_WIDTH: int = 320
const BANK_PANEL_ICON_SIZE := Vector2(64, 64)
const BANK_SEARCH_WIDTH: int = 260

# --- palette ---
const BG := Color(0.055, 0.047, 0.063, 0.86)
const BG_WINDOW := Color(0.086, 0.071, 0.086, 0.95)
const BG_BUTTON := Color(0.13, 0.11, 0.12, 0.95)
const BG_BUTTON_HOVER := Color(0.18, 0.15, 0.15, 0.97)
const BG_BUTTON_PRESSED := Color(0.08, 0.065, 0.07, 0.97)
const BG_FIELD := Color(0.0, 0.0, 0.0, 0.45)
const GOLD := Color("c9a45c")
const GOLD_LIGHT := Color("f1d27a")
const GOLD_DIM := Color(0.79, 0.64, 0.36, 0.45)
const GOLD_FAINT := Color(0.79, 0.64, 0.36, 0.18)
const TEXT := Color("ece4d0")
const TEXT_2 := Color("a89f8a")
const TEXT_DISABLED := Color(0.66, 0.62, 0.54, 0.45)
const HP := Color("b3262b")
const HP_LIGHT := Color("e0484c")
const PROGRESS := Color("b08a45")
const GOOD := Color("9be08a")
const BAD := Color("e0484c")

const FONT_SIZE: int = 17
## 9-slice margin of the frames in FRAME_DIR (frame_*.png, 64x64).
const FRAME_MARGIN: int = 14

const _PANEL_TYPES: Array[String] = ["Panel", "PanelContainer"]
const _BUTTON_TYPES: Array[String] = ["Button", "OptionButton", "MenuButton"]
const _CHECK_TYPES: Array[String] = ["CheckBox", "CheckButton"]
const _CHECK_STATES: Array[String] = ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]
const _FIELD_TYPES: Array[String] = ["LineEdit", "TextEdit", "SpinBox"]
const _TAB_TYPES: Array[String] = ["TabContainer", "TabBar"]
const _SCROLL_TYPES: Array[String] = ["VScrollBar", "HScrollBar"]

static var _font_body: Font
static var _font_bold: Font
static var _font_title: Font


static func font_body() -> Font:
	if _font_body == null:
		_font_body = load(FONT_DIR + "AlegreyaSans-Medium.ttf") as Font
	return _font_body


static func font_bold() -> Font:
	if _font_bold == null:
		_font_bold = load(FONT_DIR + "AlegreyaSans-Bold.ttf") as Font
	return _font_bold


## Bold Cinzel (variable font: wght axis at 700).
static func font_title() -> Font:
	if _font_title == null:
		var fv := FontVariation.new()
		fv.base_font = load(FONT_DIR + "Cinzel-Variable.ttf") as Font
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 700}
		fv.spacing_glyph = 1
		_font_title = fv
	return _font_title


## White Tabler icon (ICON_DIR/<icon_name>.svg, MIT): tint it with modulate or icon_*_color.
## An unknown name is a programming error: it is reported and MISSING_ICON is returned.
static func icon(icon_name: String) -> Texture2D:
	var path: String = ICON_DIR + icon_name + ".svg"
	if not ResourceLoader.exists(path):
		push_error("UiStyle.icon: unknown UI icon '%s'" % icon_name)
		return load(MISSING_ICON) as Texture2D
	return load(path) as Texture2D


static func title_label(text: String, size: int = 14) -> Label:
	var l := Label.new()
	l.theme_type_variation = &"HeaderLabel"
	l.text = text.to_upper()
	if size != 14:
		l.add_theme_font_size_override("font_size", size)
	return l


## Square button with a gold icon only and a tooltip.
static func icon_button(icon_name: String, tip: String, side: int = 40) -> Button:
	var b := Button.new()
	b.theme_type_variation = &"IconButton"
	b.icon = icon(icon_name)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(side, side)
	b.add_theme_constant_override("icon_max_width", int(side * 0.55))
	b.focus_mode = Control.FOCUS_NONE
	return b


# --- styleboxes ---

static func frame(frame_name: String, content: float = 10.0) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(FRAME_DIR + "frame_%s.png" % frame_name) as Texture2D
	sb.set_texture_margin_all(FRAME_MARGIN)
	sb.set_content_margin_all(content)
	return sb


static func flat(bg: Color, border: Color = Color.TRANSPARENT, border_w: int = 0,
		content: float = 6.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_content_margin_all(content)
	sb.anti_aliasing = false
	return sb


static func line(color: Color, thickness: int = 1, vertical: bool = false) -> StyleBoxLine:
	var sb := StyleBoxLine.new()
	sb.color = color
	sb.thickness = thickness
	sb.vertical = vertical
	return sb


static func bar_fill(color: Color) -> StyleBoxFlat:
	var sb: StyleBoxFlat = flat(color, color.lightened(0.25), 0, 0.0)
	sb.border_width_top = 1
	return sb


## Styles a progress bar (dark background, thin gold border, given fill color).
static func style_bar(bar: ProgressBar, fill: Color) -> void:
	bar.add_theme_stylebox_override("background", flat(Color(0, 0, 0, 0.65), GOLD_DIM, 1, 0.0))
	bar.add_theme_stylebox_override("fill", bar_fill(fill))


# --- global theme ---

static func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font_body()
	t.default_font_size = FONT_SIZE
	_add_labels(t)
	_add_panels(t)
	_add_buttons(t)
	_add_list_button(t)
	_add_checks_and_fields(t)
	_add_popups(t)
	_add_tabs(t)
	_add_bars_and_separators(t)
	_add_lists_and_windows(t)
	return t


static func _add_labels(t: Theme) -> void:
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.55))
	t.set_constant("shadow_offset_x", "Label", 0)
	t.set_constant("shadow_offset_y", "Label", 1)
	t.set_type_variation("TitleLabel", "Label")
	t.set_font("font", "TitleLabel", font_title())
	t.set_font_size("font_size", "TitleLabel", 21)
	t.set_color("font_color", "TitleLabel", GOLD)
	t.set_type_variation("HeaderLabel", "Label")
	t.set_font("font", "HeaderLabel", font_title())
	t.set_font_size("font_size", "HeaderLabel", 14)
	t.set_color("font_color", "HeaderLabel", GOLD)
	t.set_type_variation("MutedLabel", "Label")
	t.set_color("font_color", "MutedLabel", TEXT_2)
	t.set_font_size("font_size", "MutedLabel", 15)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font("bold_font", "RichTextLabel", font_bold())


static func _add_panels(t: Theme) -> void:
	for p: String in _PANEL_TYPES:
		t.set_stylebox("panel", p, frame("panel"))
	var variations: Dictionary[String, StyleBox] = {
		"HudPanel": frame("panel"),
		"WindowPanel": frame("window", 14.0),
		"SlotPanel": frame("slot", 3.0),
	}
	for variation: String in variations:
		# A variation has a single base type: Panel and PanelContainer share the "panel" stylebox,
		# so the variation is based on PanelContainer (the type used for layouts).
		t.set_type_variation(variation, "PanelContainer")
		t.set_stylebox("panel", variation, variations[variation])


static func _add_buttons(t: Theme) -> void:
	for b: String in _BUTTON_TYPES:
		_button_styles(t, b)
		t.set_color("font_color", b, TEXT)
		t.set_color("font_hover_color", b, GOLD_LIGHT)
		t.set_color("font_pressed_color", b, GOLD)
		t.set_color("font_focus_color", b, TEXT)
		t.set_color("font_disabled_color", b, TEXT_DISABLED)
		t.set_color("icon_normal_color", b, Color.WHITE)
		t.set_color("icon_hover_color", b, Color(1.1, 1.05, 0.95))
	t.set_type_variation("IconButton", "Button")
	t.set_color("icon_normal_color", "IconButton", GOLD)
	t.set_color("icon_hover_color", "IconButton", GOLD_LIGHT)
	t.set_color("icon_pressed_color", "IconButton", GOLD_LIGHT)
	t.set_type_variation("AccentButton", "Button")
	t.set_stylebox("normal", "AccentButton", flat(Color(0.30, 0.22, 0.12, 0.97), GOLD, 1, 8.0))
	t.set_stylebox("hover", "AccentButton", flat(Color(0.38, 0.28, 0.14, 0.97), GOLD_LIGHT, 1, 8.0))
	t.set_stylebox("pressed", "AccentButton", flat(Color(0.22, 0.16, 0.09, 0.97), GOLD, 1, 8.0))
	t.set_color("font_color", "AccentButton", GOLD_LIGHT)
	t.set_font("font", "AccentButton", font_title())
	t.set_font_size("font_size", "AccentButton", 15)


## List rows: no frame, faint gold band with a left marker on hover.
static func _add_list_button(t: Theme) -> void:
	t.set_type_variation("ListButton", "Button")
	var row: StyleBoxFlat = flat(Color.TRANSPARENT, Color.TRANSPARENT, 0, 3.0)
	row.content_margin_left = 8
	row.content_margin_right = 8
	var row_hover: StyleBoxFlat = flat(Color(GOLD, 0.16), Color.TRANSPARENT, 0, 3.0)
	row_hover.content_margin_left = 8
	row_hover.content_margin_right = 8
	row_hover.border_color = GOLD
	row_hover.border_width_left = 2
	t.set_stylebox("normal", "ListButton", row)
	t.set_stylebox("hover", "ListButton", row_hover)
	t.set_stylebox("pressed", "ListButton", row_hover)
	t.set_stylebox("hover_pressed", "ListButton", row_hover)
	t.set_color("icon_normal_color", "ListButton", TEXT_2)
	t.set_color("icon_hover_color", "ListButton", GOLD)
	t.set_constant("icon_max_width", "ListButton", 18)
	t.set_constant("h_separation", "ListButton", 8)


static func _add_checks_and_fields(t: Theme) -> void:
	for c: String in _CHECK_TYPES:
		for s: String in _CHECK_STATES:
			t.set_stylebox(s, c, StyleBoxEmpty.new())
		t.set_color("font_color", c, TEXT)
		t.set_color("font_hover_color", c, GOLD_LIGHT)
		t.set_color("font_pressed_color", c, TEXT)
	for f: String in _FIELD_TYPES:
		t.set_stylebox("normal", f, flat(BG_FIELD, GOLD_DIM, 1, 6.0))
		t.set_stylebox("focus", f, flat(Color.TRANSPARENT, GOLD, 1, 6.0))
		t.set_stylebox("read_only", f, flat(BG_FIELD, GOLD_FAINT, 1, 6.0))
		t.set_color("font_color", f, TEXT)
		t.set_color("font_placeholder_color", f, TEXT_2)
		t.set_color("caret_color", f, GOLD_LIGHT)
		t.set_color("selection_color", f, Color(GOLD, 0.35))


static func _add_popups(t: Theme) -> void:
	t.set_stylebox("panel", "PopupMenu", flat(BG_WINDOW, GOLD_DIM, 1, 6.0))
	t.set_stylebox("hover", "PopupMenu", flat(Color(GOLD, 0.18), Color.TRANSPARENT, 0, 4.0))
	t.set_stylebox("separator", "PopupMenu", line(GOLD_FAINT))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", GOLD_LIGHT)
	t.set_color("font_disabled_color", "PopupMenu", TEXT_DISABLED)
	t.set_stylebox("panel", "PopupPanel", flat(BG_WINDOW, GOLD_DIM, 1, 8.0))
	t.set_stylebox("panel", "TooltipPanel", flat(Color(0.05, 0.04, 0.05, 0.96), GOLD_DIM, 1, 8.0))
	t.set_color("font_color", "TooltipLabel", TEXT)


## Tabs: secondary text, active tab in gold with an underline.
static func _add_tabs(t: Theme) -> void:
	var tab_sel: StyleBoxFlat = flat(Color(GOLD, 0.10), Color.TRANSPARENT, 0, 10.0)
	tab_sel.border_color = GOLD
	tab_sel.border_width_bottom = 2
	var tab_off: StyleBoxFlat = flat(Color.TRANSPARENT, Color.TRANSPARENT, 0, 10.0)
	var tab_hover: StyleBoxFlat = flat(Color(GOLD, 0.06), Color.TRANSPARENT, 0, 10.0)
	for tb: String in _TAB_TYPES:
		t.set_stylebox("tab_selected", tb, tab_sel)
		t.set_stylebox("tab_unselected", tb, tab_off)
		t.set_stylebox("tab_hovered", tb, tab_hover)
		t.set_stylebox("tab_disabled", tb, tab_off)
		t.set_stylebox("tab_focus", tb, StyleBoxEmpty.new())
		t.set_color("font_selected_color", tb, GOLD)
		t.set_color("font_unselected_color", tb, TEXT_2)
		t.set_color("font_hovered_color", tb, TEXT)
		t.set_color("font_disabled_color", tb, TEXT_DISABLED)
	var tab_panel: StyleBoxFlat = flat(Color(0.05, 0.04, 0.05, 0.6), Color.TRANSPARENT, 0, 8.0)
	tab_panel.border_color = GOLD_DIM
	tab_panel.border_width_top = 1
	t.set_stylebox("panel", "TabContainer", tab_panel)
	t.set_stylebox("tabbar_background", "TabContainer", StyleBoxEmpty.new())


static func _add_bars_and_separators(t: Theme) -> void:
	t.set_stylebox("background", "ProgressBar", flat(Color(0, 0, 0, 0.65), GOLD_DIM, 1, 0.0))
	t.set_stylebox("fill", "ProgressBar", bar_fill(PROGRESS))
	t.set_color("font_color", "ProgressBar", TEXT)
	t.set_color("font_outline_color", "ProgressBar", Color(0, 0, 0, 0.8))
	t.set_constant("outline_size", "ProgressBar", 3)
	t.set_stylebox("separator", "HSeparator", line(GOLD_DIM))
	t.set_stylebox("separator", "VSeparator", line(GOLD_DIM, 1, true))
	# thin scroll bars
	for sbar: String in _SCROLL_TYPES:
		t.set_stylebox("scroll", sbar, flat(Color(0, 0, 0, 0.35), Color.TRANSPARENT, 0, 3.0))
		t.set_stylebox("grabber", sbar, flat(Color(GOLD, 0.45), Color.TRANSPARENT, 0, 3.0))
		t.set_stylebox("grabber_highlight", sbar, flat(Color(GOLD, 0.7), Color.TRANSPARENT, 0, 3.0))
		t.set_stylebox("grabber_pressed", sbar, flat(GOLD, Color.TRANSPARENT, 0, 3.0))


static func _add_lists_and_windows(t: Theme) -> void:
	t.set_stylebox("panel", "ItemList", flat(BG_FIELD, GOLD_FAINT, 1, 4.0))
	t.set_stylebox("selected", "ItemList", flat(Color(GOLD, 0.2), Color.TRANSPARENT, 0, 2.0))
	t.set_stylebox("selected_focus", "ItemList", flat(Color(GOLD, 0.25), Color.TRANSPARENT, 0, 2.0))
	t.set_color("font_color", "ItemList", TEXT)
	t.set_color("font_selected_color", "ItemList", GOLD_LIGHT)
	t.set_stylebox("panel", "AcceptDialog", flat(BG_WINDOW, GOLD_DIM, 1, 12.0))
	t.set_stylebox("embedded_border", "Window", flat(BG_WINDOW, GOLD_DIM, 1, 0.0))
	t.set_color("title_color", "Window", GOLD)
	t.set_font("title_font", "Window", font_title())


static func _button_styles(t: Theme, type_name: String) -> void:
	t.set_stylebox("normal", type_name, flat(BG_BUTTON, GOLD_DIM, 1, 8.0))
	t.set_stylebox("hover", type_name, flat(BG_BUTTON_HOVER, GOLD, 1, 8.0))
	t.set_stylebox("pressed", type_name, flat(BG_BUTTON_PRESSED, GOLD, 1, 8.0))
	t.set_stylebox("hover_pressed", type_name, flat(BG_BUTTON_PRESSED, GOLD_LIGHT, 1, 8.0))
	t.set_stylebox("disabled", type_name, flat(Color(0.08, 0.07, 0.07, 0.8), GOLD_FAINT, 1, 8.0))
	t.set_stylebox("focus", type_name, StyleBoxEmpty.new())
