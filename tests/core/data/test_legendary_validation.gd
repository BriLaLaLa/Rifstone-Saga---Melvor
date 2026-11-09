extends GutTest
## DataValidator, M14: legendaries (`equip.legendary`, F-120) and the Masterwork flag (docs/04_DATA_SCHEMA.md §21). The M14
## test content loads; one test per rule, on a broken copy of the fixture data plus the legendary pieces of
## tests/fixtures/data/m14 (the legendary tools need their skills and live in M14Data only).

const V: GDScript = preload("res://tests/core/data/test_data_validator.gd")
const M14Data := preload("res://tests/helpers/m14_data.gd")
const EFFECT_TYPES: Array[StringName] = [&"on_kill_timer_cut", &"block_heal_pct", &"kill_heal_pct", &"armor_pierce_pct",
	&"hit_cap_pct", &"stat_convert", &"double_hit_pct", &"execute_mult", &"monolith_loot_mult", &"gather_bonus_item",
	&"gather_grade_up_pct", &"byproduct_mult", &"card_drop_mult"]


func test_the_m14_content_loads_with_a_legendary_for_every_effect_type() -> void:
	var data: GameData = M14Data.data()
	assert_eq(data.errors, PackedStringArray())
	var seen: Dictionary[StringName, bool] = {}
	for def: ItemDef in data.legendaries():
		for effect: ItemEffectDef in def.equip.legendary.effects:
			seen[effect.type] = true
	for type: StringName in EFFECT_TYPES:
		assert_true(seen.has(type), "a legendary with %s" % type)


func test_legendaries_are_read_with_source_and_effects() -> void:
	var data: GameData = M14Data.data()
	var killheal: LegendaryInfo = data.item(&"fx_leg_killheal").equip.legendary
	assert_eq(killheal.source_type, &"boss")
	assert_eq(killheal.source_id, &"boss_grade_1")
	assert_eq(killheal.chance_pct, 100.0)
	assert_eq(killheal.effects.size(), 1)
	assert_eq(killheal.effects[0].type, &"kill_heal_pct")
	assert_eq(killheal.effects[0].params, {"pct": 2.0})
	var from_boss: Array[StringName] = []
	for def: ItemDef in data.legendaries_from(&"boss", &"boss_grade_2"):
		from_boss.append(def.id)
	assert_eq(from_boss, [&"fx_leg_pierce", &"fx_leg_cap", &"fx_leg_convert"] as Array[StringName], "in the order of the data")
	assert_eq(data.legendaries_from(&"monolith", &"nobody").size(), 0)
	assert_true(data.item(&"fx_leg_hatchet").equip.is_legendary_tool())
	assert_false(data.item(&"fx_leg_cap").equip.is_legendary_tool())
	assert_false(data.is_equipment_pool_base(&"fx_leg_cap"), "a legendary never drops from the pool")
	assert_true(data.is_equipment_pool_base(&"test_blade"))
	assert_false(data.is_equipment_pool_base(&"test_log"))


# --- rules --------------------------------------------------------------------------------------------------------

func _raw() -> Dictionary:
	var raw: Dictionary = V.fixture_raw()
	var equipment: Dictionary = V.file_of(raw, "items", "equipment.json")
	var extra: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/data/m14/equipment.json"))
	(equipment["items"] as Array).append_array(extra["items"] as Array)
	return raw


func _item(raw: Dictionary, id: String) -> Dictionary:
	for e: Variant in V.file_of(raw, "items", "equipment.json")["items"] as Array:
		if (e as Dictionary)["id"] == id:
			return e as Dictionary
	return {}


func _legendary(raw: Dictionary, id: String) -> Dictionary:
	return (_item(raw, id)["equip"] as Dictionary)["legendary"] as Dictionary


func _expect(raw: Dictionary, fragments: Array[String]) -> void:
	for message: String in V.validate(raw):
		var matched: bool = true
		for fragment: String in fragments:
			matched = matched and message.contains(fragment)
		if matched:
			assert_true(true)
			return
	fail_test("no error with %s in %s" % [fragments, V.validate(raw)])


func test_the_legendary_pieces_are_valid() -> void:
	assert_eq(V.validate(_raw()), PackedStringArray())


func test_a_legendary_needs_its_source_and_effects() -> void:
	var raw: Dictionary = _raw()
	_legendary(raw, "fx_leg_cap").erase("source")
	_legendary(raw, "fx_leg_pierce").erase("effects")
	_expect(raw, ["item 'fx_leg_cap'", "missing field 'equip.legendary.source'"])
	_expect(raw, ["item 'fx_leg_pierce'", "missing field 'equip.legendary.effects'"])


func test_a_legendary_with_no_effect_is_rejected() -> void:
	var raw: Dictionary = _raw()
	_legendary(raw, "fx_leg_cap")["effects"] = []
	_expect(raw, ["item 'fx_leg_cap'", "equip.legendary.effects"])


func test_the_source_must_exist_and_have_a_chance() -> void:
	var raw: Dictionary = _raw()
	_legendary(raw, "fx_leg_cap")["source"] = {"type": "boss", "id": "nobody", "chance_pct": 100}
	_legendary(raw, "fx_leg_pierce")["source"] = {"type": "monolith", "id": "nobody", "chance_pct": 100}
	_legendary(raw, "fx_leg_double")["source"] = {"type": "boss", "id": "boss_grade_3", "chance_pct": 0}
	_legendary(raw, "fx_leg_execute")["source"] = {"type": "shop", "id": "boss_grade_3", "chance_pct": 5}
	_expect(raw, ["item 'fx_leg_cap'", "unknown boss 'nobody'"])
	_expect(raw, ["item 'fx_leg_pierce'", "unknown Monolith 'nobody'"])
	_expect(raw, ["item 'fx_leg_double'", "equip.legendary.source.chance_pct"])
	_expect(raw, ["item 'fx_leg_execute'", "equip.legendary.source.type"])


func test_a_boss_has_at_most_five_legendaries() -> void:
	var raw: Dictionary = _raw()
	for id: String in ["fx_leg_blockheal", "fx_leg_killheal", "fx_leg_cap", "fx_leg_pierce", "fx_leg_convert", "fx_leg_double"]:
		_legendary(raw, id)["source"] = {"type": "boss", "id": "boss_grade_6", "chance_pct": 1}
	_expect(raw, ["boss 'boss_grade_6' has 6 legendaries, at most 5"])


func test_effect_parameters_are_checked_in_their_ranges() -> void:
	var raw: Dictionary = _raw()
	_legendary(raw, "fx_leg_cap")["effects"] = [{"type": "hit_cap_pct", "pct": 0}]
	_legendary(raw, "fx_leg_pierce")["effects"] = [{"type": "armor_pierce_pct", "pct": 120}]
	_legendary(raw, "fx_leg_double")["effects"] = [{"type": "double_hit_pct"}]
	_legendary(raw, "fx_leg_execute")["effects"] = [{"type": "execute_mult", "hp_pct": 30, "mult": 1}]
	_legendary(raw, "fx_leg_monolith")["effects"] = [{"type": "monolith_loot_mult", "mult": 11}]
	_legendary(raw, "fx_leg_cards")["effects"] = [{"type": "card_drop_mult", "mult": 2, "pct": 5}]
	_legendary(raw, "fx_leg_blockheal")["effects"] = [{"type": "mystery", "pct": 5}]
	_expect(raw, ["item 'fx_leg_cap'", "pct"])
	_expect(raw, ["item 'fx_leg_pierce'", "pct"])
	_expect(raw, ["item 'fx_leg_double'", "missing field", "pct"])
	_expect(raw, ["item 'fx_leg_execute'", "mult"])
	_expect(raw, ["item 'fx_leg_monolith'", "mult"])
	_expect(raw, ["item 'fx_leg_cards'", "pct"])
	_expect(raw, ["item 'fx_leg_blockheal'", "unknown effect type 'mystery'"])


func test_stat_convert_needs_two_different_existing_stats() -> void:
	var raw: Dictionary = _raw()
	_legendary(raw, "fx_leg_convert")["effects"] = [{"type": "stat_convert", "from": "armor", "to": "armor", "pct": 50}]
	_expect(raw, ["item 'fx_leg_convert'", "'from' and 'to' must differ"])
	_legendary(raw, "fx_leg_convert")["effects"] = [{"type": "stat_convert", "from": "nothing", "to": "armor", "pct": 50}]
	_expect(raw, ["item 'fx_leg_convert'", "equip.legendary.effects[0].from", "not in stats.json"])


func test_gathering_types_only_on_tools_and_the_loot_types_only_on_rings_and_amulets() -> void:
	var raw: Dictionary = _raw()
	_legendary(raw, "fx_leg_cap")["effects"] = [{"type": "byproduct_mult", "mult": 2}]
	_legendary(raw, "fx_leg_blockheal")["effects"] = [{"type": "card_drop_mult", "mult": 2}]
	_expect(raw, ["item 'fx_leg_cap'", "'byproduct_mult' needs a tool slot"])
	_expect(raw, ["item 'fx_leg_blockheal'", "'card_drop_mult' is only for a ring or an amulet"])


func test_a_legendary_can_be_sold_and_is_not_a_masterwork() -> void:
	var raw: Dictionary = _raw()
	_item(raw, "fx_leg_cap")["value"] = 0
	(_item(raw, "fx_leg_pierce")["equip"] as Dictionary)["masterwork"] = true
	_expect(raw, ["item 'fx_leg_cap'", "'value' >= 1"])
	_expect(raw, ["item 'fx_leg_pierce'", "not a tool or a legendary"])
