extends GutTest
## Integration, save of the M7 state: the automatic filter, refined pieces, worn refined pieces and the Rift Stone
## counter go through save -> load -> save byte for byte, and the copy continues the same way. Old saves without the
## additive keys (`armory.filter`, `combat.stone`) load as "keep everything" / counter 0. Also the end-to-end effect of
## the stats of M7 (item_rarity_pct on the drops, upgrade_success_pct on the refinement) and the stat coverage check
## for F-83..F-88.
##
## Real data, fixed seeds, no file written (the codec is used in memory).

const SEED: int = 70703
const OTHER_SEED: int = 17
const NOW_MS: int = 1793603600000
const AREA: StringName = &"redrock_plains"
const SWORD: StringName = &"emberbronze_sword"
const RING: StringName = &"emberbronze_ring"
const AMULET: StringName = &"emberbronze_amulet"
const INGOT: StringName = &"emberbronze_ingot"
const SHARD: StringName = &"rift_shard"
const LUCK: StringName = &"test:luck"
const FORMULAS_OF_M7: Array[String] = ["F-83", "F-84", "F-85", "F-86", "F-87", "F-88"]


func _session(seed_value: int = SEED) -> GameSession:
	return autofree(TestFactory.session(seed_value, TestFactory.real_data()))


# A session in the middle of an M7 play: refined worn sword, refined spare ring, a locked piece, filter rules and a
# stone about to appear. Only state the save keeps (no test modifier source survives a load).
func _played() -> GameSession:
	var s: GameSession = _session()
	TestFactory.set_character_level(s, 12)
	s.wallet.add_gold(100000)
	TestFactory.give(s, INGOT, 100)
	TestFactory.give(s, SHARD, 100)
	var sword: int = TestFactory.give_piece(s, SWORD, &"rare", 8)
	var ring: int = TestFactory.give_piece(s, RING, &"magic", 4)
	var locked: int = TestFactory.give_piece(s, AMULET, &"common", 1)
	s.modifiers.set_source(LUCK, [Modifier.make(&"upgrade_success_pct", 300.0)])
	for i: int in 5:
		assert_true(s.armory.upgrade(sword).ok)
	for i: int in 2:
		assert_true(s.armory.upgrade(ring).ok)
	s.modifiers.clear_source(LUCK)
	assert_true(s.armory.set_locked(locked, true).ok)
	assert_true(s.equipment.equip(sword).ok)
	assert_true(s.armory.set_filter(&"weapon", &"magic", 3).ok)
	assert_true(s.armory.set_filter(&"ring", &"common", 2).ok)
	var combat: Dictionary = s.combat.to_save()
	combat["stone"] = {"since": 123, "pending": true}
	s.combat.from_save(combat)
	return s


func _roundtrip(s: GameSession) -> Array:
	var text: String = SaveCodec.encode(s.to_save(NOW_MS))
	var copy: GameSession = _session(OTHER_SEED)
	var result: CommandResult = copy.from_save(SaveCodec.decode(text))
	assert_true(result.ok, "from_save: %s" % result.reason)
	return [text, copy]


func test_filter_refinement_and_stone_survive_save_load_save() -> void:
	var s: GameSession = _played()
	var rt: Array = _roundtrip(s)
	var copy: GameSession = rt[1]
	assert_eq(SaveCodec.encode(copy.to_save(NOW_MS)), rt[0], "byte for byte")
	assert_eq(copy.armory.filter_rules(), s.armory.filter_rules(), "the rules")
	assert_eq(copy.armory.filter_rule(&"weapon"), {"min_rarity": &"magic", "min_grade": 3})
	assert_eq(copy.armory.filter_rule(&"head"), {"min_rarity": &"common", "min_grade": 1}, "unset slot: keep everything")
	var levels: Array[int] = []
	for inst: ItemInstance in copy.armory.instances():
		levels.append(inst.upgrade)
	var expected: Array[int] = []
	for inst: ItemInstance in s.armory.instances():
		expected.append(inst.upgrade)
	assert_eq(levels, expected, "refinement levels, in order")
	assert_true(levels.has(5) and levels.has(2), "the refined pieces are really refined")
	assert_eq(copy.equipment.get_uid(&"weapon"), s.equipment.get_uid(&"weapon"), "the refined sword is still worn")
	assert_eq(copy.modifiers.total(&"power_bonus"), s.modifiers.total(&"power_bonus"),
			"and its refined modifiers are rebuilt after the load")
	assert_eq(copy.combat.to_save()["stone"], {"since": 123, "pending": true}, "the Rift Stone counter")
	assert_eq(copy.armory.to_save()["next_uid"], s.armory.to_save()["next_uid"])


func test_the_copy_continues_like_the_original_with_a_pending_stone() -> void:
	var s: GameSession = _played()
	var rt: Array = _roundtrip(s)
	var copy: GameSession = rt[1]
	for session: GameSession in [s, copy]:
		assert_true(session.combat.start(AREA).ok)
		assert_eq(session.combat.state(), CombatEngine.STATE_RIFTSTONE, "the pending stone is the first encounter")
	for i: int in 120:
		s.advance(1000)
		copy.advance(1000)
	assert_eq(SaveCodec.encode(copy.to_save(NOW_MS)), SaveCodec.encode(s.to_save(NOW_MS)),
			"two minutes later: same fight, same drops, same rng")


func test_saves_without_the_additive_keys_load_as_keep_everything() -> void:
	var s: GameSession = _played()
	var saved: Dictionary = s.to_save(NOW_MS)
	((saved["modules"] as Dictionary)["armory"] as Dictionary).erase("filter")
	((saved["modules"] as Dictionary)["combat"] as Dictionary).erase("stone")
	var copy: GameSession = _session(OTHER_SEED)
	assert_true(copy.from_save(SaveCodec.decode(SaveCodec.encode(saved))).ok)
	assert_eq(copy.armory.filter_rules(), {}, "no filter key: keep everything")
	assert_eq(copy.combat.to_save()["stone"], {"since": 0, "pending": false}, "no stone key: counter 0")
	assert_eq(copy.armory.instances().size(), s.armory.instances().size(), "the pieces are untouched")


func test_a_malformed_filter_rule_is_dropped_and_the_valid_one_kept() -> void:
	var s: GameSession = _played()
	var saved: Dictionary = s.to_save(NOW_MS)
	var filter: Dictionary = ((saved["modules"] as Dictionary)["armory"] as Dictionary)["filter"]
	filter["head"] = {"min_rarity": "legendary", "min_grade": 3}
	filter["body"] = {"min_rarity": "rare", "min_grade": 99}
	var copy: GameSession = _session(OTHER_SEED)
	assert_true(copy.from_save(SaveCodec.decode(SaveCodec.encode(saved))).ok, "a bad rule does not fail the load")
	assert_eq(copy.armory.filter_rule(&"head"), {"min_rarity": &"common", "min_grade": 1})
	assert_eq(copy.armory.filter_rule(&"body"), {"min_rarity": &"common", "min_grade": 1})
	assert_eq(copy.armory.filter_rule(&"weapon"), {"min_rarity": &"magic", "min_grade": 3}, "the valid rules stay")


func test_a_new_game_resets_the_filter_the_stone_and_the_refinement() -> void:
	var s: GameSession = _played()
	s.new_game()
	assert_eq(s.armory.filter_rules(), {})
	assert_eq(s.combat.to_save()["stone"], {"since": 0, "pending": false})
	assert_eq(s.armory.instances().size(), 0)


func _kill_boars_with_drops(s: GameSession, data_drop: StringName, kills: int) -> Array[ItemInstance]:
	var count: Array[int] = [0]
	s.events.monster_killed.connect(func(_i: int, _m: StringName) -> void: count[0] += 1)
	assert_true(s.combat.start(AREA).ok)
	var guard: int = 0
	while count[0] < kills and guard < 20000:
		s.advance(500)
		guard += 1
	var out: Array[ItemInstance] = []
	for inst: ItemInstance in s.armory.instances():
		if inst.base_id == data_drop:
			out.append(inst)
	return out


func _certain_sword_data() -> GameData:
	var data: GameData = GameData.load_from_dirs(TestFactory.REAL_CONTENT_ROOT, TestFactory.CONFIG_ROOT)
	for monster_id: StringName in data.area(AREA).monster_ids:
		var entry := DropEntry.new()
		entry.item_id = SWORD
		entry.chance_pct = 100.0
		entry.qty_min = 1
		entry.qty_max = 1
		data.monster(monster_id).drops = [entry] as Array[DropEntry]
	return data


func test_item_rarity_pct_changes_the_rarity_of_the_drops_end_to_end() -> void:
	# F-84: base 20% magic + 3% rare. With item_rarity_pct 1000 (k = 11): p_rare 33, p_magic min(220, 67) -> no commons.
	var data: GameData = _certain_sword_data()
	var plain: GameSession = autofree(TestFactory.session(SEED, data))
	var lucky: GameSession = autofree(TestFactory.session(SEED, data))
	for s: GameSession in [plain, lucky]:
		s.modifiers.set_source(&"test:hero", [Modifier.make(&"power_bonus", 5000.0), Modifier.make(&"max_hp_flat", 100000.0),
			Modifier.make(&"armory_slots", 500.0)])
	lucky.modifiers.set_source(LUCK, [Modifier.make(&"item_rarity_pct", 1000.0)])
	var plain_pieces: Array[ItemInstance] = _kill_boars_with_drops(plain, SWORD, 60)
	var lucky_pieces: Array[ItemInstance] = _kill_boars_with_drops(lucky, SWORD, 60)
	var plain_better: int = 0
	for inst: ItemInstance in plain_pieces:
		if inst.rarity != &"common":
			plain_better += 1
	assert_gt(plain_pieces.size(), 50, "a sword per kill")
	assert_lt(plain_better, plain_pieces.size() * 0.5, "about 23% are better than common without the stat")
	assert_gt(lucky_pieces.size(), 50)
	for inst: ItemInstance in lucky_pieces:
		assert_ne(inst.rarity, &"common", "no common piece with +1000%")
		assert_gt(inst.affixes.size(), 0, "magic and rare pieces have affixes (F-85)")


func test_upgrade_success_pct_changes_the_refinement_end_to_end() -> void:
	# F-86: +8 -> +9 has a base chance of 25%; with +300% it is min(100, 25 x 4) = 100.
	var s: GameSession = _session()
	s.wallet.add_gold(2000000)
	TestFactory.give(s, INGOT, 1000)
	TestFactory.give(s, SHARD, 1000)
	var uid: int = TestFactory.give_piece(s, SWORD, &"magic", 8)
	s.modifiers.set_source(LUCK, [Modifier.make(&"upgrade_success_pct", 300.0)])
	for i: int in 9:
		assert_true(s.armory.upgrade(uid).ok)
	assert_eq(s.armory.get_instance(uid).upgrade, 9, "nine successes in a row, the chance is 100% at every step")


func test_every_stat_of_the_m7_formulas_has_an_existing_test() -> void:
	# The stat coverage rule (Lesson "no decorative stat") for F-83..F-88: the registry names an existing test function.
	var registry: StatRegistry = TestFactory.real_data().stats
	var checked: int = 0
	for stat: StringName in registry.ids():
		var info: Dictionary = registry.info(stat)
		var formulas: String = str(info["formula"])
		var in_m7: bool = false
		for f: String in FORMULAS_OF_M7:
			in_m7 = in_m7 or formulas.contains(f)
		if not in_m7:
			continue
		checked += 1
		var ref: PackedStringArray = str(info["test"]).split("::")
		assert_eq(ref.size(), 2, "%s: path::function" % stat)
		assert_true(FileAccess.file_exists("res://" + ref[0]), "%s: %s exists" % [stat, ref[0]])
		assert_true(FileAccess.get_file_as_string("res://" + ref[0]).contains("func %s(" % ref[1]),
				"%s: %s is defined in %s" % [stat, ref[1], ref[0]])
	assert_gte(checked, 2, "item_rarity_pct and upgrade_success_pct at least")
