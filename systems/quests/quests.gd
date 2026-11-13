class_name Quests
extends RefCounted
## The Noticeboard quests (docs/01_GDD.md §31, docs/05_INTERFACES.md §5.28, docs/02_FORMULAS.md F-134/F-135).
##
## The Bacheca level gives the stat `quest_slots` = the number of active quests (slots). There is no timer and no `advance`:
## a free slot receives the next quest (QuestPicker) only when the Bacheca grows, a quest is claimed or abandoned, or the
## character or a skill levels up. Progress counts only while the quest is active, with the same signals online and offline
## (`monster_killed`, `action_completed`, `helper_completed`) and never exceeds the target. `new_game` and `from_save` set the
## state without signals.

const SAVE_KEY: StringName = &"quests"
const LOG_CATEGORY: String = "quests"
const SLOTS_STAT: StringName = &"quest_slots"
const PARAMS_KEY: String = "quest"

var _data: GameData
var _events: GameEvents
var _modifiers: ModifierService
var _bank: Bank
var _wallet: Wallet
var _skills: SkillsSystem
var _character: CharacterSystem
var _params: Dictionary = {}
var _max_slots: int = 0
# Slot -> quest id (&"" = empty) and progress; always `_max_slots` entries (the visible ones are the first `slot_count()`).
var _ids: Array[StringName] = []
var _progress: Array[int] = []
var _cursor: int = 0
var _recent: Array[StringName] = []
var _completed: int = 0
var _paying: bool = false  # true while claim pays: the final refill runs once, after the memory is updated


func _init(session: GameSession) -> void:
	assert(session != null, "Quests needs a session")
	_data = session.data
	_events = session.events
	_modifiers = session.modifiers
	_bank = session.bank
	_wallet = session.wallet
	_skills = session.skills
	_character = session.character
	_params = _data.balance_value(PARAMS_KEY) as Dictionary
	_max_slots = int(_data.stats.info(SLOTS_STAT)["max"])
	_clear()
	_events.monster_killed.connect(_on_monster_killed)
	_events.action_completed.connect(_on_action_completed)
	_events.helper_completed.connect(_on_helper_completed)
	_events.modifiers_changed.connect(refill)
	_events.character_level_up.connect(_on_character_level_up)
	_events.level_up.connect(_on_level_up)


## F-135: floor(T(quest_slots)); 0 without the Bacheca.
func slot_count() -> int:
	return clampi(floori(_modifiers.total(SLOTS_STAT)), 0, _max_slots)


## The quest id of a slot; &"" if empty or out of range.
func quest_at(slot: int) -> StringName:
	return _ids[slot] if _in_range(slot) else &""


## 0..target; 0 if empty.
func progress_at(slot: int) -> int:
	return _progress[slot] if _in_range(slot) and _ids[slot] != &"" else 0


## The target of the quest of a slot; 0 if empty.
func target_at(slot: int) -> int:
	var def: QuestDef = _def_at(slot)
	return def.target if def != null else 0


func is_complete(slot: int) -> bool:
	var def: QuestDef = _def_at(slot)
	return def != null and _progress[slot] >= def.target


## Quests claimed in the whole game (statistic only).
func completed_total() -> int:
	return _completed


## Checks in order: unknown_id (out of range), slot_empty, quest_incomplete, bank_full (a food reward with no room).
func can_claim(slot: int) -> CommandResult:
	if not _in_range(slot):
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	var def: QuestDef = _def_at(slot)
	if def == null:
		return CommandResult.fail(Reasons.SLOT_EMPTY)
	if _progress[slot] < def.target:
		return CommandResult.fail(Reasons.QUEST_INCOMPLETE)
	for row: ItemQty in def.reward_items:
		if not _bank.can_add(row.item_id):
			return CommandResult.fail(Reasons.BANK_FULL)
	return CommandResult.success()


## Pays gold, skill XP (F-02 base) and food, frees the slot, remembers the quest and assigns the next one.
func claim(slot: int) -> CommandResult:
	var check: CommandResult = can_claim(slot)
	if not check.ok:
		return check
	var def: QuestDef = _def_at(slot)
	_release(slot, def.id)
	_completed += 1
	_paying = true
	if def.reward_gold > 0:
		_wallet.add_gold(def.reward_gold)
	if def.reward_xp_skill != &"" and def.reward_xp > 0:
		_skills.add_xp(def.reward_xp_skill, def.reward_xp)
	for row: ItemQty in def.reward_items:
		var added: CommandResult = _bank.add(row.item_id, row.qty)
		if not added.ok:
			Log.error(LOG_CATEGORY, "reward '%s' of '%s' lost after can_claim (%s)" % [row.item_id, def.id, added.reason])
	_paying = false
	if refill_slots() == 0:
		_events.quests_changed.emit()
	return CommandResult.success()


## Discards the quest and its progress (no reward) and assigns the next one.
func abandon(slot: int) -> CommandResult:
	if not _in_range(slot):
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	var def: QuestDef = _def_at(slot)
	if def == null:
		return CommandResult.fail(Reasons.SLOT_EMPTY)
	_release(slot, def.id)
	if refill_slots() == 0:
		_events.quests_changed.emit()
	return CommandResult.success()


## Assigns a quest to every free slot (F-135); idempotent, silent when nothing changes.
func refill() -> void:
	refill_slots()


## Same as `refill`; returns how many slots were assigned (`quests_changed` is emitted once when any).
func refill_slots() -> int:
	if _paying:
		return 0
	var assigned: int = 0
	for slot: int in slot_count():
		if _ids[slot] != &"":
			continue
		var choice: Dictionary = QuestPicker.pick(_data.quests(), _cursor, _recent, _active_ids(), _character.get_level(),
				_skill_levels(), _params)
		if (choice["id"] as StringName) == &"":
			break
		_ids[slot] = choice["id"] as StringName
		_progress[slot] = 0
		_cursor = int(choice["cursor"])
		assigned += 1
	if assigned > 0:
		_events.quests_changed.emit()
	return assigned


func new_game() -> void:
	_clear()


## `{"slots": [{"id", "progress"} or {}], "cursor": int, "recent": [id], "completed": int}`; the empty slots after the last
## assigned one are not saved.
func to_save() -> Dictionary:
	var last: int = -1
	for slot: int in _max_slots:
		if _ids[slot] != &"":
			last = slot
	var slots: Array = []
	for slot: int in last + 1:
		slots.append({"id": String(_ids[slot]), "progress": _progress[slot]} if _ids[slot] != &"" else {})
	var recent: Array = []
	for id: StringName in _recent:
		recent.append(String(id))
	return {"slots": slots, "cursor": _cursor, "recent": recent, "completed": _completed}


## Tolerant (Log.warn): see docs/05_INTERFACES.md §5.28. Silent: no signal and no assignment (the session refills afterwards).
func from_save(d: Dictionary) -> void:
	_clear()
	_load_slots(d.get("slots"))
	var count: int = _data.quests().size()
	var cursor: Variant = d.get("cursor")
	if _is_whole(cursor) and count > 0:
		_cursor = posmod(int(cursor), count)
	elif cursor != null:
		Log.warn(LOG_CATEGORY, "'cursor' is not an integer: 0")
	var recent: Variant = d.get("recent")
	if recent is Array:
		for raw: Variant in recent as Array:
			var id: StringName = StringName(str(raw))
			if raw is String and _is_known(id):
				_recent.append(id)
			else:
				Log.warn(LOG_CATEGORY, "recent quest %s is unknown: dropped" % str(raw))
		while _recent.size() > _memory():
			_recent.pop_front()
	var completed: Variant = d.get("completed")
	if _is_whole(completed) and int(completed) >= 0:
		_completed = int(completed)
	elif completed != null:
		Log.warn(LOG_CATEGORY, "'completed' is not a non-negative integer: 0")


func _load_slots(raw: Variant) -> void:
	if not raw is Array:
		if raw != null:
			Log.warn(LOG_CATEGORY, "'slots' is not an array: no quest")
		return
	var rows: Array = raw as Array
	if rows.size() > _max_slots:
		Log.warn(LOG_CATEGORY, "%d slots saved, only %d kept" % [rows.size(), _max_slots])
	for slot: int in mini(rows.size(), _max_slots):
		var row: Variant = rows[slot]
		var id: StringName = StringName(str((row as Dictionary).get("id"))) if row is Dictionary else &""
		if not row is Dictionary or not _is_known(id):
			if not (row is Dictionary and (row as Dictionary).is_empty()):
				Log.warn(LOG_CATEGORY, "slot %d is not a known quest: empty" % slot)
			continue
		var progress: Variant = (row as Dictionary).get("progress")
		if not _is_whole(progress) or int(progress) < 0:
			Log.warn(LOG_CATEGORY, "slot %d: progress %s is not a non-negative integer: 0" % [slot, str(progress)])
			progress = 0
		_ids[slot] = id
		_progress[slot] = mini(int(progress), _data.quest(id).target)


func _clear() -> void:
	_ids.clear()
	_progress.clear()
	for slot: int in _max_slots:
		_ids.append(&"")
		_progress.append(0)
	_cursor = 0
	_recent.clear()
	_completed = 0


# Frees the slot and remembers the quest id (the last `quest.recent_memory`).
func _release(slot: int, id: StringName) -> void:
	_ids[slot] = &""
	_progress[slot] = 0
	_recent.append(id)
	while _recent.size() > _memory():
		_recent.pop_front()


func _advance(slot: int, amount: int, def: QuestDef) -> void:
	var before: int = _progress[slot]
	var after: int = mini(before + amount, def.target)
	if after == before:
		return
	_progress[slot] = after
	_events.quest_progress.emit(slot, after, def.target)
	if after >= def.target:
		_events.quest_completed.emit(def.id, slot)


func _on_monster_killed(_index: int, _monster_id: StringName) -> void:
	for slot: int in slot_count():
		var def: QuestDef = _def_at(slot)
		if def != null and def.type == &"kill":
			_advance(slot, 1, def)


func _on_action_completed(_lane: StringName, _skill: StringName, _action: StringName, outputs: Dictionary) -> void:
	_count_outputs(outputs, [&"gather", &"craft"])


func _on_helper_completed(_skill: StringName, _action: StringName, outputs: Dictionary) -> void:
	_count_outputs(outputs, [&"gather"])


func _count_outputs(outputs: Dictionary, types: Array[StringName]) -> void:
	for slot: int in slot_count():
		var def: QuestDef = _def_at(slot)
		if def == null or not types.has(def.type):
			continue
		var qty: int = int(outputs.get(def.item, outputs.get(String(def.item), 0)))
		if qty > 0:
			_advance(slot, qty, def)


func _on_character_level_up(_level: int) -> void:
	refill()


func _on_level_up(_skill: StringName, _level: int) -> void:
	refill()


func _in_range(slot: int) -> bool:
	return slot >= 0 and slot < slot_count()


func _def_at(slot: int) -> QuestDef:
	if not _in_range(slot) or _ids[slot] == &"":
		return null
	return _data.quest(_ids[slot])


func _active_ids() -> Array[StringName]:
	var active: Array[StringName] = []
	for id: StringName in _ids:
		if id != &"":
			active.append(id)
	return active


# The levels of the six skills quests ask for (F-135 requirement of a gather or craft quest).
func _skill_levels() -> Dictionary:
	var levels: Dictionary = {}
	for skill: String in DataValidatorQuests.SKILLS_OF["gather"] + DataValidatorQuests.SKILLS_OF["craft"]:
		levels[StringName(skill)] = _skills.get_level(StringName(skill))
	return levels


func _memory() -> int:
	return int(_params["recent_memory"])


func _is_known(id: StringName) -> bool:
	for def: QuestDef in _data.quests():
		if def.id == id:
			return true
	return false


static func _is_whole(value: Variant) -> bool:
	return value is int or (value is float and (value as float) == floorf(value as float))
