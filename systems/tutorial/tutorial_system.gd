class_name TutorialSystem
extends RefCounted
## The mandatory tutorial of a new game (docs/01_GDD_M30.md §41, docs/05_INTERFACES_M30.md §5.41): a list of steps from
## data/tutorial/steps.json, each ended by `ack`, a counted EventBus event or a measure read from the model. The UI never decides that a
## step is over: it notifies the page shown (`notify_page_opened`) and sends `acknowledge` / `skip_step`.
## Existing slots are completed (migration v11 -> v12). Conditions and measures live in TutorialConditions / TutorialMetrics; the
## starter quests that follow the tutorial are `starter` (StarterQuests, same module, saved under `tutorial.starter`).
## The listeners are those of the current step only; the session frees the events, so nothing is left connected.

const SAVE_KEY: StringName = &"tutorial"
const LOG_CATEGORY: String = "tutorial"

var starter: StarterQuests

var _session: GameSession
var _data: GameData
var _events: GameEvents
var _completed: bool = false
var _index: int = 0
var _progress: int = 0
var _since_ms: int = 0
var _visited: Array[StringName] = []
var _current_page: StringName = &""
var _listening: Array[StringName] = []
var _arg_names: Dictionary[StringName, PackedStringArray] = {}


func _init(session: GameSession) -> void:
	assert(session != null, "TutorialSystem needs a session")
	_session = session
	_data = session.data
	_events = session.events
	starter = StarterQuests.new(session, self)


# --- reads ---

func is_active() -> bool:
	return not _completed


func is_completed() -> bool:
	return _completed


func step_count() -> int:
	return _data.tutorial_steps().size()


func step_index() -> int:
	return step_count() if _completed else _index


func current_step() -> TutorialStepDef:
	return null if _completed else _data.tutorial_steps()[_index]


## Events counted in the current step (only when it counts more than one).
func step_progress() -> int:
	return _progress if step_target_count() > 1 else 0


func step_target_count() -> int:
	var step: TutorialStepDef = current_step()
	if step != null:
		for c: TutorialCondition in step.done_when:
			if c.type == TutorialCondition.TYPE_EVENT:
				return c.count
	return 1


func current_page() -> StringName:
	return _current_page


func required_route() -> StringName:
	var step: TutorialStepDef = current_step()
	return &"" if step == null else step.page


func needs_navigation() -> bool:
	return required_route() != &"" and _current_page != required_route()


## Completed, always-open pages, any page during a step without a page, otherwise the pages of the steps reached so far.
func is_page_open(route: StringName) -> bool:
	var page: StringName = _route_of(route)
	if _completed or _data.tutorial_always_open().has(page) or current_step().page == &"":
		return true
	var steps: Array[TutorialStepDef] = _data.tutorial_steps()
	for i: int in range(0, _index + 1):
		if steps[i].page == page:
			return true
	return false


func has_visited(route: StringName) -> bool:
	return _visited.has(_route_of(route))


func can_acknowledge() -> bool:
	return _has_type(TutorialCondition.TYPE_ACK)


## Active, a step that does not end with Avanti, and `tutorial.stuck_ms` of game time passed in it.
func can_skip_step() -> bool:
	return not _completed and not _has_type(TutorialCondition.TYPE_ACK) \
			and _session.play_time_ms - _since_ms >= _data.tutorial_stuck_ms()


# --- commands ---

## The UI says which page it shows (`skill:forestry` is the route `skill`): the visit is recorded, then the measures are reread.
func notify_page_opened(page_id: StringName) -> void:
	var page: StringName = _route_of(page_id)
	_current_page = page
	if DataValidatorTutorial.ROUTES.has(String(page)) and not _visited.has(page):
		_visited.append(page)
	if not _completed:
		_check_metrics()
	starter.on_page_visited()


func acknowledge() -> CommandResult:
	if _completed:
		return CommandResult.fail(Reasons.TUTORIAL_INACTIVE)
	if not can_acknowledge():
		return CommandResult.fail(Reasons.WRONG_STEP)
	_finish_step()
	return CommandResult.success()


func skip_step() -> CommandResult:
	if _completed:
		return CommandResult.fail(Reasons.TUTORIAL_INACTIVE)
	if not can_skip_step():
		return CommandResult.fail(Reasons.NOT_STUCK)
	_finish_step()
	return CommandResult.success()


## Active from step 0 (its gift is delivered), nothing visited, the starter quests reset. No tutorial signal.
func new_game() -> void:
	_stop_listening()
	_completed = false
	_index = 0
	_visited.clear()
	_current_page = &""
	starter.new_game()
	_begin_step(0, true)


func to_save() -> Dictionary:
	var visited: Array = []
	for route: StringName in _visited:
		visited.append(String(route))
	return {"completed": _completed, "step": "" if _completed else String(current_step().id), "progress": 0 if _completed else _progress,
			"since_ms": 0 if _completed else _since_ms, "visited": visited, "starter": starter.to_save()}


## Tolerant (Log.warn, no signal): a bad `completed` or an unknown step means completed (never trap the player).
func from_save(d: Dictionary) -> void:
	_stop_listening()
	_visited.clear()
	_current_page = &""
	var saved: Variant = d.get("visited", [])
	for route: Variant in (saved as Array if saved is Array else []):
		if DataValidatorTutorial.ROUTES.has(str(route)) and not _visited.has(StringName(str(route))):
			_visited.append(StringName(str(route)))
	_completed = d.get("completed") is not bool or d["completed"] as bool
	if d.get("completed") is not bool:
		Log.warn(LOG_CATEGORY, "'completed' is not a boolean: tutorial completed")
	if not _completed:
		_index = _index_of(StringName(str(d.get("step", ""))))
		if _index < 0:
			Log.warn(LOG_CATEGORY, "unknown step '%s': tutorial completed" % str(d.get("step")))
			_completed = true
	if _completed:
		_index = step_count()
		_progress = 0
		_since_ms = 0
	else:
		_begin_step(_index, false)
		_progress = clampi(_whole(d.get("progress"), 0), 0, step_target_count())
		var since: int = _whole(d.get("since_ms"), -1)
		_since_ms = since if since >= 0 and since <= _session.play_time_ms else _session.play_time_ms
	var starter_block: Variant = d.get("starter", {})
	starter.from_save(starter_block as Dictionary if starter_block is Dictionary else {})


# --- steps ---

# Enters step `index`: counters, listeners and, with `gift`, its Mail gift (not on a load). It sends no signal.
func _begin_step(index: int, gift: bool) -> void:
	_stop_listening()
	_index = index
	_progress = 0
	_since_ms = _session.play_time_ms
	var step: TutorialStepDef = current_step()
	for c: TutorialCondition in step.done_when:
		if c.type == TutorialCondition.TYPE_EVENT:
			_listen(c.signal_name)
		elif c.type == TutorialCondition.TYPE_METRIC:
			for signal_name: StringName in (TutorialMetrics.METRICS.get(c.metric, []) as Array):
				_listen(signal_name)
	if gift:
		_deliver_gift(step)



func _deliver_gift(step: TutorialStepDef) -> void:
	if step.gift_money > 0:
		_session.mail.post(&"tutorial_gift", {"money": step.gift_money})
	elif not step.gift_items.is_empty():
		var rows: Array[Dictionary] = []
		for q: ItemQty in step.gift_items:
			rows.append({"item": q.item_id, "qty": q.qty})
		_session.mail.post(&"tutorial_gift", {"items": rows})


# Closes the current step and opens the next one at once (or completes the tutorial); a measure already true ends it again.
func _finish_step() -> void:
	_stop_listening()
	if _index + 1 >= step_count():
		_completed = true
		_index = step_count()
		_progress = 0
		_events.tutorial_completed.emit()
		starter.activate(false)
		return
	_begin_step(_index + 1, true)
	_events.tutorial_step_changed.emit(current_step().id, _index, step_count())
	_check_metrics()


func _check_metrics() -> void:
	var step: TutorialStepDef = current_step()
	if step == null:
		return
	for c: TutorialCondition in step.done_when:
		if c.type == TutorialCondition.TYPE_METRIC and TutorialMetrics.value(_session, c.metric, c.arg) >= c.gte:
			_finish_step()
			return


# The generic listener: the emitted arguments, then the signal name (bound last).
func _on_signal(...args: Array) -> void:
	var signal_name: StringName = args.pop_back()
	var step: TutorialStepDef = current_step()
	if step == null:
		return
	for c: TutorialCondition in step.done_when:
		if c.type != TutorialCondition.TYPE_EVENT or c.signal_name != signal_name:
			continue
		if not TutorialConditions.matches(c.args, _arg_names[signal_name], args):
			continue
		if c.count > 1:
			_progress += 1
			_events.tutorial_progress.emit(step.id, mini(_progress, c.count), c.count)
			if _progress < c.count:
				continue
		_finish_step()
		return
	_check_metrics()


func _listen(signal_name: StringName) -> void:
	if _listening.has(signal_name):
		return
	_listening.append(signal_name)
	_arg_names[signal_name] = TutorialConditions.signal_arg_names(_events, signal_name)
	Signal(_events, signal_name).connect(Callable(self, &"_on_signal").bind(signal_name))


func _stop_listening() -> void:
	for signal_name: StringName in _listening:
		var callable: Callable = Callable(self, &"_on_signal").bind(signal_name)
		if Signal(_events, signal_name).is_connected(callable):
			Signal(_events, signal_name).disconnect(callable)
	_listening.clear()


func _has_type(type: StringName) -> bool:
	var step: TutorialStepDef = current_step()
	if step != null:
		for c: TutorialCondition in step.done_when:
			if c.type == type:
				return true
	return false


func _index_of(step_id: StringName) -> int:
	var steps: Array[TutorialStepDef] = _data.tutorial_steps()
	for i: int in steps.size():
		if steps[i].id == step_id:
			return i
	return -1


# `skill:forestry` -> `skill`.
static func _route_of(page_id: StringName) -> StringName:
	return StringName(String(page_id).get_slice(":", 0))


static func _whole(v: Variant, fallback: int) -> int:
	if v is int:
		return v
	if v is float and float(v) == floorf(float(v)):
		return int(v)
	return fallback
