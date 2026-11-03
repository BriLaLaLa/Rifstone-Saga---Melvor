class_name CharacterPage
extends Page
## Character page (docs/01_GDD.md §19, 05_INTERFACES.md §7), route `character`: class name and description, character
## level with its XpBar, the setup worn now and the setups of the class.
##
## Everything is read from `session.character`, `session.data` and `session.equipment` at every redraw, which runs on
## `character_xp_gained`, `character_level_up` and `equipment_changed`. The current setup comes from
## `Equipment.setup()` (05 §5.9, M4-06): while that function is not on the equipment yet the page shows a neutral
## text. It keeps no game state, only references to its own nodes.

const LEVEL_TEXT: String = "Livello %s"
const SETUP_TITLE_TEXT: String = "Assetto"
const CURRENT_SETUP_TEXT: String = "In uso: %s"
const UNARMED_NAME: String = "Mani nude"
const UNKNOWN_SETUP_TEXT: String = "non disponibile"
const NOTE_TEXT: String = "I valori di combattimento, i tratti e le abilità arrivano con le prossime tappe."
const NO_CLASS_TEXT: String = "Classe non disponibile"
const MARGIN: int = 16
const SECTION_SEPARATION: int = 12
const SETUP_FUNCTION: StringName = &"setup"
const SETUP_ROW_NAME: String = "Setup_%s"

var _session: GameSession = null

@onready var _margin: MarginContainer = %Margin
@onready var _content: VBoxContainer = %Content
@onready var _class_label: Label = %ClassLabel
@onready var _level_label: Label = %LevelLabel
@onready var _description_label: Label = %DescriptionLabel
@onready var _xp_bar: XpBar = %XpBar
@onready var _setup_title: Label = %SetupTitle
@onready var _current_setup_label: Label = %CurrentSetupLabel
@onready var _setup_list: VBoxContainer = %SetupList
@onready var _note_label: Label = %NoteLabel


func _ready() -> void:
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		_margin.add_theme_constant_override(side, MARGIN)
	_content.add_theme_constant_override("separation", SECTION_SEPARATION)
	_setup_title.text = SETUP_TITLE_TEXT
	_note_label.text = NOTE_TEXT


## Draws the character of `session` and follows its changes.
func bind(session: GameSession) -> void:
	unbind()
	_session = session
	var events: GameEvents = _session.events
	events.character_xp_gained.connect(_on_character_xp_gained)
	events.character_level_up.connect(_on_character_level_up)
	events.equipment_changed.connect(_on_equipment_changed)
	_build_setup_list()
	_refresh()


## Disconnects every event connected in `bind`.
func unbind() -> void:
	if _session != null and is_instance_valid(_session):
		var events: GameEvents = _session.events
		if events.character_xp_gained.is_connected(_on_character_xp_gained):
			events.character_xp_gained.disconnect(_on_character_xp_gained)
		if events.character_level_up.is_connected(_on_character_level_up):
			events.character_level_up.disconnect(_on_character_level_up)
		if events.equipment_changed.is_connected(_on_equipment_changed):
			events.equipment_changed.disconnect(_on_equipment_changed)
	_session = null


func _exit_tree() -> void:
	unbind()


## One line per setup of the class (the definitions never change while the page is bound).
func _build_setup_list() -> void:
	for child: Node in _setup_list.get_children():
		_setup_list.remove_child(child)
		child.queue_free()
	var class_def: ClassDef = _session.character.class_def()
	if class_def == null:
		return
	for setup: SetupDef in class_def.setups:
		var line: Label = Label.new()
		line.name = SETUP_ROW_NAME % setup.id
		line.text = setup.name
		_setup_list.add_child(line)


## Rereads class, level, XP and current setup.
func _refresh() -> void:
	if _session == null:
		return
	var class_def: ClassDef = _session.character.class_def()
	_class_label.text = class_def.name if class_def != null else NO_CLASS_TEXT
	_description_label.text = class_def.description if class_def != null else ""
	_level_label.text = LEVEL_TEXT % NumberFormat.format_int(_session.character.get_level())
	var table: XpTable = _session.data.character_xp_table()
	if table != null:
		_xp_bar.set_xp(table, _session.character.get_xp())
	var current: StringName = _current_setup_id()
	_current_setup_label.text = CURRENT_SETUP_TEXT % _current_setup_name(current)
	for row: Node in _setup_list.get_children():
		var is_current: bool = current != &"" and row.name == SETUP_ROW_NAME % current
		(row as Label).theme_type_variation = &"HeaderLabel" if is_current else &"MutedLabel"


## True if the equipment exposes `setup()` (05 §5.9, M4-06).
func _equipment_has_setup() -> bool:
	return _session.equipment != null and _session.equipment.has_method(SETUP_FUNCTION)


## Id of the worn setup among the setups of the class; `&""` if the hands are bare or it is not known yet.
func _current_setup_id() -> StringName:
	if not _equipment_has_setup():
		return &""
	var id: StringName = StringName(String(_session.equipment.call(SETUP_FUNCTION)))
	var class_def: ClassDef = _session.character.class_def()
	if class_def != null:
		for setup: SetupDef in class_def.setups:
			if setup.id == id:
				return id
	return &""


func _current_setup_name(setup_id: StringName) -> String:
	if not _equipment_has_setup():
		return UNKNOWN_SETUP_TEXT
	for setup: SetupDef in _session.character.class_def().setups:
		if setup.id == setup_id:
			return setup.name
	return UNARMED_NAME


func _on_character_xp_gained(_amount: int) -> void:
	_refresh()


func _on_character_level_up(_new_level: int) -> void:
	_refresh()


func _on_equipment_changed(_slot_id: StringName, _item_id: StringName) -> void:
	_refresh()
