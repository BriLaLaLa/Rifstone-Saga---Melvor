class_name Village
extends RefCounted
## The Village (docs/01_GDD.md §30, docs/05_INTERFACES.md §5.27): a few unique buildings with levels 1..max_level, built
## and upgraded with the same instant command `upgrade` (gold and Deposit items, F-131) for a fixed comfort effect
## (F-132) that goes through the ModifierService under the source `village:<id>`.
##
## Costs and effects come from the generated `levels` of data/village/buildings.json, never recomputed at runtime.
## There is no time, no offline case and no demolition. `village_upgraded(building_id, new_level)` is emitted after the
## modifiers are rebuilt. `new_game` and `from_save` set the state without signals.

const SAVE_KEY: StringName = &"village"
const LOG_CATEGORY: String = "village"
const SOURCE_PREFIX: String = "village:"
const LEVELS_KEY: String = "levels"
const WOODWRIGHT: StringName = &"woodwright"

var _data: GameData
var _events: GameEvents
var _modifiers: ModifierService
var _bank: Bank
var _wallet: Wallet
var _skills: SkillsSystem
# Building id -> definition and the ids in order of `order` (built once: the data is immutable).
var _defs: Dictionary[StringName, VillageBuildingDef] = {}
var _ids: Array[StringName] = []
# Building id -> level; only buildings at level >= 1.
var _levels: Dictionary[StringName, int] = {}


func _init(session: GameSession) -> void:
	assert(session != null, "Village needs a session")
	_data = session.data
	_events = session.events
	_modifiers = session.modifiers
	_bank = session.bank
	_wallet = session.wallet
	_skills = session.skills
	for def: VillageBuildingDef in _data.village_buildings():
		_defs[def.id] = def
		_ids.append(def.id)


## Every building id, placeholders included, in order of `order`.
func buildings() -> Array[StringName]:
	return _ids.duplicate()


## False for the placeholders (market, noticeboard) and for unknown ids.
func is_buildable(building_id: StringName) -> bool:
	var def: VillageBuildingDef = _def(building_id)
	return def != null and def.buildable


## 0 = not built (also for unknown ids).
func level(building_id: StringName) -> int:
	return _levels.get(building_id, 0)


func max_level() -> int:
	return int(_data.balance_value("village.max_level"))


## F-132: `per_level x at_level` (0 below level 1 and for buildings that cannot be built).
func effect_at(building_id: StringName, at_level: int) -> float:
	var def: VillageBuildingDef = _def(building_id)
	if def == null or not def.buildable or at_level < 1:
		return 0.0
	return def.effect_per_level * float(at_level)


## Cost of the next level: `{"gold": int, "items": [{"item": StringName, "qty": int}], "requires_woodwright": int}`;
## `{}` at the highest level, for a placeholder or an unknown id.
func next_cost(building_id: StringName) -> Dictionary:
	var def: VillageBuildingDef = _def(building_id)
	if def == null or not def.buildable or level(building_id) >= max_level():
		return {}
	var row: Dictionary = def.levels[level(building_id)]
	return {"gold": row["gold"], "items": (row["items"] as Array).duplicate(true),
			"requires_woodwright": row["requires_woodwright"]}


## Checks in order: unknown_id, not_buildable, max_level, level_too_low, not_enough_gold, not_enough_items.
func can_upgrade(building_id: StringName) -> CommandResult:
	var def: VillageBuildingDef = _def(building_id)
	if def == null:
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	if not def.buildable:
		return CommandResult.fail(Reasons.NOT_BUILDABLE)
	if level(building_id) >= max_level():
		return CommandResult.fail(Reasons.MAX_LEVEL)
	var cost: Dictionary = next_cost(building_id)
	if _skills.get_level(WOODWRIGHT) < int(cost["requires_woodwright"]):
		return CommandResult.fail(Reasons.LEVEL_TOO_LOW)
	if _wallet.get_gold() < int(cost["gold"]):
		return CommandResult.fail(Reasons.NOT_ENOUGH_GOLD)
	for row: Dictionary in cost["items"] as Array:
		if not _bank.has(row["item"] as StringName, int(row["qty"])):
			return CommandResult.fail(Reasons.NOT_ENOUGH_ITEMS)
	return CommandResult.success()


## Builds (level 0 to 1) or upgrades by one level: pays gold and items together (locked items too) or nothing.
func upgrade(building_id: StringName) -> CommandResult:
	var check: CommandResult = can_upgrade(building_id)
	if not check.ok:
		return check
	var cost: Dictionary = next_cost(building_id)
	var paid: CommandResult = _wallet.spend(int(cost["gold"]))
	if not paid.ok:
		return paid
	var taken: Array[Dictionary] = []
	for row: Dictionary in cost["items"] as Array:
		var removed: CommandResult = _bank.remove(row["item"] as StringName, int(row["qty"]))
		if not removed.ok:
			# Cannot happen after can_upgrade; give everything back so that nothing is ever lost.
			push_error("Village.upgrade('%s'): payment failed after can_upgrade (%s)" % [building_id, removed.reason])
			_refund(int(cost["gold"]), taken)
			return removed
		taken.append(row)
	_levels[building_id] = level(building_id) + 1
	rebuild_modifiers()
	_events.village_upgraded.emit(building_id, _levels[building_id])
	return CommandResult.success()


## F-132: the source `village:<id>` of every building at level >= 1 has `{stat, value = effect_at, scope}`; none at 0.
func rebuild_modifiers() -> void:
	_modifiers.begin_batch()
	for def: VillageBuildingDef in _defs.values():
		var source: StringName = StringName(SOURCE_PREFIX + String(def.id))
		if not def.buildable or level(def.id) < 1:
			_modifiers.clear_source(source)
			continue
		var mod: Modifier = Modifier.from_dict({"stat": def.effect_stat, "scope": def.effect_scope,
				"value": effect_at(def.id, level(def.id))})
		_modifiers.set_source(source, [mod])
	_modifiers.end_batch()


func new_game() -> void:
	_levels.clear()


## `{"levels": {building_id: int}}`, only the buildings at level >= 1.
func to_save() -> Dictionary:
	var saved: Dictionary = {}
	for id: StringName in _ids:
		if level(id) >= 1:
			saved[String(id)] = level(id)
	return {LEVELS_KEY: saved}


## Tolerant (Log.warn): `levels` not an object = nothing built; an unknown id or a placeholder is dropped; a value that
## is not an integer or is <= 0 is dropped; a value above max_level is capped.
func from_save(d: Dictionary) -> void:
	_levels.clear()
	var raw: Variant = d.get(LEVELS_KEY)
	if not raw is Dictionary:
		Log.warn(LOG_CATEGORY, "'levels' is not an object: no building built")
		return
	for key: Variant in raw as Dictionary:
		var id: StringName = StringName(str(key))
		var value: Variant = (raw as Dictionary)[key]
		if not is_buildable(id):
			Log.warn(LOG_CATEGORY, "building '%s' is unknown or not buildable: dropped" % id)
		elif not _is_whole(value) or int(value) <= 0:
			Log.warn(LOG_CATEGORY, "building '%s': level %s is not a positive integer: dropped" % [id, str(value)])
		else:
			_levels[id] = mini(int(value), max_level())


func _def(building_id: StringName) -> VillageBuildingDef:
	return _defs.get(building_id) as VillageBuildingDef


func _refund(gold: int, taken: Array[Dictionary]) -> void:
	_wallet.add_gold(gold)
	for row: Dictionary in taken:
		_bank.add(row["item"] as StringName, int(row["qty"]))


static func _is_whole(value: Variant) -> bool:
	return value is int or (value is float and (value as float) == floorf(value as float))
