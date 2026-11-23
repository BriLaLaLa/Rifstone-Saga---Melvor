class_name NodeWork
extends RefCounted
## A gathering node in progress (docs/01_GDD_M25.md §36; F-154, F-155, F-161..F-164), held by the combat engine. `begin` fixes the
## resource, the duration, the number of attempts and whether the node is rich; `resolve_attempt` takes one attempt (units of F-162,
## the color of that moment, xp and mastery of F-163). A node of a discipline that is not learned, or of a level below its
## `min_level`, is `skipped`: it lasts `encounters.skip_ms` and gives nothing (`skip_reason`).

var skill_id: StringName = &""
var action_id: StringName = &""
var duration_ms: int = 0
var elapsed_ms: int = 0
var skipped: bool = false
var skip_reason: StringName = &""  # not_learned | too_hard | &""
var attempts: int = 0  # 0 for a skipped node
var attempt: int = 0  # attempts resolved
var rich: bool = false
var units: int = 0  # units put in the Deposit so far
var difficulty: int = 0  # F-161, not saved: the data gives it again
var closed: bool = false  # a unit found no room (`bank_full`): no more attempts
var last_attempt: Dictionary = {}  # {} or {"units": int, "color": StringName, "xp": int}, not saved
var ne: int = 0  # M35 (F-198): the units planned (`Ne`), fixed at the start of the node; 0 for a skipped node
var focused: bool = false  # M35 (F-195): the resource is the one chosen by the player; not saved (a loaded node shows false)
var focus_blocked: bool = false  # M35: a choice exists but the node does not allow it (Automatico); not saved


## The node of `skill_id` in the area: resource of F-154 (for a skipped node, the one that would have been worked), duration of F-155
## (or `skip_ms`), attempts and richness (F-161, F-164: one `roll_pct` for a worked node). Null if the area has no nodes or the
## skill has no resource (data error, logged).
static func begin(session: GameSession, area_id: StringName, skill_id: StringName) -> NodeWork:
	var nodes: AreaNodesDef = session.data.area_nodes(area_id)
	if nodes == null:
		return null
	var level: int = maxi(1, session.skills.get_level(skill_id))
	var focus: StringName = session.disciplines.focus_of(skill_id)
	var action: ActionDef = EncounterCycle.worked_action(session.data, skill_id, level, nodes.max_level, focus)
	if action == null:
		Log.warn("encounters", "no resource for the node of '%s' in area '%s'" % [skill_id, area_id])
		return null
	var work := NodeWork.new()
	work.skill_id = skill_id
	work.action_id = action.id
	work.focused = focus != &"" and action.id == focus
	work.focus_blocked = focus != &"" and action.id != focus
	work.difficulty = nodes.difficulty_of(skill_id)
	if not session.disciplines.is_learned(skill_id):
		work.skip_reason = Reasons.NOT_LEARNED
	elif level < nodes.min_level_of(skill_id):
		work.skip_reason = Reasons.TOO_HARD
	work.skipped = work.skip_reason != &""
	if work.skipped:
		work.duration_ms = int(session.data.balance_value("encounters.skip_ms"))
		return work
	work.rich = session.rng.roll_pct(EncounterCycle.rich_chance(session, skill_id, action))  # F-199: one roll
	work.ne = EncounterCycle.planned_units(session.data, work.rich, EncounterCycle.units_bonus_pct(session, skill_id, action))  # F-198
	work.attempts = EncounterCycle.attempts_for(session, work.rich)
	work.duration_ms = EncounterCycle.node_duration_ms(session, skill_id, action)
	if work.rich:
		work.duration_ms = EncounterCycle.rich_duration_ms(session, work.duration_ms)
	return work


## The color of the node if the next attempt happened now (F-154); `&""` and 0% for a skipped node.
func color(session: GameSession) -> Dictionary:
	if skipped:
		return {"id": &"", "xp_pct": 0.0}
	var action: ActionDef = session.data.action(action_id)
	return EncounterCycle.color(session.data, session.skills.get_level(skill_id), action.level)


## F-162: the yield in percent of an attempt taken now (0 for a skipped node).
func yield_pct(session: GameSession) -> int:
	if skipped:
		return 0
	return EncounterCycle.yield_pct(session, maxi(1, session.skills.get_level(skill_id)), difficulty)


## The units the node plans in all at the yield of now, `floor(Ne x y / 100)` (0 for a skipped node).
func units_planned(session: GameSession) -> int:
	return 0 if skipped else ne * yield_pct(session) / 100


## True when the node has nothing left to do: all the attempts are resolved or a unit found no room.
func is_complete() -> bool:
	return closed or attempt >= attempts


## True when the node ends now: a skipped node at its time, a worked one when `is_complete`.
func is_over() -> bool:
	return elapsed_ms >= duration_ms if skipped else is_complete()


## The reason of `node_finished`: the reason of the skip, `bank_full` if a unit found no room, else `node_done`.
func end_reason() -> StringName:
	if skipped:
		return skip_reason
	return Reasons.BANK_FULL if closed else Reasons.NODE_DONE


## F-161: the attempts whose instant `t_k` is reached and that are not resolved yet.
func due_attempts() -> int:
	if skipped or closed:
		return 0
	var count: int = 0
	for k: int in range(attempt + 1, attempts + 1):
		if EncounterCycle.attempt_time_ms(duration_ms, attempts, k) > elapsed_ms:
			break
		count += 1
	return count


## The ms until the next event of the node: the next attempt, or the end of a skipped node (0 when it is over).
func next_event_ms() -> int:
	if skipped:
		return maxi(0, duration_ms - elapsed_ms)
	if is_complete():
		return 0
	return maxi(0, EncounterCycle.attempt_time_ms(duration_ms, attempts, attempt + 1) - elapsed_ms)


## F-162, F-163: the next attempt, with the units of `y` of now and the color of now. `outcome.ok` false (no unit found room, nothing
## changes, the node closes) or true; a unit that finds no room closes the node after the units already put. A skipped or
## complete node: an empty outcome.
func resolve_attempt(session: GameSession) -> ActionOutcome:
	if skipped or is_complete():
		return ActionOutcome.new()
	var planned: int = EncounterCycle.attempt_units(session, attempt + 1, attempts, rich, yield_pct(session), ne)
	var picked: Dictionary = color(session)
	var outcome: ActionOutcome = GatheringResolver.resolve_units(session, session.data.action(action_id), planned, float(picked["xp_pct"]))
	if outcome.reason == Reasons.BANK_FULL:
		closed = true
	if outcome.ok:
		attempt += 1
		units += outcome.units
		last_attempt = {"units": outcome.units, "color": picked["id"], "xp": outcome.xp}
	return outcome


func to_save() -> Dictionary:
	var d: Dictionary = {"skill": String(skill_id), "action": String(action_id), "elapsed_ms": elapsed_ms, "duration_ms": duration_ms,
		"skipped": skipped}
	if skipped:
		d["skip_reason"] = String(skip_reason)  # additive: which of the two reasons the node ends with
	else:
		d.merge({"attempts": attempts, "attempt": attempt, "rich": rich, "units": units, "ne": ne})
	return d


## Tolerant: null if the dictionary is malformed or names an unknown skill or action, or has incoherent attempts. A node saved by
## M24 (a worked node without the fields of M25) restarts at 0 attempts, not rich, with the saved duration (F-155 is unchanged).
## `area_id` gives the difficulty (F-161).
static func from_save(raw: Dictionary, data: GameData, area_id: StringName) -> NodeWork:
	var action_key := StringName(str(raw.get("action", "")))
	if not data.has_action(action_key):
		return null
	var action: ActionDef = data.action(action_key)
	if String(action.skill_id) != str(raw.get("skill", "")):
		return null
	for key: String in ["elapsed_ms", "duration_ms"]:
		if not (raw.get(key) is int or raw.get(key) is float):
			return null
	if not (raw.get("skipped") is bool):
		return null
	var work := NodeWork.new()
	work.skill_id = action.skill_id
	work.action_id = action.id
	work.skipped = raw["skipped"]
	work.duration_ms = maxi(1, int(raw["duration_ms"]))
	work.elapsed_ms = clampi(int(raw["elapsed_ms"]), 0, work.duration_ms)
	var nodes: AreaNodesDef = data.area_nodes(area_id)
	work.difficulty = nodes.difficulty_of(work.skill_id) if nodes != null else 0
	if work.skipped:
		work.skip_reason = Reasons.TOO_HARD if str(raw.get("skip_reason", "")) == String(Reasons.TOO_HARD) else Reasons.NOT_LEARNED
		return work
	if _has_attempts(raw):
		if not _read_attempts(work, raw, data):
			return null
	else:
		work.attempts = int(data.balance_value("encounters.attempts"))
		work.ne = EncounterCycle.planned_units(data, false)
		work.elapsed_ms = 0
	return work


static func _has_attempts(raw: Dictionary) -> bool:
	return raw.has("attempts") and raw.has("attempt") and raw.has("rich") and raw.has("units")


static func _read_attempts(work: NodeWork, raw: Dictionary, data: GameData) -> bool:
	for key: String in ["attempts", "attempt", "units"]:
		if not (raw[key] is int or raw[key] is float):
			return false
	if not (raw["rich"] is bool):
		return false
	work.attempts = int(raw["attempts"])
	work.attempt = int(raw["attempt"])
	work.units = int(raw["units"])
	work.rich = raw["rich"]
	work.ne = maxi(0, int(raw["ne"])) if raw.get("ne") is int or raw.get("ne") is float else EncounterCycle.planned_units(data, work.rich)
	return work.attempts >= 1 and work.attempt >= 0 and work.attempt <= work.attempts and work.units >= 0
