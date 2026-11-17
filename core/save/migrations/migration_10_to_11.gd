extends RefCounted
## v10 -> v11 (M27-02, docs/05_INTERFACES_M27.md §6e, docs/02_FORMULAS_M27.md F-177): the unit of money becomes the copper.
## In `modules.wallet` an integer `gold` >= 0 (or an integral float) becomes `copper = gold x V11_COPPER_PER_GOLD` and `gold` is removed;
## an invalid `gold` is only removed (the wallet then loads 0 with a warning); a missing `wallet` stays missing. Nothing else changes.
## Reads no data: the ratio is frozen here.

const V11_COPPER_PER_GOLD: int = 100
const LOG_CATEGORY: String = "save"


static func migrate(d: Dictionary) -> Dictionary:
	var out: Dictionary = d.duplicate(true)
	var modules: Variant = out.get("modules")
	if not modules is Dictionary or not (modules as Dictionary).get("wallet") is Dictionary:
		return out
	var wallet: Dictionary = (modules as Dictionary)["wallet"]
	if not wallet.has("gold"):
		return out
	var gold: Variant = wallet["gold"]
	wallet.erase("gold")
	if (gold is int or gold is float) and float(gold) == floorf(float(gold)) and float(gold) >= 0.0:
		wallet["copper"] = int(gold) * V11_COPPER_PER_GOLD
	else:
		Log.warn(LOG_CATEGORY, "migration 10->11: invalid wallet.gold %s dropped" % str(gold))
	return out
