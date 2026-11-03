extends GutTest
## ItemInstance: duplicate, to_dict/from_dict round trip and rejection of invalid dictionaries.

var _data: GameData = TestFactory.fixture_data()


func _valid() -> Dictionary:
	return {
		"uid": 4, "base": "test_blade", "rarity": "rare", "ilvl": 30,
		"affixes": [{"affix": "test_keen", "tier": 2, "value": 9.0}, {"affix": "test_mighty", "tier": 2, "value": 8.0}],
		"upgrade": 2, "sockets": [], "locked": true,
	}


func test_round_trip() -> void:
	var inst: ItemInstance = ItemInstance.from_dict(_valid(), _data)
	assert_not_null(inst)
	assert_eq(inst.uid, 4)
	assert_eq(inst.affixes.size(), 2)
	assert_eq(inst.to_dict(), _valid())
	var json: Variant = JSON.parse_string(JSON.stringify(inst.to_dict()))
	assert_eq(ItemInstance.from_dict(json, _data).to_dict(), _valid())


func test_duplicate_is_independent() -> void:
	var inst: ItemInstance = ItemInstance.from_dict(_valid(), _data)
	var copy: ItemInstance = inst.duplicate_instance()
	copy.affixes[0].value = 1.0
	copy.locked = false
	assert_eq(inst.affixes[0].value, 9.0)
	assert_true(inst.locked)


func test_rejects_unknown_base() -> void:
	var d: Dictionary = _valid()
	d["base"] = "nope"
	assert_null(ItemInstance.from_dict(d, _data))
	d["base"] = "test_log"
	assert_null(ItemInstance.from_dict(d, _data), "not equipment")


func test_rejects_invalid_rarity() -> void:
	var d: Dictionary = _valid()
	d["rarity"] = "legendary"
	assert_null(ItemInstance.from_dict(d, _data))


func test_rejects_bad_affixes() -> void:
	var d: Dictionary = _valid()
	d["affixes"] = [{"affix": "test_nimble", "tier": 1, "value": 4.0}]
	assert_null(ItemInstance.from_dict(d, _data), "armour affix not allowed on a weapon")
	d["affixes"] = [{"affix": "test_keen", "tier": 1, "value": 4.0}, {"affix": "test_keen", "tier": 1, "value": 5.0}]
	assert_null(ItemInstance.from_dict(d, _data), "repeated")
	d["affixes"] = [{"affix": "test_keen", "tier": 4, "value": 4.0}]
	assert_null(ItemInstance.from_dict(d, _data), "tier out of range")
	d["affixes"] = [{"affix": "ghost", "tier": 1, "value": 4.0}]
	assert_null(ItemInstance.from_dict(d, _data), "unknown affix")
