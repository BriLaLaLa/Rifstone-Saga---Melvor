class_name DataValidatorAuction
extends RefCounted
## Auction House rules of DataValidator (internal, M23; docs/04_DATA_SCHEMA.md §28, docs/02_FORMULAS.md F-145…F-152): the
## `auction` section of balance.json, data/auction/auction_items.json and the checks that tie them to items, actions,
## blueprints and the Village building. `entries` is the pure generation rule: the validator compares the written file with
## it, tools/gen_auction.gd writes it and the tests call it.

## Rule 6 of §28 is strict since M23-03 (the real data have the `auction_house` building): a Village with buildings but
## none with `unlocks_auction` is an error. Without any building at all (the minimal fixtures) it never applies.
const STRICT_REAL_DATA: bool = true
const TRADED: PackedStringArray = ["material", "component", "food"]
const BUYABLE: PackedStringArray = ["component", "food"]
const PPM: int = 1000000
const PARAM_KEYS: PackedStringArray = ["block_ms", "index", "drift", "saturation", "buy", "stock", "trend", "population", "book", "listing"]
const ITEM_FIELDS: PackedStringArray = ["item", "buy_level"]


## True for the `auction` section of balance.json (its fields are checked by `validate_balance`).
static func is_known_key(path: String) -> bool:
	return path == "auction"


## The generation rule (§28), on raw JSON dictionaries: `items` (all of data/items/), `actions` (all of data/actions/, the
## `outputs` give the producer), `tier_levels` (`village.woodwright_levels`). Every `material`, `component`, `food` with
## `value >= 1`, by category, `sort_order`, id. Returns `{"entries": Array[Dictionary], "errors": PackedStringArray}`: a
## component or food that no action produces, or whose action is at a level outside `tier_levels`, is an error; with
## `strict` false (the minimal test fixtures, which have loose components) it is simply sell-only (`buy_level` 0).
static func build(items: Array, actions: Array, tier_levels: Array, strict: bool = true) -> Dictionary:
	var errors: PackedStringArray = []
	var rows: Array[Dictionary] = []
	for e: Variant in items:
		var item: Dictionary = e as Dictionary
		if TRADED.has(str(item.get("category"))) and float(item.get("value", 0)) >= 1.0:
			rows.append(item)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ca: int = TRADED.find(str(a["category"]))
		var cb: int = TRADED.find(str(b["category"]))
		if ca != cb:
			return ca < cb
		if int(a.get("sort_order", 0)) != int(b.get("sort_order", 0)):
			return int(a.get("sort_order", 0)) < int(b.get("sort_order", 0))
		return str(a["id"]) < str(b["id"]))
	var producer_level: Dictionary = _producer_levels(actions)
	var tiers: Array[int] = []
	for level: Variant in tier_levels:
		tiers.append(int(level))
	var entries: Array[Dictionary] = []
	for item: Dictionary in rows:
		var id: String = str(item["id"])
		var buy_level: int = 0
		if BUYABLE.has(str(item["category"])):
			if not producer_level.has(id):
				if not strict:
					entries.append({"item": id, "buy_level": 0})
					continue
				errors.append("item '%s' (%s) is not produced by any action: classify it in the data, not in the generator" % [id, item["category"]])
				continue
			# The highest tier at or below the production level (the meat recipes sit between two tiers, M32-03).
			var tier: int = -1
			for k: int in tiers.size():
				if tiers[k] <= int(producer_level[id]):
					tier = k
			if tier >= 0:
				buy_level = tier + 1
			elif strict:
				errors.append("item '%s' is produced at level %s, below the first of village.woodwright_levels" % [id, producer_level[id]])
				continue
		entries.append({"item": id, "buy_level": buy_level})
	return {"entries": entries, "errors": errors}


## `build(...)["entries"]` (the errors are the caller's business).
static func entries(items: Array, actions: Array, tier_levels: Array, strict: bool = true) -> Array[Dictionary]:
	return build(items, actions, tier_levels, strict)["entries"] as Array[Dictionary]


## The text of data/auction/auction_items.json for `list` (one entry per line).
static func file_text(list: Array[Dictionary]) -> String:
	var rows: PackedStringArray = []
	for entry: Dictionary in list:
		rows.append("    " + JSON.stringify(entry, "", false))
	return '{\n  "items": [\n%s\n  ]\n}\n' % ",\n".join(rows)


## `ceil_div(a, b)` for `a >= 0`, `b > 0` (F-145…F-152 convention).
static func ceil_div(a: int, b: int) -> int:
	return (a + b - 1) / b


## balance.json `auction` (§28 table, F-147 and F-151 constraints).
static func validate_balance(v: DataValidatorRules, balance: Dictionary) -> void:
	var section: Variant = DataValidator.lookup(balance, "auction")
	if not section is Dictionary:
		v.fail("missing key 'auction'")
		return
	var auction: Dictionary = section as Dictionary
	v.keys(auction, PARAM_KEYS, "auction")
	var ok: bool = v.integer(auction, "block_ms", 60000.0, 3600000.0, "auction")
	var index: Dictionary = v.object(auction, "index", "auction")
	v.keys(index, ["base_pct", "min_pct", "max_pct"], "auction.index")
	for key: String in ["base_pct", "min_pct", "max_pct"]:
		ok = v.number(index, key, 0.0, DataValidatorRules.NO_LIMIT, "auction.index", true) and ok
	var drift: Dictionary = v.object(auction, "drift", "auction")
	v.keys(drift, ["amplitude_pct", "period_blocks"], "auction.drift")
	ok = v.number(drift, "amplitude_pct", 0.0, 50.0, "auction.drift") and ok
	ok = v.integer(drift, "period_blocks", 1.0, DataValidatorRules.NO_LIMIT, "auction.drift") and ok
	var sat: Dictionary = v.object(auction, "saturation", "auction")
	v.keys(sat, ["per_unit_pct", "max_pct", "recover_pct_per_block"], "auction.saturation")
	for key: String in ["per_unit_pct", "recover_pct_per_block"]:
		if v.number(sat, key, 0.0, DataValidatorRules.NO_LIMIT, "auction.saturation", true):
			if AuctionParams.ppm(float(sat[key])) < 1:
				v.fail("key 'auction.saturation.%s' is below 1 ppm (0.0001 %%)" % key)
				ok = false
		else:
			ok = false
	ok = v.number(sat, "max_pct", 0.0, DataValidatorRules.NO_LIMIT, "auction.saturation", true) and ok
	var buy: Dictionary = v.object(auction, "buy", "auction")
	v.keys(buy, ["spread_pct", "blueprint_margin_pct"], "auction.buy")
	ok = v.number(buy, "spread_pct", 0.0, DataValidatorRules.NO_LIMIT, "auction.buy", true) and ok
	ok = v.number(buy, "blueprint_margin_pct", 0.0, DataValidatorRules.NO_LIMIT, "auction.buy") and ok
	var stock: Dictionary = v.object(auction, "stock", "auction")
	v.keys(stock, ["gold", "min", "max", "refill_pct_per_block"], "auction.stock")
	ok = v.integer(stock, "gold", 1.0, DataValidatorRules.NO_LIMIT, "auction.stock") and ok
	ok = v.integer(stock, "min", 1.0, DataValidatorRules.NO_LIMIT, "auction.stock") and ok
	ok = v.integer(stock, "max", 1.0, DataValidatorRules.NO_LIMIT, "auction.stock") and ok
	ok = v.number(stock, "refill_pct_per_block", 0.0, DataValidatorRules.NO_LIMIT, "auction.stock", true) and ok
	var trend: Dictionary = v.object(auction, "trend", "auction")
	v.keys(trend, ["blocks", "threshold_pct"], "auction.trend")
	ok = v.integer(trend, "blocks", 1.0, DataValidatorRules.NO_LIMIT, "auction.trend") and ok
	ok = v.number(trend, "threshold_pct", 0.0, DataValidatorRules.NO_LIMIT, "auction.trend") and ok
	ok = DataValidatorAuctionPopulation.validate_params(v, auction) and ok
	ok = DataValidatorAuctionBook.validate_params(v, auction) and ok
	if ok:
		var p: AuctionParams = AuctionParams.from_dict(auction)
		_relations(v, p)
		DataValidatorAuctionBook.relations(v, p)


## The files: `raw` is the whole raw data of DataValidator.
static func validate(v: DataValidatorRules, raw: Dictionary) -> void:
	var balance_files: Dictionary = raw.get("balance", {}) as Dictionary
	for path: Variant in balance_files:
		v.at_file(str(path))
		validate_balance(v, balance_files[path] as Dictionary)
	var balance: Dictionary = _first(raw, "balance")
	var params: AuctionParams = _valid_params(balance)
	_population(v, raw, params, balance)
	var village: Dictionary = _first(raw, "village")
	var buildings: Array = village.get("buildings", []) as Array if village.get("buildings") is Array else []
	_building_rules(v, raw, buildings)
	var files: Dictionary = raw.get("auction", {}) as Dictionary
	var items: Array = _all(raw, "items", "items")
	var actions: Array = _all(raw, "actions", "actions")
	var max_level: int = _max_level(balance)
	for path: Variant in files:
		v.at_file(str(path))
		var content: Dictionary = files[path] as Dictionary
		var list: Array[Dictionary] = DataValidator.entries(v, content, "items")
		_check_items(v, list, max_level)
		var woodwright: Variant = DataValidator.lookup(balance, "village.woodwright_levels")
		if woodwright is Array and not (woodwright as Array).is_empty():
			var generated: Dictionary = build(items, actions, woodwright as Array, not buildings.is_empty())
			for message: String in generated["errors"] as PackedStringArray:
				v.fail(message)
			if (generated["errors"] as PackedStringArray).is_empty() and not _same(list, generated["entries"] as Array):
				v.fail("the file differs from the regeneration (rerun tools/gen_auction.gd)")
		_not_an_input(v, list, actions)
		if params != null and not buildings.is_empty():  # the loose blueprints of the minimal fixtures are not realistic
			_blueprints(v, list, items, params, float(DataValidator.lookup(balance, "auction.buy.blueprint_margin_pct")))


# --- balance relations ------------------------------------------------------------------------------------------

# F-147 and F-151 constraints, on the converted parameters (so the validator and the formulas agree on the rounding).
static func _relations(v: DataValidatorRules, p: AuctionParams) -> void:
	if p.min_ppm >= p.base_ppm - p.amp_ppm:
		v.fail("key 'auction.index.min_pct' must be below base_pct - amplitude_pct (F-147)")
	if p.base_ppm + p.amp_ppm > p.max_ppm:
		v.fail("key 'auction.index.max_pct' must be at least base_pct + amplitude_pct (F-147)")
	if p.max_ppm < PPM:
		v.fail("key 'auction.index.max_pct' must be at least 100 (F-151)")
	if p.cap_ppm < p.base_ppm + p.amp_ppm - p.min_ppm:
		v.fail("key 'auction.saturation.max_pct' must be at least base_pct + amplitude_pct - min_pct (F-147)")
	if p.spread_ppm <= p.max_ppm - p.min_ppm:
		v.fail("key 'auction.buy.spread_pct' must be above max_pct - min_pct (F-151: buying and selling back must lose gold)")
	if p.stock_max < p.stock_min:
		v.fail("key 'auction.stock.max' must be at least 'min'")


# M26-08: the population file and, when both it and the parameters are valid, the F-174 bounds (the bands are set on `params`).
@warning_ignore("integer_division")
static func _population(v: DataValidatorRules, raw: Dictionary, params: AuctionParams, balance: Dictionary) -> void:
	var files: Dictionary = raw.get("auction_population", {}) as Dictionary
	for path: Variant in files:
		v.at_file(str(path))
		var content: Dictionary = files[path] as Dictionary
		if DataValidatorAuctionPopulation.validate_bands(v, content) and params != null:
			params.bands = AuctionPopulationBand.list_from(content)
			var block_ms: int = maxi(1, int(DataValidator.lookup(balance, "auction.block_ms")))
			var cap_ms: Variant = DataValidator.lookup(balance, "offline.cap_ms")
			DataValidatorAuctionPopulation.relations(v, params, int(cap_ms) / block_ms if DataValidatorRules.is_int(cap_ms) else 0)


# `auction` of balance.json as AuctionParams when valid (null otherwise: reported by validate_balance).
static func _valid_params(balance: Dictionary) -> AuctionParams:
	var probe := DataValidatorRules.new()
	validate_balance(probe, balance)
	if not probe.errors.is_empty():
		return null
	return AuctionParams.from_dict(DataValidator.lookup(balance, "auction") as Dictionary)


# --- the file --------------------------------------------------------------------------------------------------

static func _check_items(v: DataValidatorRules, list: Array[Dictionary], max_level: int) -> void:
	var seen: Dictionary[StringName, bool] = {}
	for index: int in list.size():
		var e: Dictionary = list[index]
		var id: StringName = v.at_entry("auction item", index, {"id": e.get("item")})
		if id != &"" and seen.has(id):
			v.fail("duplicate auction item '%s'" % id)
		seen[id] = true
		v.keys(e, ITEM_FIELDS)
		var category: String = ""
		if v.ref(e, "item", v.items, "item"):
			category = str(v.items[StringName(e["item"] as String)].get("category"))
			if not TRADED.has(category):
				v.fail("field 'item': '%s' is %s, not material, component or food" % [e["item"], category])
			var value: float = float(v.items[StringName(e["item"] as String)].get("value", 0))
			if value < 1.0:
				v.fail("field 'item': '%s' has no value" % e["item"])
			elif value > DataValidatorAuctionBook.MAX_ITEM_VALUE:
				v.fail("field 'item': '%s' is worth more than %d (F-178)" % [e["item"], DataValidatorAuctionBook.MAX_ITEM_VALUE])
		if v.integer(e, "buy_level", 0.0, float(max_level) if max_level > 0 else DataValidatorRules.NO_LIMIT) \
				and int(e["buy_level"]) > 0 and not category.is_empty() and not BUYABLE.has(category):
			v.fail("field 'buy_level' must be 0 for a %s" % category)


# Rule 2: the written entries (in order) are the regeneration.
static func _same(written: Array[Dictionary], expected: Array) -> bool:
	if written.size() != expected.size():
		return false
	for i: int in written.size():
		var a: Dictionary = written[i]
		var b: Dictionary = expected[i] as Dictionary
		if str(a.get("item")) != str(b["item"]) or not DataValidatorRules.is_int(a.get("buy_level")) \
				or int(a["buy_level"]) != int(b["buy_level"]):
			return false
	return true


# Rule 4: a buyable item is never an ingredient of an action.
static func _not_an_input(v: DataValidatorRules, list: Array[Dictionary], actions: Array) -> void:
	var buyable: Dictionary[String, bool] = {}
	for e: Dictionary in list:
		if DataValidatorRules.is_int(e.get("buy_level")) and int(e["buy_level"]) > 0:
			buyable[str(e.get("item"))] = true
	for a: Variant in actions:
		for input: Variant in (a as Dictionary).get("inputs", []) as Array:
			if input is Dictionary and buyable.has(str((input as Dictionary).get("item"))):
				v.fail("item '%s' can be bought but is an input of action '%s' (F-151: no buy-craft-sell loop)" % [(input as Dictionary)["item"], (a as Dictionary).get("id")])


# Rule 5 (F-151): every blueprint costs, with the buyable parts at their cheapest price, at least its piece plus the margin.
static func _blueprints(v: DataValidatorRules, list: Array[Dictionary], items: Array, p: AuctionParams, margin: float) -> void:
	var value: Dictionary[String, int] = {}
	var buyable: Dictionary[String, bool] = {}
	for item: Variant in items:
		value[str((item as Dictionary).get("id"))] = int(float((item as Dictionary).get("value", 0)))
	for e: Dictionary in list:
		if DataValidatorRules.is_int(e.get("buy_level")) and int(e["buy_level"]) > 0:
			buyable[str(e.get("item"))] = true
	for item: Variant in items:
		var blueprint: Variant = (item as Dictionary).get("blueprint")
		if not blueprint is Dictionary or not value.has(str((blueprint as Dictionary).get("base"))):
			continue
		var cost: int = 0
		for key: String in ["inputs", "rare_components"]:
			for row: Variant in (blueprint as Dictionary).get(key, []) as Array:
				var id: String = str((row as Dictionary).get("item"))
				var unit: int = value.get(id, 0)
				if buyable.has(id):
					unit = ceil_div(unit * (p.min_ppm + p.spread_ppm), PPM)
				cost += int(float((row as Dictionary).get("qty", 0))) * unit
		var piece: int = value[str((blueprint as Dictionary)["base"])]
		if float(cost) < float(piece) * (100.0 + margin) / 100.0:
			v.fail("blueprint '%s': parts cost at least %d but the piece is worth %d (needs %s%% margin, F-151)" % [(item as Dictionary).get("id"), cost, piece, margin])


# --- the building ----------------------------------------------------------------------------------------------

# Rule 6: exactly one building with `unlocks_auction` (none is accepted only with no building at all, or with STRICT_REAL_DATA false).
static func _building_rules(v: DataValidatorRules, raw: Dictionary, buildings: Array) -> void:
	var found: Array[String] = []
	for b: Variant in buildings:
		if b is Dictionary and (b as Dictionary).get("unlocks_auction") == true:
			found.append(str((b as Dictionary).get("id")))
	var village_files: Dictionary = raw.get("village", {}) as Dictionary
	v.at_file(str(village_files.keys()[0]) if not village_files.is_empty() else "section 'village'")
	if found.size() > 1:
		v.fail("%d buildings have 'unlocks_auction' (%s): exactly one is allowed" % [found.size(), ", ".join(found)])
	elif found.is_empty() and STRICT_REAL_DATA and not buildings.is_empty():
		v.fail("no building has 'unlocks_auction': the Auction House is missing")


# --- helpers ---------------------------------------------------------------------------------------------------

# id -> level of the first action that outputs it.
static func _producer_levels(actions: Array) -> Dictionary:
	var result: Dictionary = {}
	for a: Variant in actions:
		for out: Variant in (a as Dictionary).get("outputs", []) as Array:
			var id: String = str((out as Dictionary).get("item")) if out is Dictionary else ""
			if not id.is_empty() and not result.has(id):
				result[id] = int(float((a as Dictionary).get("level", 0)))
	return result


static func _max_level(balance: Dictionary) -> int:
	var value: Variant = DataValidator.lookup(balance, "village.max_level")
	return int(value) if DataValidatorRules.is_int(value) else 0


# The single file of a section (`{}` if there is not exactly... the first one).
static func _first(raw: Dictionary, section: String) -> Dictionary:
	var files: Variant = raw.get(section)
	if files is Dictionary and not (files as Dictionary).is_empty():
		var first: Variant = (files as Dictionary).values()[0]
		return first as Dictionary if first is Dictionary else {}
	return {}


# Every entry of `list_key` in every file of a section (file order).
static func _all(raw: Dictionary, section: String, list_key: String) -> Array:
	var result: Array = []
	var files: Variant = raw.get(section)
	for path: Variant in (files as Dictionary if files is Dictionary else {}):
		var list: Variant = ((files as Dictionary)[path] as Dictionary).get(list_key) if (files as Dictionary)[path] is Dictionary else null
		for e: Variant in (list as Array if list is Array else []):
			if e is Dictionary:
				result.append(e)
	return result
