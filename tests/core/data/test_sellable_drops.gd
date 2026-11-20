extends GutTest
## Every item that can drop is sellable (value >= 1), except the Cards (docs/DECISIONS_LOG.md V37, OPEN_QUESTIONS Q183):
## the cross-check of DataValidatorSellableDrops and the real data, up to `shop.sell`.

const V: GDScript = preload("res://tests/core/data/test_data_validator.gd")
const DATA: String = "res://data/"
const DROP_FILES: Array[String] = ["combat/monsters.json", "combat/rift_stones.json", "dungeons/monkey_den.json",
	"maps/bosses.json", "combat/loot_tables.json"]


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


# --- the rule on the fixtures ------------------------------------------------------------------------------------

func test_the_fixture_is_clean() -> void:
	assert_eq(V.validate(V.fixture_raw()), PackedStringArray())


func test_a_dropped_stone_with_value_zero_is_rejected() -> void:
	var raw: Dictionary = V.fixture_raw()
	V.entry_of(raw, "items", "stones.json", "items", 0)["value"] = 0
	_expect(raw, ["item 'test_stone'", "droppable item must have 'value' >= 1"])


func test_the_rift_shard_must_be_sellable() -> void:
	var raw: Dictionary = V.fixture_raw()
	V.entry_of(raw, "items", "misc.json", "items", 0)["value"] = 0
	_expect(raw, ["item 'rift_shard'", "droppable item must have 'value' >= 1"])


func test_a_currency_with_value_zero_is_rejected() -> void:
	var raw: Dictionary = V.fixture_raw()
	V.entry_of(raw, "items", "currencies.json", "items", 0)["value"] = 0
	_expect(raw, ["droppable item must have 'value' >= 1"])


func test_a_card_keeps_value_zero() -> void:
	assert_eq(V.validate(V.fixture_raw()), PackedStringArray())
	var card: Dictionary = V.entry_of(V.fixture_raw(), "items", "maps.json", "items", 0)
	assert_eq(int(card["value"]), 0)


# --- the real data -----------------------------------------------------------------------------------------------

func _read(path: String) -> Variant:
	var file: FileAccess = FileAccess.open(DATA + path, FileAccess.READ)
	assert_not_null(file, path)
	return JSON.parse_string(file.get_as_text())


func _dropped_ids() -> Dictionary[StringName, bool]:
	var ids: Dictionary[StringName, bool] = {&"rift_shard": true, &"rift_dust": true}
	for path: String in DROP_FILES:
		_collect_items(_read(path), ids)
	return ids


# Every "item" string of an entry of a `drops` array or of a loot table `entries` array, at any depth.
func _collect_items(node: Variant, ids: Dictionary[StringName, bool], in_drops: bool = false) -> void:
	if node is Dictionary:
		for key: Variant in node:
			var child: Variant = node[key]
			var drops: bool = in_drops or key == "drops" or key == "entries"
			if drops and key == "item" and child is String:
				ids[StringName(child as String)] = true
			_collect_items(child, ids, drops)
	elif node is Array:
		for child: Variant in node:
			_collect_items(child, ids, in_drops)


func test_every_dropped_item_of_the_real_data_is_sellable() -> void:
	var data: GameData = TestFactory.real_data()
	var ids: Dictionary[StringName, bool] = _dropped_ids()
	for item: ItemDef in data.items():
		if item.category == &"blueprint" or item.category == &"currency":
			ids[item.id] = true
	assert_gt(ids.size(), 100)
	var session: GameSession = TestFactory.session(1234, data)
	autofree(session)
	for id: StringName in ids:
		assert_true(data.has_item(id), "unknown dropped item %s" % id)
		var item: ItemDef = data.item(id)
		if item.category == &"map":
			assert_eq(item.value, 0, "a Card cannot be sold")
			continue
		assert_gte(item.value, 1, "%s drops but has value 0" % id)
		TestFactory.give(session, id, 1)
		assert_true(session.shop.sell(id, 1).ok, "%s cannot be sold" % id)
