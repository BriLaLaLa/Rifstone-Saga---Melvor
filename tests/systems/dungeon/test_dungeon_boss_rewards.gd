extends GutTest
## F-143 (docs/02_FORMULAS.md §5j): the loot of the final boss in the bag, in order: gold, Dust, two pieces (the first rare,
## the second at least magic), two Crystals, the Card (60%), the drops and the legendaries of the dungeon. Certain and impossible
## chances, the legendary of the source `dungeon` and the win of a whole run through the system.

const DEN_PATH: String = "res://tests/fixtures/data/dungeons/test_den.json"

var _s: GameSession = null
var _bag: FractureBag = null
var _sink: LootSink = null


func before_each() -> void:
	_s = autofree(TestFactory.session(21, DungeonEngineDouble.data_with_pool()))
	_bag = FractureBag.new()
	_sink = DungeonRewards.BagSink.new(_s, _bag)


# A private copy of the fixture dungeon with the chances of the boss changed.
func _def(card_pct: float, drop_pct: float) -> DungeonDef:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DEN_PATH))
	var boss: Dictionary = raw["boss"]
	boss["card_pct"] = card_pct
	(boss["drops"] as Array)[0]["chance_pct"] = drop_pct
	var def: DungeonDef = DungeonDef.from_dict(raw)
	assert_not_null(def)
	return def


func _qty(item_id: StringName) -> int:
	for entry: Dictionary in _bag.stacks():
		if entry["item"] == item_id:
			return entry["qty"]
	return 0


func test_the_guaranteed_part_of_the_loot() -> void:
	var gold: int = _s.wallet.get_gold()
	DungeonRewards.boss_loot(_s, _sink, _def(0.0, 0.0))
	assert_between(_s.wallet.get_gold() - gold, 3000, 5000)
	assert_between(_qty(&"rift_dust"), 40, 60)
	var pieces: Array[ItemInstance] = _bag.pieces()
	assert_eq(pieces.size(), 2)
	assert_eq(pieces[0].rarity, Rarities.RARE, "the first piece is rare")
	assert_true(pieces[1].rarity == Rarities.MAGIC or pieces[1].rarity == Rarities.RARE, "the second is at least magic")
	var crystals: int = 0
	for id: StringName in DungeonRewards.crystal_ids(_s.data):
		crystals += _qty(id)
	assert_eq(crystals, 2)
	assert_eq(_bag.cards().size(), 0, "card_pct 0")
	assert_eq(_qty(&"test_log"), 0, "drop chance 0")


func test_the_card_and_the_drops_with_certain_chances() -> void:
	DungeonRewards.boss_loot(_s, _sink, _def(100.0, 100.0))
	assert_eq(_bag.cards().size(), 1)
	assert_eq(_bag.cards()[0].grade, 4)
	assert_between(_qty(&"test_log"), 3, 6)


func test_the_card_chance_is_the_data_one() -> void:
	var def: DungeonDef = _def(60.0, 0.0)
	var cards: int = 0
	for i: int in 300:
		var bag := FractureBag.new()
		DungeonRewards.boss_loot(_s, DungeonRewards.BagSink.new(_s, bag), def)
		cards += bag.cards().size()
	assert_between(cards, 150, 210, "about 60% of 300")


func test_no_legendary_in_the_fixtures_and_no_roll_for_it() -> void:
	var def: DungeonDef = _def(0.0, 0.0)
	assert_eq(_s.data.legendaries_from(&"dungeon", &"test_den").size(), 0)
	DungeonRewards.boss_loot(_s, _sink, def)
	var after: Dictionary = _s.rng.to_save()
	var twin: GameSession = autofree(TestFactory.session(21, DungeonEngineDouble.data_with_pool()))
	DungeonRewards.boss_loot(twin, DungeonRewards.BagSink.new(twin, FractureBag.new()), def)
	assert_eq(twin.rng.to_save(), after, "the same rolls: the dungeon source adds none")


func test_a_legendary_of_the_dungeon_with_a_certain_chance() -> void:
	var s: GameSession = autofree(TestFactory.session(22, DungeonEngineDouble.data_with_pool(true)))
	var bag := FractureBag.new()
	DungeonRewards.boss_loot(s, DungeonRewards.BagSink.new(s, bag), s.data.dungeon(&"test_den"))
	var legendary: Array[ItemInstance] = bag.pieces().filter(func(p: ItemInstance) -> bool: return p.base_id == DungeonEngineDouble.LEGENDARY_ID)
	assert_eq(legendary.size(), 1)
	assert_eq(legendary[0].rarity, Rarities.LEGENDARY)
	assert_eq(bag.pieces().size(), 3, "the two pieces and the legendary, in the bag of the run")


func test_a_won_run_delivers_the_whole_loot() -> void:
	var s: GameSession = autofree(TestFactory.session(23, DungeonEngineDouble.data_with_pool(true)))
	var engine: DungeonEngineDouble = DungeonEngineDouble.attach(s)
	engine.open_and_clear_entrance()
	engine.walk_to_boss()
	for _i: int in 3:
		engine.end_intro()
		engine.clear_stage()
	assert_false(s.dungeon.is_active())
	assert_false(s.dungeon.has_pending())
	assert_between(s.bank.get_count(&"rift_dust"), 40 + 15 + 15, 400)
	var bases: Array = s.armory.instances().map(func(p: ItemInstance) -> StringName: return p.base_id)
	assert_true(bases.has(DungeonEngineDouble.LEGENDARY_ID), "the legendary reached the Armory")
	assert_eq(s.dungeon.wins(&"test_den"), 1)
