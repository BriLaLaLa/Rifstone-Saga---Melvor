class_name TutorialOverlay
extends Control
## Full-screen layer of the mandatory tutorial (docs/01_GDD_M30.md §41.8, docs/05_INTERFACES_M30.md §7.ab). Child of the
## MainScreen, above the HintCard and below the offline summary and the settings.
##
## It reads `session.tutorial` and sends only commands: `acknowledge`, `skip_step` (and, through the MainScreen,
## `notify_page_opened`). While the player must change page it shows "Vai a <pagina>" and leaves only that sidebar row
## (and the menu button) free; during a step it shows the card, frames the target (`TutorialTargets`) and leaves the page
## area usable. The sidebar and the top bar are covered by the blockers. The state is redrawn on the `tutorial_*` signals
## and when the step, the navigation or the valve change; the frame and the card position follow the real rectangles every
## frame. It keeps no game state, and frees itself when the tutorial is completed or the session ends.
##
## Injection point (set it before `bind`): `is_blocked`: `() -> bool`, true while the overlay must stay hidden; the default
## is "Game.state is offline".

const LOG_CATEGORY: String = "ui"
const MENU_BUTTON_NAME: String = "MenuButton"
## Card corners tried, as the fraction of the free space: bottom right first.
const CORNERS: Array[Vector2] = [Vector2(1, 1), Vector2(0, 1), Vector2(1, 0), Vector2(0, 0)]

## `() -> bool`; invalid means "Game.state == Game.STATE_OFFLINE".
var is_blocked: Callable = Callable()

var _session: GameSession = null
var _host: PageHost = null
var _sidebar: Sidebar = null
var _top_bar: TopBar = null
## Presentation: what was drawn last (to redraw when it changes), the pulse phase and the page to go to.
var _signature: Array = []
var _layout_key: Array = []
var _pulse: float = 0.0
var _nav_route: StringName = &""

@onready var _blockers: TutorialBlockers = %Blockers
@onready var _frame: Panel = %Frame
@onready var _card: TutorialPanel = %Card


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = UiStyle.TUTORIAL_FRAME_COLOR
	style.set_border_width_all(UiStyle.TUTORIAL_FRAME_WIDTH)
	style.set_corner_radius_all(UiStyle.TUTORIAL_FRAME_RADIUS)
	_frame.add_theme_stylebox_override("panel", style)
	_card.next_pressed.connect(_on_next_pressed)
	_card.skip_pressed.connect(_on_skip_pressed)
	_card.skip_tutorial_confirmed.connect(_on_skip_tutorial_confirmed)
	_card.resized.connect(_layout)


func bind(session: GameSession, page_host: PageHost, sidebar: Sidebar, top_bar: TopBar) -> void:
	unbind()
	_session = session
	_host = page_host
	_sidebar = sidebar
	_top_bar = top_bar
	var events: GameEvents = _session.events
	events.tutorial_step_changed.connect(_on_tutorial_changed)
	events.tutorial_progress.connect(_on_tutorial_changed)
	events.tutorial_completed.connect(refresh)
	events.session_ended.connect(_on_session_ended)
	_host.page_changed.connect(_on_page_changed)
	refresh()


func unbind() -> void:
	if _session != null and is_instance_valid(_session):
		var events: GameEvents = _session.events
		if events.tutorial_step_changed.is_connected(_on_tutorial_changed):
			events.tutorial_step_changed.disconnect(_on_tutorial_changed)
		if events.tutorial_progress.is_connected(_on_tutorial_changed):
			events.tutorial_progress.disconnect(_on_tutorial_changed)
		if events.tutorial_completed.is_connected(refresh):
			events.tutorial_completed.disconnect(refresh)
		if events.session_ended.is_connected(_on_session_ended):
			events.session_ended.disconnect(_on_session_ended)
	if _host != null and is_instance_valid(_host) and _host.page_changed.is_connected(_on_page_changed):
		_host.page_changed.disconnect(_on_page_changed)
	_session = null
	_host = null
	_sidebar = null
	_top_bar = null


## Redraws the card from `session.tutorial`; frees the overlay when the tutorial is completed.
func refresh() -> void:
	if _session == null:
		return
	var tutorial: TutorialSystem = _session.tutorial
	if tutorial == null or tutorial.is_completed():
		_finish()
		return
	_signature = _read_signature(tutorial)
	var step: TutorialStepDef = tutorial.current_step()
	if tutorial.needs_navigation():
		_nav_route = tutorial.required_route()
		_card.show_navigation(TutorialTexts.page_name(_nav_route))
		if _sidebar != null:
			_sidebar.reveal(_nav_route)
	else:
		_nav_route = &""
		_card.show_step(step.title, step.text, tutorial.step_index(), tutorial.step_count(), tutorial.step_progress(),
				tutorial.step_target_count(), tutorial.can_acknowledge(), tutorial.can_skip_step(),
				tutorial.step_progress_text(), tutorial.ack_text())
	_layout_key = []
	_layout()


func _process(delta: float) -> void:
	if _session == null:
		return
	var blocked: bool = _blocked()
	if visible == blocked:
		visible = not blocked
	if blocked:
		return
	if _read_signature(_session.tutorial) != _signature:
		refresh()
		if _session == null:
			return
	_pulse += delta
	_frame.modulate.a = lerpf(UiStyle.TUTORIAL_NAV_PULSE_ALPHA, 1.0, 0.5 + 0.5 * sin(TAU * _pulse / UiStyle.TUTORIAL_PULSE_SEC))
	_layout()


func _exit_tree() -> void:
	unbind()


func _read_signature(tutorial: TutorialSystem) -> Array:
	return [tutorial.step_index(), tutorial.needs_navigation(), tutorial.can_acknowledge(), tutorial.can_skip_step(),
			tutorial.step_progress(), tutorial.is_completed()]


func _blocked() -> bool:
	if is_blocked.is_valid():
		return is_blocked.call() as bool
	return Game.state == Game.STATE_OFFLINE


## Blockers, frame and card position from the real rectangles; the frame and the card move only when one changed.
func _layout() -> void:
	if _session == null or _host == null or _sidebar == null or _top_bar == null or _session.tutorial.is_completed():
		return
	var holes: Array[Rect2] = []
	var menu: Control = _top_bar.find_child(MENU_BUTTON_NAME, true, false) as Control
	if menu != null:
		holes.append(menu.get_global_rect())
	var nav_row: Control = _sidebar.nav_row(_nav_route) if _nav_route != &"" else null
	if nav_row != null:
		holes.append(nav_row.get_global_rect())
	var area: Rect2 = _host.get_global_rect()
	var target: Control = nav_row
	var wanted: String = ""
	if _nav_route == &"":
		wanted = _session.tutorial.current_step().target
		target = TutorialTargets.resolve(wanted, get_parent() as Control)
	var has_target: bool = target != null or wanted != ""
	# A missing control is replaced by the page area (the step is never blocked).
	var target_rect: Rect2 = target.get_global_rect() if target != null else (area if has_target else Rect2())
	_blockers.set_areas([_sidebar.get_global_rect(), _top_bar.get_global_rect()], holes)
	_frame.visible = has_target
	var key: Array = [area, target_rect, has_target, _card.size, size]
	if key == _layout_key:
		return
	_layout_key = key
	if has_target:
		var padded: Rect2 = target_rect.grow(UiStyle.TUTORIAL_FRAME_PADDING)
		_frame.global_position = padded.position
		_frame.size = padded.size
	_card.global_position = _card_position(has_target, target_rect, area)


## Top left corner of the card: the page area corner farthest from the target (never over it when possible); centred on
## the screen when the step has no target.
func _card_position(has_target: bool, target_rect: Rect2, area: Rect2) -> Vector2:
	var card_size: Vector2 = _card.size
	if not has_target:
		return get_global_rect().get_center() - card_size * 0.5
	var inner: Rect2 = area.grow(-UiStyle.TUTORIAL_PANEL_MARGIN)
	var best: Vector2 = inner.position
	var best_score: float = -INF
	for corner: Vector2 in CORNERS:
		var pos: Vector2 = inner.position + (inner.size - card_size).max(Vector2.ZERO) * corner
		var rect := Rect2(pos, card_size)
		var score: float = -1.0 if rect.intersects(target_rect.grow(UiStyle.TUTORIAL_PANEL_MARGIN)) \
				else rect.get_center().distance_to(target_rect.get_center())
		if score > best_score:
			best_score = score
			best = pos
	return best


func _finish() -> void:
	unbind()
	if get_parent() != null:
		get_parent().remove_child(self)
	queue_free()


func _on_tutorial_changed(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	refresh()


func _on_page_changed(_page_id: StringName) -> void:
	refresh()


func _on_session_ended(_slot: int) -> void:
	_finish()


func _on_next_pressed() -> void:
	if _session != null and not _session.tutorial.acknowledge().ok:
		_card.show_refused(TutorialTexts.REFUSED_TEXT)


func _on_skip_pressed() -> void:
	if _session != null and not _session.tutorial.skip_step().ok:
		_card.show_refused(TutorialTexts.REFUSED_TEXT)


## "Sì" of the confirmation: the command answers; on `ok` the `tutorial_completed` signal frees the overlay, a refusal
## (already completed, a double click) is ignored.
func _on_skip_tutorial_confirmed() -> void:
	if _session != null:
		_session.tutorial.skip_tutorial()
