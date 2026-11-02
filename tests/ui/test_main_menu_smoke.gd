extends GutTest
## Smoke test of the main menu placeholder (M0-06): the scene instantiates with its 4 buttons and no errors.

const SCENE_PATH := "res://ui/screens/main_menu/main_menu.tscn"
const BUTTONS: Dictionary[String, String] = {
	"NewGameButton": "Nuova partita",
	"ContinueButton": "Continua",
	"SettingsButton": "Impostazioni",
	"ExitButton": "Esci",
}
const DISABLED_BUTTONS: Array[String] = ["NewGameButton", "ContinueButton", "SettingsButton"]

var _menu: Control


func before_each() -> void:
	var scene: PackedScene = load(SCENE_PATH) as PackedScene
	assert_not_null(scene, "main menu scene loads")
	_menu = scene.instantiate() as Control
	add_child_autofree(_menu)


func test_scene_instantiates() -> void:
	assert_not_null(_menu, "main menu root is a Control")
	assert_true(_menu.is_inside_tree(), "main menu is in the tree")


func test_main_scene_is_main_menu() -> void:
	assert_eq(str(ProjectSettings.get_setting("application/run/main_scene", "")), SCENE_PATH)


func test_has_the_four_buttons_with_italian_texts() -> void:
	var buttons: VBoxContainer = _menu.get_node("%Buttons") as VBoxContainer
	assert_eq(buttons.get_child_count(), BUTTONS.size(), "exactly 4 buttons")
	for button_name: String in BUTTONS:
		var button: Button = _menu.get_node("%" + button_name) as Button
		assert_not_null(button, button_name)
		if button != null:
			assert_eq(button.text, BUTTONS[button_name], button_name + " text")


func test_only_exit_is_enabled() -> void:
	for button_name: String in BUTTONS:
		var button: Button = _menu.get_node("%" + button_name) as Button
		assert_eq(button.disabled, DISABLED_BUTTONS.has(button_name), button_name + " disabled state")


func test_exit_button_is_connected() -> void:
	var exit_button: Button = _menu.get_node("%ExitButton") as Button
	assert_gt(exit_button.pressed.get_connections().size(), 0, "Exit has a pressed handler")


func test_title_uses_game_name_and_title_variation() -> void:
	var title: Label = _menu.get_node("%TitleLabel") as Label
	assert_eq(title.text, "RiftStone Saga: Idle")
	assert_eq(title.theme_type_variation, &"TitleLabel")


func test_window_min_size_is_set() -> void:
	assert_eq(_menu.get_window().min_size, UiStyle.WINDOW_MIN_SIZE)
