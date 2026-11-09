extends GutTest
## F-113 inside a Fracture: the Card that a killed monster can drop (probability x card_chance_pct, grade offset, rarity of
## F-109), always into the bag of the Fracture; a summoned enemy gives nothing. The drop from the tables outside a Fracture is
## covered by test_card_drops_to_store.gd. The boss Card is M13-03.

const CERTAIN: Dictionary = {"card_drop": {"monster_pct": 100.0, "boss_pct": 70, "monster_delta": [70, 27, 3], "boss_delta": [20, 70, 10]}}

var _s: GameSession = null


func _start(seed_value: int, grade: int, mods: Array = [], overrides: Dictionary = CERTAIN) -> FractureCombat:
	_s = autofree(FractureUtil.session(seed_value, 3, overrides))
	assert_true(_s.fractures.open(FractureUtil.card(_s, grade, mods)).ok)
	var fc := FractureCombat.new(_s)
	fc.begin(_s.fractures.run())
	return fc


# A monster that gives nothing but the roll of the Card: no drops, no shard, gold [1, 1].
func _enemy(summoned: bool = false) -> Encounter.Enemy:
	var def := ScaledMonsterDef.copy_of(_s.data.monster(&"test_monster_a"))
	def.drops = []
	def.rift_shard_chance = 0.0
	def.gold_min = 1
	def.gold_max = 1
	def.xp = 0
	var enemy := Encounter.Enemy.new(def, _s.data)
	enemy.summoned = summoned
	return enemy


func test_a_certain_drop_goes_to_the_bag_of_the_fracture() -> void:
	var fc: FractureCombat = _start(3, 2)
	assert_true(fc.reward(_enemy()))
	var cards: Array[MapCard] = _s.fractures.run().bag.cards()
	assert_eq(cards.size(), 1)
	assert_eq(_s.cards.used(), 0, "not in the CardStore until the win")
	assert_between(cards[0].grade, 2, 4)
	assert_eq(cards[0].uid, 0, "uid 0 until the delivery")


func test_the_order_of_the_draws_is_probability_grade_offset_rarity() -> void:
	var fc: FractureCombat = _start(41, 3)
	var shadow := RngService.new(41)
	# the state of the stream after the opening of the Fracture is not zero: sync the shadow by replaying nothing, since
	# `open` rolls nothing; the kill rolls the gold (1, 1) first, the probability is certain (nothing consumed)
	shadow.randi_range(1, 1)
	var weights: Array[int] = [70, 27, 3]
	var expected_grade: int = mini(10, 3 + shadow.pick_weighted(weights))
	var expected_rarity: StringName = MapCardRoller.roll_rarity(_s.modifiers.total(&"item_rarity_pct"), _s.data, shadow)
	fc.reward(_enemy())
	var card: MapCard = _s.fractures.run().bag.cards()[0]
	assert_eq(card.grade, expected_grade)
	assert_eq(card.rarity, expected_rarity)
	var again: MapCard = MapCardRoller.create(expected_grade, expected_rarity, _s.data, shadow)
	assert_eq(card.to_dict(), again.to_dict(), "then the modifiers of F-109 from the same stream")


func test_grade_10_stays_10_for_every_offset() -> void:
	var fc: FractureCombat = _start(8, 10)
	for _i: int in 40:
		fc.reward(_enemy())
	for card: MapCard in _s.fractures.run().bag.cards():
		assert_eq(card.grade, 10)


func test_offsets_follow_the_weights() -> void:
	var overrides: Dictionary = {"card_drop": {"monster_pct": 100.0, "boss_pct": 70, "monster_delta": [0, 0, 1], "boss_delta": [20, 70, 10]}}
	var fc: FractureCombat = _start(8, 4, [], overrides)
	for _i: int in 5:
		fc.reward(_enemy())
	for card: MapCard in _s.fractures.run().bag.cards():
		assert_eq(card.grade, 6, "always +2")


func test_the_probability_is_scaled_by_card_chance_pct() -> void:
	# grade 4 with +60% (shrouded at step 10): 40% x 1.6 = 64% per kill
	var overrides: Dictionary = {"card_drop": {"monster_pct": 40.0, "boss_pct": 70, "monster_delta": [100, 0, 0], "boss_delta": [20, 70, 10]}}
	var fc: FractureCombat = _start(12, 4, [["shrouded", 10]], overrides)
	assert_eq(_s.fractures.effect_total(&"card_chance_pct"), 60.0)
	for _i: int in 2000:
		fc.reward(_enemy())
	var count: int = _s.fractures.run().bag.cards().size()
	assert_between(count, 1180, 1380, "about 64%% of 2000 (got %d)" % count)
	var plain: FractureCombat = _start(12, 4, [], overrides)
	for _i: int in 2000:
		plain.reward(_enemy())
	var base: int = _s.fractures.run().bag.cards().size()
	assert_between(base, 720, 880, "about 40%% of 2000 (got %d)" % base)


func test_the_real_probability_is_a_fraction_of_a_percent() -> void:
	var fc: FractureCombat = _start(33, 4, [["shrouded", 4]], {})  # +40 (20-60, step 4): 0.4 x 1.4 = 0.56%
	for _i: int in 5000:
		fc.reward(_enemy())
	var count: int = _s.fractures.run().bag.cards().size()
	assert_between(count, 10, 50, "about 0.56%% of 5000 = 28 (got %d)" % count)


func test_a_summoned_enemy_gives_nothing() -> void:
	var fc: FractureCombat = _start(5, 1)
	var xp: int = _s.character.get_xp()
	var gold: int = _s.wallet.get_gold()
	var enemy: Encounter.Enemy = _enemy(true)
	enemy.def.xp = 500
	enemy.def.gold_min = 10
	enemy.def.gold_max = 10
	assert_false(fc.reward(enemy), "not a kill of a monster of the data")
	assert_eq(_s.character.get_xp(), xp)
	assert_eq(_s.wallet.get_gold(), gold)
	assert_true(_s.fractures.run().bag.is_empty())


func test_a_card_in_a_drop_table_goes_to_the_fracture_bag() -> void:
	_start(5, 1)
	var run: FractureRun = _s.fractures.run()
	var entry := DropEntry.new()
	entry.item_id = &"fracture_card_3"
	entry.chance_pct = 100.0
	entry.qty_min = 1
	entry.qty_max = 1
	var drops: Array[DropEntry] = [entry]
	KillRewards.roll_drops(_s, FractureSink.new(_s, run), drops, ItemRoller.SOURCE_MONSTER, 10)
	assert_eq(run.bag.cards().size(), 1)
	assert_eq(run.bag.cards()[0].grade, 3)
	assert_eq(_s.cards.used(), 0)
