class_name QuestsStub
extends RefCounted
## Stand-in for `Quests` (docs/05_INTERFACES.md §5.28) with the same signatures, for the UI smoke test: `slots`
## boxes (default 3), the first two occupied by fake quests (the first complete, the second not), the third empty.
## `forced_reason` makes `can_claim` fail with that reason. It also answers `quest(id)`, `skill(id)`, `has_item(id)`
## and `item(id)` like `GameData`.

const QUEST_DONE: StringName = &"stub_quest_done"
const QUEST_OPEN: StringName = &"stub_quest_open"

var slots: int = 3
var forced_reason: StringName = &""
var claim_calls: int = 0
var abandon_calls: int = 0
var _quest_ids: Array[StringName] = [QUEST_DONE, QUEST_OPEN, &""]
var _progress: Array[int] = [10, 4, 0]


class StubQuest:
	extends RefCounted
	var id: StringName = &""
	var name: String = ""
	var description: String = ""
	var target: int = 10
	var reward_gold: int = 120
	var reward_xp_skill: StringName = &"forestry"
	var reward_xp: int = 50
	var reward_items: Array[ItemQty] = []


class StubNamed:
	extends RefCounted
	var name: String = "Nome di prova"
	var icon: String = ""


func quest(quest_id: StringName) -> StubQuest:
	if quest_id != QUEST_DONE and quest_id != QUEST_OPEN:
		return null
	var q: StubQuest = StubQuest.new()
	q.id = quest_id
	q.name = "Incarico di prova"
	q.description = "Descrizione di prova."
	return q


func skill(_skill_id: StringName) -> StubNamed:
	return StubNamed.new()


func has_item(_item_id: StringName) -> bool:
	return false


func item(_item_id: StringName) -> StubNamed:
	return StubNamed.new()


func slot_count() -> int:
	return slots


func quest_at(slot: int) -> StringName:
	return _quest_ids[slot] if slot >= 0 and slot < _quest_ids.size() else &""


func progress_at(slot: int) -> int:
	return _progress[slot] if quest_at(slot) != &"" else 0


func target_at(slot: int) -> int:
	return 10 if quest_at(slot) != &"" else 0


func is_complete(slot: int) -> bool:
	return quest_at(slot) != &"" and progress_at(slot) >= target_at(slot)


func can_claim(slot: int) -> CommandResult:
	if slot < 0 or slot >= slots:
		return CommandResult.fail(&"unknown_id")
	if quest_at(slot) == &"":
		return CommandResult.fail(&"slot_empty")
	if not is_complete(slot):
		return CommandResult.fail(&"quest_incomplete")
	if forced_reason != &"":
		return CommandResult.fail(forced_reason)
	return CommandResult.success()


func claim(slot: int) -> CommandResult:
	var can: CommandResult = can_claim(slot)
	if not can.ok:
		return can
	claim_calls += 1
	_quest_ids[slot] = &""
	_progress[slot] = 0
	return CommandResult.success()


func abandon(slot: int) -> CommandResult:
	if quest_at(slot) == &"":
		return CommandResult.fail(&"slot_empty")
	abandon_calls += 1
	_quest_ids[slot] = &""
	_progress[slot] = 0
	return CommandResult.success()
