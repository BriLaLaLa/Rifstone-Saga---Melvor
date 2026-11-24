extends RefCounted
## v13 -> v14 (M38-1, docs/05_INTERFACES_M38.md §6j): the Auction House has no stock any more, so `stock` is removed from every item of
## `auction.items` and `auction.taken = {}` is added (when `auction` is an object and the key is missing). Nothing else changes.


static func migrate(d: Dictionary) -> Dictionary:
	var out: Dictionary = d.duplicate(true)
	var modules: Variant = out.get("modules")
	if not modules is Dictionary:
		return out
	var auction: Variant = (modules as Dictionary).get("auction")
	if not auction is Dictionary:
		return out
	var items: Variant = (auction as Dictionary).get("items")
	if items is Dictionary:
		for key: Variant in items as Dictionary:
			if (items as Dictionary)[key] is Dictionary:
				((items as Dictionary)[key] as Dictionary).erase("stock")
	if not (auction as Dictionary).has("taken"):
		(auction as Dictionary)["taken"] = {}
	return out
