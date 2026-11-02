extends GutTest
## DataValidator, part 3: mastery nodes (04_DATA_SCHEMA.md §7), areas and monsters (§8), shop (§9). One test per
## rule, on a broken copy of the fixture data; helpers from test_data_validator.gd.

const V: GDScript = preload("res://tests/core/data/test_data_validator.gd")
const MASTERY: String = "test_gather.json"
const AREAS: String = "areas.json"
const MONSTERS: String = "monsters.json"
const SHOP: String = "shop.json"


func _expect(raw: Dictionary, fragments: Array[String]) -> void:
	var errors: PackedStringArray = V.validate(raw)
	for message: String in errors:
		var matched: bool = true
		for fragment: String in fragments:
			matched = matched and message.contains(fragment)
		if matched:
			assert_true(true)
			return
	fail_test("no error with %s in %s" % [fragments, errors])


func _node(raw: Dictionary, index: int) -> Dictionary:
	return V.entry_of(raw, "mastery", MASTERY, "nodes", index)


func _monster(raw: Dictionary, index: int) -> Dictionary:
	return V.entry_of(raw, "monsters", MONSTERS, "monsters", index)


func _shop(raw: Dictionary, index: int) -> Dictionary:
	return V.entry_of(raw, "shop", SHOP, "entries", index)


func _add_mastery_file(raw: Dictionary, skill: String, nodes: Array) -> void:
	raw["mastery"][V.FIXTURE_ROOT.path_join("mastery/%s.json" % skill)] = {"skill": skill, "nodes": nodes}


# --- mastery -----------------------------------------------------------------------------------------------------

func test_mastery_file_skill_must_have_mastery() -> void:
	var raw: Dictionary = V.fixture_raw()
	_add_mastery_file(raw, "riftbinding", [])
	_expect(raw, ["riftbinding.json", "skill 'riftbinding' has no mastery"])


func test_mastery_file_skill_must_match_the_file_name() -> void:
	var raw: Dictionary = V.fixture_raw()
	V.file_of(raw, "mastery", MASTERY)["skill"] = "test_craft"
	_expect(raw, [MASTERY, "skill 'test_craft' must be equal to the file name"])


func test_mastery_node_id_has_the_skill_prefix() -> void:
	var raw: Dictionary = V.fixture_raw()
	_node(raw, 0)["id"] = "quick_hands"
	_expect(raw, [MASTERY, "mastery node 'quick_hands'", "id must start with 'test_gather_'"])


func test_mastery_node_ids_are_unique_across_files() -> void:
	var raw: Dictionary = V.fixture_raw()
	var copy: Dictionary = _node(raw, 0).duplicate(true)
	copy["requires"] = []
	_add_mastery_file(raw, "test_craft", [copy])
	_expect(raw, ["test_craft.json", "mastery node 'test_gather_n1'", "duplicate mastery node 'test_gather_n1'"])


func test_mastery_cost_is_above_0_and_at_most_50() -> void:
	var raw: Dictionary = V.fixture_raw()
	_node(raw, 0)["cost_pct"] = 0
	_node(raw, 1)["cost_pct"] = 50.5
	_expect(raw, [MASTERY, "mastery node 'test_gather_n1'", "field 'cost_pct' must be > 0 and <= 50"])
	_expect(raw, [MASTERY, "mastery node 'test_gather_n2'", "field 'cost_pct' must be > 0 and <= 50"])


func test_mastery_pos_is_in_the_grid() -> void:
	var raw: Dictionary = V.fixture_raw()
	_node(raw, 0)["pos"] = [0, 6]
	_expect(raw, [MASTERY, "mastery node 'test_gather_n1'", "field 'pos' must be [a, b] with integers in 0..5"])


func test_mastery_pos_is_unique_in_the_skill() -> void:
	var raw: Dictionary = V.fixture_raw()
	_node(raw, 1)["pos"] = [0, 0]
	_expect(raw, [MASTERY, "mastery node 'test_gather_n2'", "is already used in this skill"])


func test_mastery_requires_must_exist() -> void:
	var raw: Dictionary = V.fixture_raw()
	_node(raw, 1)["requires"] = ["test_gather_n9"]
	_expect(raw, [MASTERY, "mastery node 'test_gather_n2'", "unknown mastery node 'test_gather_n9'"])


func test_mastery_requires_must_be_of_the_same_skill() -> void:
	var raw: Dictionary = V.fixture_raw()
	_add_mastery_file(raw, "test_craft", [{"id": "test_craft_n1", "name": "N", "description": "D", "cost_pct": 5,
			"requires": ["test_gather_n1"], "pos": [0, 0], "modifiers": []}])
	_expect(raw, ["test_craft.json", "mastery node 'test_craft_n1'", "node 'test_gather_n1' belongs to another skill"])


func test_mastery_requires_have_no_cycles() -> void:
	var raw: Dictionary = V.fixture_raw()
	_node(raw, 0)["requires"] = ["test_gather_n3"]
	_expect(raw, [MASTERY, "mastery node 'test_gather_n1'", "is part of a cycle"])
	_expect(raw, [MASTERY, "mastery node 'test_gather_n3'", "is part of a cycle"])


func test_mastery_node_modifier_scope_is_checked() -> void:
	var raw: Dictionary = V.fixture_raw()
	((_node(raw, 1)["modifiers"] as Array)[0] as Dictionary)["scope"] = "action:missing_action"
	_expect(raw, [MASTERY, "mastery node 'test_gather_n2'", "points to an unknown action"])


# --- areas and monsters ------------------------------------------------------------------------------------------

func test_area_needs_known_monsters() -> void:
	var raw: Dictionary = V.fixture_raw()
	var area: Dictionary = V.entry_of(raw, "areas", AREAS, "areas", 0)
	area["monsters"] = ["test_monster_a", "dragon"]
	_expect(raw, [AREAS, "area 'test_area'", "field 'monsters': unknown monster 'dragon'"])
	area["monsters"] = []
	_expect(raw, [AREAS, "area 'test_area'", "field 'monsters' needs at least 1 entries"])


func test_area_order_is_unique_and_requirements_are_checked() -> void:
	var raw: Dictionary = V.fixture_raw()
	var areas: Array = V.file_of(raw, "areas", AREAS)["areas"] as Array
	var second: Dictionary = (areas[0] as Dictionary).duplicate(true)
	second["id"] = "test_area_b"
	second["requirements"] = {"guard": 0}
	areas.append(second)
	_expect(raw, [AREAS, "area 'test_area_b'", "duplicate order 1"])
	_expect(raw, [AREAS, "area 'test_area_b'", "field 'requirements.guard' must be >= 1"])


func test_monster_numbers_are_in_range() -> void:
	var raw: Dictionary = V.fixture_raw()
	var m: Dictionary = _monster(raw, 0)
	m["hp"] = 0
	m["attack_interval_ms"] = 700
	m["defence_level"] = 100
	m["evasion_bonus"] = -1
	m["damage_reduction"] = 81
	m["rift_shard_chance"] = 101
	for fragment: String in ["field 'hp' must be >= 1", "field 'attack_interval_ms' must be >= 800",
			"field 'defence_level' must be >= 1 and <= 99", "field 'evasion_bonus' must be >= 0",
			"field 'damage_reduction' must be >= 0 and <= 80", "field 'rift_shard_chance' must be >= 0 and <= 100"]:
		_expect(raw, [MONSTERS, "monster 'test_monster_a'", fragment])


func test_monster_style_and_icon() -> void:
	var raw: Dictionary = V.fixture_raw()
	_monster(raw, 0)["style"] = "claws"
	_monster(raw, 0)["icon"] = "res://assets/icons/items/boar.png"
	_expect(raw, [MONSTERS, "monster 'test_monster_a'", "field 'style' must be one of"])
	_expect(raw, [MONSTERS, "monster 'test_monster_a'", "must be a path under res://assets/icons/monsters/"])


func test_monster_gold_is_an_ordered_range() -> void:
	var raw: Dictionary = V.fixture_raw()
	_monster(raw, 0)["gold"] = [5, 2]
	_expect(raw, [MONSTERS, "monster 'test_monster_a'", "field 'gold' must be [a, b] with 0 <= min <= max"])


func test_monster_drops_are_checked() -> void:
	var raw: Dictionary = V.fixture_raw()
	var drop: Dictionary = (_monster(raw, 0)["drops"] as Array)[0] as Dictionary
	drop["item"] = "boar_tusk"
	drop["chance_pct"] = 120
	drop["qty"] = [0, 1]
	_expect(raw, [MONSTERS, "monster 'test_monster_a'", "field 'drops[0].item': unknown item 'boar_tusk'"])
	_expect(raw, [MONSTERS, "monster 'test_monster_a'", "field 'drops[0].chance_pct' must be >= 0 and <= 100"])
	_expect(raw, [MONSTERS, "monster 'test_monster_a'", "field 'drops[0].qty' must be [a, b] with 1 <= min"])


func test_monster_has_at_most_4_drops() -> void:
	var raw: Dictionary = V.fixture_raw()
	var drops: Array = _monster(raw, 0)["drops"] as Array
	for i: int in 4:
		drops.append((drops[0] as Dictionary).duplicate(true))
	_expect(raw, [MONSTERS, "monster 'test_monster_a'", "field 'drops' has 5 entries, at most 4"])


# --- shop --------------------------------------------------------------------------------------------------------

func test_shop_category_must_be_known() -> void:
	var raw: Dictionary = V.fixture_raw()
	_shop(raw, 0)["category"] = "lanes"
	_expect(raw, [SHOP, "shop entry 'bank_slot'", "field 'category' must be one of"])


func test_shop_cost_needs_exactly_one_of_gold_and_formula() -> void:
	var raw: Dictionary = V.fixture_raw()
	_shop(raw, 0)["cost"] = {"formula": "bank_slot", "gold": 10}
	_shop(raw, 1)["cost"] = {}
	_expect(raw, [SHOP, "shop entry 'bank_slot'", "field 'cost' needs exactly one of 'gold' and 'formula'"])
	_expect(raw, [SHOP, "shop entry 'test_upgrade_1'", "field 'cost' needs exactly one of 'gold' and 'formula'"])


func test_shop_cost_values_are_checked() -> void:
	var raw: Dictionary = V.fixture_raw()
	_shop(raw, 0)["cost"] = {"formula": "bank_slot_v2"}
	_shop(raw, 1)["cost"] = {"gold": 0}
	_expect(raw, [SHOP, "shop entry 'bank_slot'", "field 'cost.formula' must be one of"])
	_expect(raw, [SHOP, "shop entry 'test_upgrade_1'", "field 'cost.gold' must be >= 1"])


func test_shop_unlimited_purchases_only_for_item_effects() -> void:
	var raw: Dictionary = V.fixture_raw()
	_shop(raw, 1)["max_purchases"] = 0
	_expect(raw, [SHOP, "shop entry 'test_upgrade_1'", "'max_purchases' can be 0 (unlimited) only for item effects"])


func test_shop_requires_are_checked() -> void:
	var raw: Dictionary = V.fixture_raw()
	_shop(raw, 2)["requires"] = {"entries": ["test_upgrade_0"], "skills": {"sorcery": 5}, "total_level": -1,
			"gold": 5}
	for fragment: String in ["field 'requires.entries': unknown shop entry 'test_upgrade_0'",
			"field 'requires.skills.sorcery': unknown skill", "field 'requires.total_level' must be >= 0",
			"unknown field 'requires.gold'"]:
		_expect(raw, [SHOP, "shop entry 'test_upgrade_2'", fragment])


func test_shop_effect_needs_exactly_one_of_modifiers_and_item() -> void:
	var raw: Dictionary = V.fixture_raw()
	(_shop(raw, 3)["effect"] as Dictionary)["modifiers"] = []
	_expect(raw, [SHOP, "shop entry 'test_buy_hatchet'", "field 'effect' needs exactly one of 'modifiers' and 'item'"])


func test_shop_item_effect_needs_a_known_item() -> void:
	var raw: Dictionary = V.fixture_raw()
	(_shop(raw, 3)["effect"] as Dictionary)["item"] = {"item": "golden_hatchet", "qty": 1}
	_expect(raw, [SHOP, "shop entry 'test_buy_hatchet'", "field 'effect.item.item': unknown item 'golden_hatchet'"])
