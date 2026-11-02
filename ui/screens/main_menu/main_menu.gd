extends Control
## Main menu placeholder (task M0-06): game title, New game / Continue / Settings (disabled until M1-12) and Exit.
##
## No session exists here and nothing is written to user://. The title and version come from ProjectSettings
## (application/config/name, application/config/version), so the game name has a single definition.

const NAME_SETTING := "application/config/name"
const VERSION_SETTING := "application/config/version"

@onready var _background: ColorRect = %Background
@onready var _title_label: Label = %TitleLabel
@onready var _version_label: Label = %VersionLabel
@onready var _exit_button: Button = %ExitButton


func _ready() -> void:
	get_window().min_size = UiStyle.WINDOW_MIN_SIZE
	_background.color = UiStyle.BG
	_title_label.text = str(ProjectSettings.get_setting(NAME_SETTING, ""))
	_version_label.text = "Versione %s" % str(ProjectSettings.get_setting(VERSION_SETTING, ""))
	_exit_button.pressed.connect(_on_exit_button_pressed)


func _on_exit_button_pressed() -> void:
	get_tree().quit()
