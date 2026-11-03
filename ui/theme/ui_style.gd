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
## Mastery panel: node card size and spacing in the tree (pos = [col, row]), width of the prerequisite links, action
## icon side, opacity of a node card whose prerequisites are missing.
const MASTERY_NODE_SIZE := Vector2(240, 156)
const MASTERY_NODE_GAP := Vector2(32, 32)
const MASTERY_LINK_WIDTH: float = 2.0
const MASTERY_ACTION_ICON_SIDE: int = 36
const MASTERY_LOCKED_ALPHA: float = 0.6

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
## Opaque window background (WindowPanel): windows over the page content must not show it through.
const BG_WINDOW_OPAQUE := Color(0.086, 0.071, 0.086, 1.0)
const WINDOW_BORDER_WIDTH: int = 2
## Item rarity colors (name, border of the piece).
const RARITY_COMMON := Color("d8d2c0")
const RARITY_MAGIC := Color("6f9bff")
const RARITY_RARE := Color("f1d27a")
const RARITY_UNKNOWN := Color("a89f8a")

const FONT_SIZE: int = 17
## 9-slice margin of the frames in FRAME_DIR (frame_*.png, 64x64).
const FRAME_MARGIN: int = 14


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

## Kept for the callers of the theme build; the builder lives in UiThemeBuilder.
static func build_theme() -> Theme:
	return UiThemeBuilder.build()
