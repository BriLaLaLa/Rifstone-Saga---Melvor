extends GutTest
## F-127 (docs/02_FORMULAS.md §5f): the guaranteed piece of a destroyed Rift Stone (probability 100%, grade from the window of
## F-121 with the level of the stone, rarity F-84 with `k = 1 + (T + metin.rarity_bonus_pct) / 100`) and the Blueprint roll.
## Real data; fixed seeds.

const SOURCE: StringName = &"test:rarity"
const SAMPLES: int = 1500


func _session(seed_value: int = 41) -> GameSession:
	return autofree(TestFactory.session_no_kit(seed_value, TestFactory.real_data()))


func test_rarity_chances_with_the_bonus() -> void:
	var data: GameData = TestFactory.real_data()
	# +0% of item rarity: k = 1 + (0 + 100) / 100 = 2 -> magic 40 x 2 = 80 (cut to 100 - rare), rare 12 x 2 = 24
	assert_eq(ItemRoller.drop_chances(ItemRoller.SOURCE_RIFT_STONE, 100.0, data), Vector2(76.0, 24.0))
	# +50%: k = 2.5 -> rare 30, magic 100 -> 70 after the cut
	assert_eq(ItemRoller.drop_chances(ItemRoller.SOURCE_RIFT_STONE, 150.0, data), Vector2(70.0, 30.0))


func test_the_grade_comes_from_the_window_of_the_level() -> void:
	var data: GameData = TestFactory.real_data()
	var allowed: Array[int] = EquipmentPool.candidate_grades(45, data)
	assert_eq(allowed, [8, 9, 10, 11] as Array[int], "levels 35, 40, 45, 50 (F-121 with L_m 45)")
	var s: GameSession = _session()
	var seen: Dictionary = {}
	for _i: int in 300:
		var piece: ItemInstance = MonolithLoot.guaranteed_piece(45, s.rng, s)
		assert_not_null(piece, "the piece is always there")
		var grade: int = data.item(piece.base_id).equip.grade
		assert_true(allowed.has(grade), "grade %d in the window" % grade)
		assert_eq(piece.ilvl, 45, "the item level is the level of the stone")
		seen[grade] = true
	assert_eq(seen.size(), 4, "every grade of the window comes up")


func _share(s: GameSession, level: int) -> Vector2:
	var magic: int = 0
	var rare: int = 0
	for _i: int in SAMPLES:
		var piece: ItemInstance = MonolithLoot.guaranteed_piece(level, s.rng, s)
		if piece.rarity == &"rare":
			rare += 1
		elif piece.rarity == &"magic":
			magic += 1
	return Vector2(100.0 * magic / SAMPLES, 100.0 * rare / SAMPLES)


func test_the_rarity_is_raised_by_the_bonus() -> void:
	var shares: Vector2 = _share(_session(), 20)
	assert_almost_eq(shares.y, 24.0, 4.0, "rare about 24%")
	assert_almost_eq(shares.x, 76.0, 4.0, "magic about 76%")
	var s: GameSession = _session(42)
	s.modifiers.set_source(SOURCE, [Modifier.make(&"item_rarity_pct", 50.0)])
	var better: Vector2 = _share(s, 20)
	assert_almost_eq(better.y, 30.0, 4.0, "+50%: k = 2.5, rare about 30%")


func test_guaranteed_pieces_count_comes_from_the_balance() -> void:
	var s: GameSession = _session()
	var bag: LootBag = s.combat.loot
	MonolithLoot.grant(s, bag, 30)
	assert_eq(bag.pieces().size(), int(s.data.balance_value("metin.guaranteed_pieces")))


func test_killing_a_stone_puts_the_piece_in_the_bag() -> void:
	var s: GameSession = _session(7)
	TestFactory.make_roomy(s)
	s.modifiers.set_source(SOURCE, [Modifier.make(&"power_bonus", 5000.0), Modifier.make(&"max_hp_flat", 100000.0)])
	s.combat.from_save({"state": "riftstone", "area": "dry_uplands", "player_hp": 100000, "player_timer_ms": 0, "hand": 0,
		"between_ms": 0, "loot": {}, "kills": {}, "deaths": 0, "food_eaten": 0,
		"enemies": [{"monster": "dry_uplands_stone_30", "hp": 100, "timer_ms": 3000}],
		"stone": {"since": 0, "pending": false, "stone_id": ""}})
	var guard: int = 0
	while s.combat.state() == CombatEngine.STATE_RIFTSTONE and guard < 100:
		s.combat.advance(500)
		guard += 1
	assert_eq(s.combat.state(), CombatEngine.STATE_BETWEEN)
	var pieces: Array[ItemInstance] = s.combat.loot.pieces()
	assert_gte(pieces.size(), 1, "at least the guaranteed piece")
	assert_eq(s.armory.used(), 0, "the piece waits in the bag (Z1)")
	var found: bool = false
	for piece: ItemInstance in pieces:
		found = found or piece.ilvl == 30
	assert_true(found, "a piece at the level of the stone")
