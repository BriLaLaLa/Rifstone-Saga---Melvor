extends RefCounted
## v5 -> v6 (M15, METIN Z1/Z7, docs/05_INTERFACES.md §6), all in `modules.combat`:
## - `loot` goes from `[{"item","qty"}]` to `{"stacks": [...], "pieces": []}` (M15-04);
## - `skip_stone_level` = 0 (M15-05);
## - `stone` gets `stone_id` = "" and a pending stone is no longer pending (ids and levels of the Rift Stones changed);
## - a fight in the state `riftstone` becomes `between` with no enemies (the old stone vanishes, bag and counters stay).


static func migrate(d: Dictionary) -> Dictionary:
	var out: Dictionary = d.duplicate(true)
	var modules: Variant = out.get("modules")
	if modules is Dictionary and (modules as Dictionary).get("combat") is Dictionary:
		var combat: Dictionary = (modules as Dictionary)["combat"]
		var loot: Variant = combat.get("loot")
		if loot is Array:
			combat["loot"] = {"stacks": loot, "pieces": []}
		if not combat.has("skip_stone_level"):
			combat["skip_stone_level"] = 0
		var stone: Variant = combat.get("stone")
		if stone is Dictionary:
			(stone as Dictionary)["stone_id"] = ""
			(stone as Dictionary)["pending"] = false
		if combat.get("state") == "riftstone":
			combat["state"] = "between"
			combat["enemies"] = []
	return out
