class_name ActionRunner
extends RefCounted
## The action lanes (docs/01_GDD.md §4, §18): one running action per lane, `main` only until M8.
##
## A lane is idle or RUNNING(skill, action, elapsed_ms). Time arrives only from `advance(delta_ms)`, which completes
## as many cycles as fit (so one 1000 ms step equals ten 100 ms steps). The F-03 interval is computed when a cycle
## starts and kept for that cycle: a modifier change (e.g. a new tool) counts from the next cycle. After loading, the
## first cycle's interval is computed at the first advance (the modifiers are rebuilt after `from_save`).
## A cycle that does not count (`bank_full`) stops the lane. Every stop emits `action_stopped` and is appended to
## the stop reasons log (drained by `stop_reasons_log`, for the offline summary; not saved).
## Artisan actions (with `inputs`) start only when every input is in the bank (`missing_inputs`) and stop the lane
## with the outcome's reason when a cycle fails (ArtisanResolver).
## Signals go to the session EventBus after the state changed; `new_game`/`from_save` emit nothing.
## Dependencies: data, events, modifiers, bank, skills, mastery, rng, combat (only `stop`, from M4).

const SAVE_KEY: StringName = &"actions"
const MAIN: StringName = &"main"
const SECONDARY: StringName = &"secondary"
const LOG_CATEGORY: String = "actions"
const MIN_INTERVAL_KEY: String = "action.min_interval_ms"
const INTERVAL_STAT: StringName = &"skill_interval_pct"
const SAVE_LANES_KEY: String = "lanes"
const SAVE_SKILL_KEY: String = "skill"
const SAVE_ACTION_KEY: String = "action"
const SAVE_ELAPSED_KEY: String = "elapsed_ms"
const LANE_INTERVAL_KEY: String = "interval_ms"
## Lanes in resolution order (docs/01_GDD.md §18: main first).
const LANE_ORDER: Array[StringName] = [MAIN, SECONDARY]


## State of a running lane. `interval_ms` = 0 means "not fixed yet" (computed at the next advance).
class _Lane:
	extends RefCounted

	var action: ActionDef
	var elapsed_ms: int = 0
	var interval_ms: int = 0

	func _init(lane_action: ActionDef, elapsed: int, interval: int) -> void:
		action = lane_action
		elapsed_ms = elapsed
		interval_ms = interval


var _session: GameSession
var _data: GameData
var _events: GameEvents
var _modifiers: ModifierService
var _min_interval_ms: int = 0
# lane id -> running lane; idle lanes have no entry.
var _lanes: Dictionary[StringName, _Lane] = {}
var _stop_log: Array[StringName] = []


func _init(session: GameSession) -> void:
	assert(session != null, "ActionRunner needs a session")
	_session = session
	_data = session.data
	_events = session.events
	_modifiers = session.modifiers
	_min_interval_ms = int(_data.balance_value(MIN_INTERVAL_KEY))


## Every lane idle, empty stop log.
func new_game() -> void:
	_lanes.clear()
	_stop_log.clear()


## {"lanes": {lane: {"skill", "action", "elapsed_ms"}}}; idle lanes are absent (docs/05_INTERFACES.md §6).
func to_save() -> Dictionary:
	var lanes: Dictionary = {}
	for lane_id: StringName in _lanes:
		var lane: _Lane = _lanes[lane_id]
		lanes[String(lane_id)] = {
			SAVE_SKILL_KEY: String(lane.action.skill_id),
			SAVE_ACTION_KEY: String(lane.action.id),
			SAVE_ELAPSED_KEY: lane.elapsed_ms,
		}
	return {SAVE_LANES_KEY: lanes}


## Restores the running lanes. Unknown lanes, malformed entries, unknown actions or actions that could not start now
## are reported and left idle; a malformed or negative elapsed_ms is reported and restarts the cycle at 0.
func from_save(d: Dictionary) -> void:
	new_game()
	var lanes: Variant = d.get(SAVE_LANES_KEY, {})
	if not lanes is Dictionary:
		Log.warn(LOG_CATEGORY, "invalid lanes in save: every lane idle")
		return
	for key: Variant in lanes:
		var lane_id: StringName = StringName(str(key))
		if lane_id != MAIN:
			Log.warn(LOG_CATEGORY, "unknown lane '%s' in save ignored" % lane_id)
			continue
		_load_lane(lane_id, (lanes as Dictionary)[key])


## Starts an action, replacing the one running in the lane (stopped with `replaced`). Starting the action already
## running in the lane changes nothing. unknown_id (unknown skill or action, action of another skill), level_too_low,
## missing_inputs (artisan action without its ingredients), lane_unavailable (any lane but main until M8).
func start(skill_id: StringName, action_id: StringName, lane: StringName = MAIN) -> CommandResult:
	if lane != MAIN:
		return CommandResult.fail(Reasons.LANE_UNAVAILABLE)
	var action: ActionDef = _find_action(skill_id, action_id)
	var check: StringName = _start_check(action)
	if check != &"":
		return CommandResult.fail(check)
	var current: _Lane = _lanes.get(lane)
	if current != null and current.action == action:
		return CommandResult.success()
	# M4 (CombatEngine): starting on the main lane stops combat with REPLACED, null-safe on session.combat.
	stop(lane, Reasons.REPLACED)
	_lanes[lane] = _Lane.new(action, 0, _interval_for(action))
	_events.action_started.emit(lane, action.skill_id, action.id)
	return CommandResult.success()


## Stops the lane with `reason` (emits action_stopped, logs the reason). An idle lane: nothing happens.
func stop(lane: StringName = MAIN, reason: StringName = Reasons.STOPPED_BY_USER) -> void:
	var current: _Lane = _lanes.get(lane)
	if current == null:
		return
	_lanes.erase(lane)
	_stop_log.append(reason)
	_events.action_stopped.emit(lane, current.action.skill_id, reason)


func is_running(lane: StringName = MAIN) -> bool:
	return _lanes.has(lane)


## {} for an idle lane, otherwise {"skill", "action", "elapsed_ms", "interval_ms"} of the current cycle.
func get_lane(lane: StringName = MAIN) -> Dictionary:
	var current: _Lane = _lanes.get(lane)
	if current == null:
		return {}
	return {
		SAVE_SKILL_KEY: current.action.skill_id,
		SAVE_ACTION_KEY: current.action.id,
		SAVE_ELAPSED_KEY: current.elapsed_ms,
		LANE_INTERVAL_KEY: _cycle_interval(current),
	}


## F-04: clamp(elapsed / interval, 0, 1) of the current cycle; 0.0 for an idle lane.
func get_progress(lane: StringName = MAIN) -> float:
	var current: _Lane = _lanes.get(lane)
	if current == null:
		return 0.0
	return clampf(float(current.elapsed_ms) / float(_cycle_interval(current)), 0.0, 1.0)


## F-03 interval the action would have if a cycle started now; 0 (and an error) for an unknown action.
## The lane does not change it until M8 (F-51 secondary-lane penalty).
func current_interval_ms(action_id: StringName, _lane: StringName = MAIN) -> int:
	var action: ActionDef = _data.action(action_id)
	if action == null:
		return 0
	return _interval_for(action)


## 1 in the MVP: the secondary lane (`parallel_lanes`, F-51) arrives with M8.
func lanes_available() -> int:
	return 1


## The stop reasons since the last call, in order; the log is then emptied.
func stop_reasons_log() -> Array[StringName]:
	var result: Array[StringName] = _stop_log.duplicate()
	_stop_log.clear()
	return result


## Moves every running lane forward by delta_ms, completing as many cycles as fit, lanes in LANE_ORDER.
func advance(delta_ms: int) -> void:
	for lane_id: StringName in LANE_ORDER:
		if _lanes.has(lane_id):
			_advance_lane(lane_id, delta_ms)


func _advance_lane(lane_id: StringName, delta_ms: int) -> void:
	var lane: _Lane = _lanes[lane_id]
	if lane.interval_ms <= 0:
		lane.interval_ms = _interval_for(lane.action)
	var remaining: int = delta_ms
	while remaining > 0:
		var needed: int = maxi(0, lane.interval_ms - lane.elapsed_ms)
		if remaining < needed:
			lane.elapsed_ms += remaining
			return
		remaining -= needed
		lane.elapsed_ms = lane.interval_ms
		if not _complete_cycle(lane_id, lane):
			return
		lane.elapsed_ms = 0
		lane.interval_ms = _interval_for(lane.action)


# Resolves one cycle. False when the lane is no longer running this cycle's lane (stopped by the outcome, or
# replaced/stopped by a listener of the signals).
func _complete_cycle(lane_id: StringName, lane: _Lane) -> bool:
	var outcome: ActionOutcome
	if lane.action.is_artisan():
		outcome = ArtisanResolver.resolve(_session, lane.action)
	else:
		outcome = GatheringResolver.resolve(_session, lane.action)
	if not outcome.ok:
		stop(lane_id, outcome.reason)
		return false
	_events.action_completed.emit(lane_id, lane.action.skill_id, lane.action.id, outcome.outputs)
	return _lanes.get(lane_id) == lane


# F-03 with the stat total of the action's context.
func _interval_for(action: ActionDef) -> int:
	var pct: float = _modifiers.total(INTERVAL_STAT, ModifierContext.for_action(action.skill_id, action.id))
	return ActionMath.interval_ms(action.interval_ms, pct, _min_interval_ms)


# The interval fixed for the current cycle, or the one a cycle would get now if it is not fixed yet (after a load).
func _cycle_interval(lane: _Lane) -> int:
	return lane.interval_ms if lane.interval_ms > 0 else _interval_for(lane.action)


# &"" when the action can start now, otherwise the failure reason.
func _start_check(action: ActionDef) -> StringName:
	if action == null:
		return Reasons.UNKNOWN_ID
	if _session.skills.get_level(action.skill_id) < action.level:
		return Reasons.LEVEL_TOO_LOW
	if action.is_artisan():
		return ArtisanResolver.can_start(_session, action).reason
	return &""


# The action `action_id` of skill `skill_id`, or null (no error logged: unknown ids are a game error here).
func _find_action(skill_id: StringName, action_id: StringName) -> ActionDef:
	var known_skill: bool = false
	for skill: SkillDef in _data.skills():
		if skill.id == skill_id:
			known_skill = true
			break
	if not known_skill:
		return null
	for action: ActionDef in _data.actions_for_skill(skill_id):
		if action.id == action_id:
			return action
	return null


func _load_lane(lane_id: StringName, entry: Variant) -> void:
	if not entry is Dictionary:
		Log.warn(LOG_CATEGORY, "invalid entry for lane '%s': idle" % lane_id)
		return
	var e: Dictionary = entry
	var skill_id: StringName = StringName(str(e.get(SAVE_SKILL_KEY, "")))
	var action_id: StringName = StringName(str(e.get(SAVE_ACTION_KEY, "")))
	var action: ActionDef = _find_action(skill_id, action_id)
	var check: StringName = _start_check(action)
	if check != &"":
		Log.warn(LOG_CATEGORY, "lane '%s': action '%s' of '%s' cannot run (%s): idle" % [lane_id, action_id,
				skill_id, check])
		return
	var read: Variant = _read_int(e.get(SAVE_ELAPSED_KEY))
	var elapsed: int = 0
	if read == null or int(read) < 0:
		Log.warn(LOG_CATEGORY, "lane '%s': invalid elapsed_ms, cycle restarts at 0" % lane_id)
	else:
		elapsed = int(read)
	_lanes[lane_id] = _Lane.new(action, elapsed, 0)


# int from an int or an integral float (JSON); null otherwise.
func _read_int(v: Variant) -> Variant:
	if v is int:
		return v
	if v is float:
		var f: float = v
		if f == floorf(f):
			return int(f)
	return null
