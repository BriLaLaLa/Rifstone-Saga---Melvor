class_name Sidebar
extends PanelContainer
## Left navigation of the main screen (docs/03_ARCHITECTURE.md §11): game sections (Personaggio, Combattimento,
## Equipaggiamento (with the Armory), Bank, Shop) and every gathering/artisan skill of the data by category, with icon,
## name and level.
##
## The rows are copies of the hidden `RowTemplate` and `SectionTemplate` of the scene (the layout lives there),
## built from the data in `bind`; a skill level is read from `session.skills` and redrawn on `level_up`.
## A row whose page is not available yet (the `is_available` callable, PageHost.has_page) is disabled with
## "In arrivo". Pressing a row emits `page_requested`; the main screen shows the page and calls `set_current`.
## It keeps no game state: only the session reference and its row nodes.

signal page_requested(page_id: StringName)

const LOG_CATEGORY: String = "ui"
const COMING_SOON_TEXT: String = "In arrivo"
const LEVEL_TEXT: String = "Liv. %s"
const SECTIONS_TITLE: String = "Partita"
## Game sections, in order: page id, text, UI icon (UiStyle.icon).
const SECTIONS: Array[Dictionary] = [
	{"page": &"character", "text": "Personaggio", "icon": "user"},
	{"page": &"combat", "text": ItemTooltipLines.COMBAT_TEXT, "icon": "sword"},
	{"page": &"fractures", "text": FractureTexts.TITLE_TEXT, "icon": "skull"},
	{"page": &"equipment", "text": "Equipaggiamento", "icon": "shirt"},
	{"page": &"rift", "text": RiftTexts.TITLE_TEXT, "icon": "sparkles"},
	{"page": &"bank", "text": "Deposito", "icon": "box"},
	{"page": &"shop", "text": "Shop", "icon": "building-store"},
	{"page": &"guide", "text": "Guida", "icon": "star"},
]
## Skill categories (04_DATA_SCHEMA.md §3) and their section titles, in order (combat skills no longer exist).
const CATEGORY_TITLES: Dictionary[StringName, String] = {
	&"gathering": "Raccolta",
	&"artisan": "Artigianato",
}

var _session: GameSession = null
var _group: ButtonGroup = ButtonGroup.new()
var _rows: Dictionary[StringName, Button] = {}
var _level_labels: Dictionary[StringName, Label] = {}
var _dots: Dictionary[StringName, ActiveDot] = {}

@onready var _entries: VBoxContainer = %Entries
@onready var _row_template: Button = $Scroll/Entries/RowTemplate
@onready var _section_template: Label = $Scroll/Entries/SectionTemplate


func _ready() -> void:
	custom_minimum_size.x = UiStyle.SIDEBAR_WIDTH
	_row_template.visible = false
	_section_template.visible = false


## Builds the rows for `session`; `is_available` is `(page_id: StringName) -> bool`.
func bind(session: GameSession, is_available: Callable) -> void:
	unbind()
	_clear_rows()
	_session = session
	_add_section_title(SECTIONS_TITLE)
	for section: Dictionary in SECTIONS:
		var page_id: StringName = section["page"]
		var icon: Texture2D = UiStyle.icon(section["icon"] as String)
		_add_row(page_id, section["text"] as String, icon, is_available.call(page_id) as bool)
	for category: StringName in CATEGORY_TITLES:
		var skills: Array[SkillDef] = _session.data.skills_by_category(category)
		if skills.is_empty():
			continue
		_add_section_title(CATEGORY_TITLES[category])
		for skill: SkillDef in skills:
			var page_id: StringName = StringName(PageHost.ROUTE_SKILL + PageHost.ROUTE_SEPARATOR + skill.id)
			var row: Button = _add_row(page_id, skill.name, _skill_icon(skill), is_available.call(page_id) as bool)
			row.add_theme_color_override("icon_normal_color", skill.color)
			row.add_theme_color_override("icon_disabled_color", Color(skill.color, UiStyle.TEXT_DISABLED.a))
			_level_labels[skill.id] = row.get_node("Side") as Label
			_redraw_level(skill.id)
	_session.events.level_up.connect(_on_events_level_up)
	for sig: Signal in _work_signals(_session.events):
		sig.connect(_on_work_changed)
	_refresh_dots()


## Disconnects from the session's events; the rows stay as they are.
func unbind() -> void:
	if _session == null:
		return
	if is_instance_valid(_session):
		if _session.events.level_up.is_connected(_on_events_level_up):
			_session.events.level_up.disconnect(_on_events_level_up)
		for sig: Signal in _work_signals(_session.events):
			if sig.is_connected(_on_work_changed):
				sig.disconnect(_on_work_changed)
	_session = null


## Highlights the row of `page_id` (none if it has no row).
func set_current(page_id: StringName) -> void:
	for id: StringName in _rows:
		_rows[id].set_pressed_no_signal(id == page_id)


func _exit_tree() -> void:
	unbind()


func _clear_rows() -> void:
	for child: Node in _entries.get_children():
		if child == _row_template or child == _section_template:
			continue
		_entries.remove_child(child)
		child.queue_free()
	_rows.clear()
	_level_labels.clear()
	_dots.clear()


func _add_section_title(text: String) -> void:
	var title: Label = _section_template.duplicate() as Label
	title.name = "Section%d" % _entries.get_child_count()
	title.text = text.to_upper()
	title.visible = true
	_entries.add_child(title)


func _add_row(page_id: StringName, text: String, icon: Texture2D, available: bool) -> Button:
	var row: Button = _row_template.duplicate() as Button
	row.name = String(page_id).replace(":", "_").to_pascal_case()
	row.text = text
	row.icon = icon
	row.button_group = _group
	row.disabled = not available
	row.visible = true
	row.pressed.connect(_on_row_pressed.bind(page_id))
	if not available:
		(row.get_node("Side") as Label).text = COMING_SOON_TEXT
		row.tooltip_text = COMING_SOON_TEXT
	_entries.add_child(row)
	var dot := ActiveDot.new()
	row.add_child(dot)
	_dots[page_id] = dot
	_rows[page_id] = row
	return row


## Skill icon from the data; a missing file is reported and shown as UiStyle.MISSING_ICON.
func _skill_icon(skill: SkillDef) -> Texture2D:
	if ResourceLoader.exists(skill.icon):
		return load(skill.icon) as Texture2D
	Log.warn(LOG_CATEGORY, "sidebar: icon '%s' of skill '%s' not found" % [skill.icon, skill.id])
	return load(UiStyle.MISSING_ICON) as Texture2D


func _redraw_level(skill_id: StringName) -> void:
	_level_labels[skill_id].text = LEVEL_TEXT % NumberFormat.format_int(_session.skills.get_level(skill_id))


## The events after which the work in progress may have changed (M16-06, V9).
func _work_signals(events: GameEvents) -> Array[Signal]:
	return [events.action_started, events.action_stopped, events.combat_started, events.combat_stopped,
			events.encounter_started]  # combat_started comes before the state changes, encounter_started after


func _on_work_changed(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	_refresh_dots()


## Lights the dot of the skill in progress (main lane) and of the combat, reading both from the session.
func _refresh_dots() -> void:
	if _session == null:
		return
	var running: StringName = StringName(_session.actions.get_lane().get("skill", &""))
	var skill_page: StringName = StringName(PageHost.ROUTE_SKILL + PageHost.ROUTE_SEPARATOR + running) \
			if running != &"" else &""
	for page_id: StringName in _dots:
		var on: bool = page_id == skill_page or (page_id == &"combat" and _session.combat.is_active())
		_dots[page_id].set_active(on)


## True when the dot of the entry `page_id` is lit, for tests.
func is_working(page_id: StringName) -> bool:
	return _dots.has(page_id) and _dots[page_id].visible


func _on_row_pressed(page_id: StringName) -> void:
	page_requested.emit(page_id)


func _on_events_level_up(skill_id: StringName, _new_level: int) -> void:
	if _level_labels.has(skill_id):
		_redraw_level(skill_id)
