extends RefCounted
## v11 -> v12 (M30-02, docs/05_INTERFACES_M30.md §6g): the module `tutorial` is added to the existing slots as completed, so that nobody
## who already plays sees the tutorial (the starter quests are then active). A `tutorial` that already exists stays; `modules` missing or
## not an object leaves the file as it is. Reads no data: the block is written here.


static func migrate(d: Dictionary) -> Dictionary:
	var out: Dictionary = d.duplicate(true)
	var modules: Variant = out.get("modules")
	if not modules is Dictionary or (modules as Dictionary).has("tutorial"):
		return out
	(modules as Dictionary)["tutorial"] = {"completed": true, "step": "", "progress": 0, "since_ms": 0, "visited": [],
			"starter": {"claimed": [], "progress": {}}}
	return out
