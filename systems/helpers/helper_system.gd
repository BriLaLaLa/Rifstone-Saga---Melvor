class_name HelperSystem
extends RefCounted
## The helpers of the gathering trades (docs/01_GDD.md §4.1, docs/05_INTERFACES.md §5.21; F-101, F-102): one helper per
## trade, at one grade, working one unlocked resource while the player does something else, also offline.
##
## A cycle takes the F-101 interval, fixed when the cycle starts; at its end `GatheringResolver.resolve(..., grade)`
## runs the helper profile (same rolls as the player, the player's tool ignored, F-102 xp and mastery share). When the
## Deposit has no room for a new item the cycle does not count: the helper waits (`blocked`) and retries at every
## `advance`; no progress is lost. No modifier source of its own, so no `rebuild_modifiers`.
## Dependencies: data, events, modifiers, bank (and through it the Deposit), skills, mastery, rng.

const SAVE_KEY: StringName = &"helpers"
const LOG_CATEGORY: String = "helpers"
const MIN_INTERVAL_KEY: String = "action.min_interval_ms"
const INTERVAL_STAT: StringName = &"skill_interval_pct"
const GATHERING: StringName = &"gathering"
const SAVE_GRADE_KEY: String = "grade"
const SAVE_ACTION_KEY: String = "action"
const SAVE_ELAPSED_KEY: String = "elapsed_ms"
const BLOCKED_TEXT: String = "Un aiutante è fermo: Deposito pieno."


## The state of a trade with a helper.
class _Helper:
	extends RefCounted
	var grade: StringName = &""
	var action: ActionDef = null
	var elapsed_ms: int = 0
	var interval_ms: int = 0  # 0 = not fixed yet (computed at the next advance)
	var blocked: bool = false


var _session: GameSession
var _data: GameData
var _events: GameEvents
var _modifiers: ModifierService
var _min_interval_ms: int = 0
var _skills: Array[StringName] = []
var _grade_ids: Array[StringName] = []
# trade -> helper (only the trades that have one)
var _helpers: Dictionary[StringName, _Helper] = {}


func _init(session: GameSession) -> void:
	assert(session != null, "HelperSystem needs a session")
	_session = session
	_data = session.data
	_events = session.events
	_modifiers = session.modifiers
	_min_interval_ms = int(_data.balance_value(MIN_INTERVAL_KEY))
	for skill: SkillDef in _data.skills_by_category(GATHERING):
		_skills.append(skill.id)
	for grade: HelperGradeDef in _data.helper_grades():
		_grade_ids.append(grade.id)


func is_helper_skill(skill_id: StringName) -> bool:
	return _skills.has(skill_id)


## The grade id of the trade's helper, &"" if it has none.
func get_grade(skill_id: StringName) -> StringName:
	return _helpers[skill_id].grade if _helpers.has(skill_id) else &""


## 0 = no helper, 1..4 = position in `helper.grades`.
func grade_rank(skill_id: StringName) -> int:
	return _grade_ids.find(get_grade(skill_id)) + 1 if _helpers.has(skill_id) else 0


func get_action(skill_id: StringName) -> StringName:
	if _helpers.has(skill_id) and _helpers[skill_id].action != null:
		return _helpers[skill_id].action.id
	return &""


## Waiting because the Deposit is full.
func is_blocked(skill_id: StringName) -> bool:
	return _helpers.has(skill_id) and _helpers[skill_id].blocked


## F-04: clamp(elapsed / interval, 0, 1); 0.0 without helper or action.
func get_progress(skill_id: StringName) -> float:
	var interval: int = _cycle_interval(skill_id)
	if interval <= 0:
		return 0.0
	return clampf(float(_helpers[skill_id].elapsed_ms) / float(interval), 0.0, 1.0)


## F-101: the interval of a cycle of `action_id` (empty = the current action) if it started now; 0 without helper or
## action (or an action that is not of the trade).
func interval_ms(skill_id: StringName, action_id: StringName = &"") -> int:
	if not _helpers.has(skill_id):
		return 0
	var action: ActionDef = _helpers[skill_id].action if action_id == &"" else _find_action(skill_id, action_id)
	return _interval_for(skill_id, action, _helpers[skill_id].grade)


## The trade's actions the player's level allows, in data order.
func available_actions(skill_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	if not is_helper_skill(skill_id):
		return result
	var level: int = _session.skills.get_level(skill_id)
	for action: ActionDef in _data.actions_for_skill(skill_id):
		if action.level <= level and not action.single:
			result.append(action.id)
	return result


## Uses a contract of the Bank: unknown_id, not_a_contract, not_enough_items, helper_not_better (grade not above the
## current one: the contract is not consumed). Keeps the assigned action, restarts the cycle.
func hire(contract_item_id: StringName) -> CommandResult:
	if not _data.has_item(contract_item_id):
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	var item: ItemDef = _data.item(contract_item_id)
	if not item.is_contract():
		return CommandResult.fail(Reasons.NOT_A_CONTRACT)
	if not _session.bank.has(contract_item_id, 1):
		return CommandResult.fail(Reasons.NOT_ENOUGH_ITEMS)
	var rank: int = _grade_ids.find(item.contract_grade) + 1
	if rank <= grade_rank(item.contract_skill):
		return CommandResult.fail(Reasons.HELPER_NOT_BETTER)
	var removed: CommandResult = _session.bank.remove(contract_item_id, 1)
	if not removed.ok:
		return removed
	var helper: _Helper = _helpers.get(item.contract_skill, null)
	if helper == null:
		helper = _Helper.new()
		_helpers[item.contract_skill] = helper
	helper.grade = item.contract_grade
	_restart(item.contract_skill, helper)
	_events.helper_changed.emit(item.contract_skill, helper.grade, get_action(item.contract_skill))
	return CommandResult.success()


## unknown_id (not a gathering trade, or an action of another trade), no_helper, level_too_low. The same action again
## changes nothing; another one restarts the cycle.
func set_action(skill_id: StringName, action_id: StringName) -> CommandResult:
	var action: ActionDef = _find_action(skill_id, action_id)
	if action == null or action.single:
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	if not _helpers.has(skill_id):
		return CommandResult.fail(Reasons.NO_HELPER)
	if _session.skills.get_level(skill_id) < action.level:
		return CommandResult.fail(Reasons.LEVEL_TOO_LOW)
	var helper: _Helper = _helpers[skill_id]
	if helper.action == action:
		return CommandResult.success()
	helper.action = action
	_restart(skill_id, helper)
	_events.helper_changed.emit(skill_id, helper.grade, action.id)
	return CommandResult.success()


## Takes the action away (the helper stays). No-op without an action.
func stop(skill_id: StringName) -> void:
	if not _helpers.has(skill_id) or _helpers[skill_id].action == null:
		return
	var helper: _Helper = _helpers[skill_id]
	helper.action = null
	_restart(skill_id, helper)
	_events.helper_changed.emit(skill_id, helper.grade, &"")


## Moves every helper with an action forward by delta_ms, completing as many cycles as fit, trades in data order.
func advance(delta_ms: int) -> void:
	for skill_id: StringName in _skills:
		var helper: _Helper = _helpers.get(skill_id, null)
		if helper != null and helper.action != null:
			_advance_helper(skill_id, helper, delta_ms)


func new_game() -> void:
	_helpers.clear()


## {skill_id: {"grade": id, "action": id | "", "elapsed_ms": int}} for the trades that have a helper.
func to_save() -> Dictionary:
	var d: Dictionary = {}
	for skill_id: StringName in _skills:
		if _helpers.has(skill_id):
			var helper: _Helper = _helpers[skill_id]
			d[String(skill_id)] = {SAVE_GRADE_KEY: String(helper.grade),
					SAVE_ACTION_KEY: String(helper.action.id) if helper.action != null else "",
					SAVE_ELAPSED_KEY: helper.elapsed_ms}
	return d


## Tolerant: a trade that is not gathering or an unknown grade drops the entry; an unknown action, one of another
## trade or above the level leaves the helper without action; a bad `elapsed_ms` is 0. Emits nothing.
func from_save(d: Dictionary) -> void:
	_helpers.clear()
	for key: Variant in d:
		var skill_id: StringName = StringName(str(key))
		var entry: Variant = d[key]
		if not is_helper_skill(skill_id) or not entry is Dictionary:
			Log.warn(LOG_CATEGORY, "invalid helper entry '%s' in save ignored" % skill_id)
			continue
		var grade: StringName = StringName(str((entry as Dictionary).get(SAVE_GRADE_KEY, "")))
		if not _grade_ids.has(grade):
			Log.warn(LOG_CATEGORY, "unknown helper grade '%s' of '%s' in save: no helper" % [grade, skill_id])
			continue
		var helper := _Helper.new()
		helper.grade = grade
		_load_action(skill_id, helper, entry as Dictionary)
		_helpers[skill_id] = helper


func _load_action(skill_id: StringName, helper: _Helper, entry: Dictionary) -> void:
	var action_id: StringName = StringName(str(entry.get(SAVE_ACTION_KEY, "")))
	if action_id == &"":
		return
	var action: ActionDef = _find_action(skill_id, action_id)
	if action == null or action.single or _session.skills.get_level(skill_id) < action.level:
		Log.warn(LOG_CATEGORY, "helper of '%s': action '%s' cannot run: no action" % [skill_id, action_id])
		return
	helper.action = action
	var elapsed: Variant = entry.get(SAVE_ELAPSED_KEY)
	if elapsed is float and (elapsed as float) == floorf(elapsed as float):
		elapsed = int(elapsed as float)
	if elapsed is int and (elapsed as int) >= 0:
		helper.elapsed_ms = elapsed
	else:
		Log.warn(LOG_CATEGORY, "helper of '%s': invalid elapsed_ms, cycle restarts at 0" % skill_id)


func _advance_helper(skill_id: StringName, helper: _Helper, delta_ms: int) -> void:
	if helper.interval_ms <= 0:
		helper.interval_ms = _interval_for(skill_id, helper.action, helper.grade)
	var remaining: int = delta_ms
	while remaining > 0:
		var needed: int = maxi(0, helper.interval_ms - helper.elapsed_ms)
		if remaining < needed:
			helper.elapsed_ms += remaining
			return
		remaining -= needed
		helper.elapsed_ms = helper.interval_ms
		if not _complete_cycle(skill_id, helper):
			return
		helper.elapsed_ms = 0
		helper.interval_ms = _interval_for(skill_id, helper.action, helper.grade)


# One cycle at its end. False when the helper waits (Deposit full) or was changed by a listener of the signals.
func _complete_cycle(skill_id: StringName, helper: _Helper) -> bool:
	var action: ActionDef = helper.action
	var outcome: ActionOutcome = GatheringResolver.resolve(_session, action, helper.grade)
	if not outcome.ok:
		if not helper.blocked:
			helper.blocked = true
			_events.helper_blocked.emit(skill_id, true)
			_events.notification_requested.emit(BLOCKED_TEXT, &"warning")
		return false
	if helper.blocked:
		helper.blocked = false
		_events.helper_blocked.emit(skill_id, false)
	_events.helper_completed.emit(skill_id, action.id, outcome.outputs)
	return _helpers.get(skill_id, null) == helper and helper.action == action


# The cycle restarts from 0 with a new interval; a waiting helper is no longer waiting.
func _restart(skill_id: StringName, helper: _Helper) -> void:
	helper.elapsed_ms = 0
	helper.interval_ms = 0
	if helper.blocked:
		helper.blocked = false
		_events.helper_blocked.emit(skill_id, false)


# F-101: F-03 with the helper context total, then × the grade multiplier, rounded. 0 without action or helper.
func _interval_for(skill_id: StringName, action: ActionDef, grade: StringName) -> int:
	if action == null or grade == &"":
		return 0
	var pct: float = _modifiers.total(INTERVAL_STAT, ModifierContext.for_helper(skill_id, action.id))
	var base_ms: int = ActionMath.interval_ms(action.interval_ms, pct, _min_interval_ms)
	return roundi(float(base_ms) * _data.helper_grade(grade).interval_mult)


# The interval fixed for the current cycle, or the one a cycle would get now if not fixed yet; 0 without action.
func _cycle_interval(skill_id: StringName) -> int:
	if not _helpers.has(skill_id) or _helpers[skill_id].action == null:
		return 0
	var helper: _Helper = _helpers[skill_id]
	return helper.interval_ms if helper.interval_ms > 0 else _interval_for(skill_id, helper.action, helper.grade)


func _find_action(skill_id: StringName, action_id: StringName) -> ActionDef:
	if not is_helper_skill(skill_id):
		return null
	for action: ActionDef in _data.actions_for_skill(skill_id):
		if action.id == action_id:
			return action
	return null
