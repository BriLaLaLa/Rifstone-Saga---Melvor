class_name MainScreen
extends Control
## Main screen of a game in progress (docs/03_ARCHITECTURE.md §11): TopBar, Sidebar, PageHost and the toasts.
##
## The session is read in `_ready` (Game.session is already open and saved when this scene is loaded: no waiting for
## `session_started`). On `session_ended` (emitted before the session is freed) every node is unbound and nothing
## touches the session again. The menu button (and Esc) opens the SettingsPanel in game (M9-06); "Salva ed esci" there
## ends the session. The HintCard (modal, above the toasts) is created in `_bind`.
##
## Injection points (set them before adding the node to the tree):
## - `session`: the session to show; null means `Game.session`. Tests pass a TestFactory session.
## - `menu_action`: `() -> void` run by the menu button; empty means open the SettingsPanel. Tests pass a recording
##   callable.
##
## The ToastManager is created here, not in the scene, because its `events` must be set before it enters the tree.

const LOG_CATEGORY: String = "ui"
const FALLBACK_PAGE := &"bank"

## Session to show; null = `Game.session`.
var session: GameSession = null
## `() -> void` run by the menu button; empty = `Game.end_session(true)` and back to the main menu.
var menu_action: Callable = Callable()

var _session: GameSession = null
var _toasts: ToastManager = null
var _hint_card: HintCard = null
var _settings: SettingsPanel = null

@onready var _background: ColorRect = %Background
@onready var _top_bar: TopBar = %TopBar
@onready var _sidebar: Sidebar = %Sidebar
@onready var _page_host: PageHost = %PageHost
@onready var _toast_layer: Control = %ToastLayer


func _ready() -> void:
	_background.color = UiStyle.BG
	_top_bar.menu_requested.connect(_on_top_bar_menu_requested)
	_sidebar.page_requested.connect(_on_sidebar_page_requested)
	_page_host.page_changed.connect(_on_page_host_page_changed)
	var target: GameSession = session if session != null else Game.session
	if target == null:
		Log.warn(LOG_CATEGORY, "main screen without a session: nothing to show")
		return
	_bind(target)


func _exit_tree() -> void:
	_unbind()


func _bind(target: GameSession) -> void:
	_session = target
	_toasts = ToastManager.new()
	_toasts.name = "ToastManager"
	_toasts.events = _session.events
	_toasts.name_resolver = _display_name
	_toasts.action_resolver = _resource_name
	_toast_layer.add_child(_toasts)
	_top_bar.bind(_session)
	_page_host.setup(_session)
	_sidebar.bind(_session, _page_host.has_page)
	_session.events.session_ended.connect(_on_events_session_ended)
	# Modal layer: added after the ToastLayer, so it is drawn above the toasts (N9, see ToastManager.push).
	_hint_card = HintCard.new()
	_hint_card.name = "HintCard"
	add_child(_hint_card)
	_hint_card.bind(_session)
	_page_host.show_page(_first_page())
	# Production only (no injected session): the summary of the time away, once.
	if session == null and Game.last_offline_summary != null:
		var summary_view: OfflineSummaryView = OfflineSummaryView.open(self, Game.last_offline_summary, _session.data)
		summary_view.closed.connect(_hint_card.refresh)
		Game.last_offline_summary = null


## Unbinds every node from the session; safe to call more than once.
func _unbind() -> void:
	if _session == null:
		return
	if is_instance_valid(_session) and _session.events.session_ended.is_connected(_on_events_session_ended):
		_session.events.session_ended.disconnect(_on_events_session_ended)
	if _hint_card != null:
		_hint_card.unbind()
		remove_child(_hint_card)
		_hint_card.queue_free()
		_hint_card = null
	_page_host.setup(null)
	_sidebar.unbind()
	_top_bar.unbind()
	if _toasts != null:
		# Leaving the tree disconnects the ToastManager from the events.
		_toast_layer.remove_child(_toasts)
		_toasts.queue_free()
		_toasts = null
	_session = null


## First available skill page in data order, otherwise the bank.
func _first_page() -> StringName:
	if _session.dungeon != null and _session.dungeon.is_active():  # a loaded slot with a run on: back to the Dungeon page
		return &"dungeon"
	for skill: SkillDef in _session.data.skills():
		var page_id: StringName = StringName(PageHost.ROUTE_SKILL + PageHost.ROUTE_SEPARATOR + skill.id)
		if _page_host.has_page(page_id):
			return page_id
	return FALLBACK_PAGE


## Display name of an item or skill id for the toasts (the ids come from the session's own events).
func _display_name(id: StringName) -> String:
	if _session == null:
		return String(id)
	if _session.data.has_item(id):
		return _session.data.item(id).name
	for skill: SkillDef in _session.data.skills():
		if skill.id == id:
			return skill.name
	return String(id)


func _on_sidebar_page_requested(page_id: StringName) -> void:
	_page_host.show_page(page_id)
	# A refused page leaves the highlight on the page still shown.
	_sidebar.set_current(_page_host.current_page_id())


func _on_page_host_page_changed(page_id: StringName) -> void:
	_sidebar.set_current(page_id)


func _on_events_session_ended(_slot: int) -> void:
	_unbind()


func _on_top_bar_menu_requested() -> void:
	if menu_action.is_valid():
		menu_action.call()
		return
	_open_settings()


## Opens the settings panel inside the game ("Salva ed esci" leaves the session); one at a time.
func _open_settings() -> void:
	if _session == null or (_settings != null and is_instance_valid(_settings)):
		return
	_settings = SettingsPanel.new()
	_settings.in_game = true
	add_child(_settings)


## Esc opens the settings, unless a hint card is on screen (it closes with its own button).
func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and (_hint_card == null or _hint_card.current_hint() == &""):
		_open_settings()
		get_viewport().set_input_as_handled()


## Name of the resource of a gathering action (its first product), for the toasts of the mastery milestones.
func _resource_name(action_id: StringName) -> String:
	if _session == null:
		return String(action_id)
	for skill: SkillDef in _session.data.skills():
		for action: ActionDef in _session.data.actions_for_skill(skill.id):
			if action.id == action_id and not action.outputs.is_empty() and _session.data.has_item(action.outputs[0].item_id):
				return _session.data.item(action.outputs[0].item_id).name
	return String(action_id)
