class_name GatherBonusItem
extends TraitEffect
## F-120 `gather_bonus_item` (`items`, `pct`), hook `on_gather`: `roll_pct(pct)` for +1 of one of `items` (chosen at
## random) besides the product of the cycle. Draws: the probability, then the item (only if it succeeded).


func on_gather(ctx: GatherContext) -> void:
	if ctx.rng.roll_pct(float(params["pct"])):
		var items: Array = params["items"] as Array
		ctx.bonus_items.append(StringName(str(items[ctx.rng.randi_range(0, items.size() - 1)])))
