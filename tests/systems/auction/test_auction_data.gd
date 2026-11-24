extends GutTest
## Data of the Auction House (docs/04_DATA_SCHEMA.md §28): the parameters, the generated list, the validator rules and the
## cases it rejects. The rejected cases change the parsed real data in memory (a village building is appended where the rule needs one).

const AuctionTestData := preload("res://tests/systems/auction/auction_test_data.gd")
const ITEMS_PATH: String = "res://data/auction/auction_items.json"
const BUILDINGS_PATH: String = "res://data/village/buildings.json"


# Errors of the real data with `change` applied to the parsed raw data.
func _errors(change: Callable) -> PackedStringArray:
	var raw: Dictionary = {}
	var errors: PackedStringArray = []
	raw["balance"] = DataBuildUtil.read_files(["res://data/config/balance.json"], errors)
	raw["stats"] = DataBuildUtil.read_files(["res://data/config/stats.json"], errors)
	for section: String in GameData.CONTENT_FILES:
		raw[section] = DataBuildUtil.read_files(["res://data".path_join(GameData.CONTENT_FILES[section])], errors)
	for section: String in GameData.CONTENT_DIRS:
		raw[section] = DataBuildUtil.read_files(JsonLoader.list_json_files("res://data".path_join(GameData.CONTENT_DIRS[section]), errors), errors)
	raw["guide"] = DataBuildUtil.read_files(DataValidatorGuide.list_files("res://data", errors), errors)
	raw["dungeons"] = DataBuildUtil.read_files(DungeonIndex.list_files("res://data", errors), errors)
	raw["encounters"] = DataBuildUtil.read_files(DisciplineIndex.nodes_files("res://data"), errors)
	change.call(raw)
	var found: PackedStringArray = []
	DataValidator.validate(raw, found)
	return found


func _with_building(raw: Dictionary, extra: Array = []) -> Array:
	var buildings: Array = (raw["village"][BUILDINGS_PATH] as Dictionary)["buildings"] as Array
	for more: Variant in extra:
		buildings.append(more)
	return buildings


func _balance(raw: Dictionary) -> Dictionary:
	return (raw["balance"]["res://data/config/balance.json"] as Dictionary)["auction"] as Dictionary


func _mentions(errors: PackedStringArray, text: String) -> bool:
	for message: String in errors:
		if message.contains(text):
			return true
	return false


func test_the_real_data_is_valid_and_has_the_list() -> void:
	assert_eq(_errors(func(_raw: Dictionary) -> void: pass), PackedStringArray())
	var data: GameData = TestFactory.real_data()
	assert_eq(data.auction_items().size(), 130)
	var buyable: int = 0
	var per_step: Dictionary = {}
	for def: AuctionItemDef in data.auction_items():
		if def.buy_level > 0:
			buyable += 1
			per_step[def.buy_level] = int(per_step.get(def.buy_level, 0)) + 1
	assert_eq(buyable, 58)
	assert_eq(per_step, {1: 7, 2: 7, 3: 7, 4: 8, 5: 7, 6: 8, 7: 7, 8: 7})
	assert_eq(data.auction_items()[0].item, &"redbirch_log", "materials first")
	assert_eq(data.auction_item(&"riftite_plate").buy_level, 8)
	assert_null(data.auction_item(&"test_unknown"))
	assert_null(data.auction_item(&"coins"), "not an item of the list")


func test_the_file_equals_the_regeneration() -> void:
	var generated: Array[Dictionary] = _generated()
	var written: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ITEMS_PATH)) as Dictionary
	assert_eq((written["items"] as Array).size(), generated.size())
	for i: int in generated.size():
		assert_eq(str(((written["items"] as Array)[i] as Dictionary)["item"]), generated[i]["item"], "entry %d" % i)
		assert_eq(int(((written["items"] as Array)[i] as Dictionary)["buy_level"]), generated[i]["buy_level"], "entry %d" % i)
	assert_eq(FileAccess.get_file_as_string(ITEMS_PATH), DataValidatorAuction.file_text(generated), "byte for byte")


func test_the_generator_tool_delegates_to_the_rule() -> void:
	var gen: GDScript = load("res://tools/gen_auction.gd") as GDScript
	var from_tool: Array = gen.call("entries", _all("res://data/items", "items"), _all("res://data/actions", "actions"),
			TestFactory.real_data().balance_value("village.woodwright_levels")) as Array
	assert_eq(from_tool.size(), 130)


func test_generation_rule_on_a_small_table() -> void:
	var items: Array = [
		{"id": "b_food", "category": "food", "sort_order": 5, "value": 4},
		{"id": "z_ore", "category": "material", "sort_order": 2, "value": 1},
		{"id": "a_ore", "category": "material", "sort_order": 2, "value": 2},
		{"id": "free", "category": "material", "sort_order": 1, "value": 0},
		{"id": "plate", "category": "component", "sort_order": 1, "value": 7},
		{"id": "sword", "category": "equipment", "sort_order": 1, "value": 9},
	]
	var actions: Array = [{"id": "cook", "level": 10, "outputs": [{"item": "b_food", "qty": 1}]},
			{"id": "forge", "level": 1, "outputs": [{"item": "plate", "qty": 1}]}]
	var result: Dictionary = DataValidatorAuction.build(items, actions, [1, 10, 20])
	assert_eq(result["errors"], PackedStringArray())
	assert_eq(result["entries"], [{"item": "a_ore", "buy_level": 0}, {"item": "z_ore", "buy_level": 0},
			{"item": "plate", "buy_level": 1}, {"item": "b_food", "buy_level": 2}] as Array[Dictionary],
			"by category, sort_order, id; value 0 and equipment left out")
	var unproduced: Dictionary = DataValidatorAuction.build(items, [], [1, 10, 20])
	assert_eq((unproduced["errors"] as PackedStringArray).size(), 2, "a component and a food nobody produces")
	var off_tier: Dictionary = DataValidatorAuction.build(items, [{"id": "forge", "level": 0, "outputs": [{"item": "plate", "qty": 1}]}], [1, 10, 20])
	assert_true(_mentions(off_tier["errors"] as PackedStringArray, "woodwright_levels"))
	var lenient: Dictionary = DataValidatorAuction.build(items, [], [1, 10, 20], false)
	assert_eq(lenient["errors"], PackedStringArray())
	assert_eq((lenient["entries"] as Array).size(), 4, "loose components are sell-only")


func test_no_buyable_item_is_an_action_input() -> void:
	var data: GameData = TestFactory.real_data()
	var buyable: Dictionary = {}
	for def: AuctionItemDef in data.auction_items():
		buyable[def.item] = def.buy_level > 0
	for action: ActionDef in _all_actions(data):
		for input: ItemQty in action.inputs:
			assert_false(buyable.get(input.item_id, false), "%s: %s" % [action.id, input.item_id])


func test_a_building_with_unlocks_auction_is_accepted() -> void:
	assert_eq(_errors(func(raw: Dictionary) -> void: _with_building(raw)), PackedStringArray())
	var data: GameData = AuctionTestData.data()
	assert_true(data.village_building(&"auction_house").unlocks_auction)
	assert_eq(data.village_building(&"auction_house").levels.size(), 8)
	assert_eq((data.village_building(&"auction_house").levels[0] as Dictionary)["effect_value"], 0.0)



func test_rejects_a_ceiling_below_the_equilibrium() -> void:
	var errors: PackedStringArray = _errors(func(raw: Dictionary) -> void: ((_balance(raw))["index"] as Dictionary)["max_pct"] = 120)
	assert_true(_mentions(errors, "max_pct"), str(errors))


func test_rejects_a_minimum_above_the_lowest_equilibrium_and_a_short_saturation() -> void:
	var errors: PackedStringArray = _errors(func(raw: Dictionary) -> void: ((_balance(raw))["index"] as Dictionary)["min_pct"] = 110)
	assert_true(_mentions(errors, "min_pct"), str(errors))
	errors = _errors(func(raw: Dictionary) -> void: ((_balance(raw))["saturation"] as Dictionary)["max_pct"] = 10)
	assert_true(_mentions(errors, "saturation.max_pct"), str(errors))


func test_rejects_unknown_keys_and_a_missing_section() -> void:
	var errors: PackedStringArray = _errors(func(raw: Dictionary) -> void: (_balance(raw))["invented"] = 1)
	assert_true(_mentions(errors, "invented"), str(errors))
	errors = _errors(func(raw: Dictionary) -> void: ((_balance(raw))["trend"] as Dictionary)["invented"] = 1)
	assert_true(_mentions(errors, "invented"), str(errors))
	errors = _errors(func(raw: Dictionary) -> void: (raw["balance"]["res://data/config/balance.json"] as Dictionary).erase("auction"))
	assert_true(_mentions(errors, "missing key 'auction'"), str(errors))


func test_rejects_a_saturation_step_below_one_ppm() -> void:
	var errors: PackedStringArray = _errors(func(raw: Dictionary) -> void: ((_balance(raw))["saturation"] as Dictionary)["per_unit_pct"] = 0.00001)
	assert_true(_mentions(errors, "per_unit_pct"), str(errors))


func test_rejects_a_buy_level_on_a_material() -> void:
	var errors: PackedStringArray = _errors(func(raw: Dictionary) -> void:
		((raw["auction"][ITEMS_PATH] as Dictionary)["items"] as Array)[0]["buy_level"] = 1)
	assert_true(_mentions(errors, "buy_level"), str(errors))


func test_rejects_a_file_that_differs_from_the_regeneration() -> void:
	var errors: PackedStringArray = _errors(func(raw: Dictionary) -> void:
		((raw["auction"][ITEMS_PATH] as Dictionary)["items"] as Array).pop_back())
	assert_true(_mentions(errors, "regeneration"), str(errors))
	errors = _errors(func(raw: Dictionary) -> void:
		((raw["auction"][ITEMS_PATH] as Dictionary)["items"] as Array).reverse())
	assert_true(_mentions(errors, "regeneration"), str(errors))


func test_rejects_a_buyable_item_used_as_an_action_input() -> void:
	var errors: PackedStringArray = _errors(func(raw: Dictionary) -> void:
		for path: Variant in raw["actions"]:
			var list: Array = (raw["actions"][path] as Dictionary)["actions"] as Array
			if str((raw["actions"][path] as Dictionary).get("skill")) == "forging":
				((list[0] as Dictionary)["inputs"] as Array).append({"item": "redbirch_grip", "qty": 1})
				return)
	assert_true(_mentions(errors, "can be bought but is an input"), str(errors))


func test_rejects_two_buildings_with_unlocks_auction() -> void:
	var errors: PackedStringArray = _errors(func(raw: Dictionary) -> void:
		var second: Dictionary = AuctionTestData.building(TestFactory.real_data())
		second["id"] = "auction_annex"
		second["order"] = 9
		second["map_pos"] = [0.10, 0.05]
		_with_building(raw, [second]))
	assert_true(_mentions(errors, "exactly one"), str(errors))


func test_rejects_unlocks_auction_with_unlocks_shop_or_an_effect() -> void:
	var errors: PackedStringArray = _errors(func(raw: Dictionary) -> void:
		var buildings: Array = _with_building(raw)
		(buildings.back() as Dictionary)["unlocks_shop"] = true)
	assert_true(_mentions(errors, "exclude each other"), str(errors))
	errors = _errors(func(raw: Dictionary) -> void:
		var buildings: Array = _with_building(raw)
		(buildings.back() as Dictionary)["effect"] = {"stat": "quest_slots", "scope": "global", "per_level": 1})
	assert_true(_mentions(errors, "exclude each other"), str(errors))


func test_rejects_a_blueprint_below_the_margin() -> void:
	var errors: PackedStringArray = _errors(func(raw: Dictionary) -> void:
		_with_building(raw)
		for path: Variant in raw["items"]:
			for item: Variant in (raw["items"][path] as Dictionary).get("items", []) as Array:
				if (item as Dictionary).get("id") == "bp_mw_shield_14":
					for row: Variant in ((item as Dictionary)["blueprint"] as Dictionary)["inputs"] as Array:
						(row as Dictionary)["qty"] = 1)
	assert_true(_mentions(errors, "bp_mw_shield_14"), str(errors))


func test_the_real_blueprints_cost_more_than_their_piece_with_the_cheapest_parts() -> void:
	# The margin rule of F-151 with the purchase cost of F-217, on the real data.
	assert_eq(_errors(func(raw: Dictionary) -> void: _with_building(raw)), PackedStringArray())


func test_the_cost_of_a_part_follows_f217() -> void:
	var p: AuctionParams = TestFactory.real_data().auction_params()
	var eq_min: int = AuctionMath.eq_min(p, p.bands)
	assert_eq(DataValidatorAuctionBuy.part_cost(200, true, p, eq_min), 305, "ceil(floor(200 * 1,05) * 1,45)")
	assert_eq(DataValidatorAuctionBuy.part_cost(59500, true, p, eq_min), 90589)
	assert_eq(DataValidatorAuctionBuy.part_cost(200, false, p, eq_min), 200, "not buyable: its value")


func _generated() -> Array[Dictionary]:
	var data: GameData = TestFactory.real_data()
	return DataValidatorAuction.entries(_all("res://data/items", "items"), _all("res://data/actions", "actions"),
			data.balance_value("village.woodwright_levels") as Array)


func _all(dir: String, key: String) -> Array:
	var result: Array = []
	for file: String in DirAccess.get_files_at(dir):
		if file.ends_with(".json"):
			result.append_array((JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(file))) as Dictionary).get(key, []) as Array)
	return result


func _all_actions(data: GameData) -> Array[ActionDef]:
	var result: Array[ActionDef] = []
	for skill: SkillDef in data.skills():
		result.append_array(data.actions_for_skill(skill.id))
	return result


# --- M27-06: book, listings, stack (docs/04_DATA_SCHEMA_M27.md §32.3-§32.4, F-182) ---

func _bands(raw: Dictionary) -> Array:
	return (raw["auction_population"]["res://data/auction/population.json"] as Dictionary)["bands"] as Array


func _section(raw: Dictionary, key: String) -> Dictionary:
	return _balance(raw)[key] as Dictionary


func test_book_and_listing_parameters_of_the_real_data() -> void:
	var p: AuctionParams = TestFactory.real_data().auction_params()
	assert_eq([p.book_persist, p.book_sellers_per_listing, p.book_min_listings, p.book_max_listings, p.listing_max_active], [6, 10, 4, 12, 10])
	assert_eq(p.durations[2].id, &"long")
	assert_eq(p.durations[2].blocks, 576)
	assert_eq(p.durations[1].deposit_ppm, 20000)


func test_rejects_a_stack_that_is_zero_or_missing() -> void:
	var errors: PackedStringArray = _errors(func(raw: Dictionary) -> void: (_bands(raw)[0] as Dictionary)["stack"] = 0)
	assert_true(_mentions(errors, "stack"), str(errors))
	errors = _errors(func(raw: Dictionary) -> void: (_bands(raw)[1] as Dictionary).erase("stack"))
	assert_true(_mentions(errors, "stack"), str(errors))


func test_rejects_bad_book_values() -> void:
	var errors: PackedStringArray = _errors(func(raw: Dictionary) -> void: (_section(raw, "book"))["ask_max_pct"] = 0)
	assert_true(_mentions(errors, "ask_min_pct"), str(errors))
	errors = _errors(func(raw: Dictionary) -> void: (_section(raw, "book"))["fill_max_pct"] = 100)
	assert_true(_mentions(errors, "fill_max_pct"), str(errors))
	errors = _errors(func(raw: Dictionary) -> void: (_section(raw, "book"))["min_listings"] = 13)
	assert_true(_mentions(errors, "min_listings"), str(errors))
	errors = _errors(func(raw: Dictionary) -> void: (_section(raw, "book"))["invented"] = 1)
	assert_true(_mentions(errors, "invented"), str(errors))


func test_rejects_a_markup_that_allows_a_gain_without_risk() -> void:
	var errors: PackedStringArray = _errors(func(raw: Dictionary) -> void: (_section(raw, "buy"))["markup_pct"] = 40)
	assert_true(_mentions(errors, "F-217"), str(errors))
	errors = _errors(func(raw: Dictionary) -> void: (_section(raw, "buy"))["markup_pct"] = 43)
	assert_false(_mentions(errors, "F-217"), "43 % is the least allowed: " + str(errors))
	errors = _errors(func(raw: Dictionary) -> void: (_section(raw, "buy"))["markup_pct"] = 1000)
	assert_true(_mentions(errors, "markup_pct"), str(errors))
	errors = _errors(func(raw: Dictionary) -> void: (_section(raw, "buy"))["markup_pct"] = -1)
	assert_true(_mentions(errors, "markup_pct"), str(errors))


func test_rejects_a_book_ask_that_breaks_the_constraint() -> void:
	var errors: PackedStringArray = _errors(func(raw: Dictionary) -> void: (_section(raw, "book"))["ask_max_pct"] = 80)
	assert_true(_mentions(errors, "F-217"), str(errors))


func test_rejects_a_refill_that_does_not_empty_the_book_in_12_hours() -> void:
	var errors: PackedStringArray = _errors(func(raw: Dictionary) -> void: (_section(raw, "supply"))["refill_pct_per_block"] = 0.1)
	assert_true(_mentions(errors, "F-216"), str(errors))
	errors = _errors(func(raw: Dictionary) -> void: (_section(raw, "supply"))["refill_pct_per_block"] = 0)
	assert_true(_mentions(errors, "refill_pct_per_block"), str(errors))
	errors = _errors(func(raw: Dictionary) -> void: (_section(raw, "supply"))["refill_pct_per_block"] = 1.4)
	assert_true(_mentions(errors, "F-216"), "1,4 %: 2.400 pieces at 15 a block need 160 blocks: " + str(errors))


func test_rejects_a_bad_reference_window_and_confirmation() -> void:
	for window: Variant in [0, 201, 2.5]:
		var errors: PackedStringArray = _errors(func(raw: Dictionary) -> void: (_section(raw, "reference"))["window_epochs"] = window)
		assert_true(_mentions(errors, "window_epochs"), str(window) + str(errors))
	var errors2: PackedStringArray = _errors(func(raw: Dictionary) -> void: (_section(raw, "buy"))["confirm_share_pct"] = 0)
	assert_true(_mentions(errors2, "confirm_share_pct"), str(errors2))
	errors2 = _errors(func(raw: Dictionary) -> void: (_section(raw, "buy"))["confirm_share_pct"] = 101)
	assert_true(_mentions(errors2, "confirm_share_pct"), str(errors2))
	errors2 = _errors(func(raw: Dictionary) -> void: (_section(raw, "buy"))["confirm_premium_pct"] = -1)
	assert_true(_mentions(errors2, "confirm_premium_pct"), str(errors2))


func test_removed_keys_are_errors() -> void:
	var errors: PackedStringArray = _errors(func(raw: Dictionary) -> void:
		(raw["balance"]["res://data/config/balance.json"]["auction"] as Dictionary)["stock"] = {"gold": 1, "min": 1, "max": 1, "refill_pct_per_block": 1})
	assert_true(_mentions(errors, "stock"), str(errors))
	errors = _errors(func(raw: Dictionary) -> void: (_section(raw, "buy"))["spread_pct"] = 150)
	assert_true(_mentions(errors, "spread_pct"), str(errors))
	errors = _errors(func(raw: Dictionary) -> void: (_section(raw, "supply")).erase("refill_pct_per_block"))
	assert_gt(errors.size(), 0)



func test_rejects_bad_durations() -> void:
	var errors: PackedStringArray = _errors(func(raw: Dictionary) -> void:
		((_section(raw, "listing"))["durations"] as Array)[1]["id"] = "short")
	assert_true(_mentions(errors, "duplicate duration"), str(errors))
	errors = _errors(func(raw: Dictionary) -> void: (raw["balance"]["res://data/config/balance.json"]["auction"] as Dictionary)["block_ms"] = 420000)
	assert_true(_mentions(errors, "whole number of market blocks"), str(errors))
	errors = _errors(func(raw: Dictionary) -> void: (_section(raw, "listing"))["durations"] = [])
	assert_gt(errors.size(), 0)
	errors = _errors(func(raw: Dictionary) -> void: (_section(raw, "listing"))["cut_pct"] = 100)
	assert_true(_mentions(errors, "cut_pct"), str(errors))


func test_rejects_a_listed_item_worth_more_than_the_limit() -> void:
	var errors: PackedStringArray = _errors(func(raw: Dictionary) -> void:
		for path: Variant in raw["items"]:
			for e: Variant in (raw["items"][path] as Dictionary).get("items", []) as Array:
				if (e as Dictionary).get("id") == "redbirch_grip":
					(e as Dictionary)["value"] = 2000000)
	assert_true(_mentions(errors, "F-178"), str(errors))
