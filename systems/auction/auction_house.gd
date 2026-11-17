class_name AuctionHouse
extends RefCounted
## The Auction House (docs/01_GDD.md §34, docs/05_INTERFACES.md §5.30): selling and buying materials, components and food at
## prices that move. Commands, reasons, signals, save and the link with the Wallet, the Bank (Deposit) and the Village live here;
## every price, stock and trend comes from AuctionPricing (no formula in this class).
##
## `auction_sold`, `auction_bought` and `auction_updated` are emitted after the state changed; `item_sold` is not (it is the fixed
## price sale of the Shop, F-18). `new_game` and `from_save` set the state without signals.

const SAVE_KEY: StringName = &"auction"
const LOG_CATEGORY: String = "auction"
const SEED_MODULUS: int = 2147483647  # the market seed is 1..SEED_MODULUS (a positive int that JSON holds exactly)

var _data: GameData
var _events: GameEvents
var _rng: RngService
var _bank: Bank
var _wallet: Wallet
var _session: GameSession  # for the Village (created before, read when used, as the Shop does)
var _pricing: AuctionPricing
var _listed: Array[StringName] = []
var _buyable: Array[StringName] = []


func _init(session: GameSession) -> void:
	assert(session != null, "AuctionHouse needs a session")
	_data = session.data
	_events = session.events
	_rng = session.rng
	_bank = session.bank
	_wallet = session.wallet
	_session = session
	_pricing = AuctionPricing.new(_data)
	for def: AuctionItemDef in _data.auction_items():
		_listed.append(def.item)
		if def.buy_level >= 1:
			_buyable.append(def.item)


## Level of the Auction House building; 0 without a Village or without the building in the data.
func level() -> int:
	var building: StringName = _data.auction_building()
	if _session.village == null or building == &"":
		return 0
	return _session.village.level(building)


func is_open() -> bool:
	return level() >= 1


## The traded items, in file order.
func listed_items() -> Array[StringName]:
	return _listed.duplicate()


## The items that can also be bought, in file order.
func buyable_items() -> Array[StringName]:
	return _buyable.duplicate()


# Read-only pass-through of AuctionPricing for the UI.
func buy_level(item_id: StringName) -> int: return _pricing.buy_level(item_id)
func sell_quote(item_id: StringName, qty: int) -> int: return _pricing.sell_quote(item_id, qty)
func buy_quote(item_id: StringName, qty: int) -> int: return _pricing.buy_quote(item_id, qty)
func stock(item_id: StringName) -> int: return _pricing.stock(item_id)
func stock_max(item_id: StringName) -> int: return _pricing.stock_max(item_id)
func trend(item_id: StringName) -> StringName: return _pricing.trend(item_id)
func population(item_id: StringName) -> Dictionary: return _pricing.population(item_id)  # M26-08, F-173


## Checks in order: invalid_amount, unknown_id, not_tradable, requirement_not_met (not built), item_locked, not_enough_items,
## not_sellable (the sale would give 0 gold).
func can_sell(item_id: StringName, qty: int) -> CommandResult:
	if qty <= 0:
		return CommandResult.fail(Reasons.INVALID_AMOUNT)
	if not _data.has_item(item_id):
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	if not _pricing.is_listed(item_id):
		return CommandResult.fail(Reasons.NOT_TRADABLE)
	if not is_open():
		return CommandResult.fail(Reasons.REQUIREMENT_NOT_MET)
	if _bank.is_locked(item_id):
		return CommandResult.fail(Reasons.ITEM_LOCKED)
	if not _bank.has(item_id, qty):
		return CommandResult.fail(Reasons.NOT_ENOUGH_ITEMS)
	if _pricing.sell_quote(item_id, qty) <= 0:
		return CommandResult.fail(Reasons.NOT_SELLABLE)
	return CommandResult.success()


## Sells `qty` pieces. The gold is computed before the saturation changes (the pieces of one sale lower each other's price).
func sell(item_id: StringName, qty: int) -> CommandResult:
	var check: CommandResult = can_sell(item_id, qty)
	if not check.ok:
		return check
	var gold: int = _pricing.sell_quote(item_id, qty)
	var removed: CommandResult = _bank.remove(item_id, qty)
	if not removed.ok:
		return removed
	_wallet.add_gold(gold)
	_pricing.record_sale(item_id, qty)
	_events.auction_sold.emit(item_id, qty, gold)
	return CommandResult.success()


## Checks in order: invalid_amount, unknown_id, not_tradable (cannot be bought), requirement_not_met (level below the step),
## out_of_stock, not_enough_gold, bank_full.
func can_buy(item_id: StringName, qty: int) -> CommandResult:
	if qty <= 0:
		return CommandResult.fail(Reasons.INVALID_AMOUNT)
	if not _data.has_item(item_id):
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	if not _pricing.is_buyable(item_id):
		return CommandResult.fail(Reasons.NOT_TRADABLE)
	if level() < _pricing.buy_level(item_id):
		return CommandResult.fail(Reasons.REQUIREMENT_NOT_MET)
	if _pricing.stock(item_id) < qty:
		return CommandResult.fail(Reasons.OUT_OF_STOCK)
	if _wallet.get_gold() < _pricing.buy_quote(item_id, qty):
		return CommandResult.fail(Reasons.NOT_ENOUGH_GOLD)
	if not _bank.can_add(item_id):
		return CommandResult.fail(Reasons.BANK_FULL)
	return CommandResult.success()


## Buys `qty` pieces: pays, then puts them in the Deposit (the gold goes back if that could ever fail).
func buy(item_id: StringName, qty: int) -> CommandResult:
	var check: CommandResult = can_buy(item_id, qty)
	if not check.ok:
		return check
	var gold: int = _pricing.buy_quote(item_id, qty)
	var paid: CommandResult = _wallet.spend(gold)
	if not paid.ok:
		return paid
	var added: CommandResult = _bank.add(item_id, qty)
	if not added.ok:
		push_error("AuctionHouse.buy: the Deposit refused %s after can_buy (%s)" % [item_id, added.reason])
		_wallet.add_gold(gold)
		return added
	_pricing.record_purchase(item_id, qty)
	_events.auction_bought.emit(item_id, qty, gold)
	return CommandResult.success()


## F-145: advances the market clock; `auction_updated(blocks)` if at least one block passed.
func advance(delta_ms: int) -> void:
	var blocks: int = _pricing.advance(delta_ms)
	if blocks > 0:
		_events.auction_updated.emit(blocks)


## A new market with the seed taken from the slot's generator (without consuming a roll).
func new_game() -> void:
	_pricing.reset(_new_seed())


func to_save() -> Dictionary:
	return _pricing.to_save()


## Tolerant load (§5.30): a missing or invalid seed becomes a new one, the rest is corrected by AuctionPricing.
func from_save(d: Dictionary) -> void:
	var seed_raw: Variant = d.get("seed")
	var valid: bool = (seed_raw is int and (seed_raw as int) > 0) \
			or (seed_raw is float and is_finite(seed_raw as float) and (seed_raw as float) == floorf(seed_raw as float) and (seed_raw as float) > 0.0)
	if valid:
		_pricing.from_save(d)
		return
	Log.warn(LOG_CATEGORY, "invalid seed %s: a new one is used" % str(seed_raw))
	var fixed: Dictionary = d.duplicate()
	fixed["seed"] = _new_seed()
	_pricing.from_save(fixed)


func _new_seed() -> int:
	return posmod(_rng.seed_value(), SEED_MODULUS) + 1
