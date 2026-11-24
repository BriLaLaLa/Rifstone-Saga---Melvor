extends RefCounted
## Checks (10) and (11) of `tools/sim_market.gd` (M38-5, docs/02_FORMULAS_M38.md F-217): buying the whole book of an item and the
## pace of the supply. Pure model on AuctionPricing + AuctionListings, like `sim_market_book.gd` (whose `advance_market` is reused).

const ONE: int = 1_000_000
const HOUR_MS: int = 3_600_000
const SHARE_MAX: float = 0.95  # (10) net revenue of the resale <= 0.95 * the cost of the purchase
## M23 reference of (11): `S + 144 * r(S)` of docs/02_FORMULAS.md F-150 (its examples; stock cap and rate of M23, long gone from the data).
const M23_REFERENCE: Dictionary = {&"redbirch_grip": 500 + 144 * 7, &"riftite_plate": 10 + 144 * 1, &"seared_riftmaw": 35 + 144 * 1, &"shardcedar_grip": 166 + 144 * 2}


## Runs (10) and (11), prints the results and returns the failures.
static func run(data: GameData, opts: Dictionary) -> Array:
	var failures: Array = []
	print_rich("== (10) buy the whole book and resell it at the suggested price for 12 h, %d states per buyable item" % opts["buyall_states"])
	var a: Dictionary = check_buy_all(data, int(opts["seed"]), int(opts["buyall_states"]))
	failures.append_array(a["failures"] as Array)
	print_rich(a["text"])
	print_rich("== (11) supply pace: pieces buyable in 12 h = V + 144 * r_i, per band (M23: S + 144 * r(S))")
	print_rich(check_pace(data, int(opts["seed"])))
	return failures


static func _pricing(data: GameData, seed_value: int, block: int) -> AuctionPricing:
	var pricing := AuctionPricing.new(data)
	pricing.reset(seed_value)
	pricing.advance(block * data.auction_params().block_ms)
	return pricing


## (10) From rest (`taken` 0, `sat` 0): buy all `V` pieces, list them all at the suggested price (one under the cheapest NPC ask) for
## 12 h, one listing without the stack limit (generous to the player). Net = the money of the sales - the deposit. Threshold: net <= 0.95 * cost.
static func check_buy_all(data: GameData, seed_value: int, states: int) -> Dictionary:
	var p: AuctionParams = data.auction_params()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 10
	var failures: Array = []
	var per_band: Dictionary = {}  # band index -> {share_max, premium_max, hours_max, sold_min, sold_max}
	var worst: float = -INF
	var worst_id: StringName = &""
	for def: AuctionItemDef in data.auction_items():
		if def.buy_level < 1:
			continue
		var v: int = data.item(def.item).value
		var band: AuctionPopulationBand = AuctionMath.band_of(v, p)
		var k: int = p.bands.find(band)
		var rate: int = AuctionMath.restock_rate(band, p)
		var row: Dictionary = per_band.get(k, {"share": -INF, "premium": -INF, "hours": 0.0, "sold_min": INF, "sold_max": -INF, "n": 0})
		for _i: int in states:
			var pricing: AuctionPricing = _pricing(data, rng.randi_range(1, 2147483646), rng.randi_range(0, 3000))
			var volume: int = pricing.volume(def.item)
			var cost: int = pricing.buy_quote(def.item, volume)
			if volume <= 0 or cost <= 0:
				failures.append("(10) %s: volume %d, cost %d" % [def.item, volume, cost])
				continue
			var best: int = pricing.buy_unit(def.item)
			pricing.record_purchase(def.item, volume)
			var recover_h: float = float(AuctionMath.ceil_div(pricing.taken(def.item), rate) * p.block_ms) / HOUR_MS
			var asks: Array[Vector2i] = pricing.npc_asks(def.item)
			var price: int = maxi(1, (asks[0].x if not asks.is_empty() else pricing.sell_quote(def.item, 1)) - 1)
			var listings := AuctionListings.new(p)
			var ledger: Dictionary = {"start": pricing.block()}
			listings.add(def.item, volume, price, p.durations[0], pricing.block())
			var deposit: int = pricing.deposit(def.item, volume, p.durations[0])
			(load("res://tools/sim_market_book.gd") as GDScript).call("advance_market", pricing, listings, 12 * HOUR_MS, ledger)
			var net: int = int(ledger.get("net", 0)) - deposit
			var share: float = float(net) / float(cost)
			row["share"] = maxf(float(row["share"]), share)
			row["premium"] = maxf(float(row["premium"]), float(cost) / float(volume) / float(best) - 1.0)
			row["hours"] = maxf(float(row["hours"]), recover_h)
			var sold: float = float(ledger.get("sold", 0)) / float(volume)
			row["sold_min"] = minf(float(row["sold_min"]), sold)
			row["sold_max"] = maxf(float(row["sold_max"]), sold)
			row["n"] = int(row["n"]) + 1
			if share > worst:
				worst = share
				worst_id = def.item
			if share > SHARE_MAX and failures.size() < 6:
				failures.append("(10) %s: buying all %d pieces costs %d, the resale nets %d (%.3f of the cost, threshold %.2f)" % [
						def.item, volume, cost, net, share, SHARE_MAX])
		per_band[k] = row
	var lines: Array[String] = []
	for k: int in per_band:
		var r: Dictionary = per_band[k]
		lines.append("band %d (%d runs): worst net/cost %.3f; average price up to +%.1f%% on the best piece; taken needs up to %.1f h to recover; sold %.0f%%-%.0f%% in 12 h" % [
				k + 1, r["n"], r["share"], 100.0 * float(r["premium"]), r["hours"], 100.0 * float(r["sold_min"]), 100.0 * float(r["sold_max"])])
	return {"failures": failures, "text": "\n".join(lines) + "\nworst over all bands: %.3f (%s), threshold %.2f" % [worst, worst_id, SHARE_MAX]}


## (11) No threshold: `V + 144 * r_i` per band (V from the books of several epochs at rest) against the M23 reference of the four examples.
static func check_pace(data: GameData, seed_value: int) -> String:
	var p: AuctionParams = data.auction_params()
	var blocks: int = 12 * HOUR_MS / p.block_ms
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 11
	var per_band: Dictionary = {}
	var refs: Array[String] = []
	for def: AuctionItemDef in data.auction_items():
		if def.buy_level < 1:
			continue
		var band: AuctionPopulationBand = AuctionMath.band_of(data.item(def.item).value, p)
		var k: int = p.bands.find(band)
		var rate: int = AuctionMath.restock_rate(band, p)
		var low: int = 1 << 30
		var high: int = 0
		for _i: int in 20:
			var volume: int = _pricing(data, rng.randi_range(1, 2147483646), rng.randi_range(0, 3000)).volume(def.item)
			low = mini(low, volume)
			high = maxi(high, volume)
		var row: Dictionary = per_band.get(k, {"lo": 1 << 30, "hi": 0, "r": rate, "items": 0})
		row["lo"] = mini(int(row["lo"]), low + blocks * rate)
		row["hi"] = maxi(int(row["hi"]), high + blocks * rate)
		row["items"] = int(row["items"]) + 1
		per_band[k] = row
		if M23_REFERENCE.has(def.item):
			refs.append("%s: M38 %d-%d, M23 %d" % [def.item, low + blocks * rate, high + blocks * rate, M23_REFERENCE[def.item]])
	var lines: Array[String] = []
	for k: int in per_band:
		var r: Dictionary = per_band[k]
		lines.append("band %d: r_i %d per block, V + %d * r_i = %d - %d pieces in 12 h (%d items)" % [k + 1, r["r"], blocks, r["lo"], r["hi"], r["items"]])
	return "\n".join(lines) + "\nagainst M23 (S + 144 * r(S)): " + "; ".join(refs)
