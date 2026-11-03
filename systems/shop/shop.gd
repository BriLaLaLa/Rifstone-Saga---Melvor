class_name Shop
extends RefCounted
## The shop (docs/01_GDD.md §8): buying entries of data/shop/shop.json and selling items for gold.
##
## Prices are fixed (`cost_gold`) or the F-17 bank slot formula; modifier effects are worth `value x purchases`
## (F-19) under the source `shop:<entry_id>`; item effects go to the bank. Selling is F-18.
## `shop_purchased(entry_id, count)` and `item_sold(item_id, qty, gold)` are emitted after the state changed.
## `new_game` and `from_save` set the state without signals.

const SAVE_KEY: StringName = &"shop"
const LOG_CATEGORY: String = "shop"
const SOURCE_PREFIX: String = "shop:"
const PURCHASES_KEY: String = "purchases"
const FORMULA_BANK_SLOT: StringName = &"bank_slot"
const FORMULA_ARMORY_SLOT: StringName = &"armory_slot"
const ARMORY_COST_BASE_KEY: String = "armory.slot_cost_base"
const ARMORY_COST_GROWTH_KEY: String = "armory.slot_cost_growth"
const ARMORY_COST_CAP_KEY: String = "armory.slot_cost_cap"
const PIECE_RARITY: StringName = &"common"
const PIECE_ILVL: int = 1
const SLOT_COST_BASE_KEY: String = "bank.slot_cost_base"
const SLOT_COST_GROWTH_KEY: String = "bank.slot_cost_growth"
const SLOT_COST_CAP_KEY: String = "bank.slot_cost_cap"

var _data: GameData
var _events: GameEvents
var _modifiers: ModifierService
var _bank: Bank
var _wallet: Wallet
var _skills: SkillsSystem
var _character: CharacterSystem
var _armory: Armory
# Entry id -> definition, built once (the data is immutable).
var _entries: Dictionary[StringName, ShopEntryDef] = {}
# Entry id -> number of purchases (only entries bought at least once).
var _purchases: Dictionary[StringName, int] = {}


func _init(session: GameSession) -> void:
	assert(session != null, "Shop needs a session")
	_data = session.data
	_events = session.events
	_modifiers = session.modifiers
	_bank = session.bank
	_wallet = session.wallet
	_skills = session.skills
	_character = session.character
	_armory = session.armory
	for entry: ShopEntryDef in _data.shop_entries():
		_entries[entry.id] = entry


func purchase_count(entry_id: StringName) -> int:
	return _purchases.get(entry_id, 0)


## Gold price of the next purchase: F-17 for the bank slot formula, else the fixed cost. 0 for an unknown entry.
func price(entry_id: StringName) -> int:
	if not _entries.has(entry_id):
		return 0
	var entry: ShopEntryDef = _entries[entry_id]
	if entry.cost_formula == FORMULA_BANK_SLOT:
		return _slot_price(purchase_count(entry_id))
	if entry.cost_formula == FORMULA_ARMORY_SLOT:
		return _armory_slot_price(purchase_count(entry_id))
	return entry.cost_gold


## Checks in order: unknown_id, max_purchases, requirement_not_met, not_enough_gold, bank_full or armory_full
## (item effects; equipment and tools go to the Armory as common pieces).
func can_buy(entry_id: StringName) -> CommandResult:
	if not _entries.has(entry_id):
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	var entry: ShopEntryDef = _entries[entry_id]
	if entry.max_purchases > 0 and purchase_count(entry_id) >= entry.max_purchases:
		return CommandResult.fail(Reasons.MAX_PURCHASES)
	if not _requirements_met(entry):
		return CommandResult.fail(Reasons.REQUIREMENT_NOT_MET)
	if _wallet.get_gold() < price(entry_id):
		return CommandResult.fail(Reasons.NOT_ENOUGH_GOLD)
	if entry.effect_item != null and _gives_pieces(entry):
		if not _armory.can_add(entry.effect_item.qty):
			return CommandResult.fail(Reasons.ARMORY_FULL)
	elif entry.effect_item != null and not _bank.can_add(entry.effect_item.item_id):
		return CommandResult.fail(Reasons.BANK_FULL)
	return CommandResult.success()


## Pays and applies the effect. Nothing is spent when the check fails.
func buy(entry_id: StringName) -> CommandResult:
	var check: CommandResult = can_buy(entry_id)
	if not check.ok:
		return check
	var entry: ShopEntryDef = _entries[entry_id]
	var paid: CommandResult = _wallet.spend(price(entry_id))
	if not paid.ok:
		return paid
	if entry.effect_item != null:
		var given: CommandResult = _give_item(entry.effect_item)
		if not given.ok:
			# Cannot happen after can_buy; refund so that no gold is ever lost.
			_wallet.add_gold(price(entry_id))
			return given
	_purchases[entry_id] = purchase_count(entry_id) + 1
	if not entry.effect_modifiers.is_empty():
		_apply_source(entry)
	_events.shop_purchased.emit(entry_id, _purchases[entry_id])
	return CommandResult.success()


## F-18: `item.value x qty`; 0 for an unknown item or a non-positive quantity.
func sell_value(item_id: StringName, qty: int) -> int:
	if not _data.has_item(item_id) or qty <= 0:
		return 0
	return _data.item(item_id).value * qty


## Checks in order: invalid_amount, unknown_id, item_locked, not_sellable (value 0), not_enough_items.
func sell(item_id: StringName, qty: int) -> CommandResult:
	if qty <= 0:
		return CommandResult.fail(Reasons.INVALID_AMOUNT)
	if not _data.has_item(item_id):
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	if _bank.is_locked(item_id):
		return CommandResult.fail(Reasons.ITEM_LOCKED)
	if _data.item(item_id).value <= 0:
		return CommandResult.fail(Reasons.NOT_SELLABLE)
	var removed: CommandResult = _bank.remove(item_id, qty)
	if not removed.ok:
		return removed
	var gold: int = sell_value(item_id, qty)
	_wallet.add_gold(gold)
	_events.item_sold.emit(item_id, qty, gold)
	return CommandResult.success()


## Sells a piece of the Armory for F-18 with qty 1. Checks in order: unknown_id, item_locked, item_equipped,
## not_sellable (value 0).
func sell_instance(uid: int) -> CommandResult:
	var inst: ItemInstance = _armory.get_instance(uid)
	if inst == null:
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	if inst.locked:
		return CommandResult.fail(Reasons.ITEM_LOCKED)
	if _armory.is_worn(uid):
		return CommandResult.fail(Reasons.ITEM_EQUIPPED)
	var gold: int = sell_value(inst.base_id, 1)
	if gold <= 0:
		return CommandResult.fail(Reasons.NOT_SELLABLE)
	var removed: CommandResult = _armory.remove(uid)
	if not removed.ok:
		return removed
	_wallet.add_gold(gold)
	_events.item_sold.emit(inst.base_id, 1, gold)
	return CommandResult.success()


## F-19: one source `shop:<id>` per modifier entry already bought (values scaled by the purchases).
func rebuild_modifiers() -> void:
	_modifiers.begin_batch()
	for entry: ShopEntryDef in _data.shop_entries():
		_apply_source(entry)
	_modifiers.end_batch()


func new_game() -> void:
	_purchases.clear()


func to_save() -> Dictionary:
	var saved: Dictionary = {}
	for entry_id: StringName in _purchases:
		saved[String(entry_id)] = _purchases[entry_id]
	return {PURCHASES_KEY: saved}


## Unknown entries and non-positive or non-integer counts are reported with Log.warn and dropped.
func from_save(d: Dictionary) -> void:
	_purchases.clear()
	var saved: Variant = d.get(PURCHASES_KEY)
	if not saved is Dictionary:
		Log.warn(LOG_CATEGORY, "'purchases' is not an object: no purchases")
		return
	for key: Variant in saved:
		var entry_id: StringName = StringName(str(key))
		var count: Variant = _as_positive_int(saved[key])
		if not _entries.has(entry_id) or count == null:
			Log.warn(LOG_CATEGORY, "purchase '%s' dropped (unknown entry or bad count)" % str(key))
			continue
		var limit: int = _entries[entry_id].max_purchases
		if limit > 0 and count > limit:
			Log.warn(LOG_CATEGORY, "purchase '%s' limited from %d to %d" % [key, count, limit])
			count = limit
		_purchases[entry_id] = count


# F-17: min(cap, floor(base x growth^n)).
func _slot_price(bought: int) -> int:
	var base: float = float(_data.balance_value(SLOT_COST_BASE_KEY))
	var growth: float = float(_data.balance_value(SLOT_COST_GROWTH_KEY))
	var cap: int = int(_data.balance_value(SLOT_COST_CAP_KEY))
	return mini(cap, floori(base * pow(growth, bought)))


func _requirements_met(entry: ShopEntryDef) -> bool:
	for required: StringName in entry.req_entries:
		if purchase_count(required) < 1:
			return false
	var mixed: Dictionary = {}
	for skill_id: StringName in entry.req_skills:
		mixed[skill_id] = entry.req_skills[skill_id]
	if entry.req_character > 0:
		mixed[CharacterSystem.REQUIREMENT_KEY] = entry.req_character
	if not mixed.is_empty() and not _character.meets_requirements(mixed):
		return false
	return _skills.total_level() >= entry.req_total_level


# Sets (or clears, when never bought) the source of a modifier entry.
func _apply_source(entry: ShopEntryDef) -> void:
	if entry.effect_modifiers.is_empty():
		return
	var source_id: StringName = StringName(SOURCE_PREFIX + String(entry.id))
	var count: int = purchase_count(entry.id)
	if count <= 0:
		_modifiers.clear_source(source_id)
		return
	var scaled: Array[Modifier] = []
	for mod: Modifier in entry.effect_modifiers:
		scaled.append(mod.scaled(count))
	_modifiers.set_source(source_id, scaled)


static func _as_positive_int(v: Variant) -> Variant:
	if v is float and float(v) == floorf(float(v)):
		v = int(v)
	if v is int and int(v) > 0:
		return int(v)
	return null


# F-82: min(cap, floor(base x growth^n)).
func _armory_slot_price(bought: int) -> int:
	var base: float = float(_data.balance_value(ARMORY_COST_BASE_KEY))
	var growth: float = float(_data.balance_value(ARMORY_COST_GROWTH_KEY))
	var cap: int = int(_data.balance_value(ARMORY_COST_CAP_KEY))
	return mini(cap, floori(base * pow(growth, bought)))


# True when the item effect is a unique piece (equipment or tool): it goes to the Armory, not to the bank.
func _gives_pieces(entry: ShopEntryDef) -> bool:
	return _is_piece(entry.effect_item.item_id)


func _is_piece(item_id: StringName) -> bool:
	return _data.has_item(item_id) and _data.item(item_id).category in Bank.PIECE_CATEGORIES


# Bank stack, or `qty` common pieces of ilvl 1 in the Armory.
func _give_item(effect: ItemQty) -> CommandResult:
	if not _is_piece(effect.item_id):
		return _bank.add(effect.item_id, effect.qty)
	for i: int in effect.qty:
		if _armory.create(effect.item_id, PIECE_RARITY, PIECE_ILVL) == 0:
			return CommandResult.fail(Reasons.ARMORY_FULL)
	return CommandResult.success()
