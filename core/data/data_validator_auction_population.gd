class_name DataValidatorAuctionPopulation
extends RefCounted
## Population rules of DataValidatorAuction (M26-08; docs/04_DATA_SCHEMA_M26.md §31.7, docs/02_FORMULAS_M26.md F-172…F-174): the
## `auction.population` keys of balance.json, data/auction/population.json and the bounds that keep the index in [MIN, MAX].

const PARAM_KEYS: PackedStringArray = ["ref", "period_blocks", "variation_pct", "pressure_pct", "demand_threshold_pct"]
const FILE_KEYS: PackedStringArray = ["bands"]
const BAND_FIELDS: PackedStringArray = ["max_value", "buyers", "sellers", "stack"]


## `auction.population` of balance.json; true if every key is valid.
static func validate_params(v: DataValidatorRules, auction: Dictionary) -> bool:
	var pop: Dictionary = v.object(auction, "population", "auction")
	v.keys(pop, PARAM_KEYS, "auction.population")
	var ok: bool = v.integer(pop, "ref", 1.0, DataValidatorRules.NO_LIMIT, "auction.population")
	ok = v.integer(pop, "period_blocks", 1.0, DataValidatorRules.NO_LIMIT, "auction.population") and ok
	ok = v.number(pop, "variation_pct", 0.0, 99.0, "auction.population") and ok
	ok = v.number(pop, "pressure_pct", 0.0, DataValidatorRules.NO_LIMIT, "auction.population") and ok
	ok = v.number(pop, "demand_threshold_pct", 0.0, DataValidatorRules.NO_LIMIT, "auction.population") and ok
	return ok


## data/auction/population.json: the bands (§31.7). True if the file is valid.
static func validate_bands(v: DataValidatorRules, content: Dictionary) -> bool:
	var before: int = v.errors.size()
	v.keys(content, FILE_KEYS)
	var list: Array[Dictionary] = v.object_list(content, "bands", "", 1)
	var last_max: int = 0
	for index: int in list.size():
		var e: Dictionary = list[index]
		v.at_entry("auction population band", index, {})
		v.keys(e, BAND_FIELDS)
		v.integer(e, "buyers", 1.0)
		v.integer(e, "sellers", 1.0)
		v.integer(e, "stack", 1.0)
		var is_last: bool = index == list.size() - 1
		if is_last:
			if e.has("max_value"):
				v.fail("field 'max_value' must be absent in the last band (the open one)")
		elif v.integer(e, "max_value", 1.0):
			if int(e["max_value"]) <= last_max:
				v.fail("field 'max_value' must be strictly increasing (%d after %d)" % [int(e["max_value"]), last_max])
			last_max = maxi(last_max, int(e["max_value"]))
	return v.errors.size() == before


## F-174 bounds on the converted parameters (with `p.bands` set): the index stays in [MIN, MAX] and a full recovery takes at most
## `offline_blocks` blocks in every band. `offline_blocks` = offline cap / block length.
static func relations(v: DataValidatorRules, p: AuctionParams, offline_blocks: int) -> void:
	var plus: int = 0
	var minus: int = 0
	for band: AuctionPopulationBand in p.bands:
		var lo: Vector2i = AuctionMath.population(band.buyers, band.sellers, -p.pop_var_ppm, -p.pop_var_ppm)
		var hi: Vector2i = AuctionMath.population(band.buyers, band.sellers, p.pop_var_ppm, p.pop_var_ppm)
		plus = maxi(plus, AuctionMath.pressure(hi.x, lo.y, p))
		minus = maxi(minus, -AuctionMath.pressure(lo.x, hi.y, p))
		var rec: int = int(AuctionMath.liquidity(1, band, p)["rec"])
		if DataValidatorAuction.ceil_div(p.cap_ppm, rec) > offline_blocks:
			v.fail("key 'auction.saturation.max_pct': a band with %d buyers needs %d blocks to recover, more than the offline cap (%d, F-172)"
					% [band.buyers, DataValidatorAuction.ceil_div(p.cap_ppm, rec), offline_blocks])
	if p.min_ppm >= p.base_ppm - p.amp_ppm - minus:
		v.fail("key 'auction.index.min_pct' must be below base_pct - amplitude_pct - the lowest pressure (%d ppm, F-174)" % minus)
	if p.base_ppm + p.amp_ppm + plus > p.max_ppm:
		v.fail("key 'auction.index.max_pct' must be at least base_pct + amplitude_pct + the highest pressure (%d ppm, F-174)" % plus)
	if p.cap_ppm < p.base_ppm + p.amp_ppm + plus - p.min_ppm:
		v.fail("key 'auction.saturation.max_pct' must be at least base_pct + amplitude_pct + the highest pressure - min_pct (F-174)")
