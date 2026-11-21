class_name StarterQuests
extends RefCounted
## The starter quests «Primi passi» (docs/01_GDD_M30.md §41.5, docs/05_INTERFACES_M30.md §5.42). Part of TutorialSystem (one session
## module, one save key): it saves its own block under `tutorial.starter`. Active from the end of the tutorial (or from a load with the
## tutorial completed); counted events and measures are listened to only while a quest still needs them.

const LOG_CATEGORY: String = "tutorial"

var _session: GameSession
var _data: GameData
var _events: GameEvents
var _tutorial_ref: WeakRef  # weak: the tutorial owns this object, a strong link would be a cycle that outlives the session
var _active: bool = false
var _claimed: Dictionary[StringName, bool] = {}
var _final_claimed: bool = false  # M31: the final bonus (saved as `final_claimed`)
var _counts: Dictionary[StringName, int] = {}  # counted events, by quest
var _notified: Dictionary[StringName, bool] = {}  # starter_quest_completed already given (volatile)
var _connected: Dictionary[StringName, bool] = {}  # signals listened to


func _init(session: GameSession, tutorial: TutorialSystem) -> void:
	assert(session != null and tutorial != null, "StarterQuests needs a session and a tutorial")
	_session = session
	_data = session.data
	_events = session.events
	_tutorial_ref = weakref(tutorial)


func is_enabled() -> bool:
	return (_tutorial_ref.get_ref() as TutorialSystem).is_completed()


func quests() -> Array[StarterQuestDef]:
	return _data.starter_quests()


func target(quest_id: StringName) -> int:
	var def: StarterQuestDef = _data.starter_quest(quest_id)
	if def == null:
		return 0
	return def.goal.gte if def.goal.type == TutorialCondition.TYPE_METRIC else def.goal.count


## 0..target: a measure is read from the model (`min(value, gte)`), an event is the saved counter; 0 if inactive or unknown.
func progress(quest_id: StringName) -> int:
	var def: StarterQuestDef = _data.starter_quest(quest_id)
	if def == null or not _active:
		return 0
	if _claimed.has(quest_id):
		return target(quest_id)
	if def.goal.type == TutorialCondition.TYPE_METRIC:
		return mini(TutorialMetrics.value(_session, def.goal.metric, def.goal.arg), def.goal.gte)
	return mini(_counts.get(quest_id, 0), def.goal.count)


func is_complete(quest_id: StringName) -> bool:
	return _data.starter_quest(quest_id) != null and (_claimed.has(quest_id) or (_active and progress(quest_id) >= target(quest_id)))


func is_claimed(quest_id: StringName) -> bool:
	return _claimed.has(quest_id)


func claimable() -> Array[StarterQuestDef]:
	var result: Array[StarterQuestDef] = []
	for def: StarterQuestDef in quests():
		if not _claimed.has(def.id) and is_complete(def.id):
			result.append(def)
	return result


## The first quest not claimed, in file order; null when all are claimed.
func next_open() -> StarterQuestDef:
	for def: StarterQuestDef in quests():
		if not _claimed.has(def.id):
			return def
	return null


func claimed_count() -> int:
	return _claimed.size()


func total() -> int:
	return quests().size()


## In order: unknown_id, tutorial_inactive, already_claimed, quest_incomplete, mailbox_full (only when a message must be posted).
func can_claim(quest_id: StringName) -> CommandResult:
	var def: StarterQuestDef = _data.starter_quest(quest_id)
	if def == null:
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	if not _active:
		return CommandResult.fail(Reasons.TUTORIAL_INACTIVE)
	if _claimed.has(quest_id):
		return CommandResult.fail(Reasons.ALREADY_CLAIMED)
	if not is_complete(quest_id):
		return CommandResult.fail(Reasons.QUEST_INCOMPLETE)
	if (def.reward_money > 0 or not def.reward_items.is_empty()) and _session.mail.is_full():
		return CommandResult.fail(Reasons.MAILBOX_FULL)
	return CommandResult.success()


## can_claim, then the character xp, one `starter_reward` Mail message (money OR items), `claimed`, `starter_quests_changed`.
func claim(quest_id: StringName) -> CommandResult:
	var can: CommandResult = can_claim(quest_id)
	if not can.ok:
		return can
	var def: StarterQuestDef = _data.starter_quest(quest_id)
	if def.reward_character_xp > 0:
		_session.character.add_xp(def.reward_character_xp)
	if def.reward_money > 0:
		_session.mail.post(&"starter_reward", {"money": def.reward_money})
	elif not def.reward_items.is_empty():
		var rows: Array[Dictionary] = []
		for q: ItemQty in def.reward_items:
			rows.append({"item": q.item_id, "qty": q.qty})
		_session.mail.post(&"starter_reward", {"items": rows})
	_claimed[quest_id] = true
	_counts.erase(quest_id)
	_events.starter_quests_changed.emit()
	return CommandResult.success()


## M31 (docs/M31_RITOCCHI_TUTORIAL.md §5): the final bonus of the data (`final_reward` of starter_quests.json).
func final_reward() -> StarterFinalDef:
	return _data.starter_final()


## Active, every quest claimed, the bonus not claimed yet.
func is_final_available() -> bool:
	return _active and claimed_count() == total() and not _final_claimed


func is_final_claimed() -> bool:
	return _final_claimed


## Every quest claimed and the bonus too: the box of the UI goes away here.
func all_done() -> bool:
	return claimed_count() == total() and _final_claimed


## In order: tutorial_inactive, already_claimed, quest_incomplete (not every quest claimed), mailbox_full (when a message must be posted).
func can_claim_final() -> CommandResult:
	if not _active:
		return CommandResult.fail(Reasons.TUTORIAL_INACTIVE)
	if _final_claimed:
		return CommandResult.fail(Reasons.ALREADY_CLAIMED)
	if claimed_count() != total():
		return CommandResult.fail(Reasons.QUEST_INCOMPLETE)
	var def: StarterFinalDef = final_reward()
	if (def.reward_money > 0 or not def.reward_items.is_empty()) and _session.mail.is_full():
		return CommandResult.fail(Reasons.MAILBOX_FULL)
	return CommandResult.success()


## can_claim_final, then the character xp, one `starter_reward` Mail message (money OR items), `final_claimed`, `starter_quests_changed`.
func claim_final() -> CommandResult:
	var can: CommandResult = can_claim_final()
	if not can.ok:
		return can
	var def: StarterFinalDef = final_reward()
	if def.reward_character_xp > 0:
		_session.character.add_xp(def.reward_character_xp)
	if def.reward_money > 0:
		_session.mail.post(&"starter_reward", {"money": def.reward_money})
	elif not def.reward_items.is_empty():
		var rows: Array[Dictionary] = []
		for q: ItemQty in def.reward_items:
			rows.append({"item": q.item_id, "qty": q.qty})
		_session.mail.post(&"starter_reward", {"items": rows})
	_final_claimed = true
	_events.starter_quests_changed.emit()
	return CommandResult.success()


## Rereads the `page_visited` measures (the UI notifies a page through TutorialSystem; no EventBus signal exists for it).
func on_page_visited() -> void:
	_check_metrics(&"")


func new_game() -> void:
	_reset()


func to_save() -> Dictionary:
	var claimed: Array = []
	var counts: Dictionary = {}
	for def: StarterQuestDef in quests():
		if _claimed.has(def.id):
			claimed.append(String(def.id))
		elif def.goal.type == TutorialCondition.TYPE_EVENT and _counts.get(def.id, 0) > 0:
			counts[String(def.id)] = _counts[def.id]
	return {"claimed": claimed, "progress": counts, "final_claimed": _final_claimed}


## Tolerant (Log.warn): bad lists are cleaned, unknown ids, non-event quests, non-integers and claimed quests are dropped, values are capped to `count`.
func from_save(d: Dictionary) -> void:
	_reset()
	var claimed: Variant = d.get("claimed", [])
	if claimed is Array:
		for entry: Variant in (claimed as Array):
			if _data.starter_quest(StringName(str(entry))) != null:
				_claimed[StringName(str(entry))] = true
			else:
				Log.warn(LOG_CATEGORY, "unknown claimed starter quest '%s' dropped" % str(entry))
	else:
		Log.warn(LOG_CATEGORY, "starter 'claimed' is not a list: none claimed")
	var counts: Variant = d.get("progress", {})
	if counts is Dictionary:
		for key: Variant in (counts as Dictionary):
			_read_count(StringName(str(key)), (counts as Dictionary)[key])
	else:
		Log.warn(LOG_CATEGORY, "starter 'progress' is not an object: no progress")
	if d.has("final_claimed"):
		if d["final_claimed"] is bool:
			_final_claimed = d["final_claimed"] as bool
		else:
			Log.warn(LOG_CATEGORY, "starter 'final_claimed' is not a boolean: not claimed")
	if (_tutorial_ref.get_ref() as TutorialSystem).is_completed():
		activate(true)


## Starts the quests: the counters begin now (they are kept after a load), the quests already true are not announced.
func activate(silent: bool) -> void:
	_active = true
	for def: StarterQuestDef in quests():
		if not _claimed.has(def.id) and progress(def.id) >= target(def.id):
			_notified[def.id] = true
	_listen()
	if not silent:
		_events.starter_quests_changed.emit()


func _reset() -> void:
	for signal_name: StringName in _connected:
		_unlisten(signal_name)
	_connected.clear()
	_active = false
	_claimed.clear()
	_final_claimed = false
	_counts.clear()
	_notified.clear()


func _read_count(quest_id: StringName, raw: Variant) -> void:
	var def: StarterQuestDef = _data.starter_quest(quest_id)
	var value: int = -1
	if raw is int or (raw is float and float(raw) == floorf(float(raw))):
		value = int(raw)
	if def == null or def.goal.type != TutorialCondition.TYPE_EVENT or value < 1 or _claimed.has(quest_id):
		Log.warn(LOG_CATEGORY, "starter progress of '%s' dropped" % quest_id)
		return
	_counts[quest_id] = mini(value, def.goal.count)


# Connects the signals that a quest still needs (counted events; the signals of the measures not yet announced).
func _listen() -> void:
	for def: StarterQuestDef in quests():
		if _claimed.has(def.id) or _notified.has(def.id):
			continue
		var names: Array = [def.goal.signal_name] if def.goal.type == TutorialCondition.TYPE_EVENT \
				else (TutorialMetrics.METRICS.get(def.goal.metric, []) as Array)
		for signal_name: Variant in names:
			if not _connected.has(signal_name):
				_connected[signal_name] = true
				Signal(_events, signal_name).connect(Callable(self, &"_on_signal").bind(signal_name))


func _unlisten(signal_name: StringName) -> void:
	var callable: Callable = Callable(self, &"_on_signal").bind(signal_name)
	if Signal(_events, signal_name).is_connected(callable):
		Signal(_events, signal_name).disconnect(callable)


# The generic listener: the emitted arguments, then the signal name (bound last).
func _on_signal(...args: Array) -> void:
	var signal_name: StringName = args.pop_back()
	var rose: bool = false
	var names: PackedStringArray = TutorialConditions.signal_arg_names(_events, signal_name)
	for def: StarterQuestDef in quests():
		var goal: TutorialCondition = def.goal
		if goal.type != TutorialCondition.TYPE_EVENT or goal.signal_name != signal_name or _claimed.has(def.id):
			continue
		if _counts.get(def.id, 0) >= goal.count or not TutorialConditions.matches(goal.args, names, args):
			continue
		_counts[def.id] = _counts.get(def.id, 0) + 1
		rose = true
		_announce(def.id, _counts[def.id] >= goal.count)
	if rose:
		_events.starter_quests_changed.emit()
	_check_metrics(signal_name)
	_prune(signal_name)


# Rereads the measures that the signal makes worth reading (every measure when `signal_name` is empty).
func _check_metrics(signal_name: StringName) -> void:
	if not _active:
		return
	for def: StarterQuestDef in quests():
		var goal: TutorialCondition = def.goal
		if goal.type != TutorialCondition.TYPE_METRIC or _notified.has(def.id) or _claimed.has(def.id):
			continue
		var triggers: Array = TutorialMetrics.METRICS.get(goal.metric, []) as Array
		if (not triggers.is_empty()) if signal_name == &"" else not triggers.has(signal_name):
			continue
		_announce(def.id, TutorialMetrics.value(_session, goal.metric, goal.arg) >= goal.gte)


func _announce(quest_id: StringName, reached: bool) -> void:
	if reached and not _notified.has(quest_id):
		_notified[quest_id] = true
		_events.starter_quest_completed.emit(quest_id)


# Stops listening to a signal that no quest needs any more (no rereading of the measures after the announcement).
func _prune(signal_name: StringName) -> void:
	for def: StarterQuestDef in quests():
		if _claimed.has(def.id) or _notified.has(def.id):
			continue
		var names: Array = [def.goal.signal_name] if def.goal.type == TutorialCondition.TYPE_EVENT \
				else (TutorialMetrics.METRICS.get(def.goal.metric, []) as Array)
		if names.has(signal_name):
			return
	if _connected.has(signal_name):
		_unlisten(signal_name)
		_connected.erase(signal_name)
