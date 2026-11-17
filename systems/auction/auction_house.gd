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
var _listings: AuctionListings
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
	_listings = AuctionListings.new(_data.auction_params())
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
func durations() -> Array[AuctionDuration]: return _data.auction_params().durations.duplicate()
func max_price(item_id: StringName) -> int: return _pricing.max_price(item_id)
func max_listings() -> int: return _data.auction_params().listing_max_active
func market_price(item_id: StringName) -> int: return _pricing.sell_quote(item_id, 1)  # F-181


## F-181: the market and the player's listings of the item: `{"buyers", "sellers", "demand", "listings", "units"}`; `{}` if not listed.
func population(item_id: StringName) -> Dictionary:
	return AuctionView.population(_pricing, _listings, item_id)


## F-181: one copper under the cheapest NPC listing (at least 1); 0 if the item is not listed.
func suggested_price(item_id: StringName) -> int:
	var asks: Array[Vector2i] = _pricing.npc_asks(item_id)
	return maxi(1, asks[0].x - 1) if not asks.is_empty() else 0


## F-181: the NPC listings and the player's, by price (at equal price: NPC first, then `j`, then the id of the listing).
## `[{"price", "qty", "mine": bool, "listing": int (0 for an NPC)}]`.
func book(item_id: StringName) -> Array[Dictionary]:
	return AuctionView.book(_pricing, _listings, item_id)


## F-180: the deposit of a listing (0 for an unknown duration).
func listing_deposit(item_id: StringName, qty: int, duration_id: StringName) -> int:
	var duration: AuctionDuration = _duration(duration_id)
	return _pricing.deposit(item_id, qty, duration) if duration != null else 0


## F-180: what the listing gives if everything sells, before the deposit: `qty * price` minus the commission.
func listing_net(_item_id: StringName, qty: int, price: int) -> int:
	return _pricing.listing_net(qty, price)


## F-181: the active listings by id, with the time left and the forecast at the current block (`selling` or `undercut`).
func my_listings() -> Array[Dictionary]:
	return AuctionView.my_listings(_pricing, _listings, _data.auction_params().block_ms)


## Checks in order: invalid_amount, unknown_id (item or duration), not_tradable, requirement_not_met, item_locked, not_enough_items,
## invalid_price, listings_full, mailbox_full, not_enough_gold (the deposit).
func can_list(item_id: StringName, qty: int, price: int, duration_id: StringName) -> CommandResult:
	if qty <= 0:
		return CommandResult.fail(Reasons.INVALID_AMOUNT)
	var duration: AuctionDuration = _duration(duration_id)
	if not _data.has_item(item_id) or duration == null:
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	if not _pricing.is_listed(item_id):
		return CommandResult.fail(Reasons.NOT_TRADABLE)
	if not is_open():
		return CommandResult.fail(Reasons.REQUIREMENT_NOT_MET)
	if _bank.is_locked(item_id):
		return CommandResult.fail(Reasons.ITEM_LOCKED)
	if not _bank.has(item_id, qty):
		return CommandResult.fail(Reasons.NOT_ENOUGH_ITEMS)
	if price < 1 or price > _pricing.max_price(item_id):
		return CommandResult.fail(Reasons.INVALID_PRICE)
	if _listings.count() >= max_listings():
		return CommandResult.fail(Reasons.LISTINGS_FULL)
	if _session.mail.is_full():
		return CommandResult.fail(Reasons.MAILBOX_FULL)
	if _wallet.get_gold() < _pricing.deposit(item_id, qty, duration):
		return CommandResult.fail(Reasons.NOT_ENOUGH_GOLD)
	return CommandResult.success()


## Puts `qty` pieces up for sale: they leave the Deposit, the deposit money is spent, the listing starts at the current block.
func list_item(item_id: StringName, qty: int, price: int, duration_id: StringName) -> CommandResult:
	var check: CommandResult = can_list(item_id, qty, price, duration_id)
	if not check.ok:
		return check
	var duration: AuctionDuration = _duration(duration_id)
	var removed: CommandResult = _bank.remove(item_id, qty)
	if not removed.ok:
		return removed
	var paid: CommandResult = _wallet.spend(_pricing.deposit(item_id, qty, duration))
	if not paid.ok:
		push_error("AuctionHouse.list_item: the wallet refused the deposit after can_list (%s)" % paid.reason)
		_bank.add(item_id, qty)
		return paid
	_listings.add(item_id, qty, price, duration, _pricing.block())
	_events.auction_listings_changed.emit()
	return CommandResult.success()


## `unknown_id` if there is no such active listing.
func can_cancel(listing_id: int) -> CommandResult:
	return CommandResult.success() if not _listings.get_listing(listing_id).is_empty() else CommandResult.fail(Reasons.UNKNOWN_ID)


## The pieces left go to the Mail (`auction_cancelled`); the deposit is lost, the sales already made stay.
func cancel_listing(listing_id: int) -> CommandResult:
	var check: CommandResult = can_cancel(listing_id)
	if not check.ok:
		return check
	var listing: Dictionary = _listings.remove(listing_id)
	var item_id: StringName = listing["item"]
	_session.mail.post(&"auction_cancelled", {"item": item_id, "qty": listing["qty"], "price": listing["price"], "listing": listing_id,
			"items": [{"item": item_id, "qty": listing["qty"]}]})
	_events.auction_listings_changed.emit()
	return CommandResult.success()


## Checks in order: invalid_amount, unknown_id, not_tradable, requirement_not_met (not built), item_locked, not_enough_items,
## not_sellable (the sale would give 0 money), mailbox_full (the money goes to the Mail, F-183).
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
	if _session.mail.is_full():
		return CommandResult.fail(Reasons.MAILBOX_FULL)
	return CommandResult.success()


## Sells `qty` pieces at once: the money is computed before the saturation changes (the pieces of one sale lower each other's
## price) and goes to the Mail (`auction_sale`), not to the wallet; `auction_sold(item, qty, money)`.
@warning_ignore("integer_division")
func sell(item_id: StringName, qty: int) -> CommandResult:
	var check: CommandResult = can_sell(item_id, qty)
	if not check.ok:
		return check
	var gold: int = _pricing.sell_quote(item_id, qty)
	var removed: CommandResult = _bank.remove(item_id, qty)
	if not removed.ok:
		return removed
	_session.mail.post(&"auction_sale", {"item": item_id, "qty": qty, "price": gold / qty, "money": gold})
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


## F-145, F-184: advances the market clock; without active listings in one go, otherwise up to every block boundary, where the
## listings sell (F-180) and their Mail is delivered. `auction_updated(blocks)` if at least one block passed, then
## `auction_listings_changed` if a listing sold, closed or expired. Same result for `advance(a); advance(b)` and `advance(a + b)`.
func advance(delta_ms: int) -> void:
	var blocks: int = 0
	var changed: bool = false
	var left: int = maxi(0, delta_ms)
	while left > 0:
		if _listings.count() == 0:
			blocks += _pricing.advance(left)
			break
		var step: int = mini(left, _pricing.ms_to_next_block())
		left -= step
		if _pricing.advance(step) > 0:
			blocks += 1
			changed = _deliver(_listings.process_block(_pricing, _pricing.block())) or changed
	if blocks > 0:
		_events.auction_updated.emit(blocks)
	if changed:
		_events.auction_listings_changed.emit()


## A new market with the seed taken from the slot's generator (without consuming a roll).
func new_game() -> void:
	_pricing.reset(_new_seed())
	_listings.clear()


func to_save() -> Dictionary:
	var result: Dictionary = _pricing.to_save()
	result.merge(_listings.to_save())
	return result


## Tolerant load (§5.30): a missing or invalid seed becomes a new one, the rest is corrected by AuctionPricing and AuctionListings.
func from_save(d: Dictionary) -> void:
	_load_market(d)
	_listings.from_save(d)
	_listings.drop_if(func(item_id: StringName) -> bool: return not _pricing.is_listed(item_id))


func _load_market(d: Dictionary) -> void:
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


func _duration(duration_id: StringName) -> AuctionDuration:
	for duration: AuctionDuration in _data.auction_params().durations:
		if duration.id == duration_id:
			return duration
	return null


# F-180 steps 5 and 6: the Mail of the events of a block (sold: the net money; expired: the pieces back). True if there was any.
func _deliver(events: Array[Dictionary]) -> bool:
	for e: Dictionary in events:
		var item_id: StringName = e["item"]
		match e["kind"]:
			&"sold":
				_session.mail.post(&"auction_sold", {"item": item_id, "qty": e["qty"], "price": e["price"], "listing": e["id"], "money": e["net"]})
			&"expired":
				_session.mail.post(&"auction_expired", {"item": item_id, "qty": e["qty"], "listing": e["id"], "items": [{"item": item_id, "qty": e["qty"]}]})
	return not events.is_empty()
