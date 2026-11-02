extends GutTest
## UiStyle: fonts, generated theme variations, icons and presentation constants.

const VARIATIONS: Dictionary[String, String] = {
	"TitleLabel": "Label",
	"HeaderLabel": "Label",
	"MutedLabel": "Label",
	"IconButton": "Button",
	"AccentButton": "Button",
	"ListButton": "Button",
	"HudPanel": "PanelContainer",
	"WindowPanel": "PanelContainer",
	"SlotPanel": "PanelContainer",
}


func test_fonts_are_loadable() -> void:
	assert_not_null(UiStyle.font_body(), "body font")
	assert_not_null(UiStyle.font_bold(), "bold font")
	var title: FontVariation = UiStyle.font_title() as FontVariation
	assert_not_null(title, "title font is a FontVariation")
	if title != null:
		assert_not_null(title.base_font, "title base font (Cinzel)")


func test_font_licenses_are_present() -> void:
	assert_true(FileAccess.file_exists(UiStyle.FONT_DIR + "OFL-Cinzel.txt"))
	assert_true(FileAccess.file_exists(UiStyle.FONT_DIR + "OFL-AlegreyaSans.txt"))
	assert_true(FileAccess.file_exists(UiStyle.ICON_DIR + "LICENSE-tabler.txt"))


func test_built_theme_has_all_variations() -> void:
	var theme: Theme = UiStyle.build_theme()
	for variation: String in VARIATIONS:
		assert_true(theme.is_type_variation(variation, VARIATIONS[variation]),
				"%s is a variation of %s" % [variation, VARIATIONS[variation]])


func test_saved_theme_has_all_variations() -> void:
	var theme: Theme = load(UiStyle.THEME_PATH) as Theme
	assert_not_null(theme, "theme resource at THEME_PATH")
	if theme == null:
		return
	for variation: String in VARIATIONS:
		assert_true(theme.is_type_variation(variation, VARIATIONS[variation]), variation)


func test_theme_is_the_project_theme() -> void:
	assert_eq(ProjectSettings.get_setting("gui/theme/custom", "") as String, UiStyle.THEME_PATH)


func test_frames_are_loadable() -> void:
	for frame_name: String in ["panel", "window", "slot"]:
		var sb: StyleBoxTexture = UiStyle.frame(frame_name)
		assert_not_null(sb.texture, "frame_%s.png" % frame_name)


func test_icon_returns_texture() -> void:
	var tex: Texture2D = UiStyle.icon("coins")
	assert_not_null(tex)
	assert_true(tex.get_width() > 0)


func test_unknown_icon_returns_missing_icon_and_reports_error() -> void:
	var tex: Texture2D = UiStyle.icon("no_such_icon")
	assert_push_error("unknown UI icon")
	assert_not_null(tex)
	assert_eq(tex.resource_path, UiStyle.MISSING_ICON)


func test_icon_button_uses_icon_variation() -> void:
	var b: Button = UiStyle.icon_button("x", "Chiudi")
	assert_eq(b.theme_type_variation, &"IconButton")
	assert_not_null(b.icon)
	b.free()


func test_presentation_constants() -> void:
	assert_eq(UiStyle.TOAST_MAX_VISIBLE, 4)
	assert_eq(UiStyle.TOAST_GROUP_MS, 1000)
	assert_eq(UiStyle.BANNER_MS, 2000)
	assert_eq(UiStyle.SIDEBAR_WIDTH, 260)
	assert_eq(UiStyle.TOP_BAR_HEIGHT, 56)
	assert_eq(UiStyle.WINDOW_MIN_SIZE, Vector2i(1280, 720))
