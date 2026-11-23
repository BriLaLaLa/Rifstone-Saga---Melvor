extends GutTest
## Real data: `resources` in data/encounters/nodes.json (docs/04_DATA_SCHEMA_M35B.md §36.1, F-201) read straight from the JSON files, plus
## reachability of the resources cited by quests (data/quests).

const SKILLS: Array[String] = ["forestry", "quarrying", "angling", "herbalism"]


func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary


## `{skill: {action_id: level}}` of data/actions.
func _levels() -> Dictionary:
	var result: Dictionary = {}
	for skill: String in SKILLS:
		var levels: Dictionary = {}
		for action: Variant in _json("res://data/actions/%s.json" % skill)["actions"] as Array:
			levels[(action as Dictionary)["id"]] = int((action as Dictionary)["level"])
		result[skill] = levels
	return result


func _reachable() -> Dictionary:
	var reached: Dictionary = {}
	for area: Variant in _json("res://data/encounters/nodes.json")["areas"] as Array:
		for node: Variant in (area as Dictionary)["nodes"] as Array:
			for entry: Variant in (node as Dictionary)["resources"] as Array:
				reached[(entry as Dictionary)["action"]] = true
	return reached


func test_every_node_has_ordered_percentage_resources_summing_to_100() -> void:
	var levels: Dictionary = _levels()
	for area: Variant in _json("res://data/encounters/nodes.json")["areas"] as Array:
		for node: Variant in (area as Dictionary)["nodes"] as Array:
			var skill: String = str((node as Dictionary)["skill"])
			var list: Array = (node as Dictionary).get("resources", []) as Array
			assert_false(list.is_empty(), "%s/%s resources" % [(area as Dictionary)["area"], skill])
			var sum: int = 0
			var last_level: int = 0
			var seen: Dictionary = {}
			for entry: Variant in list:
				var action: String = str((entry as Dictionary)["action"])
				assert_true((levels[skill] as Dictionary).has(action), "%s is not a %s action" % [action, skill])
				assert_false(seen.has(action), "%s duplicated" % action)
				seen[action] = true
				assert_gte(int((entry as Dictionary)["weight"]), 1)
				var level: int = int((levels[skill] as Dictionary).get(action, 0))
				assert_gt(level, last_level, "%s not in ascending level order" % action)
				last_level = level
				sum += int((entry as Dictionary)["weight"])
			assert_eq(sum, 100, "%s/%s sum" % [(area as Dictionary)["area"], skill])


func test_every_gathering_action_appears_in_some_zone() -> void:
	var reached: Dictionary = _reachable()
	var levels: Dictionary = _levels()
	for skill: String in SKILLS:
		for action: Variant in (levels[skill] as Dictionary):
			assert_true(reached.has(action), "%s is in no zone" % action)


func test_copper_is_dominant_in_zone_one() -> void:
	var first: Dictionary = (_json("res://data/encounters/nodes.json")["areas"] as Array)[0] as Dictionary
	assert_eq(first["area"], "redrock_plains")
	for node: Variant in first["nodes"] as Array:
		if (node as Dictionary)["skill"] == "quarrying":
			var top: Dictionary = ((node as Dictionary)["resources"] as Array)[0] as Dictionary
			assert_eq(top["action"], "quarry_emberbronze")
			assert_eq(int(top["weight"]), 79)


func test_resource_profile_is_in_balance() -> void:
	var profile: Array = (_json("res://data/config/balance.json")["encounters"] as Dictionary)["resource_profile"] as Array
	assert_eq(profile.size(), 4)


## Gathering quests: the item they ask for is made by an action that some zone offers, at a level the quest already requires.
func test_quest_gather_items_are_reachable() -> void:
	var by_item: Dictionary = {}
	for skill: String in SKILLS:
		for action: Variant in _json("res://data/actions/%s.json" % skill)["actions"] as Array:
			for output: Variant in (action as Dictionary).get("outputs", []) as Array:
				by_item[(output as Dictionary)["item"]] = {"skill": skill, "action": (action as Dictionary)["id"], "level": int((action as Dictionary)["level"])}
	var reachable: Dictionary = _reachable()
	var checked: int = 0
	for quest: Variant in _json("res://data/quests/quests.json")["quests"] as Array:
		if (quest as Dictionary).get("type", "") != "gather":
			continue
		var item: String = str((quest as Dictionary)["item"])
		assert_true(by_item.has(item), "%s: no gathering action produces %s" % [(quest as Dictionary)["id"], item])
		if by_item.has(item):
			var source: Dictionary = by_item[item] as Dictionary
			assert_true(reachable.has(source["action"]), "%s: %s is in no zone" % [(quest as Dictionary)["id"], source["action"]])
			var skills: Dictionary = ((quest as Dictionary).get("requires", {}) as Dictionary).get("skills", {}) as Dictionary
			assert_lte(int(source["level"]), int(skills.get(source["skill"], 1)), "%s asks for a lower level than the action needs" % (quest as Dictionary)["id"])
			checked += 1
	assert_gt(checked, 0)
