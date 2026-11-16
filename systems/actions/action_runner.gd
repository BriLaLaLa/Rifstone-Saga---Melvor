class_name ActionRunner
extends RefCounted
## The production queue (docs/01_GDD_M24.md §35.4, docs/05_INTERFACES_M24.md §5.32): up to `production.queue_slots` jobs run in turn;
## the head works. A job is `count` cycles of a recipe, "until the ingredients run out" (`repeat`), or a blueprint craft.
## Time arrives only from `advance(delta_ms)`: the head completes the cycles that fit and the next job starts with the time left.
## The F-03 interval is fixed when a cycle starts (0 = not fixed yet, e.g. after a load). Missing ingredients at the start of a cycle
## end the job (`missing_inputs`); a full Bank or Armory makes the head wait at 100% (one notification, retried at every advance).
## Every end of a job emits `action_stopped` and goes in the stop reasons log (not saved); `new_game`/`from_save` emit nothing. Its rolls use its own
## `RngService`, derived from the slot seed and saved (Q124). Dependencies: data, events, modifiers, bank, armory, skills, mastery, rng, disciplines.

const SAVE_KEY: StringName = &"actions"
const QUEUE: StringName = &"queue"
const NODE: StringName = &"node"
const LOG_CATEGORY: String = "actions"
const MIN_INTERVAL_KEY: String = "action.min_interval_ms"
const QUEUE_SLOTS_KEY: String = "production.queue_slots"
const MAX_COUNT_KEY: String = "production.max_job_count"
const CRYSTALLIZE_KIND: StringName = &"crystallize"  # ActionDef.kind resolved by EngraverResolver (F-104)
const INTERVAL_STAT: StringName = &"skill_interval_pct"
const SAVE_JOBS_KEY: String = "jobs"
const SAVE_ELAPSED_KEY: String = "elapsed_ms"
const SAVE_RNG_KEY: String = "rng"

var _session: GameSession
var _data: GameData
var _events: GameEvents
var _modifiers: ModifierService
var _min_interval_ms: int = 0
var _rng: RngService
var _jobs: Array[ProductionJob] = []
# The head: elapsed time of the current cycle (or of the blueprint craft), its fixed interval (0 = not fixed yet), waiting for room.
var _elapsed_ms: int = 0
var _interval_ms: int = 0
var _waiting: bool = false
# False while the head is a blueprint whose materials are still in the bank (started at the next advance).
var _head_ready: bool = true
var _stop_log: Array[StringName] = []


func _init(session: GameSession) -> void:
	assert(session != null, "ActionRunner needs a session")
	_session = session
	_data = session.data
	_events = session.events
	_modifiers = session.modifiers
	_min_interval_ms = int(_data.balance_value(MIN_INTERVAL_KEY))
	_rng = ProductionQueueLoader.derive_rng(session)


## Empty queue, empty stop log.
func new_game() -> void:
	_jobs.clear()
	_stop_log.clear()
	_reset_head()
	_head_ready = true
	_rng = ProductionQueueLoader.derive_rng(_session)


## {"jobs": [...], "elapsed_ms": int, "rng": {...}} (docs/05_INTERFACES_M24.md §6b); `elapsed_ms` is the head's.
func to_save() -> Dictionary:
	return {SAVE_JOBS_KEY: jobs(), SAVE_ELAPSED_KEY: _elapsed_ms, SAVE_RNG_KEY: _rng.to_save()}


## Restores the queue (see ProductionQueueLoader): unusable jobs are reported and dropped, the queue is cut to the
## capacity, an invalid elapsed_ms restarts the head cycle at 0. Nothing is emitted.
func from_save(d: Dictionary) -> void:
	new_game()
	_jobs = ProductionQueueLoader.load_jobs(_session, d.get(SAVE_JOBS_KEY), capacity())
	_elapsed_ms = ProductionQueueLoader.load_elapsed(d.get(SAVE_ELAPSED_KEY, 0), _jobs)
	_head_ready = _jobs.is_empty() or not _jobs[0].is_blueprint() or _jobs[0].consumed
	if d.get(SAVE_RNG_KEY) is Dictionary:  # a v8 save without it keeps the generator derived from the seed
		_rng.from_save(d[SAVE_RNG_KEY])


## Appends `count` cycles of the recipe (`repeat`: until the ingredients run out; `count` is not checked). Refusals in order:
## unknown_id (unknown skill or action, action of another skill, gathering or single-cycle), not_learned, recipe_unknown,
## level_too_low, invalid_amount (count outside 1..production.max_job_count), queue_full. Nothing changes on a refusal.
func enqueue(skill_id: StringName, action_id: StringName, count: int, repeat: bool = false) -> CommandResult:
	var action: ActionDef = ProductionQueueLoader.find_action(_data, skill_id, action_id)
	if action == null or action.single or not action.is_artisan():
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	if not _session.disciplines.is_learned(skill_id):
		return CommandResult.fail(Reasons.NOT_LEARNED)
	if action.discover and not _session.disciplines.knows_recipe(action_id):
		return CommandResult.fail(Reasons.RECIPE_UNKNOWN)
	if _session.skills.get_level(skill_id) < action.level:
		return CommandResult.fail(Reasons.LEVEL_TOO_LOW)
	if not repeat and (count < 1 or count > int(_data.balance_value(MAX_COUNT_KEY))):
		return CommandResult.fail(Reasons.INVALID_AMOUNT)
	if _jobs.size() >= capacity():
		return CommandResult.fail(Reasons.QUEUE_FULL)
	var job := ProductionJob.new()
	job.action = action
	job.remaining = count
	job.repeat = repeat
	_push(job)
	return CommandResult.success()


## Appends a blueprint craft. Refusals in order: not_learned (Forging), queue_full, then BlueprintCraft.can_start without
## armory_full (unknown_id, level_too_low, invalid_choice, missing_inputs). The materials leave the bank when it becomes the head.
func enqueue_blueprint(blueprint_id: StringName, chosen_affix: StringName = &"") -> CommandResult:
	if not _session.disciplines.is_learned(BlueprintCraft.SKILL):
		return CommandResult.fail(Reasons.NOT_LEARNED)
	if _jobs.size() >= capacity():
		return CommandResult.fail(Reasons.QUEUE_FULL)
	var check: CommandResult = _can_start_blueprint(blueprint_id, chosen_affix)
	if not check.ok:
		return check
	var job := ProductionJob.new()
	job.action = ProductionQueueLoader.find_action(_data, BlueprintCraft.SKILL, BlueprintCraft.ACTION)
	if job.action == null:
		Log.error(LOG_CATEGORY, "action '%s' is missing from the data" % BlueprintCraft.ACTION)
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	job.blueprint = blueprint_id
	job.chosen_affix = chosen_affix
	_push(job)
	return CommandResult.success()


## Removes the job at `index`. The head stops with `stopped_by_user` and a started blueprint gives its materials back
## (a piece that does not fit is lost, `bank_rejected`). invalid_amount for an index outside the queue.
func cancel(index: int) -> CommandResult:
	if index < 0 or index >= _jobs.size():
		return CommandResult.fail(Reasons.INVALID_AMOUNT)
	if index == 0:
		_end_head(Reasons.STOPPED_BY_USER)
		return CommandResult.success()
	_jobs.remove_at(index)
	_events.production_queue_changed.emit()
	return CommandResult.success()


## Moves the job at `index` to `new_index`. invalid_amount for an index outside the queue, and for the head (0) or a move into 0.
func move(index: int, new_index: int) -> CommandResult:
	var last: int = _jobs.size() - 1
	if index < 0 or index > last or new_index < 0 or new_index > last or index == 0 or new_index == 0:
		return CommandResult.fail(Reasons.INVALID_AMOUNT)
	if index != new_index:
		var job: ProductionJob = _jobs[index]
		_jobs.remove_at(index)
		_jobs.insert(new_index, job)
		_events.production_queue_changed.emit()
	return CommandResult.success()


## Copies of the jobs in order: {"skill", "action", "remaining", "repeat"} or, for a blueprint craft, {"skill", "action":
## "blueprint_craft", "blueprint", "chosen_affix", "duration_ms", "consumed"}.
func jobs() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for job: ProductionJob in _jobs:
		result.append(job.to_dict())
	return result


func is_running() -> bool:
	return not _jobs.is_empty()


## {} or the head's job plus {"elapsed_ms", "interval_ms", "waiting"}.
func current() -> Dictionary:
	if _jobs.is_empty():
		return {}
	var d: Dictionary = _jobs[0].to_dict()
	d["elapsed_ms"] = _elapsed_ms
	d["interval_ms"] = _head_interval()
	d["waiting"] = _waiting
	return d


## F-04: clamp(elapsed / interval, 0, 1) of the head's cycle (or craft); 0.0 for an empty queue.
func get_progress() -> float:
	if _jobs.is_empty():
		return 0.0
	return clampf(float(_elapsed_ms) / float(maxi(_head_interval(), 1)), 0.0, 1.0)


## F-157: ms still needed by the job at `index` (-1: the whole queue). Repeat jobs count the cycles the Bank allows (preservation and
## doubles ignored); the head loses what its cycle has already run.
func estimate_ms(index: int = -1) -> int:
	if index >= 0:
		return maxi(0, _estimate_job(index)) if index < _jobs.size() else 0
	var total: int = 0
	for i: int in _jobs.size():
		total += maxi(0, _estimate_job(i))
	return total


## production.queue_slots
func capacity() -> int:
	return int(_data.balance_value(QUEUE_SLOTS_KEY))


## F-03 interval the action would have if a cycle started now; 0 (and an error) for an unknown action.
func current_interval_ms(action_id: StringName) -> int:
	var action: ActionDef = _data.action(action_id)
	return 0 if action == null else _interval_for(action)


## {} or {"blueprint", "chosen_affix", "duration_ms", "elapsed_ms", "waiting"} of the blueprint craft at the head.
func blueprint_state() -> Dictionary:
	if _jobs.is_empty() or not _jobs[0].is_blueprint():
		return {}
	var job: ProductionJob = _jobs[0]
	return {ProductionJob.KEY_BLUEPRINT: job.blueprint, ProductionJob.KEY_AFFIX: job.chosen_affix,
			ProductionJob.KEY_DURATION: job.duration_ms, SAVE_ELAPSED_KEY: _elapsed_ms, "waiting": _waiting}


## Removes the jobs of `skill_id` (the discipline is unlearned): a started head gives its materials back and stops with `not_learned`.
func drop_jobs_of(skill_id: StringName) -> void:
	var head_dropped: bool = not _jobs.is_empty() and _jobs[0].action.skill_id == skill_id
	var changed: bool = head_dropped
	if head_dropped:
		_end_head(Reasons.NOT_LEARNED, false)
	var kept: Array[ProductionJob] = []
	for job: ProductionJob in _jobs:
		if job.action.skill_id != skill_id:
			kept.append(job)
	if kept.size() != _jobs.size():
		_jobs = kept
		changed = true
	if changed:
		_events.production_queue_changed.emit()
	if head_dropped:
		_start_head()


## The stop reasons since the last call, in order; the log is then emptied.
func stop_reasons_log() -> Array[StringName]:
	var result: Array[StringName] = _stop_log.duplicate()
	_stop_log.clear()
	return result


## Moves the queue forward by delta_ms: the head completes the cycles that fit, the next job starts with the time left.
func advance(delta_ms: int) -> void:
	if not _head_ready:
		_start_head()
	var left: int = delta_ms
	while left >= 0 and not _jobs.is_empty():
		var job: ProductionJob = _jobs[0]
		left = _advance_blueprint(job, left) if job.is_blueprint() else _advance_cycles(job, left)


# Time left after the head's job ended, or -1 while it is still running (all the time used, or waiting for room).
func _advance_cycles(job: ProductionJob, left: int) -> int:
	if _interval_ms <= 0:
		_interval_ms = _interval_for(job.action)
	while true:
		if _elapsed_ms == 0 and not ArtisanResolver.can_start(_session, job.action).ok:
			return _finish(job, Reasons.MISSING_INPUTS, left)
		var needed: int = maxi(0, _interval_ms - _elapsed_ms)
		if left < needed:
			_elapsed_ms += left
			return -1
		left -= needed
		_elapsed_ms = _interval_ms
		var outcome: ActionOutcome = _resolve(job.action)
		if not outcome.ok:
			if outcome.reason == Reasons.BANK_FULL:
				_wait("Deposito pieno: il lavoro attende un posto libero.")
				return -1
			return _finish(job, outcome.reason, left)
		_waiting = false
		_events.action_completed.emit(QUEUE, job.action.skill_id, job.action.id, outcome.outputs)
		if _jobs.is_empty() or _jobs[0] != job:
			return left  # a listener changed the queue
		if not job.repeat:
			job.remaining -= 1
			if job.remaining <= 0:
				return _finish(job, Reasons.JOB_DONE, left)
		_elapsed_ms = 0
		_interval_ms = _interval_for(job.action)
	return -1


# Blueprint craft (docs/05_INTERFACES.md §5.8b): a single cycle; with the Armory full at the end the craft waits at 100%.
func _advance_blueprint(job: ProductionJob, left: int) -> int:
	var needed: int = maxi(0, job.duration_ms - _elapsed_ms)
	if left < needed:
		_elapsed_ms += left
		return -1
	left -= needed
	_elapsed_ms = job.duration_ms
	var uid: int = BlueprintCraft.finish(_session, job.blueprint, job.chosen_affix, _rng)
	if uid == 0:
		_wait("Armeria piena: il lavoro attende un posto libero.")
		return -1
	var bp: ItemDef = _data.item(job.blueprint)
	var ctx: ModifierContext = ModifierContext.for_action(job.action.skill_id, job.action.id)
	_session.skills.add_xp(job.action.skill_id, BlueprintCraft.xp(bp, _data), ctx)
	_events.blueprint_crafted.emit(job.blueprint, uid)
	_events.action_completed.emit(QUEUE, job.action.skill_id, job.action.id, {bp.blueprint.base_id: 1})
	if _jobs.is_empty() or _jobs[0] != job:
		return left
	return _finish(job, Reasons.BLUEPRINT_DONE, left)


func _resolve(action: ActionDef) -> ActionOutcome:
	if action.kind == CRYSTALLIZE_KIND:
		return EngraverResolver.resolve(_session, action, _rng)
	return ArtisanResolver.resolve(_session, action, _rng)


func _wait(text: String) -> void:
	if not _waiting:
		_waiting = true
		_events.notification_requested.emit(text, &"warning")


# The head ended with `reason`: removed, logged, signalled; the next job starts. Returns `left`.
func _finish(job: ProductionJob, reason: StringName, left: int) -> int:
	assert(not _jobs.is_empty() and _jobs[0] == job, "only the head can finish")
	_end_head(reason)
	return left


# Removes the head, stops it with `reason` (a started blueprint gives its materials back) and starts the next job.
func _end_head(reason: StringName, start_next: bool = true) -> void:
	var job: ProductionJob = _jobs[0]
	_jobs.remove_at(0)
	_reset_head()
	if job.is_blueprint() and job.consumed and reason != Reasons.BLUEPRINT_DONE:
		BlueprintCraft.refund(_session, job.blueprint)
	_stop_log.append(reason)
	_events.action_stopped.emit(QUEUE, job.action.skill_id, reason)
	if start_next:
		_events.production_queue_changed.emit()
		_start_head()


func _reset_head() -> void:
	_elapsed_ms = 0
	_interval_ms = 0
	_waiting = false


# The new head starts: a blueprint takes its materials now (missing: it ends with `missing_inputs` and the next one starts).
func _start_head() -> void:
	_head_ready = true
	while not _jobs.is_empty():
		var job: ProductionJob = _jobs[0]
		if job.is_blueprint() and not job.consumed:
			if not _can_start_blueprint(job.blueprint, job.chosen_affix).ok:
				_jobs.remove_at(0)
				_stop_log.append(Reasons.MISSING_INPUTS)
				_events.action_stopped.emit(QUEUE, job.action.skill_id, Reasons.MISSING_INPUTS)
				_events.production_queue_changed.emit()
				continue
			BlueprintCraft.consume(_session, job.blueprint)
			job.consumed = true
			job.duration_ms = _blueprint_duration(job)
		_reset_head()
		_events.action_started.emit(QUEUE, job.action.skill_id, job.action.id)
		return


func _push(job: ProductionJob) -> void:
	_jobs.append(job)
	_events.production_queue_changed.emit()
	if _jobs.size() == 1:
		_start_head()


# BlueprintCraft.can_start, where a full Armory does not refuse (it makes the craft wait at the end).
func _can_start_blueprint(blueprint_id: StringName, chosen_affix: StringName) -> CommandResult:
	var check: CommandResult = BlueprintCraft.can_start(_session, blueprint_id, chosen_affix)
	if not check.ok and check.reason == Reasons.ARMORY_FULL:
		return CommandResult.success()
	return check


func _interval_for(action: ActionDef) -> int:
	var pct: float = _modifiers.total(INTERVAL_STAT, ModifierContext.for_action(action.skill_id, action.id))
	return ActionMath.interval_ms(action.interval_ms, pct, _min_interval_ms)


# The head's fixed interval (blueprint: the craft duration), or the one a cycle would get now if it is not fixed yet.
func _head_interval() -> int:
	var job: ProductionJob = _jobs[0]
	if job.is_blueprint():
		return job.duration_ms
	return _interval_ms if _interval_ms > 0 else _interval_for(job.action)


# F-157 for one job (may be negative for the head when the elapsed time exceeds it: callers clamp).
func _estimate_job(index: int) -> int:
	var job: ProductionJob = _jobs[index]
	var done: int = _elapsed_ms if index == 0 else 0
	if job.is_blueprint():
		return (job.duration_ms if job.consumed else _blueprint_duration(job)) - done
	var cycle: int = _head_interval() if index == 0 else _interval_for(job.action)
	var cycles: int = ProductionQueueLoader.cycles_possible(_session, job.action) if job.repeat else job.remaining
	return cycles * cycle - done


# F-90 + F-03 of a blueprint craft now.
func _blueprint_duration(job: ProductionJob) -> int:
	var pct: float = _modifiers.total(INTERVAL_STAT, ModifierContext.for_action(job.action.skill_id, job.action.id))
	return BlueprintCraft.duration_ms(_data.item(job.blueprint), pct, _data)
