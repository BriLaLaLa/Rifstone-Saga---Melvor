class_name ProductionQueueLoader
extends RefCounted
## Tolerant loading of the production queue and small reads of ActionRunner (docs/05_INTERFACES_M24.md §5.32, §6b).
## Internal helper of ActionRunner (not an API for other modules): static functions, no state.

const LOG_CATEGORY: String = "actions"


## The jobs of the save entry `raw` (an Array of Dictionaries). Unknown or unusable jobs (unknown action, discipline not learned,
## recipe not discovered, `remaining` not valid, malformed blueprint craft) are reported and dropped; more than `capacity` are cut.
static func load_jobs(session: GameSession, raw: Variant, capacity: int) -> Array[ProductionJob]:
	var jobs: Array[ProductionJob] = []
	if not raw is Array:
		if raw != null:
			Log.warn(LOG_CATEGORY, "invalid jobs in save: empty queue")
		return jobs
	for entry: Variant in raw as Array:
		var job: ProductionJob = _load_job(session, entry)
		if job == null:
			continue
		if jobs.size() >= capacity:
			Log.warn(LOG_CATEGORY, "queue over its capacity %d in save: the last jobs are dropped" % capacity)
			break
		jobs.append(job)
	return jobs


## The head's elapsed_ms: `raw` when a non-negative integer (a blueprint craft is limited to its duration), otherwise 0 (reported).
static func load_elapsed(raw: Variant, jobs: Array[ProductionJob]) -> int:
	var read: Variant = read_int(raw)
	if read == null or int(read) < 0:
		Log.warn(LOG_CATEGORY, "invalid elapsed_ms, the head cycle restarts at 0")
		return 0
	if jobs.is_empty():
		return 0
	return mini(int(read), jobs[0].duration_ms) if jobs[0].is_blueprint() else int(read)


## min over the inputs of floor(owned / qty): the cycles the Bank allows (F-157; preservation and doubles ignored).
static func cycles_possible(session: GameSession, action: ActionDef) -> int:
	var cycles: int = -1
	for entry: ItemQty in action.inputs:
		@warning_ignore("integer_division")
		var possible: int = session.bank.get_count(entry.item_id) / maxi(entry.qty, 1)
		cycles = possible if cycles < 0 else mini(cycles, possible)
	return maxi(cycles, 0)


## The action `action_id` of skill `skill_id`, or null (no error logged: unknown ids are a game error to the caller).
static func find_action(data: GameData, skill_id: StringName, action_id: StringName) -> ActionDef:
	var known: bool = false
	for skill: SkillDef in data.skills():
		if skill.id == skill_id:
			known = true
			break
	if not known:
		return null
	for action: ActionDef in data.actions_for_skill(skill_id):
		if action.id == action_id:
			return action
	return null


## int from an int or an integral float (JSON); null otherwise.
static func read_int(v: Variant) -> Variant:
	if v is int:
		return v
	if v is float:
		var f: float = v
		if f == floorf(f):
			return int(f)
	return null


static func _load_job(session: GameSession, entry: Variant) -> ProductionJob:
	if not entry is Dictionary:
		Log.warn(LOG_CATEGORY, "invalid job in save ignored")
		return null
	var e: Dictionary = entry
	var skill_id := StringName(str(e.get(ProductionJob.KEY_SKILL, "")))
	var action_id := StringName(str(e.get(ProductionJob.KEY_ACTION, "")))
	var action: ActionDef = find_action(session.data, skill_id, action_id)
	if action == null:
		Log.warn(LOG_CATEGORY, "job '%s' of '%s' is unknown: ignored" % [action_id, skill_id])
		return null
	if not session.disciplines.is_learned(skill_id):
		Log.warn(LOG_CATEGORY, "job '%s': discipline '%s' is not learned: ignored" % [action_id, skill_id])
		return null
	var job := ProductionJob.new()
	job.action = action
	if e.has(ProductionJob.KEY_BLUEPRINT):
		return job if _fill_blueprint(session.data, job, e) else null
	if action.single or not action.is_artisan() or (action.discover and not session.disciplines.knows_recipe(action_id)):
		Log.warn(LOG_CATEGORY, "job '%s' cannot be queued now: ignored" % action_id)
		return null
	job.repeat = e.get(ProductionJob.KEY_REPEAT, false) == true
	var remaining: Variant = read_int(e.get(ProductionJob.KEY_REMAINING, 0))
	if not job.repeat and (remaining == null or int(remaining) < 1):
		Log.warn(LOG_CATEGORY, "job '%s': invalid remaining: ignored" % action_id)
		return null
	job.remaining = 0 if job.repeat else int(remaining)
	return job


# A saved blueprint craft: the blueprint must exist; a started one (`consumed`) needs a positive duration.
static func _fill_blueprint(data: GameData, job: ProductionJob, e: Dictionary) -> bool:
	var blueprint_id := StringName(str(e[ProductionJob.KEY_BLUEPRINT]))
	var duration: Variant = read_int(e.get(ProductionJob.KEY_DURATION, 0))
	var consumed: bool = e.get(ProductionJob.KEY_CONSUMED, false) == true
	if not job.action.single or not data.has_item(blueprint_id) or not data.item(blueprint_id).is_blueprint() \
			or duration == null or int(duration) < 0 or (consumed and int(duration) <= 0):
		Log.warn(LOG_CATEGORY, "invalid blueprint craft '%s' in save: ignored" % blueprint_id)
		return false
	job.blueprint = blueprint_id
	job.chosen_affix = StringName(str(e.get(ProductionJob.KEY_AFFIX, "")))
	job.duration_ms = int(duration)
	job.consumed = consumed
	return true
