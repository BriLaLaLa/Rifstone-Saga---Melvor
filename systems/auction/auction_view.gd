class_name AuctionView
extends RefCounted
## What the Auction House page reads (docs/02_FORMULAS_M27.md F-181, docs/05_INTERFACES_M27.md §5.39): the book, the population summary
## and the player's listings, put together from AuctionPricing and AuctionListings. No state, no formula of its own; used by AuctionHouse.


## `{"buyers", "sellers", "demand", "listings", "units"}`: the market plus the player's listings of the item; `{}` if not listed.
static func population(pricing: AuctionPricing, listings: AuctionListings, item_id: StringName) -> Dictionary:
	var result: Dictionary = pricing.population(item_id)
	if result.is_empty():
		return result
	var count: int = 0
	var units: int = 0
	for ask: Vector2i in pricing.npc_asks(item_id):
		count += 1
		units += ask.y
	for mine: Dictionary in listings.of_item(item_id):
		count += 1
		units += int(mine["qty"])
	result["listings"] = count
	result["units"] = units
	return result


## `[{"price", "qty", "mine": bool, "listing": int (0 for an NPC)}]` by price; at equal price the NPC rows come first (then `j`, then the id).
static func book(pricing: AuctionPricing, listings: AuctionListings, item_id: StringName) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for ask: Vector2i in pricing.npc_asks(item_id):
		rows.append({"price": ask.x, "qty": ask.y, "mine": false, "listing": 0})
	for mine: Dictionary in listings.of_item(item_id):
		rows.append({"price": mine["price"], "qty": mine["qty"], "mine": true, "listing": mine["id"]})
	var result: Array[Dictionary] = []
	for row: Dictionary in rows:  # stable insertion: both sources are already in order
		var at: int = result.size()
		while at > 0 and int((result[at - 1] as Dictionary)["price"]) > int(row["price"]):
			at -= 1
		result.insert(at, row)
	return result


## The active listings by id with `ends_in_ms` and the forecast at the current block: `selling` if the demand reaches them, else `undercut`.
static func my_listings(pricing: AuctionPricing, listings: AuctionListings, block_ms: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for listing: Dictionary in listings.all():
		var item_id: StringName = listing["item"]
		var open: int = pricing.demand(item_id) - listings.ahead_of(int(listing["id"]), pricing.npc_asks(item_id))
		listing["ends_in_ms"] = (int(listing["end"]) - pricing.block()) * block_ms - pricing.pending_ms()
		listing["status"] = &"selling" if open > 0 else &"undercut"
		listing.erase("start")
		listing.erase("end")
		result.append(listing)
	return result


## F-210: `round(100 * (unit - value) / value)` (half away from zero) in integer maths; `AuctionHouse.NO_GAP` if `value` or `unit` is 0 or less.
@warning_ignore("integer_division")
static func gap_pct(unit: int, value: int) -> int:
	if value <= 0 or unit <= 0:
		return AuctionHouse.NO_GAP
	var diff: int = 100 * (unit - value)
	var magnitude: int = (2 * absi(diff) + value) / (2 * value)
	return magnitude if diff >= 0 else -magnitude


## F-211 without the Deposit constraint: `min(stock, floor(gold / unit))`, 0 if `unit` is 0 or less.
@warning_ignore("integer_division")
static func max_buy(unit: int, stock: int, gold: int) -> int:
	if unit <= 0:
		return 0
	return maxi(0, mini(stock, gold / unit))


## F-213: `{"count", "units", "expected_net"}`; `quote` is `Callable(qty, price) -> int` (the net of one listing, F-180).
static func summary(listings: Array[Dictionary], quote: Callable) -> Dictionary:
	var units: int = 0
	var net: int = 0
	for listing: Dictionary in listings:
		units += int(listing["qty"])
		net += int(quote.call(int(listing["qty"]), int(listing["price"])))
	return {"count": listings.size(), "units": units, "expected_net": net}
