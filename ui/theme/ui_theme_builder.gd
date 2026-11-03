class_name UiThemeBuilder
extends RefCounted
## Builds the global UI theme from the UiStyle palette and styleboxes.
## Regenerate the theme with: godot --headless --path . -s tools/build_ui_theme.gd

const _PANEL_TYPES: Array[String] = ["Panel", "PanelContainer"]
const _BUTTON_TYPES: Array[String] = ["Button", "OptionButton", "MenuButton"]
const _CHECK_TYPES: Array[String] = ["CheckBox", "CheckButton"]
const _CHECK_STATES: Array[String] = ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]
const _FIELD_TYPES: Array[String] = ["LineEdit", "TextEdit", "SpinBox"]
const _TAB_TYPES: Array[String] = ["TabContainer", "TabBar"]
const _SCROLL_TYPES: Array[String] = ["VScrollBar", "HScrollBar"]


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = UiStyle.font_body()
	t.default_font_size = UiStyle.FONT_SIZE
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
	t.set_color("font_color", "Label", UiStyle.TEXT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.55))
	t.set_constant("shadow_offset_x", "Label", 0)
	t.set_constant("shadow_offset_y", "Label", 1)
	t.set_type_variation("TitleLabel", "Label")
	t.set_font("font", "TitleLabel", UiStyle.font_title())
	t.set_font_size("font_size", "TitleLabel", 21)
	t.set_color("font_color", "TitleLabel", UiStyle.GOLD)
	t.set_type_variation("HeaderLabel", "Label")
	t.set_font("font", "HeaderLabel", UiStyle.font_title())
	t.set_font_size("font_size", "HeaderLabel", 14)
	t.set_color("font_color", "HeaderLabel", UiStyle.GOLD)
	t.set_type_variation("MutedLabel", "Label")
	t.set_color("font_color", "MutedLabel", UiStyle.TEXT_2)
	t.set_font_size("font_size", "MutedLabel", 15)
	t.set_color("default_color", "RichTextLabel", UiStyle.TEXT)
	t.set_font("bold_font", "RichTextLabel", UiStyle.font_bold())


static func _add_panels(t: Theme) -> void:
	for p: String in _PANEL_TYPES:
		t.set_stylebox("panel", p, UiStyle.frame("panel"))
	var variations: Dictionary[String, StyleBox] = {
		"HudPanel": UiStyle.frame("panel"),
		"WindowPanel": UiStyle.flat(UiStyle.BG_WINDOW_OPAQUE, UiStyle.GOLD, UiStyle.WINDOW_BORDER_WIDTH, 14.0),
		"SlotPanel": UiStyle.frame("slot", 3.0),
	}
	for variation: String in variations:
		# A variation has a single base type: Panel and PanelContainer share the "panel" stylebox,
		# so the variation is based on PanelContainer (the type used for layouts).
		t.set_type_variation(variation, "PanelContainer")
		t.set_stylebox("panel", variation, variations[variation])


static func _add_buttons(t: Theme) -> void:
	for b: String in _BUTTON_TYPES:
		_button_styles(t, b)
		t.set_color("font_color", b, UiStyle.TEXT)
		t.set_color("font_hover_color", b, UiStyle.GOLD_LIGHT)
		t.set_color("font_pressed_color", b, UiStyle.GOLD)
		t.set_color("font_focus_color", b, UiStyle.TEXT)
		t.set_color("font_disabled_color", b, UiStyle.TEXT_DISABLED)
		t.set_color("icon_normal_color", b, Color.WHITE)
		t.set_color("icon_hover_color", b, Color(1.1, 1.05, 0.95))
	t.set_type_variation("IconButton", "Button")
	t.set_color("icon_normal_color", "IconButton", UiStyle.GOLD)
	t.set_color("icon_hover_color", "IconButton", UiStyle.GOLD_LIGHT)
	t.set_color("icon_pressed_color", "IconButton", UiStyle.GOLD_LIGHT)
	t.set_type_variation("AccentButton", "Button")
	t.set_stylebox("normal", "AccentButton", UiStyle.flat(Color(0.30, 0.22, 0.12, 0.97), UiStyle.GOLD, 1, 8.0))
	t.set_stylebox("hover", "AccentButton", UiStyle.flat(Color(0.38, 0.28, 0.14, 0.97), UiStyle.GOLD_LIGHT, 1, 8.0))
	t.set_stylebox("pressed", "AccentButton", UiStyle.flat(Color(0.22, 0.16, 0.09, 0.97), UiStyle.GOLD, 1, 8.0))
	t.set_color("font_color", "AccentButton", UiStyle.GOLD_LIGHT)
	t.set_font("font", "AccentButton", UiStyle.font_title())
	t.set_font_size("font_size", "AccentButton", 15)


## List rows: no frame, faint gold band with a left marker on hover.
static func _add_list_button(t: Theme) -> void:
	t.set_type_variation("ListButton", "Button")
	var row: StyleBoxFlat = UiStyle.flat(Color.TRANSPARENT, Color.TRANSPARENT, 0, 3.0)
	row.content_margin_left = 8
	row.content_margin_right = 8
	var row_hover: StyleBoxFlat = UiStyle.flat(Color(UiStyle.GOLD, 0.16), Color.TRANSPARENT, 0, 3.0)
	row_hover.content_margin_left = 8
	row_hover.content_margin_right = 8
	row_hover.border_color = UiStyle.GOLD
	row_hover.border_width_left = 2
	t.set_stylebox("normal", "ListButton", row)
	t.set_stylebox("hover", "ListButton", row_hover)
	t.set_stylebox("pressed", "ListButton", row_hover)
	t.set_stylebox("hover_pressed", "ListButton", row_hover)
	t.set_color("icon_normal_color", "ListButton", UiStyle.TEXT_2)
	t.set_color("icon_hover_color", "ListButton", UiStyle.GOLD)
	t.set_constant("icon_max_width", "ListButton", 18)
	t.set_constant("h_separation", "ListButton", 8)


static func _add_checks_and_fields(t: Theme) -> void:
	for c: String in _CHECK_TYPES:
		for s: String in _CHECK_STATES:
			t.set_stylebox(s, c, StyleBoxEmpty.new())
		t.set_color("font_color", c, UiStyle.TEXT)
		t.set_color("font_hover_color", c, UiStyle.GOLD_LIGHT)
		t.set_color("font_pressed_color", c, UiStyle.TEXT)
	for f: String in _FIELD_TYPES:
		t.set_stylebox("normal", f, UiStyle.flat(UiStyle.BG_FIELD, UiStyle.GOLD_DIM, 1, 6.0))
		t.set_stylebox("focus", f, UiStyle.flat(Color.TRANSPARENT, UiStyle.GOLD, 1, 6.0))
		t.set_stylebox("read_only", f, UiStyle.flat(UiStyle.BG_FIELD, UiStyle.GOLD_FAINT, 1, 6.0))
		t.set_color("font_color", f, UiStyle.TEXT)
		t.set_color("font_placeholder_color", f, UiStyle.TEXT_2)
		t.set_color("caret_color", f, UiStyle.GOLD_LIGHT)
		t.set_color("selection_color", f, Color(UiStyle.GOLD, 0.35))


static func _add_popups(t: Theme) -> void:
	t.set_stylebox("panel", "PopupMenu", UiStyle.flat(UiStyle.BG_WINDOW, UiStyle.GOLD_DIM, 1, 6.0))
	t.set_stylebox("hover", "PopupMenu", UiStyle.flat(Color(UiStyle.GOLD, 0.18), Color.TRANSPARENT, 0, 4.0))
	t.set_stylebox("separator", "PopupMenu", UiStyle.line(UiStyle.GOLD_FAINT))
	t.set_color("font_color", "PopupMenu", UiStyle.TEXT)
	t.set_color("font_hover_color", "PopupMenu", UiStyle.GOLD_LIGHT)
	t.set_color("font_disabled_color", "PopupMenu", UiStyle.TEXT_DISABLED)
	t.set_stylebox("panel", "PopupPanel", UiStyle.flat(UiStyle.BG_WINDOW, UiStyle.GOLD_DIM, 1, 8.0))
	t.set_stylebox("panel", "TooltipPanel", UiStyle.flat(Color(0.05, 0.04, 0.05, 0.96), UiStyle.GOLD_DIM, 1, 8.0))
	t.set_color("font_color", "TooltipLabel", UiStyle.TEXT)


## Tabs: secondary text, active tab in gold with an underline.
static func _add_tabs(t: Theme) -> void:
	var tab_sel: StyleBoxFlat = UiStyle.flat(Color(UiStyle.GOLD, 0.10), Color.TRANSPARENT, 0, 10.0)
	tab_sel.border_color = UiStyle.GOLD
	tab_sel.border_width_bottom = 2
	var tab_off: StyleBoxFlat = UiStyle.flat(Color.TRANSPARENT, Color.TRANSPARENT, 0, 10.0)
	var tab_hover: StyleBoxFlat = UiStyle.flat(Color(UiStyle.GOLD, 0.06), Color.TRANSPARENT, 0, 10.0)
	for tb: String in _TAB_TYPES:
		t.set_stylebox("tab_selected", tb, tab_sel)
		t.set_stylebox("tab_unselected", tb, tab_off)
		t.set_stylebox("tab_hovered", tb, tab_hover)
		t.set_stylebox("tab_disabled", tb, tab_off)
		t.set_stylebox("tab_focus", tb, StyleBoxEmpty.new())
		t.set_color("font_selected_color", tb, UiStyle.GOLD)
		t.set_color("font_unselected_color", tb, UiStyle.TEXT_2)
		t.set_color("font_hovered_color", tb, UiStyle.TEXT)
		t.set_color("font_disabled_color", tb, UiStyle.TEXT_DISABLED)
	var tab_panel: StyleBoxFlat = UiStyle.flat(Color(0.05, 0.04, 0.05, 0.6), Color.TRANSPARENT, 0, 8.0)
	tab_panel.border_color = UiStyle.GOLD_DIM
	tab_panel.border_width_top = 1
	t.set_stylebox("panel", "TabContainer", tab_panel)
	t.set_stylebox("tabbar_background", "TabContainer", StyleBoxEmpty.new())


static func _add_bars_and_separators(t: Theme) -> void:
	t.set_stylebox("background", "ProgressBar", UiStyle.flat(Color(0, 0, 0, 0.65), UiStyle.GOLD_DIM, 1, 0.0))
	t.set_stylebox("fill", "ProgressBar", UiStyle.bar_fill(UiStyle.PROGRESS))
	t.set_color("font_color", "ProgressBar", UiStyle.TEXT)
	t.set_color("font_outline_color", "ProgressBar", Color(0, 0, 0, 0.8))
	t.set_constant("outline_size", "ProgressBar", 3)
	t.set_stylebox("separator", "HSeparator", UiStyle.line(UiStyle.GOLD_DIM))
	t.set_stylebox("separator", "VSeparator", UiStyle.line(UiStyle.GOLD_DIM, 1, true))
	# thin scroll bars
	for sbar: String in _SCROLL_TYPES:
		t.set_stylebox("scroll", sbar, UiStyle.flat(Color(0, 0, 0, 0.35), Color.TRANSPARENT, 0, 3.0))
		t.set_stylebox("grabber", sbar, UiStyle.flat(Color(UiStyle.GOLD, 0.45), Color.TRANSPARENT, 0, 3.0))
		t.set_stylebox("grabber_highlight", sbar, UiStyle.flat(Color(UiStyle.GOLD, 0.7), Color.TRANSPARENT, 0, 3.0))
		t.set_stylebox("grabber_pressed", sbar, UiStyle.flat(UiStyle.GOLD, Color.TRANSPARENT, 0, 3.0))


static func _add_lists_and_windows(t: Theme) -> void:
	t.set_stylebox("panel", "ItemList", UiStyle.flat(UiStyle.BG_FIELD, UiStyle.GOLD_FAINT, 1, 4.0))
	t.set_stylebox("selected", "ItemList", UiStyle.flat(Color(UiStyle.GOLD, 0.2), Color.TRANSPARENT, 0, 2.0))
	t.set_stylebox("selected_focus", "ItemList", UiStyle.flat(Color(UiStyle.GOLD, 0.25), Color.TRANSPARENT, 0, 2.0))
	t.set_color("font_color", "ItemList", UiStyle.TEXT)
	t.set_color("font_selected_color", "ItemList", UiStyle.GOLD_LIGHT)
	t.set_stylebox("panel", "AcceptDialog", UiStyle.flat(UiStyle.BG_WINDOW, UiStyle.GOLD_DIM, 1, 12.0))
	t.set_stylebox("embedded_border", "Window", UiStyle.flat(UiStyle.BG_WINDOW, UiStyle.GOLD_DIM, 1, 0.0))
	t.set_color("title_color", "Window", UiStyle.GOLD)
	t.set_font("title_font", "Window", UiStyle.font_title())


static func _button_styles(t: Theme, type_name: String) -> void:
	t.set_stylebox("normal", type_name, UiStyle.flat(UiStyle.BG_BUTTON, UiStyle.GOLD_DIM, 1, 8.0))
	t.set_stylebox("hover", type_name, UiStyle.flat(UiStyle.BG_BUTTON_HOVER, UiStyle.GOLD, 1, 8.0))
	t.set_stylebox("pressed", type_name, UiStyle.flat(UiStyle.BG_BUTTON_PRESSED, UiStyle.GOLD, 1, 8.0))
	t.set_stylebox("hover_pressed", type_name, UiStyle.flat(UiStyle.BG_BUTTON_PRESSED, UiStyle.GOLD_LIGHT, 1, 8.0))
	t.set_stylebox("disabled", type_name, UiStyle.flat(Color(0.08, 0.07, 0.07, 0.8), UiStyle.GOLD_FAINT, 1, 8.0))
	t.set_stylebox("focus", type_name, StyleBoxEmpty.new())
