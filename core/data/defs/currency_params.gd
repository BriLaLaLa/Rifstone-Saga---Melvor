class_name CurrencyParams
extends RefCounted
## The `currency` section of balance.json (docs/04_DATA_SCHEMA_M27.md §32.1, docs/02_FORMULAS_M27.md F-177): every money amount of
## the game is an integer in copper; these are the ratios and the texts used to show it (`Money`). `from_dict` returns null
## (after logging, see DefReader) if a key is missing or mistyped; ranges are the validator's job.

const COINS: Array[StringName] = [&"gold", &"silver", &"copper"]

var copper_per_silver: int = 100
var silver_per_gold: int = 100
var symbols: Dictionary[StringName, String] = {}
var names: Dictionary[StringName, String] = {}


static func from_dict(d: Dictionary) -> CurrencyParams:
	var r := DefReader.new(d, "balance currency")
	var p := CurrencyParams.new()
	p.copper_per_silver = r.integer("copper_per_silver")
	p.silver_per_gold = r.integer("silver_per_gold")
	for key: String in ["symbols", "names"]:
		var child := DefReader.new(r.dict(key), "balance currency.%s" % key)
		for coin: StringName in COINS:
			(p.symbols if key == "symbols" else p.names)[coin] = child.text(String(coin))
		r.absorb(child.ok)
	return p if r.ok else null


## Copper in one gold piece (CPG of F-177).
func copper_per_gold() -> int:
	return copper_per_silver * silver_per_gold


## The unit to which the generated costs and rewards are rounded (F-131, F-134): ten silver pieces.
func round_unit() -> int:
	return 10 * copper_per_silver
