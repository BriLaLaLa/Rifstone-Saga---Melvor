extends RefCounted
## v5 -> v6 (M15-04, METIN Z1): the loot bag of the combat engine keeps pieces too.
## `modules.combat.loot` goes from `[{"item","qty"}]` to `{"stacks": [...], "pieces": []}`.


static func migrate(d: Dictionary) -> Dictionary:
	var out: Dictionary = d.duplicate(true)
	var modules: Variant = out.get("modules")
	if modules is Dictionary and (modules as Dictionary).get("combat") is Dictionary:
		var combat: Dictionary = (modules as Dictionary)["combat"]
		var loot: Variant = combat.get("loot")
		if loot is Array:
			combat["loot"] = {"stacks": loot, "pieces": []}
	return out
