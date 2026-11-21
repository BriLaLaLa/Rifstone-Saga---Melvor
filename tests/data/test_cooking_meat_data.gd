extends GutTest
## M32-03 (docs/M32_CIBO.md decisions 1-3): ten raw meats, ten cooked foods, ten `cook_*` meat recipes without `discover`, meat drops
## only on the animal monsters of the right area. Reads the real JSON files.

const MEAT: Array[String] = ["plains_haunch", "wood_venison", "upland_game", "gallery_game", "marsh_fowl", "scorpion_pulp", "hound_cut",
	"serpent_fillet", "coral_tentacle", "leech_pulp"]
const LEVELS: Array[int] = [1, 10, 20, 30, 40, 50, 60, 70, 80, 90]
const HEALS: Array[int] = [20, 35, 55, 80, 95, 123, 150, 183, 220, 260]


func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary


func _by_id(list: Array) -> Dictionary:
	var out: Dictionary = {}
	for e: Dictionary in list:
		out[e["id"]] = e
	return out


func test_raw_meat_and_cooked_food_exist_with_the_heal_scale() -> void:
	var mats: Dictionary = _by_id(_json("res://data/items/materials.json")["items"] as Array)
	var food: Dictionary = _by_id(_json("res://data/items/food.json")["items"] as Array)
	for i: int in MEAT.size():
		assert_true(mats.has(MEAT[i]), MEAT[i])
		assert_eq((mats[MEAT[i]] as Dictionary)["category"], "material")
		var cooked: Dictionary = food["cooked_" + MEAT[i]] as Dictionary
		assert_eq(int((cooked["food"] as Dictionary)["heal"]), HEALS[i], "heal of " + MEAT[i])
		assert_true(FileAccess.file_exists(cooked["icon"] as String), "icon of " + MEAT[i])
		assert_true(FileAccess.file_exists((mats[MEAT[i]] as Dictionary)["icon"] as String), "icon of raw " + MEAT[i])


func test_meat_recipes_have_levels_reagents_and_no_discover() -> void:
	var acts: Dictionary = _by_id(_json("res://data/actions/hearthcraft.json")["actions"] as Array)
	for i: int in MEAT.size():
		var a: Dictionary = acts["cook_" + MEAT[i]] as Dictionary
		assert_eq(int(a["level"]), LEVELS[i])
		assert_eq(int(a["interval_ms"]), 2500)
		assert_false(a.has("discover"), "meat recipes are always available")
		var inputs: Array = a["inputs"] as Array
		assert_eq((inputs[0] as Dictionary)["item"], MEAT[i])
		assert_eq(inputs.size(), 1 if LEVELS[i] == 1 else 2)
		assert_eq(((a["outputs"] as Array)[0] as Dictionary)["item"], "cooked_" + MEAT[i])
	for id: String in acts:
		if id.begins_with("brew_tonic_"):
			assert_true(acts[id].get("discover", false), id + " stays to be discovered")


func test_meat_drops_only_from_animals_and_at_least_one_per_area() -> void:
	var areas: Array = _json("res://data/combat/areas.json")["areas"] as Array
	var monsters: Dictionary = _by_id(_json("res://data/combat/monsters.json")["monsters"] as Array)
	for i: int in areas.size():
		var carriers: int = 0
		for pack: Dictionary in (areas[i] as Dictionary)["packs"]:
			for id: String in pack["monsters"]:
				for d: Dictionary in (monsters[id] as Dictionary)["drops"]:
					if d["item"] == MEAT[i]:
						carriers += 1
		assert_gt(carriers, 0, "area %d has a meat carrier in its packs" % i)
	for id: String in monsters:
		for d: Dictionary in (monsters[id] as Dictionary)["drops"]:
			if MEAT.has(d["item"] as String):
				assert_between(float(d["chance_pct"]), 30.0, 50.0, id)
	for id: String in ["plains_boar", "ember_rat"]:
		var has_meat: bool = false
		for d: Dictionary in (monsters[id] as Dictionary)["drops"]:
			has_meat = has_meat or d["item"] == "plains_haunch"
		assert_true(has_meat, id + " drops meat in the first kills")
	for id: String in ["crack_golem", "redrock_raider", "rift_knight", "shard_wraith", "hollow_archer"]:
		for d: Dictionary in (monsters[id] as Dictionary)["drops"]:
			assert_false(MEAT.has(d["item"] as String), id + " is not an animal")
