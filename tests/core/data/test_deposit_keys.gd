extends GutTest
## M12-01 data: `deposit.*` in balance.json, the `bag` item category, the shop without cost formulas, no bank/armory keys
## and no bank_slots/armory_slots stats (docs/04_DATA_SCHEMA.md §3, §5, §9, §20; F-100).

const V: GDScript = preload("res://tests/core/data/test_data_validator.gd")
const BAGS: String = "bags.json"


func _balance(raw: Dictionary) -> Dictionary:
	return V.file_of(raw, "balance", V.BALANCE)


func _bag(raw: Dictionary, index: int) -> Dictionary:
	return V.entry_of(raw, "items", BAGS, "items", index)


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


# --- real data ---------------------------------------------------------------------------------------------------

func test_real_balance_has_the_deposit_and_not_bank_or_armory() -> void:
	var data: GameData = TestFactory.real_data()
	assert_eq(int(data.balance_value("deposit.base_slots")), 60)
	assert_eq(int(data.balance_value("deposit.bag_slots")), 6)
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/config/balance.json"))
	assert_false(balance.has("bank"), "bank.* removed")
	assert_false(balance.has("armory"), "armory.* removed")
	assert_true(balance.has("deposit"))


func test_stats_without_bank_slots_and_armory_slots() -> void:
	var data: GameData = TestFactory.real_data()
	assert_false(data.stats.has(&"bank_slots"))
	assert_false(data.stats.has(&"armory_slots"))


func test_shop_without_slot_entries_and_formulas() -> void:
	var shop: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/shop/shop.json"))
	for entry: Dictionary in shop["entries"]:
		assert_ne(entry["id"], "bank_slot")
		assert_ne(entry["id"], "armory_slot")
		assert_false((entry["cost"] as Dictionary).has("formula"), str(entry["id"]))
		assert_ne(entry["vendor"], "deposito", str(entry["id"]))


func test_real_data_has_the_five_bags() -> void:
	var bags: Array[StringName] = []
	for item: ItemDef in TestFactory.real_data().items():
		if item.category == &"bag":
			bags.append(item.id)
	if bags.is_empty():
		pending("M12-05: the real bags (bags.json) arrive with the content task")
		return
	assert_eq(bags.size(), 5)


# --- fixtures ----------------------------------------------------------------------------------------------------

func test_fixtures_have_two_bags_with_their_slots() -> void:
	var data: GameData = TestFactory.fixture_data()
	assert_eq(data.item(&"test_bag_small").category, &"bag")
	assert_eq(data.item(&"test_bag_small").bag_slots, 6)
	assert_eq(data.item(&"test_bag_large").bag_slots, 10)
	assert_eq(data.item(&"test_log").bag_slots, 0, "other items have no bag slots")
	var count: int = 0
	for item: ItemDef in data.items():
		count += 1 if item.category == &"bag" else 0
	assert_eq(count, 2)


# --- validator: balance ------------------------------------------------------------------------------------------

func test_deposit_keys_are_required() -> void:
	for key: String in ["deposit.base_slots", "deposit.bag_slots"]:
		assert_true(DataValidator.REQUIRED_BALANCE_KEYS.has(key), key)
	for key: String in ["bank.base_slots", "bank.slot_cost_base", "armory.base_slots", "armory.slot_cost_cap"]:
		assert_false(DataValidator.REQUIRED_BALANCE_KEYS.has(key), key)


func test_old_bank_and_armory_keys_are_unknown() -> void:
	var raw: Dictionary = V.fixture_raw()
	_balance(raw)["bank"] = {"base_slots": 24}
	_expect(raw, [V.BALANCE, "unknown key 'bank'"])


func test_base_slots_must_be_at_least_one() -> void:
	var raw: Dictionary = V.fixture_raw()
	(_balance(raw)["deposit"] as Dictionary)["base_slots"] = 0
	_expect(raw, [V.BALANCE, "deposit", "base_slots", ">= 1"])


func test_bag_slots_are_at_most_twelve() -> void:
	var raw: Dictionary = V.fixture_raw()
	(_balance(raw)["deposit"] as Dictionary)["bag_slots"] = 13
	_expect(raw, [V.BALANCE, "deposit", "bag_slots", "<= 12"])
	var raw_zero: Dictionary = V.fixture_raw()
	(_balance(raw_zero)["deposit"] as Dictionary)["bag_slots"] = 0
	_expect(raw_zero, [V.BALANCE, "deposit", "bag_slots", ">= 1"])


# --- validator: bags ---------------------------------------------------------------------------------------------

func test_fixture_bags_are_valid() -> void:
	assert_eq(V.validate(V.fixture_raw()), PackedStringArray())


func test_bag_needs_its_slots_object() -> void:
	var raw: Dictionary = V.fixture_raw()
	_bag(raw, 0).erase("bag")
	_expect(raw, [BAGS, "item 'test_bag_small'", "bag"])


func test_bag_slots_range() -> void:
	var raw: Dictionary = V.fixture_raw()
	_bag(raw, 0)["bag"] = {"slots": 0}
	_bag(raw, 1)["bag"] = {"slots": 101}
	_expect(raw, [BAGS, "item 'test_bag_small'", "bag.slots", ">= 1"])
	_expect(raw, [BAGS, "item 'test_bag_large'", "bag.slots", "<= 100"])


func test_bag_value_must_be_zero() -> void:
	var raw: Dictionary = V.fixture_raw()
	_bag(raw, 0)["value"] = 5
	_expect(raw, [BAGS, "item 'test_bag_small'", "value 0"])


func test_bag_object_is_forbidden_on_other_categories() -> void:
	var raw: Dictionary = V.fixture_raw()
	var materials: Array = V.file_of(raw, "items", "materials.json")["items"] as Array
	(materials[0] as Dictionary)["bag"] = {"slots": 4}
	_expect(raw, ["materials.json", "field 'bag' is not allowed for category 'material'"])


func test_bag_file_must_hold_bags_only() -> void:
	var raw: Dictionary = V.fixture_raw()
	_bag(raw, 0)["category"] = "material"
	_expect(raw, [BAGS, "item 'test_bag_small'", "does not match its file"])
