class_name CharacterPage
extends Page
## Character page (docs/01_GDD.md §19, 05_INTERFACES.md §7), route `character`: class name and description, character
## level with its XpBar, the setup worn now and the setups of the class.
##
## Everything is read from `session.character`, `session.data` and `session.equipment` at every redraw, which runs on
## `character_xp_gained`, `character_level_up` and `equipment_changed`. The current setup comes from
## `Equipment.setup()` (05 §5.9). It keeps no game state, only references to its own nodes.

const LEVEL_TEXT: String = "Livello %s"
const NO_CLASS_TEXT: String = "Classe non disponibile"
const MARGIN: int = 16
const SECTION_SEPARATION: int = 12
const SETUP_ROW_NAME: String = "Setup_%s"
## Key of CombatTexts.STAT_NAME_SOURCES for each line of `final_stat_lines`; damage (empty) has no stat, so no tooltip.
const STAT_LINE_KEYS: Array[StringName] = [&"accuracy", &"evasion", &"", &"max_hp"]

var _session: GameSession = null

@onready var _margin: MarginContainer = %Margin
@onready var _content: VBoxContainer = %Content
@onready var _class_label: Label = %ClassLabel
@onready var _level_label: Label = %LevelLabel
@onready var _description_label: Label = %DescriptionLabel
@onready var _xp_bar: XpBar = %XpBar
@onready var _setup_title: Label = %SetupTitle
@onready var _setup_list: VBoxContainer = %SetupList
@onready var _stats_title: Label = %StatsTitle
@onready var _stats_list: VBoxContainer = %StatsList
@onready var _loadout: LoadoutPanel = %LoadoutPanel


func _ready() -> void:
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		_margin.add_theme_constant_override(side, MARGIN)
	_content.add_theme_constant_override("separation", SECTION_SEPARATION)
	_setup_title.text = ItemTooltipLines.SETUP_LABEL
	_stats_title.text = CombatTexts.STATS_TITLE


## Draws the character of `session` and follows its changes.
func bind(session: GameSession) -> void:
	unbind()
	_session = session
	HelpButton.attach(_class_label.get_parent(), session.data, &"character")
	var events: GameEvents = _session.events
	events.character_xp_gained.connect(_on_character_xp_gained)
	events.character_level_up.connect(_on_character_level_up)
	events.equipment_changed.connect(_on_equipment_changed)
	events.modifiers_changed.connect(_refresh_stats)
	for sig: Signal in _loadout_signals(events):
		sig.connect(_refresh_loadout)
	_loadout.bind(_session)
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
	_refresh_stats()
	_loadout.refresh()
	var current: StringName = _current_setup_id()
	for row: Node in _setup_list.get_children():
		var is_current: bool = current != &"" and row.name == SETUP_ROW_NAME % current
		(row as Label).add_theme_color_override("font_color", UiStyle.GOLD_LIGHT if is_current else UiStyle.TEXT_2)


## Id of the worn setup among the setups of the class; `&""` if the hands are bare.
func _current_setup_id() -> StringName:
	var id: StringName = _session.equipment.setup()
	if id == Equipment.UNARMED:
		return &""
	var class_def: ClassDef = _session.character.class_def()
	if class_def != null:
		for setup: SetupDef in class_def.setups:
			if setup.id == id:
				return id
	return &""


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
