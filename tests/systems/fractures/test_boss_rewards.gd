extends GutTest
## F-115: the guaranteed rewards of the boss (a piece at least magic of the base grade `piece_grade`, Rift Dust x dust_pct)
## and the Card of F-113 (`boss_pct`, `boss_delta`), all into the bag of the Fracture. xp and gold are the values of the data.

const SURE: Dictionary = {"card_drop": {"monster_pct": 0.4, "boss_pct": 100, "monster_delta": [70, 27, 3], "boss_delta": [20, 70, 10]}}
const NEVER: Dictionary = {"card_drop": {"monster_pct": 0.4, "boss_pct": 0, "monster_delta": [70, 27, 3], "boss_delta": [20, 70, 10]}}

var _s: GameSession = null


# A fight reduced to the boss: `reward` is called on the boss enemy of the grade.
func _kill_boss(seed_value: int, grade: int, overrides: Dictionary = {}, effects: Array[Dictionary] = []) -> FractureBag:
	_s = autofree(FractureUtil.session(seed_value, 3, overrides))
	assert_true(_s.fractures.open(FractureUtil.card(_s, grade)).ok)
	var fc := FractureCombat.new(_s)
	fc.begin(_s.fractures.run())
	fc.run.groups_cleared = fc.run.groups_total
	fc.run.effects.append_array(effects)
	var boss: Encounter.Enemy = fc.next_encounter().enemies[0]
	assert_false(fc.reward(boss), "the boss is not a kill of the data")
	return fc.run.bag


# F-115 example: dust [20, 30] with dust_pct 40 -> 28-42.
func test_dust_with_dust_pct() -> void:
	assert_eq(BossRewards.dust_qty(20, 40.0), 28)
	assert_eq(BossRewards.dust_qty(30, 40.0), 42)
	assert_eq(BossRewards.dust_qty(25, 0.0), 25)
	var effect: Dictionary = {"risk_type": &"", "risk": 0, "reward_type": FractureScaler.REWARD_DUST, "reward": 40}
	var seen: Dictionary = {}
	for seed_value: int in 40:
		var bag: FractureBag = _kill_boss(seed_value, 1, {}, [effect] as Array[Dictionary])
		seen[_dust(bag)] = true
	for qty: int in seen:
		assert_between(qty, 28, 42)
	assert_gt(seen.size(), 3, "the range is really rolled")


func _dust(bag: FractureBag) -> int:
	for entry: Dictionary in bag.stacks():
		if entry["item"] == BossRewards.DUST_ITEM:
			return entry["qty"]
	return 0


func test_the_dust_is_the_range_of_the_boss() -> void:
	for seed_value: int in 30:
		assert_between(_dust(_kill_boss(seed_value, 1)), 20, 30)


# F-115 example (shape): grade 1 -> bases of grade 5 (piece_grade), at least magic, ilvl of the boss.
func test_the_piece_is_at_least_magic_and_of_the_grade_of_the_table() -> void:
	var kinds: Dictionary = {}
	for seed_value: int in 60:
		var bag: FractureBag = _kill_boss(seed_value, 1)
		assert_eq(bag.pieces().size(), 1)
		var piece: ItemInstance = bag.pieces()[0]
		assert_true(piece.rarity == &"magic" or piece.rarity == &"rare", "rarity %s" % piece.rarity)
		assert_eq(_s.data.item(piece.base_id).equip.grade, 5)
		assert_eq(piece.ilvl, 20, "the highest level of boss_grade_1 (power 20)")
		assert_gt(piece.affixes.size(), 0)
		kinds[piece.base_id] = true
	assert_eq(kinds.size(), 3, "a random base among the three of grade 5")


func test_a_higher_grade_uses_the_piece_grade_of_its_row() -> void:
	for seed_value: int in 10:
		var bag: FractureBag = _kill_boss(seed_value, 3)
		assert_eq(bag.pieces()[0].base_id, &"test_boss_helm_6", "piece_grade 6 at grade 3")


func test_bases_are_the_ones_the_class_can_wear() -> void:
	var data: GameData = FractureUtil.data()
	var narrow := ClassDef.new()
	narrow.weapon_kinds = [&"sword"]
	narrow.offhand_kinds = [&"shield"]
	var ids: Array = BossRewards.piece_bases(narrow, 5, data).map(func(d: ItemDef) -> StringName: return d.id)
	assert_true(ids.has(&"test_boss_sword") and ids.has(&"test_boss_helm"))
	assert_false(ids.has(&"test_boss_greatsword"), "greatsword is not allowed to this class")
	var none: Array = BossRewards.piece_bases(null, 5, data).map(func(d: ItemDef) -> StringName: return d.id)
	assert_eq(none, [&"test_boss_helm"], "without a class only the slots with no kind")
	assert_true(BossRewards.piece_bases(narrow, 9, data).is_empty())


func test_the_rewards_are_rolled_after_the_drops_in_a_fixed_order() -> void:
	# Two runs with the same seed give the same bag: piece, dust and card come from one stream.
	var a: FractureBag = _kill_boss(11, 2, SURE)
	var b: FractureBag = _kill_boss(11, 2, SURE)
	assert_eq(a.to_save(), b.to_save())


func test_the_card_of_the_boss_follows_f113() -> void:
	for seed_value: int in 20:
		var bag: FractureBag = _kill_boss(seed_value, 4, SURE)
		assert_eq(bag.cards().size(), 1, "boss_pct 100: a Card at every boss")
		assert_between(bag.cards()[0].grade, 4, 6)
	for seed_value: int in 20:
		assert_eq(_kill_boss(seed_value, 4, NEVER).cards().size(), 0)


func test_the_boss_card_does_not_use_card_chance_pct() -> void:
	var effect: Dictionary = {"risk_type": &"", "risk": 0, "reward_type": FractureScaler.REWARD_CARD, "reward": 500}
	for seed_value: int in 20:
		assert_eq(_kill_boss(seed_value, 4, NEVER, [effect] as Array[Dictionary]).cards().size(), 0)


func test_grade_10_card_stays_grade_10() -> void:
	for seed_value: int in 10:
		var bag: FractureBag = _kill_boss(seed_value, 10, SURE)
		assert_eq(bag.cards()[0].grade, 10)


func test_xp_and_gold_are_the_values_of_the_data() -> void:
	var data: GameData = FractureUtil.data()
	for grade: int in [1, 5, 10]:
		if data.boss_for_grade(grade) == null:
			continue
		var scaled := FractureScaler.scale_monster(data.boss_for_grade(grade), grade, [] as Array[Dictionary], data)
		assert_eq(scaled.xp, data.boss_for_grade(grade).xp, "no reward_mult on a boss")
		assert_eq([scaled.gold_min, scaled.gold_max], [data.boss_for_grade(grade).gold_min, data.boss_for_grade(grade).gold_max])
		assert_eq(scaled.hp, data.boss_for_grade(grade).hp)


func test_a_won_fracture_delivers_the_piece_and_the_dust() -> void:
	_s = autofree(FractureUtil.session(21))
	FractureUtil.hero(_s)
	var seen: Array = []
	_s.events.fracture_finished.connect(func(o: StringName, _g: int, _n: int, c: int, p: int) -> void: seen.append([o, c, p]))
	assert_true(_s.fractures.open(FractureUtil.card(_s, 1)).ok)
	FractureUtil.run_until(_s, func() -> bool: return not _s.combat.in_fracture())
	assert_eq(seen.size(), 1)
	assert_eq(seen[0][0], &"won")
	assert_eq(seen[0][2], 1, "the guaranteed piece was in the bag")
	assert_gte(_s.bank.get_count(BossRewards.DUST_ITEM), 20)
