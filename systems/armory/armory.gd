class_name Armory
extends RefCounted
## The Armory (docs/01_GDD.md §21): the only container of unique pieces (equipment and tools), as ItemInstance.
##
## The capacity is the Deposit's (F-100), shared with the Bank; only the pieces that are not worn count (`used`).
## `uid` values start from 1, grow and are never reused (`next_uid` is saved). Getters return copies. Signals go to the
## session EventBus after the state changed (`deposit_changed` through `Deposit.notify_changed`). `new_game` and
## `from_save` set the state without signals.

const SAVE_KEY: StringName = &"armory"
const OCCUPANT_ID: StringName = &"armory"
const LOG_CATEGORY: String = "armory"
const CHANGE_ADDED: StringName = &"added"
const CHANGE_REMOVED: StringName = &"removed"
const CHANGE_UPDATED: StringName = &"updated"

var _data: GameData
var _events: GameEvents
var _modifiers: ModifierService
var _rng: RngService
var _bank: Bank
var _wallet: Wallet
# uid -> instance, in insertion order (Dictionary keeps it).
var _items: Dictionary[int, ItemInstance] = {}
var _worn: Dictionary[int, bool] = {}
var _next_uid: int = 1
var _filter: ArmoryFilter
var _skills: SkillsSystem
var _deposit: Deposit


func _init(session: GameSession) -> void:
	assert(session != null, "Armory needs a session")
	_data = session.data
	_events = session.events
	_modifiers = session.modifiers
	_rng = session.rng
	_bank = session.bank
	_wallet = session.wallet
	_skills = session.skills
	_deposit = session.deposit
	_deposit.register_occupant(OCCUPANT_ID, used)
	_filter = ArmoryFilter.new((_data.balance_value("equipment.grade_levels") as Array).size())  # M14: 15 piece grades


## Pieces that are not worn.
func used() -> int:
	return _items.size() - _worn.size()


func can_add(count: int = 1) -> bool: return count >= 0 and _deposit.has_room(count)


## Takes a copy of `inst`, assigns the next uid and returns it. 0 (and armory_rejected) when the Armory is full,
## 0 when the base is not equipment or tool.
func add(inst: ItemInstance) -> int:
	if inst == null or not _is_piece_base(inst.base_id):
		return 0
	if not can_add(1):
		_events.armory_rejected.emit(inst.base_id, 1)
		return 0
	var stored: ItemInstance = inst.duplicate_instance()
	stored.uid = _next_uid
	_next_uid += 1
	_items[stored.uid] = stored
	_events.armory_changed.emit(stored.uid, CHANGE_ADDED)
	_events.item_obtained.emit(stored.base_id, 1)
	_deposit.notify_changed()
	return stored.uid


## ItemRoller.create + add. 0 when the Armory is full or the base is not equipment/tool (unknown included).
func create(base_id: StringName, rarity: StringName, ilvl: int) -> int:
	if not _is_piece_base(base_id):
		return 0
	if not can_add(1):
		_events.armory_rejected.emit(base_id, 1)
		return 0
	return add(ItemRoller.create(_data.item(base_id), rarity, ilvl, _data, _rng))


func get_instance(uid: int) -> ItemInstance:
	var inst: ItemInstance = _items.get(uid)
	return inst.duplicate_instance() if inst != null else null


func instances() -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	for inst: ItemInstance in _items.values():
		result.append(inst.duplicate_instance())
	return result


## The base id of the piece `uid` (&"" if none) without copying the instance: hot path of the combat loop.
func base_id_of(uid: int) -> StringName: return _items[uid].base_id if _items.has(uid) else &""

func has(uid: int) -> bool: return _items.has(uid)


func is_worn(uid: int) -> bool: return _worn.has(uid)


## Only Equipment calls this. Changes used(). `quiet` (only Equipment.from_save) sets the flag without signals.
func set_worn(uid: int, worn: bool, quiet: bool = false) -> void:
	if not _items.has(uid) or _worn.has(uid) == worn:
		return
	if worn:
		_worn[uid] = true
	else:
		_worn.erase(uid)
	if quiet:
		_deposit.sync_known()
		return
	_events.armory_changed.emit(uid, CHANGE_UPDATED)
	_deposit.notify_changed()


## unknown_id, item_unique (a unique tool has no lock).
func set_locked(uid: int, locked: bool) -> CommandResult:
	if not _items.has(uid):
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	if _is_unique(uid):
		return CommandResult.fail(Reasons.ITEM_UNIQUE)
	if _items[uid].locked != locked:
		_items[uid].locked = locked
		_events.armory_changed.emit(uid, CHANGE_UPDATED)
	return CommandResult.success()


## unknown_id, item_unique, item_locked, item_equipped (in this order).
func remove(uid: int) -> CommandResult:
	if not _items.has(uid):
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	if _is_unique(uid):
		return CommandResult.fail(Reasons.ITEM_UNIQUE)
	if _items[uid].locked:
		return CommandResult.fail(Reasons.ITEM_LOCKED)
	if _worn.has(uid):
		return CommandResult.fail(Reasons.ITEM_EQUIPPED)
	_items.erase(uid)
	_events.armory_changed.emit(uid, CHANGE_REMOVED)
	_deposit.notify_changed()
	return CommandResult.success()


func instance_modifiers(uid: int) -> Array[Modifier]:
	if not _items.has(uid):
		var none: Array[Modifier] = []
		return none
	return ItemRoller.instance_modifiers(_items[uid], _data)


## F-89: number of sockets of the piece (0 for an unknown uid).
func socket_count(uid: int) -> int:
	if not _items.has(uid):
		return 0
	return Sockets.count(_items[uid].rarity, _items[uid].upgrade, _data)


## Sets a stone from the bank into the first free socket. unknown_id, not_equippable (not a stone), socket_locked (the
## piece has no socket), socket_occupied (all full), not_enough_items (the stone is not in the bank). Atomic.
func socket_stone(uid: int, stone_id: StringName) -> CommandResult:
	if not _items.has(uid):
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	var result: CommandResult = Sockets.set_stone(_items[uid], stone_id, _bank, _data)
	if result.ok:
		_events.armory_changed.emit(uid, CHANGE_UPDATED)
	return result


## Destroys the stone at `index` (0-based, in the order they were set). unknown_id, slot_empty (no stone there).
func clear_socket(uid: int, index: int) -> CommandResult:
	if not _items.has(uid):
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	var inst: ItemInstance = _items[uid]
	if index < 0 or index >= inst.sockets.size():
		return CommandResult.fail(Reasons.SLOT_EMPTY)
	inst.sockets.remove_at(index)
	_events.armory_changed.emit(uid, CHANGE_UPDATED)
	return CommandResult.success()


## GDD §26: spends a currency from the bank on the piece (CurrencyUse). unknown_id, not_equippable (not a currency),
## item_locked, item_equipped, requirement_not_met (rarity does not fit), not_enough_items. Atomic.
func use_currency(uid: int, currency_id: StringName) -> CommandResult:
	if not _items.has(uid):
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	var result: CommandResult = CurrencyUse.use(_items[uid], _worn.has(uid), currency_id, _bank, _data, _rng)
	if result.ok:
		_events.armory_changed.emit(uid, CHANGE_UPDATED)
	return result


## F-86: one refinement attempt of `uid`. Fails without any change: unknown_id, not_equippable (a unique tool: use
## `upgrade_tool`), then Upgrade.check (upgrade_max, not_enough_gold, not_enough_items). Success: +1.
## Failure: the materials are lost and, from `upgrade.downgrade_from`, the piece drops one level, unless `use_seal`
## (the Seal is then consumed; it is neither required nor consumed below that level). Never destroys the piece.
func upgrade(uid: int, use_seal: bool = false) -> CommandResult:
	if not _items.has(uid):
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	if _is_unique(uid) or _is_legendary_tool(uid):  # F-120: a legendary tool has no refinement
		return CommandResult.fail(Reasons.NOT_EQUIPPABLE)
	var inst: ItemInstance = _items[uid]
	var checked: CommandResult = Upgrade.check(inst, use_seal, _wallet, _bank, _data)
	if not checked.ok:
		return checked
	Upgrade.pay(inst, _wallet, _bank, _data)
	var success: bool = _rng.roll_pct(Upgrade.chance_pct(inst.upgrade, _modifiers.total(Upgrade.STAT), _data))
	if success:
		inst.upgrade += 1
	elif Upgrade.seal_needed(inst, use_seal, _data):
		Upgrade.spend(_bank, Upgrade.seal_item(_data), 1)
	else:
		inst.upgrade = Upgrade.failed_level(inst.upgrade, _data)
	_events.armory_changed.emit(uid, CHANGE_UPDATED)
	_events.item_upgraded.emit(uid, success, inst.upgrade)
	return CommandResult.success()


## F-94 (M10): one always-successful refinement step of a unique tool. unknown_id, not_a_tool, upgrade_max,
## level_too_low (the craft), not_enough_gold, not_enough_items (plates and handles of the grade of the step). Atomic.
func upgrade_tool(uid: int) -> CommandResult:
	if not _items.has(uid):
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	if _is_legendary_tool(uid):
		return CommandResult.fail(Reasons.NOT_EQUIPPABLE)
	var checked: CommandResult = ToolUpgrade.check(_items[uid], _skills, _wallet, _bank, _data)
	if checked.ok:
		ToolUpgrade.apply(_items[uid], _wallet, _bank, _data)
		_events.armory_changed.emit(uid, CHANGE_UPDATED)
		_events.item_upgraded.emit(uid, true, _items[uid].upgrade)
	return checked

## The row of the next step of a unique tool for the UI (ToolUpgrade.step); empty if not a unique tool or at the maximum.
func tool_next_step(uid: int) -> Dictionary:
	if not _items.has(uid) or not _is_unique(uid) or _items[uid].upgrade >= ToolUpgrade.max_level(_data):
		return {}
	return ToolUpgrade.step(_items[uid].upgrade + 1, _data)


## The uid of the unique tool of a `tool_*` slot; 0 if there is none.
func tool_uid(slot_id: StringName) -> int:
	for uid: int in _items:
		if _is_unique(uid) and _data.item(_items[uid].base_id).equip.slot == slot_id:
			return uid
	return 0


## F-95: destroys a piece and pays its components and shards into the bank. unknown_id, item_unique, item_locked,
## item_equipped, bank_full (the yield does not fit: nothing changes).
func salvage(uid: int) -> CommandResult:
	if not _items.has(uid):
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	if _is_unique(uid):
		return CommandResult.fail(Reasons.ITEM_UNIQUE)
	if _items[uid].locked:
		return CommandResult.fail(Reasons.ITEM_LOCKED)
	if _worn.has(uid):
		return CommandResult.fail(Reasons.ITEM_EQUIPPED)
	var inst: ItemInstance = _items[uid]
	var paid: Dictionary[StringName, int] = Salvage.paid(inst, _data)
	if not Salvage.fits(paid, _bank):
		return CommandResult.fail(Reasons.BANK_FULL)
	_items.erase(uid)
	_events.armory_changed.emit(uid, CHANGE_REMOVED)
	_deposit.notify_changed()
	Salvage.pay(paid, _bank)
	_events.item_salvaged.emit(uid, inst.base_id, false)
	return CommandResult.success()


## Entry point of the drops (docs/01_GDD.md §25): the piece goes to the Armory unless it is under the filter of its
## slot or the Armory is full; then it is salvaged at once (item_salvaged with auto = true, never silent). Returns the
## uid of the stored piece, or 0 when it was salvaged (its uid is spent, never reused) or the base is not a piece.
func add_drop(inst: ItemInstance) -> int:
	if inst == null or not _is_piece_base(inst.base_id):
		return 0
	var equip: EquipInfo = _data.item(inst.base_id).equip
	if inst.rarity == Rarities.LEGENDARY:  # F-120: never filtered; with the Deposit full it is lost (armory_rejected)
		return add(inst)
	if not _filter.rejects(equip.slot, inst.rarity, equip.grade) and can_add(1):
		return add(inst)
	var uid: int = _next_uid
	_next_uid += 1
	Salvage.pay(Salvage.paid(inst, _data), _bank)
	_events.item_obtained.emit(inst.base_id, 1)  # F-124: seen even when the filter sells it
	_events.item_salvaged.emit(uid, inst.base_id, true)
	return 0


## The rule of the automatic filter for an equipment slot: {"min_rarity": StringName, "min_grade": int}.
func filter_rule(slot: StringName) -> Dictionary:
	return _filter.rule(slot)


## The rules other than "keep everything": slot -> {"min_rarity", "min_grade"}.
func filter_rules() -> Dictionary:
	return _filter.rules()


## unknown_id (not an equipment slot or unknown rarity), invalid_amount (grade outside 1..8). "common" and 1 keep all.
func set_filter(slot: StringName, min_rarity: StringName, min_grade: int) -> CommandResult:
	return _filter.set_rule(slot, min_rarity, min_grade)


## True when `inst` would be salvaged by the filter (the full Armory is not considered).
func is_filtered(inst: ItemInstance) -> bool:
	if inst == null or not _is_piece_base(inst.base_id):
		return false
	var equip: EquipInfo = _data.item(inst.base_id).equip
	return _filter.rejects(equip.slot, inst.rarity, equip.grade)


## M14 "Riordina" (`ArmorySort`): signals `armory_changed` only for the pieces that moved.
func sort() -> void:
	var before: Array = _items.keys()
	var sorted: Dictionary[int, ItemInstance] = {}
	for uid: int in ArmorySort.sorted_uids(_items, _data):
		sorted[uid] = _items[uid]
	_items = sorted
	for uid: int in sorted.keys().filter(func(u: int) -> bool: return sorted.keys().find(u) != before.find(u)):
		_events.armory_changed.emit(uid, CHANGE_UPDATED)


## Empty, then the starting kit (ArmoryKit, docs/01_GDD.md §1.1) with uids 1…n, without signals; Equipment.new_game wears it.
func new_game() -> void:
	_clear()
	for inst: ItemInstance in ArmoryKit.pieces(_data):
		inst.uid = _next_uid
		_next_uid += 1
		_items[inst.uid] = inst
	_deposit.sync_known()


func _is_unique(uid: int) -> bool:
	var def: ItemDef = _data.item(_items[uid].base_id) if _data.has_item(_items[uid].base_id) else null
	return def != null and def.equip != null and def.equip.unique


func _is_legendary_tool(uid: int) -> bool:
	var def: ItemDef = _data.item(_items[uid].base_id) if _items.has(uid) and _data.has_item(_items[uid].base_id) else null
	return def != null and def.equip != null and def.equip.is_legendary_tool()


func to_save() -> Dictionary:
	var saved: Array[Dictionary] = []
	for inst: ItemInstance in _items.values():
		saved.append(inst.to_dict())
	return {"next_uid": _next_uid, "items": saved, "filter": _filter.to_save()}


## Invalid entries, unknown or non-piece bases and duplicate uids are reported with Log.warn and dropped (also the
## invalid rules of `filter`; a missing `filter` keeps everything).
## The capacity is not checked. `next_uid` is raised above the highest uid if it is not.
func from_save(d: Dictionary) -> void:
	_clear()
	_filter.from_save(d.get("filter"))
	var list: Variant = d.get("items")
	if not list is Array:
		Log.warn(LOG_CATEGORY, "'items' is not a list: empty Armory")
	else:
		for entry: Variant in list:
			_load_entry(entry)
	var highest: int = 0
	for uid: int in _items:
		highest = maxi(highest, uid)
	var saved_next: Variant = d.get("next_uid")
	var next: int = int(saved_next) if (saved_next is int or saved_next is float) else 1
	_next_uid = maxi(next, highest + 1)
	_deposit.sync_known()


func _load_entry(entry: Variant) -> void:
	if not entry is Dictionary:
		Log.warn(LOG_CATEGORY, "piece dropped (not an object): %s" % str(entry))
		return
	var inst: ItemInstance = ItemInstance.from_dict(entry, _data)
	if inst == null or inst.uid <= 0 or _items.has(inst.uid) or not _is_piece_base(inst.base_id):
		Log.warn(LOG_CATEGORY, "piece dropped (invalid, bad uid or duplicate): %s" % str(entry))
		return
	var stones: Array[StringName] = []
	for stone_id: StringName in inst.sockets:
		if Sockets.is_stone(stone_id, _data):
			stones.append(stone_id)
		else:
			Log.warn(LOG_CATEGORY, "piece %d: '%s' is not a stone, dropped from its sockets" % [inst.uid, stone_id])
	inst.sockets = stones
	_items[inst.uid] = inst


func _clear() -> void:
	_items.clear()
	_worn.clear()
	_next_uid = 1
	_filter.clear()


func _is_piece_base(base_id: StringName) -> bool:
	return _data.has_item(base_id) and _data.item(base_id).category in Bank.PIECE_CATEGORIES \
			and _data.item(base_id).equip != null
