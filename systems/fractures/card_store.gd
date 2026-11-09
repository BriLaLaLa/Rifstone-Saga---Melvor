class_name CardStore
extends RefCounted
## The only container of Fracture Cards (docs/05_INTERFACES.md §5.23, docs/01_GDD.md §17.1): MapCard instances.
##
## One Deposit box per Card (occupant `cards`, F-100). `uid` values start from 1, grow and are never reused (`next_uid`
## is saved). Getters return copies. Signals go to the session EventBus after the state changed (`deposit_changed`
## through `Deposit.notify_changed`). `new_game` and `from_save` set the state without signals.

const SAVE_KEY: StringName = &"cards"
const OCCUPANT_ID: StringName = &"cards"
const LOG_CATEGORY: String = "cards"
const DUST_ITEM: StringName = &"rift_dust"
const RARITY_STAT: StringName = &"item_rarity_pct"
const CHANGE_ADDED: StringName = &"added"
const CHANGE_REMOVED: StringName = &"removed"
const CHANGE_UPDATED: StringName = &"updated"
const EPSILON: float = 1e-9

var _data: GameData
var _events: GameEvents
var _modifiers: ModifierService
var _rng: RngService
var _bank: Bank
var _deposit: Deposit
# uid -> Card, in insertion order (Dictionary keeps it).
var _items: Dictionary[int, MapCard] = {}
var _next_uid: int = 1


func _init(session: GameSession) -> void:
	assert(session != null, "CardStore needs a session")
	_data = session.data
	_events = session.events
	_modifiers = session.modifiers
	_rng = session.rng
	_bank = session.bank
	_deposit = session.deposit


## Cards in the Deposit (one box each).
func used() -> int:
	return _items.size()


func can_add(count: int = 1) -> bool:
	return count >= 0 and _deposit.has_room(count)


## Takes a copy of `card`, assigns the next uid and returns it. 0 (and card_rejected) when the Deposit is full, 0 when
## the base is not a Card base.
func add(card: MapCard) -> int:
	if card == null or not _data.has_item(card.base_id) or not _data.item(card.base_id).is_map():
		return 0
	if not can_add(1):
		_events.card_rejected.emit(card.grade)
		return 0
	var stored: MapCard = card.duplicate_card()
	stored.uid = _next_uid
	_next_uid += 1
	_items[stored.uid] = stored
	_events.card_changed.emit(stored.uid, CHANGE_ADDED)
	_events.item_obtained.emit(stored.base_id, 1)
	_deposit.notify_changed()
	return stored.uid


## MapCardRoller.create + add. 0 when the grade has no Card base or the Deposit is full (card_rejected, nothing rolled).
func create(grade: int, rarity: StringName) -> int:
	if grade < 1 or not _data.has_item(StringName("fracture_card_%d" % grade)):
		return 0
	if not can_add(1):
		_events.card_rejected.emit(grade)
		return 0
	return add(MapCardRoller.create(grade, rarity, _data, _rng))


## The rarity of a Card that drops (F-109), with the `item_rarity_pct` of the session.
func roll_rarity() -> StringName:
	return MapCardRoller.roll_rarity(_modifiers.total(RARITY_STAT), _data, _rng)


func get_card(uid: int) -> MapCard:
	var card: MapCard = _items.get(uid)
	return card.duplicate_card() if card != null else null


func cards() -> Array[MapCard]:
	var result: Array[MapCard] = []
	for card: MapCard in _items.values():
		result.append(card.duplicate_card())
	return result


func has(uid: int) -> bool:
	return _items.has(uid)


## unknown_id.
func set_locked(uid: int, locked: bool) -> CommandResult:
	if not _items.has(uid):
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	if _items[uid].locked != locked:
		_items[uid].locked = locked
		_events.card_changed.emit(uid, CHANGE_UPDATED)
	return CommandResult.success()


## F-109: spends a Rift Crystal from the Bank on the Card. unknown_id, not_equippable (not a currency), item_locked,
## requirement_not_met (rarity does not fit), not_enough_items (in this order). Atomic.
func use_currency(uid: int, currency_id: StringName) -> CommandResult:
	if not _items.has(uid):
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	if not CurrencyUse.is_currency(currency_id, _data):
		return CommandResult.fail(Reasons.NOT_EQUIPPABLE)
	var card: MapCard = _items[uid]
	if card.locked:
		return CommandResult.fail(Reasons.ITEM_LOCKED)
	var effect: StringName = _data.item(currency_id).currency_effect
	if not CurrencyUse.accepts(effect, card.rarity):
		return CommandResult.fail(Reasons.REQUIREMENT_NOT_MET)
	var removed: CommandResult = _bank.remove(currency_id, 1)
	if not removed.ok:
		return removed
	match effect:
		CurrencyUse.TO_MAGIC:
			card.rarity = &"magic"
			card.mods = MapCardRoller.extend_mods(card, &"magic", _data, _rng)
		CurrencyUse.TO_RARE:
			card.rarity = &"rare"
			card.mods = MapCardRoller.extend_mods(card, &"rare", _data, _rng)
		CurrencyUse.REROLL:
			card.mods = MapCardRoller.extend_mods(_without_mods(card), card.rarity, _data, _rng)
	_events.card_changed.emit(uid, CHANGE_UPDATED)
	return CommandResult.success()


## F-114: destroys a Card and pays Rift Dust into the Bank. unknown_id, item_locked, bank_full (the Dust does not fit:
## nothing changes).
func salvage(uid: int) -> CommandResult:
	if not _items.has(uid):
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	var card: MapCard = _items[uid]
	if card.locked:
		return CommandResult.fail(Reasons.ITEM_LOCKED)
	if _bank.get_count(DUST_ITEM) == 0 and _bank.free_boxes() < 1:
		return CommandResult.fail(Reasons.BANK_FULL)
	var dust: int = salvage_dust(card.grade, card.rarity)
	_items.erase(uid)
	_events.card_changed.emit(uid, CHANGE_REMOVED)
	_deposit.notify_changed()
	_bank.add(DUST_ITEM, dust)
	return CommandResult.success()


## F-114: `floor(dust_per_grade x grade x rarity_mult[rarity])`.
func salvage_dust(grade: int, rarity: StringName) -> int:
	var per_grade: float = float(_data.balance_value("fracture.salvage.dust_per_grade"))
	var mult: float = float(_data.balance_value("fracture.salvage.rarity_mult.%s" % rarity))
	return floori(per_grade * float(grade) * mult + EPSILON)


## INTERNAL (FractureSystem.open): removes the Card and returns it; null when absent.
func take(uid: int) -> MapCard:
	var card: MapCard = _items.get(uid)
	if card == null:
		return null
	_items.erase(uid)
	_events.card_changed.emit(uid, CHANGE_REMOVED)
	_deposit.notify_changed()
	return card


func new_game() -> void:
	_clear()
	_deposit.sync_known()


func to_save() -> Dictionary:
	var saved: Array[Dictionary] = []
	for card: MapCard in _items.values():
		saved.append(card.to_dict())
	return {"next_uid": _next_uid, "items": saved}


## Invalid entries, unknown bases, unknown modifiers, a step out of range and duplicate uids are reported with Log.warn
## and dropped. The capacity is not checked. `next_uid` is raised above the highest uid if it is not.
func from_save(d: Dictionary) -> void:
	_clear()
	var list: Variant = d.get("items")
	if not list is Array:
		Log.warn(LOG_CATEGORY, "'items' is not a list: no Cards")
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
		Log.warn(LOG_CATEGORY, "Card dropped (not an object): %s" % str(entry))
		return
	var card: MapCard = MapCard.from_dict(entry, _data)
	if card == null or card.uid <= 0 or _items.has(card.uid):
		Log.warn(LOG_CATEGORY, "Card dropped (invalid, bad uid or duplicate): %s" % str(entry))
		return
	_items[card.uid] = card


func _clear() -> void:
	_items.clear()
	_next_uid = 1


# A copy of `card` with no modifiers (the input of a reroll).
static func _without_mods(card: MapCard) -> MapCard:
	var copy: MapCard = card.duplicate_card()
	copy.mods.clear()
	return copy
