extends GutTest
## M35-D2 (F-197, 04_DATA_SCHEMA_M35.md §35.1-§35.3): tool heads, balance keys and the three new stats. Reads the real JSON files.

const ALLOWED: Array[String] = ["node_units_pct", "node_rich_pct", "byproduct_chance_pct", "double_item_chance", "rift_shard_chance"]
const TOOLS: Array[String] = ["unique_hatchet", "unique_pick", "unique_rod", "unique_sickle"]


func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary


func _tools() -> Dictionary:
	var out: Dictionary = {}
	for e: Dictionary in _json("res://data/items/tools.json")["items"] as Array:
		out[e["id"]] = e
	return out


## Equivalent units at +9 (three steps): units 1/pt, double 1/pt, rich 0.5/pt (F-197).
func _ue(head: Dictionary) -> float:
	var total: float = 0.0
	for step: Array in head["steps"] as Array:
		for m: Dictionary in step:
			var v: float = float(m["value"])
			match m["stat"]:
				"node_units_pct", "double_item_chance":
					total += v
				"node_rich_pct":
					total += v * 0.5
	return total


func test_four_unique_tools_with_two_heads_and_three_steps() -> void:
	var tools: Dictionary = _tools()
	assert_eq(tools.size(), 4)
	for id: String in TOOLS:
		assert_true(tools.has(id), id)
		var heads: Array = ((tools[id] as Dictionary)["equip"] as Dictionary)["heads"] as Array
		assert_eq(heads.size(), 2, id)
		for h: Dictionary in heads:
			assert_eq((h["steps"] as Array).size(), 3)
			assert_true(String(h["name"]).length() <= 24 and String(h["description"]).length() <= 80)
	var sickle: Dictionary = (tools["unique_sickle"] as Dictionary)["equip"] as Dictionary
	assert_eq(sickle["slot"], "tool_herbalism")
	assert_true(FileAccess.file_exists((tools["unique_sickle"] as Dictionary)["icon"] as String))


func test_ue_per_head_in_range_and_resa_heads_are_15() -> void:
	var tools: Dictionary = _tools()
	for id: String in TOOLS:
		var heads: Array = ((tools[id] as Dictionary)["equip"] as Dictionary)["heads"] as Array
		var resa: Dictionary = heads[0] as Dictionary
		assert_eq(_ue(resa), 15.0, String(resa["id"]))
		for h: Dictionary in heads:
			var ue: float = _ue(h)
			assert_true(ue >= 9.0 and ue <= 15.0, "%s UE %s" % [h["id"], ue])


func test_no_upgrade_extras_and_allowed_stats() -> void:
	assert_false(FileAccess.get_file_as_string("res://data/items/tools.json").contains("upgrade_extras"))
	var stats: Dictionary = {}
	for s: Dictionary in _json("res://data/config/stats.json")["stats"] as Array:
		stats[s["id"]] = s
	for id: String in TOOLS:
		for h: Dictionary in (((_tools()[id] as Dictionary)["equip"] as Dictionary)["heads"] as Array):
			for step: Array in h["steps"] as Array:
				assert_false(step.is_empty())
				for m: Dictionary in step:
					assert_true(ALLOWED.has(m["stat"]), String(m["stat"]))
					assert_true(float(m["value"]) > 0.0 and float(m["value"]) <= float((stats[m["stat"]] as Dictionary)["max"]))


func test_balance_keys_and_stats() -> void:
	var b: Dictionary = _json("res://data/config/balance.json")
	var tu: Dictionary = b["tool_upgrade"] as Dictionary
	assert_eq(int(tu["units_per_level_pct"]), 1)
	assert_eq((tu["head_steps"] as Array).map(func(v: Variant) -> int: return int(v)), [3, 6, 9] as Array)
	assert_eq(int(tu["respec_pct"]), 25)
	var levels: int = (tu["levels"] as Array).size()
	for s: Variant in tu["head_steps"] as Array:
		assert_true(int(s) >= 1 and int(s) <= levels)
	assert_true(((b["start"] as Dictionary)["tools"] as Array).has({"base": "unique_sickle"}))
	var ids: Array[String] = []
	for s: Dictionary in _json("res://data/config/stats.json")["stats"] as Array:
		ids.append(s["id"])
		if ["node_units_pct", "node_rich_pct", "byproduct_chance_pct"].has(s["id"]):
			assert_false(String(s["formula"]).is_empty())
			assert_false(String(s["test"]).is_empty())
	for id: String in ["node_units_pct", "node_rich_pct", "byproduct_chance_pct"]:
		assert_true(ids.has(id), id)
