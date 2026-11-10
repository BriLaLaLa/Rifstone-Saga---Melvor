class_name CharacterPage
extends Page
## Character page (docs/01_GDD.md §19, 05_INTERFACES.md §7), route `character`: the player's name (renamable), under it
## "<class> · Livello N", the XpBar, the combat values and the traits/abilities panel (two tabs).
##
## Everything is read from `session.player_name`, `session.character` and `session.data` at every redraw, which runs on
## `character_xp_gained`, `character_level_up` and `equipment_changed`. It keeps no game state, only references to its
## own nodes. The setups are chosen in the equipment page, not here.

const LEVEL_TEXT: String = "%s · Livello %s"
const NO_CLASS_TEXT: String = "Classe non disponibile"
const RENAME_TEXT: String = "Rinomina"
const SAVE_NAME_TEXT: String = "Salva"
const MARGIN: int = 16
const SECTION_SEPARATION: int = 12
## Key of CombatTexts.STAT_NAME_SOURCES for each line of `final_stat_lines`; damage (empty) has no stat, so no tooltip.
const STAT_LINE_KEYS: Array[StringName] = [&"accuracy", &"evasion", &"", &"max_hp", &"armor", &"barrier"]

var _session: GameSession = null

@onready var _margin: MarginContainer = %Margin
@onready var _content: VBoxContainer = %Content
@onready var _name_label: Label = %NameLabel
@onready var _name_edit: LineEdit = %NameEdit
@onready var _rename_button: Button = %RenameButton
@onready var _rename_error: Label = %RenameError
@onready var _level_label: Label = %LevelLabel
@onready var _xp_bar: XpBar = %XpBar
@onready var _stats_title: Label = %StatsTitle
@onready var _stats_list: VBoxContainer = %StatsList
@onready var _loadout: LoadoutPanel = %LoadoutPanel


func _ready() -> void:
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		_margin.add_theme_constant_override(side, MARGIN)
	_content.add_theme_constant_override("separation", SECTION_SEPARATION)
	_stats_title.text = CombatTexts.STATS_TITLE
	_rename_button.text = RENAME_TEXT
	_rename_button.pressed.connect(_on_rename_pressed)
	_name_edit.text_submitted.connect(_submit_name)
	_rename_error.add_theme_color_override("font_color", UiStyle.BAD)


## Draws the character of `session` and follows its changes.
func bind(session: GameSession) -> void:
	unbind()
	_session = session
	HelpButton.attach(_name_label.get_parent(), session.data, &"character")
	_set_editing(false)
	var events: GameEvents = _session.events
	events.character_xp_gained.connect(_on_character_xp_gained)
	events.character_level_up.connect(_on_character_level_up)
	events.equipment_changed.connect(_on_equipment_changed)
	events.modifiers_changed.connect(_refresh_stats)
	for sig: Signal in _loadout_signals(events):
		sig.connect(_refresh_loadout)
	_loadout.bind(_session)
	_refresh()


## Disconnects every event connected in `bind`.
func unbind() -> void:
	if _session != null and is_instance_valid(_session):
		var events: GameEvents = _session.events
		if events.character_xp_gained.is_connected(_on_character_xp_gained):
			events.character_xp_gained.disconnect(_on_character_xp_gained)
		if events.character_level_up.is_connected(_on_character_level_up):
			events.character_level_up.disconnect(_on_character_level_up)
		if events.modifiers_changed.is_connected(_refresh_stats):
			events.modifiers_changed.disconnect(_refresh_stats)
		for sig: Signal in _loadout_signals(events):
			if sig.is_connected(_refresh_loadout):
				sig.disconnect(_refresh_loadout)
		if events.equipment_changed.is_connected(_on_equipment_changed):
			events.equipment_changed.disconnect(_on_equipment_changed)
	if is_instance_valid(_loadout):
		_loadout.unbind()
	_session = null


func _exit_tree() -> void:
	unbind()


## Rereads name, class, level and XP.
func _refresh() -> void:
	if _session == null:
		return
	var class_def: ClassDef = _session.character.class_def()
	_name_label.text = _session.player_name
	_level_label.text = LEVEL_TEXT % [class_def.name if class_def != null else NO_CLASS_TEXT,
			NumberFormat.format_int(_session.character.get_level())]
	var table: XpTable = _session.data.character_xp_table()
	if table != null:
		_xp_bar.set_xp(table, _session.character.get_xp())
	_refresh_stats()
	_loadout.refresh()


## Rename button: first press opens the field, the second (or Enter) sends the command `PlayerName.rename` and
## saves the slot; a refusal shows its reason and keeps the field open.
func _on_rename_pressed() -> void:
	if _session == null:
		return
	if not _name_edit.visible:
		_set_editing(true)
		return
	_submit_name(_name_edit.text)


func _submit_name(text: String) -> void:
	if _session == null:
		return
	var result: CommandResult = PlayerName.rename(_session, text)
	if not result.ok:
		_rename_error.text = SlotTexts.reason_text(result.reason)
		_rename_error.visible = true
		return
	if Game.session == _session:
		Game.save_now()
	_set_editing(false)
	_refresh()


func _set_editing(editing: bool) -> void:
	_name_edit.visible = editing
	_name_label.visible = not editing
	_rename_error.visible = false
	_rename_button.text = SAVE_NAME_TEXT if editing else RENAME_TEXT
	if editing:
		_name_edit.text = _session.player_name
		_name_edit.grab_focus()
		_name_edit.select_all()



func _on_character_xp_gained(_amount: int) -> void:
	_refresh()


func _on_character_level_up(_new_level: int) -> void:
	_refresh()


func _on_equipment_changed(_slot_id: StringName, _uid: int) -> void:
	_refresh()


## Base combat values of F-70 (accuracy, evasion, damage, HP), one line each (`CombatTexts.final_stat_lines`).
func _refresh_stats() -> void:
	if _session == null:
		return
	var lines: Array[String] = CombatTexts.final_stat_lines(_session)
	while _stats_list.get_child_count() < lines.size():
		var line := Label.new()
		line.name = "Stat%d" % _stats_list.get_child_count()
		line.mouse_filter = Control.MOUSE_FILTER_STOP
		line.mouse_entered.connect(_on_stat_hover.bind(_stats_list.get_child_count()))
		line.mouse_exited.connect(Tooltips.hide_tooltip)
		_stats_list.add_child(line)
	for i: int in lines.size():
		(_stats_list.get_child(i) as Label).text = lines[i]


## Name and description of the stat of line `index`, from the stat registry (`stats.json`).
func _on_stat_hover(index: int) -> void:
	if _session == null or index >= STAT_LINE_KEYS.size() or STAT_LINE_KEYS[index].is_empty():
		return
	var info: Dictionary = _session.data.stats.info(CombatTexts.STAT_NAME_SOURCES[STAT_LINE_KEYS[index]])
	Tooltips.show_text(str(info.get("name", "")), str(info.get("description", "")), get_global_mouse_position())


## Signals after which the loadout panel is redrawn: the choice itself, level, setup and the combat state (a choice
## cannot change during an encounter).
func _loadout_signals(events: GameEvents) -> Array[Signal]:
	return [events.traits_changed, events.combat_started, events.combat_stopped, events.encounter_started,
			events.encounter_cleared]


func _refresh_loadout(_arg1: Variant = null, _arg2: Variant = null) -> void:
	if _session != null:
		_loadout.refresh()
