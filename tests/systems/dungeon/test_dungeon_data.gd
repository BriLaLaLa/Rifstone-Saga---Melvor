extends GutTest
## The data of the dungeons (docs/04_DATA_SCHEMA.md §27): the Defs built from the fixture dungeon and the rules of
## DataValidatorDungeon (each test breaks one thing in a copy of the fixture data and expects the error), the area
## `miniboss` and the tickets. The real data (the Monkey Den) is checked in tests/data/test_dungeon_data.gd.

const V: GDScript = preload("res://tests/core/data/test_data_validator.gd")
const DEN_PATH: String = "res://tests/fixtures/data/dungeons/test_den.json"
const TICKET: String = "test_den_ticket"


func _raw() -> Dictionary:
	var raw: Dictionary = V.fixture_raw()
	raw["dungeons"] = {DEN_PATH: JSON.parse_string(FileAccess.get_file_as_string(DEN_PATH))}
	return raw


func _den(raw: Dictionary) -> Dictionary:
	return (raw["dungeons"] as Dictionary)[DEN_PATH] as Dictionary


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


func _area_entries(raw: Dictionary) -> Array:
	return V.file_of(raw, "areas", "areas.json")["areas"] as Array


# Every area gets its own miniboss monster (a copy of test_monster_a marked `miniboss`, in no pack).
func _with_minibosses(raw: Dictionary) -> void:
	var monsters: Array = V.file_of(raw, "monsters", "monsters.json")["monsters"] as Array
	var model: Dictionary = monsters[0] as Dictionary
	var areas: Array = _area_entries(raw)
	for index: int in areas.size():
		var copy: Dictionary = model.duplicate(true)
		copy["id"] = "mb_%d" % index
		copy["miniboss"] = true
		copy["drops"] = []
		monsters.append(copy)
		(areas[index] as Dictionary)["miniboss"] = {"monster": "mb_%d" % index, "escorts": 2}


# --- the Defs ------------------------------------------------------------------------------------------------------

func test_fixtures_with_the_dungeon_are_valid() -> void:
	assert_eq(V.validate(_raw()), PackedStringArray())


func test_the_dungeon_is_built() -> void:
	var data: GameData = TestFactory.fixture_data()
	assert_eq(data.dungeons().size(), 1)
	var def: DungeonDef = data.dungeon(&"test_den")
	assert_not_null(def)
	assert_eq(def.name, "Covo di prova")
	assert_eq(def.req_character, 35)
	assert_eq(def.recommended_level, 45)
	assert_eq(def.forks, 5)
	assert_eq(def.width_weights, [3, 4, 3] as Array[int])
	assert_eq(def.exit_weights, [5, 3, 2] as Array[int])
	assert_almost_eq(def.hint_pct, 45.0, 1e-9)
	assert_eq(def.room_types.size(), 6)
	assert_eq(def.trap_kinds.size(), 3)
	assert_eq(def.boss_gold, Vector2i(3000, 5000))
	assert_eq(def.boss_pieces.size(), 2)
	assert_eq(def.boss_pieces[0], {"rarity": &"rare"})
	assert_eq(def.boss_pieces[1], {"min_rarity": &"magic"})
	assert_eq(def.loot_table, &"test_monster_loot")


func test_the_ticket_finds_its_dungeon() -> void:
	var data: GameData = TestFactory.fixture_data()
	assert_eq(data.dungeon_for_ticket(&"test_den_ticket").id, &"test_den")
	assert_null(data.dungeon_for_ticket(&"rift_shard"))
	assert_eq(data.item(&"test_den_ticket").dungeon, &"test_den")
	assert_eq(data.item(&"rift_shard").dungeon, &"")


func test_the_three_stages_resolve_their_monsters() -> void:
	var def: DungeonDef = TestFactory.fixture_data().dungeon(&"test_den")
	assert_eq(def.stages.size(), 3)
	assert_eq(def.stages[0].monster.id, &"tden_right_hand")
	assert_eq(def.stages[0].escorts, [&"tden_guard", &"tden_guard"] as Array[StringName])
	assert_eq(def.stages[0].ability.type, BossAbilityDef.HEAVY_STRIKE)
	assert_eq(def.stages[1].ability.type, BossAbilityDef.SUMMON)
	assert_eq(def.stages[2].ability.type, BossAbilityDef.SHIELD)
	assert_true(def.stages[2].escorts.is_empty())
	assert_true(def.stages[2].reward.is_empty())
	assert_eq(def.stages[0].reward["gold"], Vector2i(1500, 2500))
	assert_eq(def.stages[2].intro_ms, 5500)


func test_its_monsters_are_ordinary_monsters_of_the_game() -> void:
	var data: GameData = TestFactory.fixture_data()
	var king: MonsterDef = data.monster(&"tden_king")
	assert_not_null(king)
	assert_eq(king.dungeon, &"test_den")
	assert_eq(data.monster(&"test_monster_a").dungeon, &"")
	assert_false(king.is_miniboss)


func test_real_data_is_valid_with_the_strict_dungeon_rules() -> void:
	assert_true(GameData.load_from_dirs().is_valid(), "the real data loads (STRICT_REAL_DATA true since M22-03)")


# --- the rules of the dungeon file ---------------------------------------------------------------------------------

func test_stages_must_be_three() -> void:
	var raw: Dictionary = _raw()
	(_den(raw)["stages"] as Array).remove_at(1)
	_expect(raw, ["test_den.json", "dungeon 'test_den'", "exactly 3 stages"])


func test_pack_type_is_required() -> void:
	var raw: Dictionary = _raw()
	var types: Array = (_den(raw)["rooms"] as Dictionary)["types"] as Array
	types.remove_at(0)
	_expect(raw, ["the type 'pack' is required"])


func test_pack_starts_at_level_one() -> void:
	var raw: Dictionary = _raw()
	((((_den(raw)["rooms"] as Dictionary)["types"] as Array)[0]) as Dictionary)["min_layer"] = 2
	_expect(raw, ["'pack' must start at layer 1"])


func test_room_types_are_a_closed_list_used_once() -> void:
	var raw: Dictionary = _raw()
	var types: Array = (_den(raw)["rooms"] as Dictionary)["types"] as Array
	types.append((types[1] as Dictionary).duplicate(true))
	_expect(raw, ["appears twice"])
	raw = _raw()
	((((_den(raw)["rooms"] as Dictionary)["types"] as Array)[1]) as Dictionary)["id"] = "swamp"
	_expect(raw, ["rooms.types[1].id"])


func test_a_combat_room_needs_a_composition() -> void:
	var raw: Dictionary = _raw()
	(((_den(raw)["rooms"] as Dictionary)["types"] as Array)[0] as Dictionary).erase("size")
	_expect(raw, ["rooms.types[0]", "needs 'size' with 'pool'"])


func test_a_pool_names_monsters_of_the_dungeon() -> void:
	var raw: Dictionary = _raw()
	((((_den(raw)["rooms"] as Dictionary)["types"] as Array)[0] as Dictionary)["pool"] as Array).append({"monster": "test_monster_a", "weight": 1})
	_expect(raw, ["unknown monster 'test_monster_a'"])


func test_a_reward_has_only_its_keys() -> void:
	var raw: Dictionary = _raw()
	(((_den(raw)["rooms"] as Dictionary)["entrance"] as Dictionary)["reward"] as Dictionary)["silver"] = [1, 2]
	_expect(raw, ["rooms.entrance.reward.silver"])


func test_the_direction_band_must_not_be_wider_than_a_quarter() -> void:
	var raw: Dictionary = _raw()
	var balance: Dictionary = V.file_of(raw, "balance", "balance.json")
	((balance["dungeon"] as Dictionary))["direction_bands"] = [-0.7, -0.3, -0.1, 0.1, 0.3, 0.55]
	_expect(raw, ["dungeon.direction_bands", "at most 0.25"])


func test_direction_bands_must_increase() -> void:
	var raw: Dictionary = _raw()
	var balance: Dictionary = V.file_of(raw, "balance", "balance.json")
	((balance["dungeon"] as Dictionary))["direction_bands"] = [-0.55, -0.30, -0.10, 0.10, 0.05, 0.55]
	_expect(raw, ["strictly increasing"])


func test_balance_needs_the_dungeon_and_miniboss_sections() -> void:
	var raw: Dictionary = _raw()
	V.file_of(raw, "balance", "balance.json").erase("dungeon")
	V.file_of(raw, "balance", "balance.json").erase("miniboss")
	_expect(raw, ["missing key 'dungeon'"])
	_expect(raw, ["missing key 'miniboss'"])


func test_dungeon_monster_ids_are_unique_in_the_whole_game() -> void:
	var raw: Dictionary = _raw()
	((_den(raw)["monsters"] as Array)[0] as Dictionary)["id"] = "test_monster_a"
	_expect(raw, ["already used by another monster"])


func test_dungeon_monsters_are_not_in_areas() -> void:
	var raw: Dictionary = _raw()
	((_area_entries(raw)[0] as Dictionary)["packs"] as Array).append({"weight": 1, "monsters": ["tden_king"]})
	_expect(raw, ["unknown monster 'tden_king'"])


func test_the_loot_table_has_no_cards_and_no_contracts() -> void:
	var raw: Dictionary = _raw()
	var tables: Array = V.file_of(raw, "loot_tables", "loot_tables.json")["tables"] as Array
	for table: Variant in tables:
		if (table as Dictionary)["id"] == "test_monster_loot":
			((table as Dictionary)["entries"] as Array).append({"item": "fracture_card_1", "chance_pct": 5, "qty": [1, 1]})
	_expect(raw, ["field 'loot_table'", "no Cards and no Contracts"])


func test_the_ticket_must_belong_to_the_dungeon() -> void:
	var raw: Dictionary = _raw()
	_den(raw)["ticket"] = "rift_shard"
	_expect(raw, ["field 'ticket'", "no `dungeon` equal to the id"])


# --- tickets ---------------------------------------------------------------------------------------------------------

func test_a_second_ticket_is_rejected() -> void:
	var raw: Dictionary = _raw()
	var items: Array = V.file_of(raw, "items", "misc.json")["items"] as Array
	var copy: Dictionary = (items[1] as Dictionary).duplicate(true)
	copy["id"] = "test_den_ticket_2"
	items.append(copy)
	_expect(raw, ["2 tickets", "exactly 1 is needed"])


func test_a_dungeon_without_ticket_is_rejected() -> void:
	var raw: Dictionary = _raw()
	((V.file_of(raw, "items", "misc.json")["items"] as Array)[1] as Dictionary).erase("dungeon")
	_expect(raw, ["0 tickets", "exactly 1 is needed"])


func test_a_ticket_is_a_misc_item_without_value() -> void:
	var raw: Dictionary = _raw()
	((V.file_of(raw, "items", "misc.json")["items"] as Array)[1] as Dictionary)["value"] = 5
	_expect(raw, ["a ticket must have value 0"])


func test_a_ticket_of_an_unknown_dungeon_is_rejected() -> void:
	var raw: Dictionary = _raw()
	((V.file_of(raw, "items", "misc.json")["items"] as Array)[1] as Dictionary)["dungeon"] = "nowhere"
	_expect(raw, ["unknown dungeon 'nowhere'"])


func test_a_ticket_drops_from_a_miniboss_only() -> void:
	var raw: Dictionary = _raw()
	_with_minibosses(raw)
	var monsters: Array = V.file_of(raw, "monsters", "monsters.json")["monsters"] as Array
	for monster: Variant in monsters:
		if (monster as Dictionary)["id"] == "mb_0":
			((monster as Dictionary)["drops"] as Array).append({"item": TICKET, "chance_pct": 25, "qty": [1, 1]})
	assert_eq(V.validate(raw), PackedStringArray(), "a miniboss may drop it")
	((monsters[0] as Dictionary)["drops"] as Array).append({"item": TICKET, "chance_pct": 25, "qty": [1, 1]})
	_expect(raw, ["monster 'test_monster_a'", "drops only from an area miniboss"])


func test_a_ticket_in_a_table_of_an_area_is_out_of_place() -> void:
	var raw: Dictionary = _raw()
	var tables: Array = V.file_of(raw, "loot_tables", "loot_tables.json")["tables"] as Array
	for table: Variant in tables:
		if (table as Dictionary)["id"] == "test_area_loot":
			((table as Dictionary)["entries"] as Array).append({"item": TICKET, "chance_pct": 20, "qty": [1, 1]})
	_expect(raw, ["loot table 'test_area_loot'", "used by the area 'test_loot_area'"])


func test_a_ticket_in_a_dungeon_drop_is_out_of_place() -> void:
	var raw: Dictionary = _raw()
	((_den(raw)["boss"] as Dictionary)["drops"] as Array).append({"item": TICKET, "chance_pct": 50, "qty": [1, 1]})
	_expect(raw, ["does not drop inside a dungeon"])


# --- the miniboss of an area -----------------------------------------------------------------------------------------

func test_every_area_gets_a_miniboss_once_one_has_it() -> void:
	var raw: Dictionary = _raw()
	_with_minibosses(raw)
	assert_eq(V.validate(raw), PackedStringArray())
	((_area_entries(raw)[1] as Dictionary)).erase("miniboss")
	_expect(raw, ["area 'test_stone_area'", "field 'miniboss' is required"])


func test_a_miniboss_is_marked_outside_the_packs_and_used_once() -> void:
	var raw: Dictionary = _raw()
	_with_minibosses(raw)
	var areas: Array = _area_entries(raw)
	(areas[1] as Dictionary)["miniboss"] = {"monster": "mb_0", "escorts": 2}
	_expect(raw, ["already the miniboss of another area"])
	raw = _raw()
	_with_minibosses(raw)
	((_area_entries(raw)[0] as Dictionary)["miniboss"] as Dictionary)["monster"] = "test_monster_b"
	_expect(raw, ["is not marked `miniboss`"])
	raw = _raw()
	_with_minibosses(raw)
	((_area_entries(raw)[0] as Dictionary)["packs"] as Array).append({"weight": 1, "monsters": ["mb_0"]})
	_expect(raw, ["is in a pack, a miniboss never is"])


func test_a_marked_monster_needs_an_area() -> void:
	var raw: Dictionary = _raw()
	(V.file_of(raw, "monsters", "monsters.json")["monsters"] as Array)[0]["miniboss"] = true
	_expect(raw, ["monster 'test_monster_a'", "no area names this monster as its miniboss"])


func test_the_miniboss_fields_are_read() -> void:
	var raw: Dictionary = _raw()
	_with_minibosses(raw)
	var monsters: Array[Dictionary] = []
	monsters.assign(V.file_of(raw, "monsters", "monsters.json")["monsters"] as Array)
	var def: MonsterDef = MonsterDef.from_dict(monsters[monsters.size() - 1])
	assert_true(def.is_miniboss)
	var area: AreaDef = AreaDef.from_dict(_area_entries(raw)[0] as Dictionary)
	assert_eq(area.miniboss_id, &"mb_0")
	assert_eq(area.miniboss_escorts, 2)


# --- legendary source `dungeon` --------------------------------------------------------------------------------------

func _legendary_items(source_id: String) -> Dictionary[String, Dictionary]:
	return {"items.json": {"items": [{"id": "leg_test", "equip": {"legendary": {
		"source": {"type": "dungeon", "id": source_id, "chance_pct": 3.5}, "effects": []}}}]}}


func test_a_legendary_source_dungeon_must_exist() -> void:
	var dungeons: Dictionary[String, Dictionary] = {DEN_PATH: {"id": "test_den"}}
	var v := DataValidatorRules.new()
	DataValidatorLegendary.validate_sources(v, _legendary_items("test_den"), {}, {}, dungeons)
	assert_eq(v.errors, PackedStringArray())
	var bad := DataValidatorRules.new()
	DataValidatorLegendary.validate_sources(bad, _legendary_items("nowhere"), {}, {}, dungeons)
	assert_eq(bad.errors.size(), 1)
	assert_true(bad.errors[0].contains("unknown dungeon 'nowhere'"), str(bad.errors))


func test_the_dungeon_is_a_legendary_source_type() -> void:
	assert_true(DataValidatorLegendary.SOURCE_TYPES.has("dungeon"))
	assert_eq(LegendaryInfo.SOURCE_DUNGEON, &"dungeon")


func test_balance_values_of_f137_and_f139() -> void:
	var data: GameData = TestFactory.fixture_data()
	assert_eq(data.balance_value("dungeon.direction_bands"), [-0.55, -0.30, -0.10, 0.10, 0.30, 0.55])
	assert_eq(float(data.balance_value("miniboss.chance_pct")), 1.5)
	assert_eq(float(data.balance_value("miniboss.hp_mult")), 4.0)
	assert_eq(float(data.balance_value("miniboss.power_mult")), 1.5)
	assert_eq(float(data.balance_value("miniboss.xp_mult")), 4.0)
	assert_eq(float(data.balance_value("miniboss.gold_mult")), 4.0)
