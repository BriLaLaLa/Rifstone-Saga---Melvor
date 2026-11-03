extends Control
## Main menu (docs/01_GDD.md §1): New game, Continue, Settings (M1-12) and Exit. Main scene of the project.
##
## No session exists here and nothing is written to user://: the menu only reads `Game.list_slots()`; the slot
## screen (SlotSelect, a child of this scene) sends the commands. New game and Continue are offered only with valid
## game data (with invalid data Game configures no slot and every command fails, so the menu says why instead);
## Continue only when at least one slot holds a loadable game. After new_game/continue_game returned ok the scene
## changes to the main screen; if that fails the session is closed again and the menu shows an error.
## The title and version come from ProjectSettings (application/config/name, application/config/version).
##
## Injection points (set them before adding the node to the tree), for tests:
## - `game`: the coordinator; null means the `Game` autoload. Passed on to SlotSelect.
## - `data`: the game data whose validity is checked; null means `DataRegistry.data`.
## - `scene_changer`: `(path: String) -> Error`; invalid means `get_tree().change_scene_to_file`.

const GameScript := preload("res://core/autoload/game.gd")
const NAME_SETTING := "application/config/name"
const VERSION_SETTING := "application/config/version"
const MAIN_SCREEN_PATH := "res://ui/screens/main/main_screen.tscn"
const LOG_CATEGORY: String = "ui"
const DATA_INVALID_TEXT := "I dati di gioco non sono validi: non si può avviare una partita."
const SCENE_FAILED_TEXT := "Impossibile aprire la schermata di gioco."

## Coordinator to read and command; null = the `Game` autoload.
var game: GameScript = null
## Game data to check; null = `DataRegistry.data`.
var data: GameData = null
## `(path: String) -> Error`; invalid = `get_tree().change_scene_to_file`.
var scene_changer: Callable = Callable()

@onready var _background: ColorRect = %Background
@onready var _menu_center: CenterContainer = %MenuCenter
@onready var _menu_panel: PanelContainer = %MenuPanel
@onready var _title_label: Label = %TitleLabel
@onready var _version_label: Label = %VersionLabel
@onready var _message_label: Label = %MessageLabel
@onready var _new_game_button: Button = %NewGameButton
@onready var _continue_button: Button = %ContinueButton
@onready var _exit_button: Button = %ExitButton
@onready var _buttons: VBoxContainer = %Buttons
@onready var _slot_select: SlotSelect = %SlotSelect


func _ready() -> void:
	get_window().min_size = UiStyle.WINDOW_MIN_SIZE
	_background.color = UiStyle.BG
	_apply_layout()
	_title_label.text = str(ProjectSettings.get_setting(NAME_SETTING, ""))
	_version_label.text = "Versione %s" % str(ProjectSettings.get_setting(VERSION_SETTING, ""))
	_message_label.add_theme_color_override("font_color", UiStyle.BAD)
	_slot_select.game = game
	_slot_select.visible = false
	_new_game_button.pressed.connect(_on_new_game_button_pressed)
	_continue_button.pressed.connect(_on_continue_button_pressed)
	_exit_button.pressed.connect(_on_exit_button_pressed)
	_slot_select.closed.connect(_on_slot_select_closed)
	_slot_select.game_started.connect(_on_slot_select_game_started)
	_refresh()


func _coordinator() -> GameScript:
	return game if game != null else Game


func _data_is_valid() -> bool:
	var game_data: GameData = data if data != null else DataRegistry.data
	return game_data != null and game_data.is_valid()


# Reads the data validity and the slot states again (after returning from the slot screen, a delete...).
func _refresh() -> void:
	var valid: bool = _data_is_valid()
	_new_game_button.disabled = not valid
	_continue_button.disabled = not valid or not _has_loadable_slot()
	_show_message("" if valid else DATA_INVALID_TEXT)


func _has_loadable_slot() -> bool:
	for info: SlotInfo in _coordinator().list_slots():
		if info.state == SlotTexts.STATE_OK:
			return true
	return false


func _show_message(text: String) -> void:
	_message_label.text = text
	_message_label.visible = not text.is_empty()


func _open_slots(mode: StringName) -> void:
	if not _data_is_valid():
		_refresh()
		return
	_menu_center.visible = false
	_slot_select.open(mode)


func _change_to_main_screen() -> void:
	var err: int = OK
	if scene_changer.is_valid():
		err = int(scene_changer.call(MAIN_SCREEN_PATH))
	else:
		err = get_tree().change_scene_to_file(MAIN_SCREEN_PATH)
	if err == OK:
		return
	Log.error(LOG_CATEGORY, "cannot open %s (error %d): session closed" % [MAIN_SCREEN_PATH, err])
	_coordinator().end_session(true)
	_on_slot_select_closed()
	_show_message(SCENE_FAILED_TEXT)


func _on_new_game_button_pressed() -> void:
	_open_slots(SlotSelect.MODE_NEW)


func _on_continue_button_pressed() -> void:
	_open_slots(SlotSelect.MODE_CONTINUE)


func _on_exit_button_pressed() -> void:
	get_tree().quit()


func _on_slot_select_closed() -> void:
	_slot_select.visible = false
	_menu_center.visible = true
	_refresh()


func _on_slot_select_game_started() -> void:
	_change_to_main_screen()


# Presentation sizes from UiStyle (the scene keeps only the structure).
func _apply_layout() -> void:
	_menu_panel.custom_minimum_size.x = UiStyle.MENU_PANEL_WIDTH
	_title_label.add_theme_font_size_override("font_size", UiStyle.MENU_TITLE_FONT_SIZE)
	for button: Button in _buttons.get_children():
		button.custom_minimum_size.y = UiStyle.MENU_BUTTON_HEIGHT
