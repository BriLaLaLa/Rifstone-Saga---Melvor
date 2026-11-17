class_name Money
extends RefCounted
## Money amounts (docs/02_FORMULAS_M27.md F-177): an amount is an integer in copper; this is the split into gold, silver and
## copper and the text. Pure logic, no state. The UI and the Guide format money only through `text` (or MoneyLabel).

const LOG_CATEGORY: String = "money"
const MINUS: String = "−"


## (gold, silver, copper) of |copper|.
static func split(copper: int, p: CurrencyParams) -> Vector3i:
	var c: int = absi(copper)
	var per_gold: int = p.copper_per_gold()
	return Vector3i(c / per_gold, (c % per_gold) / p.copper_per_silver, c % p.copper_per_silver)


## The amount in copper of the three parts; a negative part is a programming error: logged, gives 0.
static func from_parts(gold: int, silver: int, copper: int, p: CurrencyParams) -> int:
	if gold < 0 or silver < 0 or copper < 0:
		Log.error(LOG_CATEGORY, "from_parts: negative part (%d, %d, %d)" % [gold, silver, copper])
		return 0
	return gold * p.copper_per_gold() + silver * p.copper_per_silver + copper


## "1g 25s 40c" (symbols from currency.symbols): the non-zero parts in order gold, silver, copper; 0 is "0c"; a negative amount (only for deltas) has a minus sign.
static func text(copper: int, p: CurrencyParams) -> String:
	if copper < 0:
		return MINUS + text(-copper, p)
	var parts: Vector3i = split(copper, p)
	var out: PackedStringArray = []
	if parts.x > 0:
		out.append("%d%s" % [parts.x, p.symbols[&"gold"]])
	if parts.y > 0:
		out.append("%d%s" % [parts.y, p.symbols[&"silver"]])
	if parts.z > 0 or out.is_empty():
		out.append("%d%s" % [parts.z, p.symbols[&"copper"]])
	return " ".join(out)
