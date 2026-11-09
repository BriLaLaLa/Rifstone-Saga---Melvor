extends GutTest
## Acceptance of M13 (docs/07_TASKS.md M13-06), end to end through the public API (docs/05_INTERFACES.md §5.23): no opening
## without a Card, Cards 1-10 with rarity, modifiers and Crystals, N groups + boss, win = loot in the Deposit, death and
## abandon = Card and bag lost, offline with a summary, save round-trip in the middle of a Fracture, stat coverage.
## The Fracture content uses the fixtures with `fracture.groups` = 3 (FractureUtil); the Cards use the real data.

const AREA: StringName = &"test_area"
const GROUPS: int = 3

var _log: Array = []


func _session(seed_value: int = 4242) -> GameSession:
	var s: GameSession = autofree(FractureUtil.session(seed_value, GROUPS))
	_log = []
	s.events.fracture_opened.connect(func(g: int) -> void: _log.append(["opened", g]))
	s.events.fracture_group_cleared.connect(func(i: int, t: int) -> void: _log.append(["cleared", i, t]))
	s.events.fracture_boss_started.connect(func(_b: StringName) -> void: _log.append(["boss"]))
	s.events.fracture_finished.connect(func(o: StringName, g: int, n: int, c: int, p: int) -> void: _log.append(["finished", o, g, n, c, p]))
	s.events.fracture_loot_lost.connect(func(a: int, b: int, c: int) -> void: _log.append(["lost", a, b, c]))
	return s


func _names() -> Array:
	var names: Array = []
	for entry: Array in _log:
		names.append(entry[0])
	return names


func _entry(name: String) -> Array:
	for entry: Array in _log:
		if entry[0] == name:
			return entry
	return []


func _run_to_end(s: GameSession) -> void:
	FractureUtil.run_until(s, func() -> bool: return not s.combat.in_fracture())


# --- no opening without a Card ---------------------------------------------------------------------------------------

func test_no_opening_without_a_card() -> void:
	var s: GameSession = _session()
	assert_false(s.fractures.open(1).ok, "no Card, no Fracture")
	assert_false(s.fractures.is_active())
	s.combat.start(AREA)
	FractureUtil.run_until(s, func() -> bool: return false, 100, 4 * 3_600_000)
	assert_false(s.fractures.is_active(), "four hours of combat open nothing")
	assert_false(_names().has("opened"))


# --- Cards 1-10, rarity, modifiers, Crystals ---------------------------------------------------------------------

func test_cards_of_every_grade_with_rarity_and_modifiers() -> void:
	var s: GameSession = autofree(TestFactory.session(11, TestFactory.real_data()))
	TestFactory.make_roomy(s)
	var counts: Dictionary = s.data.balance_value("fracture.mod_count")
	for grade: int in range(1, 11):
		for rarity: StringName in [&"common", &"magic", &"rare"]:
			var uid: int = s.cards.create(grade, rarity)
			assert_gt(uid, 0, "grade %d %s" % [grade, rarity])
			var card: MapCard = s.cards.get_card(uid)
			assert_eq(card.grade, grade)
			assert_eq(card.base_id, StringName("fracture_card_%d" % grade))
			var range_: Array = counts[str(rarity)]
			# F-123: the risk cap can leave a rare Card with fewer than 3 modifiers
			assert_between(card.mods.size(), mini(int(range_[0]), 1), int(range_[1]), "mods of grade %d %s" % [grade, rarity])
			var risk_types: Array = []
			for roll: MapModRoll in card.mods:
				assert_between(roll.step, 0, int(s.data.balance_value("fracture.intensity_steps")))
			for effect: Dictionary in MapCardRoller.effects(card, s.data):
				assert_false(risk_types.has(effect["risk_type"]), "one risk type per Card")
				risk_types.append(effect["risk_type"])
	assert_eq(s.cards.used(), 30)


func test_crystals_raise_the_rarity_of_a_card() -> void:
	var s: GameSession = autofree(TestFactory.session(12, TestFactory.real_data()))
	TestFactory.make_roomy(s)
	var uid: int = s.cards.create(5, &"common")
	TestFactory.give(s, &"currency_spark", 1)
	assert_true(s.cards.use_currency(uid, &"currency_spark").ok)
	assert_eq(s.cards.get_card(uid).rarity, &"magic")
	assert_eq(s.bank.get_count(&"currency_spark"), 0, "the Crystal is spent")
	TestFactory.give(s, &"currency_crown", 1)
	assert_true(s.cards.use_currency(uid, &"currency_crown").ok)
	assert_eq(s.cards.get_card(uid).rarity, &"rare")
	assert_between(s.cards.get_card(uid).mods.size(), 3, 4)
	assert_false(s.cards.use_currency(uid, &"currency_spark").ok, "no Crystal left")


# --- N groups + boss, win = loot in the Deposit ------------------------------------------------------------------

func test_groups_then_boss_then_the_loot_reaches_the_deposit() -> void:
	var s: GameSession = _session()
	FractureUtil.hero(s)
	var pieces_before: int = s.armory.used()
	var cards_before: int = s.cards.used()
	var uid: int = FractureUtil.card(s, 1)
	cards_before = s.cards.used() - 1
	assert_true(s.fractures.open(uid).ok)
	_run_to_end(s)
	var names: Array = _names()
	assert_eq(names.count("cleared"), GROUPS, "N groups")
	assert_true(names.has("boss"))
	assert_true(names.find("boss") > names.rfind("cleared"), "the boss comes after the last group")
	var done: Array = _entry("finished")
	assert_eq(done[1], &"won")
	assert_eq(done[3], GROUPS)
	assert_false(s.fractures.is_active())
	assert_false(s.fractures.has_pending(), "the Deposit had room: nothing waits")
	assert_gt(s.bank.get_count(&"rift_shard") + s.bank.get_count(&"rift_dust"), 0, "stacks were delivered")
	assert_eq(s.armory.used() - pieces_before, int(done[5]), "every piece of the bag is in the Armory")
	assert_eq(s.cards.used() - cards_before, int(done[4]), "every Card of the bag is in the Deposit")
	assert_false(_names().has("lost"))


# --- death and abandon: Card and bag lost -----------------------------------------------------------------------------

func test_death_loses_the_card_and_the_bag() -> void:
	var s: GameSession = _session()
	FractureUtil.weakling(s)
	var uid: int = FractureUtil.card(s, 1)
	var bank_before: Dictionary = s.bank.to_save()
	var pieces_before: int = s.armory.used()
	assert_true(s.fractures.open(uid).ok)
	_run_to_end(s)
	assert_eq(_entry("finished")[1], &"died")
	assert_false(s.cards.has(uid), "the Card is not given back")
	assert_eq(s.cards.used(), 0)
	assert_false(s.fractures.has_pending())
	assert_eq(s.bank.to_save(), bank_before, "nothing of the bag reached the Bank")
	assert_eq(s.armory.used(), pieces_before)


func test_abandon_loses_the_card_and_the_bag() -> void:
	var s: GameSession = _session()
	FractureUtil.hero(s)
	var uid: int = FractureUtil.card(s, 1)
	assert_true(s.fractures.open(uid).ok)
	FractureUtil.run_until(s, func() -> bool: return _names().has("cleared"))
	var bank_before: Dictionary = s.bank.to_save()
	assert_true(s.fractures.abandon().ok)
	assert_eq(_entry("finished")[1], &"abandoned")
	assert_false(s.fractures.is_active())
	assert_false(s.cards.has(uid))
	assert_eq(s.bank.to_save(), bank_before, "the bag is lost, not delivered")
	assert_false(s.fractures.abandon().ok, "nothing left to abandon")


# --- offline -------------------------------------------------------------------------------------------------------

func test_offline_summary_tells_the_fracture() -> void:
	var s: GameSession = _session()
	FractureUtil.hero(s)
	assert_true(s.fractures.open(FractureUtil.card(s, 2)).ok)
	var summary: OfflineSummary = await OfflineSimulator.new().run(s, 3_600_000, false, false)
	assert_eq(summary.fractures.size(), 1)
	assert_eq(summary.fractures[0]["grade"], 2)
	assert_eq(summary.fractures[0]["outcome"], &"won")
	assert_eq(summary.fractures[0]["groups"], GROUPS)
	assert_false(s.fractures.is_active())


# --- save round-trip in the middle of a Fracture -------------------------------------------------------------------

func test_save_in_the_middle_of_a_fracture_resumes_the_same_run() -> void:
	var a: GameSession = _session(91)
	TestFactory.set_character_level(a, 90)
	assert_true(a.fractures.open(FractureUtil.card(a, 1, [["sturdy", 3]])).ok)
	FractureUtil.run_until(a, func() -> bool: return _names().has("cleared"))
	assert_true(a.combat.in_fracture())
	var parsed: Variant = JSON.parse_string(JSON.stringify(a.to_save(1234)))
	var b: GameSession = autofree(FractureUtil.session(5, GROUPS))
	assert_true(b.from_save(parsed as Dictionary).ok)
	assert_true(b.combat.in_fracture())
	assert_eq(b.fractures.to_save(), a.fractures.to_save())
	for _i: int in 3000:
		a.advance(250)
		b.advance(250)
		if not a.combat.in_fracture() and not b.combat.in_fracture():
			break
	assert_false(b.combat.in_fracture())
	assert_eq(a.bank.to_save(), b.bank.to_save())
	assert_eq(a.cards.to_save(), b.cards.to_save())
	assert_eq(a.fractures.to_save(), b.fractures.to_save())


# --- stat coverage -------------------------------------------------------------------------------------------------

func test_rewards_use_existing_stats_and_the_duration_stat_is_gone() -> void:
	var data: GameData = TestFactory.real_data()
	for stat: StringName in [&"item_rarity_pct", &"skill_xp_pct", &"gold_drop_pct"]:
		assert_true(data.stats.ids().has(stat), "%s is in stats.json" % stat)
	assert_false(data.stats.ids().has(&"fracture_duration_pct"), "no timed Fractures any more")
