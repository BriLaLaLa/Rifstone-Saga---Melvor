extends RefCounted
## Checks (6)-(9) of `tools/sim_market.gd` (M27-09, docs/02_FORMULAS_M27.md F-182): the NPC book, the player's listings and the Mail.
## Pure model on AuctionPricing + AuctionListings (the same engine as AuctionHouse, whose `advance` is mirrored by `advance_market`).
## Money is copper. The Mail is modelled as "collected at once": a message waiting in the Mail is money already earned, so a
## strategy that never collects can only look worse (the sum counts the same).

const ONE: int = 1_000_000
const START: int = 1_000_000_000
const HOUR_MS: int = 3_600_000
const HORIZON_48H: int = 48 * HOUR_MS
const RATIO_MIN: float = 0.85
const RATIO_MAX: float = 1.40
const RAW_SKILLS: Array[StringName] = [&"forestry", &"quarrying", &"angling"]


## Mirror of `AuctionHouse.advance` (F-184). Returns the net money of the sold pieces and gives back the pieces of expired
## listings through `ledger["returned"]` (item -> qty). `ledger["sold"]` = pieces sold, `ledger["net"]` = copper.
static func advance_market(pricing: AuctionPricing, listings: AuctionListings, delta_ms: int, ledger: Dictionary) -> void:
	var left: int = maxi(0, delta_ms)
	while left > 0:
		if listings.count() == 0:
			pricing.advance(left)
			return
		var step: int = mini(left, pricing.ms_to_next_block())
		left -= step
		if pricing.advance(step) > 0:
			for e: Dictionary in listings.process_block(pricing, pricing.block()):
				match e["kind"]:
					&"sold":
						ledger["sold"] = int(ledger.get("sold", 0)) + int(e["qty"])
						ledger["net"] = int(ledger.get("net", 0)) + int(e["net"])
						ledger["sold_blocks"] = int(ledger.get("sold_blocks", 0)) + int(e["qty"]) * (pricing.block() - int(ledger.get("start", 0)))
					&"expired":
						ledger["returned"] = int(ledger.get("returned", 0)) + int(e["qty"])


## Runs (6)-(9), prints the results and returns the failures.
static func run(data: GameData, opts: Dictionary) -> Array:
	var failures: Array = []
	var seed_value: int = int(opts["seed"])
	print_rich("== (6) NPC asks against the F-182 ceiling and the counter, %d states per listed item" % opts["book_states"])
	var a: Dictionary = check_asks(data, int(opts["book_states"]), seed_value)
	failures.append_array(a["failures"] as Array)
	if not bool(a["static_ok"]):
		failures.append("(6) F-217 EQMIN * (PPM + MK) > MAX * (PPM + HI) * (PPM - CUT) does not hold")
	print_rich("asks %d, max ask/ceiling %.4f, max ask/unit %.4f, non-arbitrage constraint holds: %s" % [
		a["asks"], a["max_over_ceiling"], a["max_over_unit"], a["static_ok"]])
	print_rich("== (7) %d random strategies per buyable item over 48 h (counter, listings, Mail, Deposit)" % opts["book_strategies"])
	var s: Dictionary = check_strategies(data, int(opts["book_strategies"]), seed_value)
	failures.append_array(s["failures"] as Array)
	print_rich("strategies %d per item, steps %d, listings created %d, pieces sold by listings %d; best net result %.2f copper (must be <= 0)" % [
		s["runs"], s["ops"], s["listings"], s["sold"], s["best_net"]])
	print_rich("== (8) 1 h of raw production listed at the suggested price for 12 h, %d market states per item" % opts["prod_states"])
	var pr: Dictionary = check_production(data, seed_value, int(opts["prod_states"]))
	failures.append_array(pr["failures"] as Array)
	print_rich(pr["text"])
	print_rich("== (9) equivalence with 3 listings: one step = 100 ms = 60 s = 6 h + save/load + 6 h")
	var e: Dictionary = check_equivalence(data, seed_value)
	failures.append_array(e["failures"] as Array)
	print_rich("identical in all four runs: %s; net %d copper, %d pieces sold, %d returned" % [(e["failures"] as Array).is_empty(), e["net"], e["sold"], e["returned"]])
	return failures


static func new_pricing(data: GameData, seed_value: int) -> AuctionPricing:
	var pricing := AuctionPricing.new(data)
	pricing.reset(seed_value)
	return pricing


## (6) Every NPC ask is at most the F-182 ceiling `v*MAX*(PPM+HI)/PPM^2` and, if buyable, below the counter's `unit`.
static func check_asks(data: GameData, states: int, seed_value: int) -> Dictionary:
	var p: AuctionParams = data.auction_params()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 6
	var failures: Array = []
	var worst_over_ceiling: float = 0.0
	var worst_over_unit: float = 0.0
	var count: int = 0
	for def: AuctionItemDef in data.auction_items():
		var v: int = data.item(def.item).value
		var ceiling: float = float(v) * p.max_ppm / ONE * (ONE + p.book_hi_ppm) / ONE
		for _i: int in states:
			var pricing: AuctionPricing = new_pricing(data, rng.randi_range(1, 2147483646))
			pricing.advance(rng.randi_range(0, 2000) * p.block_ms)
			pricing.record_sale(def.item, rng.randi_range(0, p.cap_ppm / p.step_ppm + 5))
			var unit: int = pricing.buy_unit(def.item) if def.buy_level >= 1 else 0
			for ask: Vector2i in pricing.npc_asks(def.item):
				count += 1
				worst_over_ceiling = maxf(worst_over_ceiling, float(ask.x) / ceiling)
				if def.buy_level >= 1:
					worst_over_unit = maxf(worst_over_unit, float(ask.x) / float(unit))
				if float(ask.x) > ceiling + 1.0 or (def.buy_level >= 1 and ask.x >= unit):
					if failures.size() < 6:
						failures.append("(6) %s: ask %d, ceiling %.1f, unit %d" % [def.item, ask.x, ceiling, unit])
	return {"failures": failures, "asks": count, "max_over_ceiling": worst_over_ceiling, "max_over_unit": worst_over_unit,
			"static_ok": AuctionMath.eq_min(p, p.bands) * (ONE + p.markup_ppm) > p.max_ppm * (ONE + p.book_hi_ppm) * (ONE - p.listing_cut_ppm) / ONE}


## (7) Random strategies over 48 h: buy at the counter, list at random prices, cancel, sell at once, wait, use the Deposit.
## Final money + pieces left (in the bag or in an active listing or returned) valued at v*MAX must not exceed the start.
static func check_strategies(data: GameData, runs: int, seed_value: int) -> Dictionary:
	var p: AuctionParams = data.auction_params()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 7
	var failures: Array = []
	var best: float = -INF
	var ops: int = 0
	var listed_count: int = 0
	var sold_pieces: int = 0
	for def: AuctionItemDef in data.auction_items():
		if def.buy_level < 1:
			continue
		var v: int = data.item(def.item).value
		var ceiling: int = v * p.max_ppm
		for i: int in runs:
			var r: Dictionary = _one_strategy(data, p, def.item, v, i % 2 == 1, rng)
			ops += int(r["ops"])
			listed_count += int(r["listed"])
			sold_pieces += int(r["sold"])
			var net: float = float(r["net"]) / ONE
			if net > best:
				best = net
			if net > 0.0 and failures.size() < 6:
				failures.append("(7) %s: strategy %d ends %.2f copper above its start (ceiling %d)" % [def.item, i, net, ceiling])
	return {"failures": failures, "runs": runs, "ops": ops, "best_net": best, "listings": listed_count, "sold": sold_pieces}


static func _one_strategy(data: GameData, p: AuctionParams, id: StringName, v: int, with_pile: bool, rng: RandomNumberGenerator) -> Dictionary:
	var ceiling: int = v * p.max_ppm
	var pile: int = rng.randi_range(1, 3000) if with_pile else 0
	var pricing: AuctionPricing = new_pricing(data, rng.randi_range(1, 2147483646))
	pricing.advance(rng.randi_range(0, 300) * p.block_ms)
	var listings := AuctionListings.new(p)
	var ledger: Dictionary = {}
	var money: int = START
	var held: int = pile
	var left_ms: int = HORIZON_48H
	var steps: int = 0
	var listed: int = 0
	while left_ms > 0 and steps < 40:
		steps += 1
		var action: int = rng.randi_range(0, 7)
		if action == 0 and pricing.available(id) > 0:
			var q: int = 1 + int(pow(rng.randf(), 3.0) * float(pricing.available(id) - 1))
			money -= pricing.buy_quote(id, q)
			held += q
			pricing.record_purchase(id, q)
		elif action == 1 and held > 0:
			var q: int = 1 + int(pow(rng.randf(), 2.0) * float(held - 1))
			money += pricing.sell_quote(id, q)
			held -= q
			pricing.record_sale(id, q)
		elif action == 2 and held > 0:
			var q: int = rng.randi_range(1, held)
			money += q * v
			held -= q
		elif (action == 3 or action == 4) and held > 0 and listings.count() < p.listing_max_active:
			var q: int = rng.randi_range(1, held)
			var duration: AuctionDuration = p.durations[rng.randi_range(0, p.durations.size() - 1)]
			var cap: int = pricing.max_price(id)
			var asks: Array[Vector2i] = pricing.npc_asks(id)
			var price: int = rng.randi_range(1, cap) if rng.randi_range(0, 2) == 0 or asks.is_empty() else clampi(asks[0].x + rng.randi_range(-3, 3), 1, cap)
			var cost: int = pricing.deposit(id, q, duration)
			money -= cost
			held -= q
			listings.add(id, q, price, duration, pricing.block())
			listed += 1
		elif action == 5 and listings.count() > 0:
			var all: Array[Dictionary] = listings.all()
			var gone: Dictionary = listings.remove(int(all[rng.randi_range(0, all.size() - 1)]["id"]))
			held += int(gone["qty"])
		else:
			var wait: int = mini(left_ms, rng.randi_range(0, 8) * p.block_ms * (1 if action != 7 else 15) + rng.randi_range(0, p.block_ms))
			left_ms -= wait
			advance_market(pricing, listings, wait, ledger)
			money += int(ledger.get("net", 0))
			ledger["net"] = 0
			held += int(ledger.get("returned", 0))
			ledger["returned"] = 0
	var in_listings: int = 0
	for l: Dictionary in listings.all():
		in_listings += int(l["qty"])
	var total: float = float(money) * ONE + float(held + in_listings) * ceiling
	var net: float = total - float(START) * ONE - float(pile) * ceiling
	return {"net": net, "ops": steps, "listed": listed, "sold": int(ledger.get("sold", 0))}


## (8) 1 h of production of every raw item T1-T8 listed at the suggested price (and at +10%) for 12 h, in several market states.
## Ratio = (net of the commission, minus the deposit) / F-18 (`v * q`); pieces unsold return in the Mail and are not counted.
static func check_production(data: GameData, seed_value: int, states: int) -> Dictionary:
	var p: AuctionParams = data.auction_params()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 8
	var made: Dictionary = {}
	for skill: SkillDef in data.skills():
		if not RAW_SKILLS.has(skill.id):
			continue
		for action: ActionDef in data.actions_for_skill(skill.id):
			for out: ItemQty in action.outputs:
				if action.interval_ms > 0 and action.inputs.is_empty() and not made.has(out.item_id):
					made[out.item_id] = HOUR_MS / action.interval_ms * out.qty
	var failures: Array = []
	var duration: AuctionDuration = p.durations[0]  # 12 h
	var lo: float = INF
	var hi: float = -INF
	var full_lo: float = INF
	var full_hi: float = -INF
	var partial: int = 0
	var total_states: int = 0
	var per_band: Dictionary = {}  # band index -> [sold_sug, total_sug, wsum_sug, sold_hi, total_hi, wsum_hi]
	var lines: Array[String] = []
	for item_id: StringName in made:
		var def: AuctionItemDef = data.auction_item(item_id)
		if def == null:
			continue
		var v: int = data.item(item_id).value
		var q: int = int(made[item_id])
		var band: int = p.bands.find(AuctionMath.band_of(v, p))
		var item_lo: float = INF
		var item_hi: float = -INF
		var sold_frac: float = 0.0
		for s: int in states:
			var seed_i: int = rng.randi_range(1, 2147483646)
			var start_block: int = rng.randi_range(0, 3000)
			for mode: int in 2:
				var pricing: AuctionPricing = new_pricing(data, seed_i)
				pricing.advance(start_block * p.block_ms)
				var asks: Array[Vector2i] = pricing.npc_asks(item_id)
				var suggested: int = maxi(1, (asks[0].x if not asks.is_empty() else pricing.sell_quote(item_id, 1)) - 1)
				var price: int = suggested if mode == 0 else int(ceil(float(suggested) * 1.1))
				var listings := AuctionListings.new(p)
				var ledger: Dictionary = {"start": pricing.block()}
				listings.add(item_id, q, price, duration, pricing.block())
				var deposit: int = pricing.deposit(item_id, q, duration)
				advance_market(pricing, listings, 12 * HOUR_MS, ledger)
				var ratio: float = float(int(ledger.get("net", 0)) - deposit) / float(v * q)
				var sold: int = int(ledger.get("sold", 0))
				var row: Array = per_band.get(band, [0, 0, 0, 0, 0, 0])
				row[mode * 3] += sold
				row[mode * 3 + 1] += q
				row[mode * 3 + 2] += int(ledger.get("sold_blocks", 0))
				per_band[band] = row
				if mode == 0:
					item_lo = minf(item_lo, ratio)
					item_hi = maxf(item_hi, ratio)
					sold_frac += float(sold) / float(q) / float(states)
					lo = minf(lo, ratio)
					total_states += 1
					if float(sold) < 0.95 * float(q):
						partial += 1
					else:
						full_lo = minf(full_lo, ratio)
						full_hi = maxf(full_hi, ratio)
					hi = maxf(hi, ratio)
		lines.append("%s: %d/h, suggested ratio %.3f - %.3f, sold %.0f%%" % [item_id, q, item_lo, item_hi, sold_frac * 100.0])
	# Q164 (decided at M27-10): the threshold applies to the states sold at least 95% in 12 h; a partial sale (the suggested
	# price taken at a market top that then falls) is informative only, the unsold pieces come back by Mail.
	if full_lo < RATIO_MIN or full_hi > RATIO_MAX:
		failures.append("(8) ratio against F-18 among the states sold >= 95%% %.3f - %.3f outside %.2f - %.2f (no tuning: numbers to the Reviewer, Q164)" % [full_lo, full_hi, RATIO_MIN, RATIO_MAX])
	var text: String = "\n".join(lines) + "\nratio among the states sold >= 95%% %.3f - %.3f (threshold %.2f - %.2f); all states %.3f - %.3f (informative, Q164); states with less than 95%% sold in 12 h: %d of %d" % [full_lo, full_hi, RATIO_MIN, RATIO_MAX, lo, hi, partial, total_states]
	for band: int in per_band:
		var row: Array = per_band[band]
		text += "\nband %d: at the suggested price sold %.0f%%, mean sale time %.1f h; at +10%% sold %.0f%%, mean sale time %.1f h" % [
			band + 1, 100.0 * row[0] / maxf(1.0, row[1]), float(row[2]) * p.block_ms / HOUR_MS / maxf(1.0, row[0]),
			100.0 * row[3] / maxf(1.0, row[4]), float(row[5]) * p.block_ms / HOUR_MS / maxf(1.0, row[3])]
	return {"failures": failures, "text": text, "min": lo, "max": hi}


## (9) F-184: three listings (one sells out, one sells in pieces, one expires) and a sale at once; 12 h in one step = 100 ms = 60 s
## = 6 h + save/load + 6 h: the market, the listings and the money are identical.
static func check_equivalence(data: GameData, seed_value: int) -> Dictionary:
	var p: AuctionParams = data.auction_params()
	var states: Array[Dictionary] = []
	for mode: int in 4:
		var pricing: AuctionPricing = new_pricing(data, seed_value)
		var listings := AuctionListings.new(p)
		var ledger: Dictionary = {"start": 0}
		pricing.advance(120_000)
		listings.add(&"redbirch_grip", 600, 250, p.durations[0], pricing.block())
		listings.add(&"redbirch_grip", 300, 270, p.durations[0], pricing.block())
		listings.add(&"riftite_plate", 10, 75_000, p.durations[2], pricing.block())
		pricing.record_sale(&"ashlead_plate", 50)
		var total: int = 12 * HOUR_MS
		if mode == 0:
			advance_market(pricing, listings, total, ledger)
		elif mode == 1:
			for _i: int in total / 100:
				advance_market(pricing, listings, 100, ledger)
		elif mode == 2:
			for _i: int in total / 60_000:
				advance_market(pricing, listings, 60_000, ledger)
		else:
			advance_market(pricing, listings, total / 2, ledger)
			var saved_p: Dictionary = JSON.parse_string(JSON.stringify(pricing.to_save())) as Dictionary
			var saved_l: Dictionary = JSON.parse_string(JSON.stringify(listings.to_save())) as Dictionary
			pricing = new_pricing(data, 1)
			pricing.from_save(saved_p)
			listings = AuctionListings.new(p)
			listings.from_save(saved_l)
			advance_market(pricing, listings, total / 2, ledger)
		var snap: Dictionary = {"pricing": JSON.stringify(pricing.to_save()), "listings": JSON.stringify(listings.to_save())}
		snap["net"] = int(ledger.get("net", 0))
		snap["sold"] = int(ledger.get("sold", 0))
		snap["returned"] = int(ledger.get("returned", 0))
		states.append(snap)
	var failures: Array = []
	for k: int in range(1, 4):
		if states[k] != states[0]:
			failures.append("(9) the state after 12 h differs between the one-step run and run %d" % k)
	return {"failures": failures, "net": states[0]["net"], "sold": states[0]["sold"], "returned": states[0]["returned"]}
