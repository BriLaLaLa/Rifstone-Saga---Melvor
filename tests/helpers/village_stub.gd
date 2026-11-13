class_name VillageStub
extends RefCounted
## Stand-in for `Village` (docs/05_INTERFACES.md §5.27) with the same signatures, for the UI smoke test: five
## buildable buildings and two placeholders, two levels, fake data. Gold and items are paid from the session.
## `forced_reason` makes `can_upgrade` fail with that reason (to test the disabled button and its text).
## It also answers `village_building(id)` like `GameData`.

const MAX_LEVEL: int = 2
const BUILDABLE: Array[StringName] = [&"storehouse", &"inn", &"forge", &"sawmill", &"loot_shed"]
const PLACEHOLDERS: Array[StringName] = [&"market", &"noticeboard"]
const PER_LEVEL: float = 4.0
const GOLD_PER_LEVEL: int = 100

var forced_reason: StringName = &""
var upgrade_calls: int = 0
var cost_item: StringName = &"test_log"
var _session: GameSession
var _levels: Dictionary[StringName, int] = {}


class StubDef:
	extends RefCounted
	var id: StringName = &""
	var name: String = ""
	var description: String = ""
	var icon: String = ""
	var buildable: bool = true
	var effect_stat: StringName = &"food_healing_pct"


func _init(session: GameSession) -> void:
	_session = session


func village_building(building_id: StringName) -> StubDef:
	if not BUILDABLE.has(building_id) and not PLACEHOLDERS.has(building_id):
		return null
	var def: StubDef = StubDef.new()
	def.id = building_id
	def.name = "Edificio %s" % building_id
	def.description = "Descrizione di prova."
	def.buildable = BUILDABLE.has(building_id)
	return def


func buildings() -> Array[StringName]:
	var ids: Array[StringName] = BUILDABLE.duplicate()
	ids.append_array(PLACEHOLDERS)
	return ids


func is_buildable(building_id: StringName) -> bool:
	return BUILDABLE.has(building_id)


func level(building_id: StringName) -> int:
	return _levels.get(building_id, 0)


func max_level() -> int:
	return MAX_LEVEL


func effect_at(building_id: StringName, at_level: int) -> float:
	return PER_LEVEL * at_level if is_buildable(building_id) and at_level >= 1 else 0.0


func next_cost(building_id: StringName) -> Dictionary:
	if not is_buildable(building_id) or level(building_id) >= MAX_LEVEL:
		return {}
	var next: int = level(building_id) + 1
	return {"gold": GOLD_PER_LEVEL * next, "items": [{"item": cost_item, "qty": 2 * next}], "requires_woodwright": 0}


func can_upgrade(building_id: StringName) -> CommandResult:
	if not BUILDABLE.has(building_id) and not PLACEHOLDERS.has(building_id):
		return CommandResult.fail(&"unknown_id")
	if not is_buildable(building_id):
		return CommandResult.fail(&"not_buildable")
	if level(building_id) >= MAX_LEVEL:
		return CommandResult.fail(&"max_level")
	if forced_reason != &"":
		return CommandResult.fail(forced_reason)
	var cost: Dictionary = next_cost(building_id)
	if _session.wallet.get_gold() < int(cost["gold"]):
		return CommandResult.fail(&"not_enough_gold")
	for row: Dictionary in cost["items"]:
		if _session.bank.get_count(row["item"]) < int(row["qty"]):
			return CommandResult.fail(&"not_enough_items")
	return CommandResult.success()


func upgrade(building_id: StringName) -> CommandResult:
	var can: CommandResult = can_upgrade(building_id)
	if not can.ok:
		return can
	upgrade_calls += 1
	var cost: Dictionary = next_cost(building_id)
	_session.wallet.spend(int(cost["gold"]))
	for row: Dictionary in cost["items"]:
		_session.bank.remove(row["item"], int(row["qty"]))
	_levels[building_id] = level(building_id) + 1
	return CommandResult.success()
