extends GutTest
## M29-01 (F-109, F-111, F-123): magic Cards have 1-2 modifiers, rare Cards 3-6, a `reroll` Crystal keeps the number of
## modifiers, the three new risks on the player act on the stats, and the F-123 cap still holds. Real data.

const SEEDS: int = 60

var _data: GameData = null


func before_all() -> void:
	_data = TestFactory.real_data()


func _types(mods: Array[MapModRoll]) -> Array[StringName]:
	var types: Array[StringName] = []
	for roll: MapModRoll in mods:
		types.append(_data.map_mod(roll.mod_id).risk.type)
	return types


func _card(grade: int, rarity: StringName, seed_value: int) -> MapCard:
	return MapCardRoller.create(grade, rarity, _data, RngService.new(seed_value))


func test_balance_has_the_new_counts() -> void:
	assert_eq(_data.balance_value("fracture.mod_count.magic"), [1.0, 2.0])
	assert_eq(_data.balance_value("fracture.mod_count.rare"), [3.0, 6.0])


func test_magic_card_has_one_or_two_modifiers() -> void:
	for grade: int in range(1, 11):
		for seed_value: int in SEEDS:
			assert_between(_card(grade, &"magic", seed_value).mods.size(), 1, 2, "magic 1-2 (grade %d)" % grade)


func test_rare_card_has_three_to_six_and_reaches_the_drawn_number() -> void:
	var seen: Dictionary = {}
	for grade: int in range(2, 11):
		for seed_value: int in SEEDS:
			var target: int = RngService.new(seed_value).randi_range(3, 6)  # the first draw of `create`
			var card: MapCard = _card(grade, &"rare", seed_value)
			assert_eq(card.mods.size(), target, "grade %d reaches the drawn number" % grade)
			seen[card.mods.size()] = true
			var types: Array[StringName] = _types(card.mods)
			for type: StringName in types:
				assert_eq(types.count(type), 1, "one risk type per modifier")
			assert_lte(MapCardRoller.total_risk_points(card.mods, _data), MapCardRoller.risk_cap(grade, _data) + 1e-9)
	assert_eq(seen.keys().size(), 4, "3, 4, 5 and 6 all appear")


func test_grade_1_rare_is_cut_by_the_cap_at_five() -> void:
	# F-123: grade 1 has 7 risk types and the cap is 40: the six cheapest cost 60 at step 0, the five 40.
	for seed_value: int in SEEDS:
		var card: MapCard = _card(1, &"rare", seed_value)
		assert_between(card.mods.size(), 1, 5)
		assert_lte(MapCardRoller.total_risk_points(card.mods, _data), 40.0 + 1e-9)


func test_every_grade_has_six_risk_types() -> void:
	for grade: int in range(1, 11):
		var types: Dictionary = {}
		for def: MapModDef in _data.map_mods():
			if def.min_grade <= grade:
				types[def.risk.type] = true
		assert_gte(types.size(), 6, "grade %d: enough risk types for six modifiers" % grade)


func test_reroll_keeps_the_number_of_modifiers() -> void:
	for rarity: StringName in [&"magic", &"rare"]:
		for grade: int in [1, 3, 6, 10]:
			for seed_value: int in 40:
				var card: MapCard = _card(grade, rarity, seed_value)
				var before: int = card.mods.size()
				var again: Array[MapModRoll] = MapCardRoller.reroll_mods(card, _data, RngService.new(seed_value + 500))
				assert_eq(again.size(), before, "%s grade %d keeps %d" % [rarity, grade, before])
				assert_eq(card.mods.size(), before, "the card itself is not changed")
				assert_lte(MapCardRoller.total_risk_points(again, _data), MapCardRoller.risk_cap(grade, _data) + 1e-9)
				var types: Array[StringName] = _types(again)
				for type: StringName in types:
					assert_eq(types.count(type), 1)


func test_reroll_is_deterministic_and_draws_no_number() -> void:
	var card: MapCard = _card(5, &"rare", 7)
	var first: Array[MapModRoll] = MapCardRoller.reroll_mods(card, _data, RngService.new(11))
	var second: Array[MapModRoll] = MapCardRoller.reroll_mods(card, _data, RngService.new(11))
	assert_eq(first.size(), second.size())
	for i: int in first.size():
		assert_eq(first[i].mod_id, second[i].mod_id)
		assert_eq(first[i].step, second[i].step)
	# Draws on the rng: per modifier the choice (pick_weighted) and the step, nothing else.
	var rng := RngService.new(11)
	var ref := RngService.new(11)
	MapCardRoller.reroll_mods(card, _data, rng)
	var used: Array[StringName] = []
	for roll: MapModRoll in first:
		used.append(_data.map_mod(roll.mod_id).risk.type)
	assert_eq(used.size(), card.mods.size())
	assert_ne(rng.randf(), ref.randf(), "draws were consumed")


func test_store_reroll_keeps_the_number_and_the_rarity() -> void:
	for seed_value: int in 25:
		var session: GameSession = TestFactory.session(seed_value, _data)
		add_child_autofree(session)
		TestFactory.make_roomy(session)
		for rarity: StringName in [&"magic", &"rare"]:
			var card: MapCard = _card(7, rarity, seed_value)
			var before: int = card.mods.size()
			var uid: int = session.cards.add(card)
			TestFactory.give(session, &"currency_flux", 1)
			var result: CommandResult = session.cards.use_currency(uid, &"currency_flux")
			assert_true(result.ok, "reroll crystal id exists in the real data")
			assert_eq(session.cards.get_card(uid).mods.size(), before)
			assert_eq(session.cards.get_card(uid).rarity, rarity)


# --- the new risks on the player (F-111) -------------------------------------------------------------------------------

func _open(session: GameSession, grade: int, mods: Array) -> int:
	var made := MapCard.new()
	made.base_id = StringName("fracture_card_%d" % grade)
	made.grade = grade
	made.rarity = &"magic"
	for pair: Array in mods:
		made.mods.append(MapModRoll.make(StringName(pair[0]), int(pair[1])))
	return session.cards.add(made)


func test_new_risks_change_the_stats_of_the_player_only_in_the_fracture() -> void:
	var session: GameSession = TestFactory.session(31, _data)
	add_child_autofree(session)
	TestFactory.make_roomy(session)
	var before: CombatantStats = CombatantStats.for_player(session)
	var uid: int = _open(session, 4, [["weary", 10], ["blinded", 5]])  # damage -30, accuracy -25 (step 5: 10 + 15)
	assert_true(session.fractures.open(uid).ok)
	assert_eq(session.modifiers.total(&"power_pct"), -30.0)
	assert_eq(session.modifiers.total(&"accuracy_pct"), -25.0)
	var during: CombatantStats = CombatantStats.for_player(session)
	assert_lt(during.max_hit, before.max_hit, "the player hits less")
	assert_lt(during.accuracy, before.accuracy, "the player aims worse")
	session.fractures.abandon()
	assert_eq(session.modifiers.total(&"power_pct"), 0.0)
	assert_eq(CombatantStats.for_player(session).max_hit, before.max_hit)


func test_player_speed_risk_lengthens_the_interval_f26() -> void:
	var session: GameSession = TestFactory.session(32, _data)
	add_child_autofree(session)
	TestFactory.make_roomy(session)
	var before: CombatantStats = CombatantStats.for_player(session)
	assert_true(session.fractures.open(_open(session, 4, [["numbing", 10]])).ok)  # +30% interval
	assert_eq(session.modifiers.total(&"attack_interval_pct"), 30.0)
	var during: CombatantStats = CombatantStats.for_player(session)
	assert_eq(during.attack_interval_ms, CombatMath.attack_interval_ms(before.attack_interval_ms, 30.0, _data))
	assert_gt(during.attack_interval_ms, before.attack_interval_ms)


func test_player_risk_points_use_the_unit() -> void:
	assert_eq(MapCardRoller.risk_points(_data.map_mod(&"weary"), 10, _data), 15.0, "30 x 0.5")
	assert_eq(MapCardRoller.risk_points(_data.map_mod(&"blinded"), 10, _data), 20.0, "40 x 0.5")
	assert_eq(MapCardRoller.risk_points(_data.map_mod(&"numbing"), 0, _data), 5.0, "10 x 0.5")


func test_to_rare_keeps_the_old_modifiers_and_reaches_the_number() -> void:
	for grade: int in range(2, 11):
		for seed_value: int in 40:
			var card: MapCard = _card(grade, &"magic", seed_value)
			var target: int = RngService.new(seed_value + 900).randi_range(3, 6)
			var extended: Array[MapModRoll] = MapCardRoller.extend_mods(card, &"rare", _data, RngService.new(seed_value + 900))
			if extended.size() < target:  # only when no other modifier fits in the cap (F-123)
				var room: float = MapCardRoller.risk_cap(grade, _data) - MapCardRoller.total_risk_points(extended, _data)
				var used: Array[StringName] = _types(extended)
				for def: MapModDef in _data.map_mods():
					if def.min_grade <= grade and not used.has(def.risk.type):
						assert_gt(MapCardRoller.risk_points(def, 0, _data), room, "%s would still fit" % def.id)
			else:
				assert_eq(extended.size(), target, "grade %d reaches the drawn number" % grade)
			for i: int in card.mods.size():
				assert_eq(extended[i].mod_id, card.mods[i].mod_id, "old modifiers kept")
				assert_lte(extended[i].step, card.mods[i].step, "their steps can only go down")
			assert_lte(MapCardRoller.total_risk_points(extended, _data), MapCardRoller.risk_cap(grade, _data) + 1e-9)
