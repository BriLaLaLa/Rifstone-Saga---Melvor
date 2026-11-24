extends RefCounted
## v12 -> v13 (M37-1, docs/05_INTERFACES_M37.md §6i): `auction.history = []` is added when `auction` is an object and the key is missing.
## Nothing else changes.


static func migrate(d: Dictionary) -> Dictionary:
	var out: Dictionary = d.duplicate(true)
	var modules: Variant = out.get("modules")
	if not modules is Dictionary:
		return out
	var auction: Variant = (modules as Dictionary).get("auction")
	if auction is Dictionary and not (auction as Dictionary).has("history"):
		(auction as Dictionary)["history"] = []
	return out
