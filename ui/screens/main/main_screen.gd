class_name MainScreen
extends Control
## Main screen of a game in progress (docs/03_ARCHITECTURE.md §11): TopBar, Sidebar, PageHost and the toasts.
##
## The session is read in `_ready` (Game.session is already open and saved when this scene is loaded: no waiting for
## `session_started`). On `session_ended` (emitted before the session is freed) every node is unbound and nothing
## touches the session again. The menu button ends the session with a save and goes back to the main scene.
##
## Injection points (set them before adding the node to the tree):
## - `session`: the session to show; null means `Game.session`. Tests pass a TestFactory session.
## - `menu_action`: `() -> void` run by the menu button; empty means `Game.end_session(true)` and then the main scene
##   of the project (application/run/main_scene). Tests pass a recording callable.
##
## The ToastManager is created here, not in the scene, because its `events` must be set before it enters the tree.

const LOG_CATEGORY: String = "ui"
const MAIN_SCENE_SETTING: String = "application/run/main_scene"
const FALLBACK_PAGE := &"bank"

## Session to show; null = `Game.session`.
var session: GameSession = null
## `() -> void` run by the menu button; empty = `Game.end_session(true)` and back to the main menu.
var menu_action: Callable = Callable()

var _session: GameSession = null
var _toasts: ToastManager = null

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
	_toast_layer.add_child(_toasts)
	_top_bar.bind(_session)
	_page_host.setup(_session)
	_sidebar.bind(_session, _page_host.has_page)
	_session.events.session_ended.connect(_on_events_session_ended)
	_page_host.show_page(_first_page())


## Unbinds every node from the session; safe to call more than once.
func _unbind() -> void:
	if _session == null:
		return
	if is_instance_valid(_session) and _session.events.session_ended.is_connected(_on_events_session_ended):
		_session.events.session_ended.disconnect(_on_events_session_ended)
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
	Game.end_session(true)
	get_tree().change_scene_to_file(str(ProjectSettings.get_setting(MAIN_SCENE_SETTING)))
