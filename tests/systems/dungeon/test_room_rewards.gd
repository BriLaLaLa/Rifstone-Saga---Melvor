extends GutTest
## F-142 (docs/02_FORMULAS.md §5j): the prize of a room and of a stage. The example of the formula (a Capobranco with the
## percentages at 100: a piece at least magic, a Crystal, Dust in 10-18, gold in 1.200-2.000) and with them at 0 (nothing,
## nothing rolled), the prize of the entrance and of the first stage through the system.

var _s: GameSession = null
var _engine: DungeonEngineDouble = null
var _bag: FractureBag = null
var _sink: LootSink = null


func before_each() -> void:
	_s = autofree(TestFactory.session(5, DungeonEngineDouble.data_with_pool()))
	_engine = DungeonEngineDouble.attach(_s)
	_bag = FractureBag.new()
	_sink = DungeonRewards.BagSink.new(_s, _bag)


func _miniboss_reward(piece_pct: float, crystal_pct: float) -> Dictionary:
	var reward: Dictionary = _s.data.dungeon(&"test_den").room_type(&"miniboss").reward.duplicate()
	reward["piece_pct"] = piece_pct
	reward["crystal_pct"] = crystal_pct
	return reward


func _qty(item_id: StringName) -> int:
	for entry: Dictionary in _bag.stacks():
		if entry["item"] == item_id:
			return entry["qty"]
	return 0


func test_the_miniboss_example_with_certain_chances() -> void:
	var gold: int = _s.wallet.get_gold()
	DungeonRewards.room_reward(_miniboss_reward(100.0, 100.0), 50, _sink, _s)
	assert_between(_s.wallet.get_gold() - gold, 1200, 2000)
	assert_between(_qty(&"rift_dust"), 10, 18)
	var crystals: int = 0
	for id: StringName in DungeonRewards.crystal_ids(_s.data):
		crystals += _qty(id)
	assert_eq(crystals, 1, "one Crystal")
	assert_eq(_bag.pieces().size(), 1, "one piece")
	var rarity: StringName = _bag.pieces()[0].rarity
	assert_true(rarity == Rarities.MAGIC or rarity == Rarities.RARE, "at least magic: %s" % rarity)


func test_with_the_chances_at_zero_only_gold_and_dust_arrive() -> void:
	DungeonRewards.room_reward(_miniboss_reward(0.0, 0.0), 50, _sink, _s)
	assert_eq(_bag.pieces().size(), 0)
	assert_eq(_bag.stacks().size(), 1, "only the Dust")
	assert_eq(_bag.cards().size(), 0)


func test_a_reward_without_keys_rolls_nothing() -> void:
	var before: Dictionary = _s.rng.to_save()
	DungeonRewards.room_reward({}, 50, _sink, _s)
	assert_eq(_s.rng.to_save(), before, "no roll consumed")
	assert_true(_bag.is_empty())


func test_the_chances_are_the_data_ones_over_many_rooms() -> void:
	var with_piece: int = 0
	for i: int in 400:
		var bag := FractureBag.new()
		DungeonRewards.room_reward({"piece_pct": 40.0}, 50, DungeonRewards.BagSink.new(_s, bag), _s)
		with_piece += 1 if not bag.pieces().is_empty() else 0
	assert_between(with_piece, 120, 200, "about 40% of 400")


func test_the_bag_tells_the_ui() -> void:
	var seen: Array = []
	_s.events.dungeon_bag_changed.connect(func(stacks: int, pieces: int, cards: int) -> void: seen.append([stacks, pieces, cards]))
	DungeonRewards.room_reward({"dust": Vector2i(5, 5)}, 0, _sink, _s)
	assert_eq(seen, [[1, 0, 0]])


func test_clearing_the_entrance_pays_its_gold_and_opens_the_fork() -> void:
	var gold: int = _s.wallet.get_gold()
	_engine.open_and_clear_entrance()
	assert_between(_s.wallet.get_gold() - gold, 200, 400)
	assert_eq(_s.dungeon.run().cleared, 1)
	assert_eq(_s.dungeon.run().phase, &"await")


func test_the_stage_prize_arrives_at_the_end_of_stages_one_and_two_only() -> void:
	_engine.open_and_clear_entrance()
	_engine.walk_to_boss()
	var gold: int = _s.wallet.get_gold()
	var dust_before: int = _stack_in_run(&"rift_dust")
	_engine.end_intro()
	_engine.clear_stage()
	assert_between(_s.wallet.get_gold() - gold, 1500, 2500, "the right hand")
	assert_between(_stack_in_run(&"rift_dust") - dust_before, 15, 25)
	assert_eq(_s.dungeon.run().stage, 2)
	assert_eq(_s.dungeon.run().phase, &"intro")
	gold = _s.wallet.get_gold()
	_engine.end_intro()
	_engine.clear_stage()
	assert_between(_s.wallet.get_gold() - gold, 1500, 2500, "the strategist")
	assert_eq(_s.dungeon.run().cleared, 6, "the three stages are one room: the boss counts when the king falls")


func _stack_in_run(item_id: StringName) -> int:
	for entry: Dictionary in _s.dungeon.run().bag.stacks():
		if entry["item"] == item_id:
			return entry["qty"]
	return 0
