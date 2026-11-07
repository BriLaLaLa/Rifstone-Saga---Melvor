class_name Armory
extends RefCounted
## The Armory (docs/01_GDD.md §21): the only container of unique pieces (equipment and tools), as ItemInstance.
##
## Capacity is F-82: `armory.base_slots + floor(T(armory_slots, global))`; only the pieces that are not worn count.
## `uid` values start from 1, grow and are never reused (`next_uid` is saved). Getters return copies. Signals go to the
## session EventBus after the state changed. `new_game` and `from_save` set the state without signals.

const SAVE_KEY: StringName = &"armory"
const LOG_CATEGORY: String = "armory"
const BASE_SLOTS_KEY: String = "armory.base_slots"
const CAPACITY_STAT: StringName = &"armory_slots"
const CHANGE_ADDED: StringName = &"added"
const CHANGE_REMOVED: StringName = &"removed"
const CHANGE_UPDATED: StringName = &"updated"

var _data: GameData
var _events: GameEvents
var _modifiers: ModifierService
var _rng: RngService
var _bank: Bank
var _wallet: Wallet
var _base_slots: int = 0
# uid -> instance, in insertion order (Dictionary keeps it).
var _items: Dictionary[int, ItemInstance] = {}
var _worn: Dictionary[int, bool] = {}
var _next_uid: int = 1
var _filter: ArmoryFilter
# Base item id -> ingots of its recipe (F-88), built on first use.
var _recipe_ingots: Dictionary[StringName, int] = {}
# Capacity last announced, to emit armory_capacity_changed when the modifiers change it.
var _known_capacity: int = 0


func _init(session: GameSession) -> void:
	assert(session != null, "Armory needs a session")
	_data = session.data
	_events = session.events
	_modifiers = session.modifiers
	_rng = session.rng
	_bank = session.bank
	_wallet = session.wallet
	_base_slots = int(_data.balance_value(BASE_SLOTS_KEY))
	_filter = ArmoryFilter.new((_data.balance_value(Upgrade.INGOT_ITEMS_KEY) as Array).size())
	_known_capacity = capacity()
	_events.modifiers_changed.connect(_on_modifiers_changed)


## F-82.
func capacity() -> int:
	return _base_slots + floori(_modifiers.total(CAPACITY_STAT))


## Pieces that are not worn.
func used() -> int:
	return _items.size() - _worn.size()


func can_add(count: int = 1) -> bool:
	return count >= 0 and used() + count <= capacity()


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
	_emit_capacity()
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


func has(uid: int) -> bool:
	return _items.has(uid)


func is_worn(uid: int) -> bool:
	return _worn.has(uid)


## Only Equipment calls this. Changes used(). `quiet` (only Equipment.from_save) sets the flag without signals.
func set_worn(uid: int, worn: bool, quiet: bool = false) -> void:
	if not _items.has(uid) or _worn.has(uid) == worn:
		return
	if worn:
		_worn[uid] = true
	else:
		_worn.erase(uid)
	if quiet:
		_known_capacity = capacity()
		return
	_events.armory_changed.emit(uid, CHANGE_UPDATED)
	_emit_capacity()


func set_locked(uid: int, locked: bool) -> CommandResult:
	if not _items.has(uid):
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	if _items[uid].locked != locked:
		_items[uid].locked = locked
		_events.armory_changed.emit(uid, CHANGE_UPDATED)
	return CommandResult.success()


## unknown_id, item_locked, item_equipped (in this order).
func remove(uid: int) -> CommandResult:
	if not _items.has(uid):
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	if _items[uid].locked:
		return CommandResult.fail(Reasons.ITEM_LOCKED)
	if _worn.has(uid):
		return CommandResult.fail(Reasons.ITEM_EQUIPPED)
	_items.erase(uid)
	_events.armory_changed.emit(uid, CHANGE_REMOVED)
	_emit_capacity()
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
	if not Sockets.is_stone(stone_id, _data):
		return CommandResult.fail(Reasons.NOT_EQUIPPABLE)
	var inst: ItemInstance = _items[uid]
	var total: int = socket_count(uid)
	if total == 0:
		return CommandResult.fail(Reasons.SOCKET_LOCKED)
	if inst.sockets.size() >= total:
		return CommandResult.fail(Reasons.SOCKET_OCCUPIED)
	var removed: CommandResult = _bank.remove(stone_id, 1)
	if not removed.ok:
		return removed
	inst.sockets.append(stone_id)
	_events.armory_changed.emit(uid, CHANGE_UPDATED)
	return CommandResult.success()


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


## F-86: one refinement attempt of `uid`. Fails without any change: unknown_id, upgrade_max, not_enough_gold,
## not_enough_items (ingots, shards and, when `use_seal` and the step can lose a level, the Seal). Success: +1.
## Failure: the materials are lost and, from `upgrade.downgrade_from`, the piece drops one level, unless `use_seal`
## (the Seal is then consumed; it is neither required nor consumed below that level). Never destroys the piece.
func upgrade(uid: int, use_seal: bool = false) -> CommandResult:
	if not _items.has(uid):
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	var inst: ItemInstance = _items[uid]
	if inst.upgrade >= Upgrade.max_level(_data):
		return CommandResult.fail(Reasons.UPGRADE_MAX)
	var cost: Dictionary = Upgrade.cost(inst.upgrade, _data.item(inst.base_id).equip.grade, _data)
	var seal_needed: bool = use_seal and Upgrade.failed_level(inst.upgrade, _data) < inst.upgrade
	if _wallet.get_gold() < int(cost["gold"]):
		return CommandResult.fail(Reasons.NOT_ENOUGH_GOLD)
	var ingot: StringName = cost["ingot"]
	if not _bank.has(ingot, int(cost["ingots"])) or not _bank.has(Upgrade.SHARD_ITEM, int(cost["shards"])) \
			or (seal_needed and not _bank.has(Upgrade.seal_item(_data), 1)):
		return CommandResult.fail(Reasons.NOT_ENOUGH_ITEMS)
	if int(cost["gold"]) > 0:
		_wallet.spend(int(cost["gold"]))
	_spend_items(ingot, int(cost["ingots"]))
	_spend_items(Upgrade.SHARD_ITEM, int(cost["shards"]))
	var chance: float = Upgrade.chance_pct(inst.upgrade, _modifiers.total(Upgrade.STAT), _data)
	var success: bool = _rng.roll_pct(chance)
	if success:
		inst.upgrade += 1
	else:
		if seal_needed:
			_spend_items(Upgrade.seal_item(_data), 1)
		else:
			inst.upgrade = Upgrade.failed_level(inst.upgrade, _data)
	_events.armory_changed.emit(uid, CHANGE_UPDATED)
	_events.item_upgraded.emit(uid, success, inst.upgrade)
	return CommandResult.success()


func _spend_items(item_id: StringName, qty: int) -> void:
	if qty > 0:
		_bank.remove(item_id, qty)


## F-88: destroys a piece and pays ingots and shards into the bank. unknown_id, item_locked, item_equipped,
## bank_full (the yield does not fit: nothing changes).
func salvage(uid: int) -> CommandResult:
	if not _items.has(uid):
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	if _items[uid].locked:
		return CommandResult.fail(Reasons.ITEM_LOCKED)
	if _worn.has(uid):
		return CommandResult.fail(Reasons.ITEM_EQUIPPED)
	var inst: ItemInstance = _items[uid]
	var paid: Dictionary[StringName, int] = Salvage.yields(inst, _recipes(), _data)
	if not _bank_fits(paid):
		return CommandResult.fail(Reasons.BANK_FULL)
	_items.erase(uid)
	_events.armory_changed.emit(uid, CHANGE_REMOVED)
	_emit_capacity()
	_pay(paid)
	_events.item_salvaged.emit(uid, inst.base_id, false)
	return CommandResult.success()


## Entry point of the drops (docs/01_GDD.md §25): the piece goes to the Armory unless it is under the filter of its
## slot or the Armory is full; then it is salvaged at once (item_salvaged with auto = true, never silent). Returns the
## uid of the stored piece, or 0 when it was salvaged (its uid is spent, never reused) or the base is not a piece.
func add_drop(inst: ItemInstance) -> int:
	if inst == null or not _is_piece_base(inst.base_id):
		return 0
	var equip: EquipInfo = _data.item(inst.base_id).equip
	if not _filter.rejects(equip.slot, inst.rarity, equip.grade) and can_add(1):
		return add(inst)
	var uid: int = _next_uid
	_next_uid += 1
	_pay(Salvage.yields(inst, _recipes(), _data))
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


func _recipes() -> Dictionary[StringName, int]:
	if _recipe_ingots.is_empty():
		_recipe_ingots = Salvage.recipe_ingots(_data)
	return _recipe_ingots


# Bank.add reports a full bank with bank_rejected, so a yield lost in an automatic salvage is never silent.
func _pay(paid: Dictionary[StringName, int]) -> void:
	for item_id: StringName in paid:
		_bank.add(item_id, paid[item_id])


func _bank_fits(paid: Dictionary[StringName, int]) -> bool:
	var new_stacks: int = 0
	for item_id: StringName in paid:
		if _bank.get_count(item_id) == 0:
			new_stacks += 1
	return new_stacks <= _bank.capacity() - _bank.used()


func new_game() -> void:
	_clear()
	_known_capacity = capacity()


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
	_known_capacity = capacity()


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


func _emit_capacity() -> void:
	_known_capacity = capacity()
	_events.armory_capacity_changed.emit(used(), _known_capacity)


func _on_modifiers_changed() -> void:
	if capacity() != _known_capacity:
		_emit_capacity()
