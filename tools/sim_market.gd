extends SceneTree
## Balance and safety tool of the Auction House (M23-05, docs/02_FORMULAS.md §5k "Simulazione"). Read-only: nothing is written.
## Checks (1) unit price above any sale price, (2) random buy/sell/wait strategies never gain gold (also through the Deposit),
## (3) no buyable item is an action ingredient, the shop does not give listed items cheaper, blueprints keep their margin,
## (4) 12 h in one step = 100 ms ticks = 60 s blocks, (5) 1 h of production sold at once against F-18 (0.85-1.25).
##
## Usage: godot --headless --path . -s tools/sim_market.gd [-- states=<n per item> strategies=<n per item> seed=<n>]
## Exit code 1 if some threshold fails (the failures are printed with their numbers).

const ONE: int = 1_000_000
const START_GOLD: int = 1_000_000_000
const HOUR_MS: int = 3_600_000
const HORIZON_MS: int = 12 * HOUR_MS
const RATIO_MIN: float = 0.85
const RATIO_MAX: float = 1.25
const RAW_SKILLS: Array[StringName] = [&"forestry", &"quarrying", &"angling"]

var _fails: Array[String] = []


func _initialize() -> void:
	quit(run(OS.get_cmdline_user_args()))


static func parse_args(args: PackedStringArray) -> Dictionary:
	var opts: Dictionary = {"states": 1000, "strategies": 10000, "seed": 2305}
	for arg: String in args:
		var key: String = arg.get_slice("=", 0)
		if not opts.has(key) or not arg.get_slice("=", 1).is_valid_int():
			return {"error": "sim_market: bad argument '%s'" % arg}
		opts[key] = int(arg.get_slice("=", 1))
	return opts


func run(args: PackedStringArray) -> int:
	var opts: Dictionary = parse_args(args)
	if opts.has("error"):
		printerr(opts["error"])
		return 1
	var data: GameData = GameData.load_from_dirs("res://data", "res://data/config")
	if not data.is_valid():
		printerr("sim_market: invalid data: %s" % "\n".join(data.errors))
		return 1
	_fails.clear()
	var started: int = Time.get_ticks_msec()
	print_rich("== (1) unit price against sale price, %d random states per buyable item" % opts["states"])
	print_rich(check_unit_prices(data, int(opts["states"]), int(opts["seed"])))
	print_rich("== (2) %d random strategies per buyable item over 12 h" % opts["strategies"])
	print_rich(check_strategies(data, int(opts["strategies"]), int(opts["seed"])))
	print_rich("== (3) transformations")
	print_rich(check_transformations(data))
	print_rich("== (4) the clock: one step = 100 ms ticks = 60 s blocks")
	print_rich(check_clock(data, int(opts["seed"])))
	print_rich("== (5) 1 h of production sold at once against F-18")
	print_rich(check_production(data))
	print_rich("elapsed %.1f s" % (float(Time.get_ticks_msec() - started) / 1000.0))
	if _fails.is_empty():
		print_rich("sim_market: all thresholds respected")
		return 0
	for f: String in _fails:
		printerr("FAIL: " + f)
	return 1


## Each check returns its text; failures are collected in `failures` of the result of the static helpers below.
func check_unit_prices(data: GameData, states: int, seed_value: int) -> String:
	var r: Dictionary = unit_prices(data, states, seed_value)
	_fails.append_array(r["failures"] as Array)
	return "items %d, states %d, min unit/(v*MAX) = %.4f, min unit/v = %.4f, min unit/sale-of-one = %.4f" % [
		r["items"], r["states"], r["min_over_max"], r["min_over_value"], r["min_over_sale"]]


func check_strategies(data: GameData, n: int, seed_value: int) -> String:
	var r: Dictionary = strategies(data, n, seed_value)
	_fails.append_array(r["failures"] as Array)
	return ("items %d, strategies %d, operations %d; best net result of any strategy %.2f gold (must be <= 0), "
			+ "cheapest round trip (buy 1, sell 1 now) loses %.2f gold; saturate-and-rebuy best net %.2f gold") % [
		r["items"], r["runs"], r["ops"], r["best_net"], r["min_round_trip_loss"], r["best_saturate"]]


func check_transformations(data: GameData) -> String:
	var r: Dictionary = transformations(data)
	_fails.append_array(r["failures"] as Array)
	return "ingredient clashes %d, shop gifts of listed items %d, blueprints checked %d (with a buyable component %d), worst ratio %.3f (%s, margin %d%%)" % [
		r["clashes"], r["shop_gifts"], r["blueprints"], r["bp_buyable"], r["worst_ratio"], r["worst_id"], r["margin"]]


func check_clock(data: GameData, seed_value: int) -> String:
	var r: Dictionary = clock(data, seed_value)
	_fails.append_array(r["failures"] as Array)
	return "blocks after 12 h %d, in one step / 100 ms ticks / 60 s blocks identical: %s" % [r["blocks"], r["same"]]


func check_production(data: GameData) -> String:
	var r: Dictionary = production(data)
	_fails.append_array(r["failures"] as Array)
	return r["text"]


# ---------------------------------------------------------------------------------------------------------------------

static func new_pricing(data: GameData, seed_value: int) -> AuctionPricing:
	var pricing := AuctionPricing.new(data)
	pricing.reset(seed_value)
	return pricing


static func buyable(data: GameData) -> Array[StringName]:
	var out: Array[StringName] = []
	for def: AuctionItemDef in data.auction_items():
		if def.buy_level >= 1:
			out.append(def.item)
	return out


## (1) F-151: `unit` > sale of one piece at the ceiling (v*MAX) and > v, in random states (seed, block, saturation).
static func unit_prices(data: GameData, states: int, seed_value: int) -> Dictionary:
	var p: AuctionParams = data.auction_params()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var failures: Array = []
	var min_max: float = INF
	var min_value: float = INF
	var min_sale: float = INF
	var items: Array[StringName] = buyable(data)
	for id: StringName in items:
		var v: int = data.item(id).value
		for _i: int in states:
			var pricing: AuctionPricing = new_pricing(data, rng.randi_range(1, 2147483646))
			pricing.advance(rng.randi_range(0, 2000) * p.block_ms)
			pricing.record_sale(id, rng.randi_range(0, p.cap_ppm / p.step_ppm + 5))
			var unit: int = pricing.buy_quote(id, 1)
			var sale: int = pricing.sell_quote(id, 1)
			min_max = minf(min_max, float(unit) * ONE / float(v * p.max_ppm))
			min_value = minf(min_value, float(unit) / float(v))
			if sale > 0:
				min_sale = minf(min_sale, float(unit) / float(sale))
			if unit * ONE <= v * p.max_ppm or unit <= v or unit <= sale:
				failures.append("(1) %s: unit %d, v %d, sale of one %d" % [id, unit, v, sale])
				if failures.size() > 5:
					return {"failures": failures, "items": items.size(), "states": states, "min_over_max": min_max,
							"min_over_value": min_value, "min_over_sale": min_sale}
	return {"failures": failures, "items": items.size(), "states": states, "min_over_max": min_max,
			"min_over_value": min_value, "min_over_sale": min_sale}


## (2) Random walks over 12 h starting without the item (every second strategy starts with a pile of it, which is valued at
## v*MAX): gold at the end + pieces left * v*MAX must not exceed the same at the start. Sales go to the house or to the Deposit.
static func strategies(data: GameData, runs: int, seed_value: int) -> Dictionary:
	var p: AuctionParams = data.auction_params()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 1
	var failures: Array = []
	var best_net: float = -INF
	var best_saturate: float = -INF
	var min_loss: float = INF
	var ops: int = 0
	var items: Array[StringName] = buyable(data)
	for id: StringName in items:
		var v: int = data.item(id).value
		var ceiling: int = v * p.max_ppm  # value of one piece in ppm of gold
		for i: int in runs:
			var pile: int = 0 if i % 2 == 0 else rng.randi_range(1, 3000)
			var pricing: AuctionPricing = new_pricing(data, rng.randi_range(1, 2147483646))
			pricing.advance(rng.randi_range(0, 300) * p.block_ms)
			var gold: int = START_GOLD
			var held: int = pile
			var left_ms: int = HORIZON_MS
			var steps: int = 0
			while left_ms > 0 and steps < 40:
				steps += 1
				ops += 1
				var action: int = rng.randi_range(0, 4)
				if action == 0 and pricing.stock(id) > 0:
					var q: int = 1 + int(pow(rng.randf(), 3.0) * float(pricing.stock(id) - 1))
					gold -= pricing.buy_quote(id, q)
					held += q
					pricing.record_purchase(id, q)
				elif action == 1 and held > 0:
					var q: int = 1 + int(pow(rng.randf(), 2.0) * float(held - 1))
					gold += pricing.sell_quote(id, q)
					held -= q
					pricing.record_sale(id, q)
				elif action == 2 and held > 0:
					var q: int = 1 + rng.randi_range(0, held - 1)
					gold += q * v
					held -= q
				else:
					var wait: int = mini(left_ms, rng.randi_range(0, 8) * p.block_ms * (1 if action != 4 else 15) + rng.randi_range(0, p.block_ms))
					left_ms -= wait
					pricing.advance(wait)
			var net: float = (float(gold) * ONE + float(held) * ceiling - float(START_GOLD) * ONE - float(pile) * ceiling) / ONE
			best_net = maxf(best_net, net)
			if net > 0.0 and failures.size() < 6:
				failures.append("(2) %s: strategy %d ends %.2f gold above its start (gold %d, pieces %d -> %d)" % [id, i, net, gold - START_GOLD, pile, held])
		min_loss = minf(min_loss, round_trip_loss(data, id, rng.randi_range(1, 2147483646)))
		best_saturate = maxf(best_saturate, saturate_and_rebuy(data, id, rng.randi_range(1, 2147483646)))
		if best_saturate > 0.0 and failures.size() < 6:
			failures.append("(2) %s: saturate-and-rebuy gains %.2f gold" % [id, best_saturate])
	return {"failures": failures, "items": items.size(), "runs": runs, "ops": ops, "best_net": best_net,
			"min_round_trip_loss": min_loss, "best_saturate": best_saturate}


## Buy one piece and sell it back at once: the gold lost.
static func round_trip_loss(data: GameData, id: StringName, seed_value: int) -> float:
	var pricing: AuctionPricing = new_pricing(data, seed_value)
	return float(pricing.buy_quote(id, 1) - pricing.sell_quote(id, 1))


## Starts with 2000 pieces: sells them all into the saturation, waits for the full recovery (110 blocks), buys back as many as the
## stock allows. Returns the net gold, counting the pieces at v*MAX (negative = a loss).
static func saturate_and_rebuy(data: GameData, id: StringName, seed_value: int) -> float:
	var p: AuctionParams = data.auction_params()
	var pricing: AuctionPricing = new_pricing(data, seed_value)
	var pile: int = 2000
	var gold: int = pricing.sell_quote(id, pile)
	pricing.record_sale(id, pile)
	var rec: int = int(AuctionMath.liquidity(data.item(id).value, AuctionMath.band_of(data.item(id).value, p), p)["rec"])
	pricing.advance(AuctionMath.ceil_div(p.cap_ppm, rec) * p.block_ms)
	var q: int = pricing.stock(id)
	gold -= pricing.buy_quote(id, q)
	var v: int = data.item(id).value
	return float(gold) + float((q - pile) * v) * float(p.max_ppm) / ONE


## (3) Ingredients, shop gifts and blueprints.
static func transformations(data: GameData) -> Dictionary:
	var p: AuctionParams = data.auction_params()
	var failures: Array = []
	var buy: Dictionary = {}
	for id: StringName in buyable(data):
		buy[id] = true
	var clashes: int = 0
	for skill: SkillDef in data.skills():
		for action: ActionDef in data.actions_for_skill(skill.id):
			for input: ItemQty in action.inputs:
				if buy.has(input.item_id):
					clashes += 1
					failures.append("(3) action %s uses the buyable item %s" % [action.id, input.item_id])
	var gifts: int = 0
	for entry: ShopEntryDef in data.shop_entries():
		if entry.effect_item != null and data.auction_item(entry.effect_item.item_id) != null:
			var v: int = data.item(entry.effect_item.item_id).value
			if entry.cost_gold * ONE <= entry.effect_item.qty * v * p.max_ppm:
				gifts += 1
				failures.append("(3) shop entry %s gives %s at %d gold, sellable above that" % [entry.id, entry.effect_item.item_id, entry.cost_gold])
	var margin: int = int(data.balance_value("auction.buy.blueprint_margin_pct"))
	var worst: float = INF
	var worst_id: String = ""
	var checked: int = 0
	var with_buyable: int = 0
	for bp: ItemDef in data.blueprints():
		var cost: int = 0
		var uses_buyable: bool = false
		for row: ItemQty in bp.blueprint.inputs + bp.blueprint.rare_components:
			var unit: int = data.item(row.item_id).value
			if buy.has(row.item_id):
				unit = AuctionMath.ceil_div(unit * (p.min_ppm + p.spread_ppm), ONE)
				uses_buyable = true
			cost += row.qty * unit
		var piece: int = data.item(bp.blueprint.base_id).value
		checked += 1
		if not uses_buyable:
			continue
		with_buyable += 1
		var ratio: float = float(cost) / float(maxi(1, piece))
		if ratio < worst:
			worst = ratio
			worst_id = String(bp.id)
		if cost * 100 < piece * (100 + margin):
			failures.append("(3) blueprint %s: components cost %d against a piece of %d (margin %d%%)" % [bp.id, cost, piece, margin])
	return {"failures": failures, "clashes": clashes, "shop_gifts": gifts, "blueprints": checked, "bp_buyable": with_buyable,
			"worst_ratio": worst, "worst_id": worst_id, "margin": margin}


## (4) The same 12 h in one step, in 100 ms ticks and in 60 s blocks give the same saved state.
static func clock(data: GameData, seed_value: int) -> Dictionary:
	var failures: Array = []
	var states: Array[Dictionary] = []
	var blocks: int = 0
	for step_ms: int in [HORIZON_MS, 60_000, 100]:
		var pricing: AuctionPricing = new_pricing(data, seed_value)
		var ids: Array[StringName] = buyable(data)
		for k: int in ids.size():
			pricing.record_sale(ids[k], 100 + k * 40)
			pricing.record_purchase(ids[k], 1 + k * 3)
		pricing.advance(123_456)  # a clock not at a block boundary
		var done: int = 0
		var total: int = 0
		while done < HORIZON_MS:
			var step: int = mini(step_ms, HORIZON_MS - done)
			total += pricing.advance(step)
			done += step
		if step_ms == HORIZON_MS:
			blocks = total
		states.append(pricing.to_save())
	var same: bool = states[0] == states[1] and states[1] == states[2]
	if not same:
		failures.append("(4) the state after 12 h depends on the step size")
	if blocks != 144 and blocks != 145:
		failures.append("(4) 12 h made %d blocks, expected 144 (145 with the 123 s already pending)" % blocks)
	return {"failures": failures, "blocks": blocks, "same": same}


## (5) 1 h of production of every raw T1-T8 item (tiers by level inside each gathering skill), sold in one go at the minimum
## and maximum equilibrium, against F-18. Components and food are printed too (no threshold).
static func production(data: GameData) -> Dictionary:
	var p: AuctionParams = data.auction_params()
	var failures: Array = []
	var lines: Array[String] = []
	var worst_low: float = INF
	var worst_high: float = -INF
	var made: Dictionary = {}
	for skill: SkillDef in data.skills():
		for action: ActionDef in data.actions_for_skill(skill.id):
			for out: ItemQty in action.outputs:
				if action.interval_ms > 0 and not made.has(out.item_id):
					made[out.item_id] = {"per_hour": HOUR_MS / action.interval_ms * out.qty, "raw": RAW_SKILLS.has(skill.id) and action.inputs.is_empty()}
	var rec_blocks: Dictionary = {}  # band index -> recovery blocks from the cap
	var fill_blocks: Dictionary = {}  # band index -> slowest refill blocks from empty
	var extra: Array[String] = []
	for def: AuctionItemDef in data.auction_items():
		var v: int = data.item(def.item).value
		var band: AuctionPopulationBand = AuctionMath.band_of(v, p)
		var liq: Dictionary = AuctionMath.liquidity(v, band, p)
		if def.buy_level >= 1:
			var k: int = p.bands.find(band)
			var cap: int = AuctionMath.stock_max(v, p)
			rec_blocks[k] = AuctionMath.ceil_div(p.cap_ppm, int(liq["rec"]))
			fill_blocks[k] = maxi(int(fill_blocks.get(k, 0)), AuctionMath.ceil_div(cap, int(liq["refill"])))
		if not made.has(def.item):
			continue
		var q: int = int((made[def.item] as Dictionary)["per_hour"])
		var ratios: Array[float] = []
		for eq: int in _eq_range(band, p):
			var idx: int = clampi(eq, p.min_ppm, p.max_ppm)
			ratios.append(float(AuctionMath.gold_of(v, AuctionMath.sale_sum_ppm(idx, 0, q, p, int(liq["step"])))) / float(v * q))
		if bool((made[def.item] as Dictionary)["raw"]):
			worst_low = minf(worst_low, ratios[0])
			worst_high = maxf(worst_high, ratios[1])
			lines.append("%s: %d/h, ratio %.3f - %.3f" % [def.item, q, ratios[0], ratios[1]])
		else:
			extra.append("%s %d/h %.2f-%.2f" % [def.item, q, ratios[0], ratios[1]])
	if worst_low < RATIO_MIN or worst_high > RATIO_MAX:
		failures.append("(5) raw ratio %.3f - %.3f outside %.2f - %.2f" % [worst_low, worst_high, RATIO_MIN, RATIO_MAX])
	var text: String = "\n".join(lines)
	text += "\nraw materials: ratio %.3f - %.3f (threshold %.2f - %.2f); min-max spread %.3f; %d components/food (no threshold):\n%s" % [
		worst_low, worst_high, RATIO_MIN, RATIO_MAX, worst_high - worst_low, extra.size(), ", ".join(extra)]
	for k: int in rec_blocks:
		text += "\nband %d: recovery from the cap %d blocks (%.2f h), slowest stock refill from empty %d blocks (%.2f h)" % [
			k + 1, rec_blocks[k], float(int(rec_blocks[k]) * p.block_ms) / HOUR_MS, fill_blocks[k], float(int(fill_blocks[k]) * p.block_ms) / HOUR_MS]
	return {"failures": failures, "text": text}


## Extreme equilibria of a band at saturation 0 (F-174): base -/+ amplitude with the extreme pressure (Bmin against Smax, Bmax against Smin).
@warning_ignore("integer_division")
static func _eq_range(band: AuctionPopulationBand, p: AuctionParams) -> Array[int]:
	var b_lo: int = band.buyers * (ONE - p.pop_var_ppm) / ONE
	var b_hi: int = band.buyers * (ONE + p.pop_var_ppm) / ONE
	var s_lo: int = band.sellers * (ONE - p.pop_var_ppm) / ONE
	var s_hi: int = band.sellers * (ONE + p.pop_var_ppm) / ONE
	return [p.base_ppm - p.amp_ppm + AuctionMath.pressure(b_lo, s_hi, p), p.base_ppm + p.amp_ppm + AuctionMath.pressure(b_hi, s_lo, p)]
