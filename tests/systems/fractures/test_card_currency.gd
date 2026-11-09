extends GutTest
## CardStore.use_currency (F-109): the three Crystal effects on Cards (`to_magic`, `to_rare` without duplicates, `reroll`),
## every refusal in the documented order, atomicity (nothing consumed or changed on a failure). Fixture crystals:
## test_currency (to_magic), test_currency_rare (to_rare), test_currency_reroll (reroll).

const TO_MAGIC: StringName = &"test_currency"
const TO_RARE: StringName = &"test_currency_rare"
const REROLL: StringName = &"test_currency_reroll"

var _session: GameSession = null
var _changes: Array = []


func before_each() -> void:
	_session = TestFactory.session(21)
	add_child_autofree(_session)
	_changes = []
	_session.events.card_changed.connect(func(uid: int, change: StringName) -> void: _changes.append([uid, change]))


func _add(grade: int, rarity: StringName) -> int:
	return _session.cards.add(MapCardRoller.create(grade, rarity, _session.data, RngService.new(grade * 13 + 5)))


func _ids(card: MapCard) -> Array[StringName]:
	var result: Array[StringName] = []
	for roll: MapModRoll in card.mods:
		result.append(roll.mod_id)
	return result


func test_to_magic_makes_a_common_card_magic() -> void:
	var uid: int = _add(4, &"common")
	TestFactory.give(_session, TO_MAGIC, 2)
	assert_true(_session.cards.use_currency(uid, TO_MAGIC).ok)
	var card: MapCard = _session.cards.get_card(uid)
	assert_eq(card.rarity, &"magic")
	assert_between(card.mods.size(), 1, 2)
	assert_eq(_session.bank.get_count(TO_MAGIC), 1, "one crystal spent")
	assert_eq(_changes.back(), [uid, &"updated"])


func test_to_rare_keeps_the_old_modifiers_without_duplicates() -> void:
	for seed_value: int in 25:
		var session: GameSession = TestFactory.session(seed_value)
		add_child_autofree(session)
		var uid: int = session.cards.add(MapCardRoller.create(6, &"magic", session.data, RngService.new(seed_value)))
		var before: Array[StringName] = _ids(session.cards.get_card(uid))
		TestFactory.give(session, TO_RARE, 1)
		assert_true(session.cards.use_currency(uid, TO_RARE).ok)
		var card: MapCard = session.cards.get_card(uid)
		assert_eq(card.rarity, &"rare")
		assert_between(card.mods.size(), 3, 4)
		var after: Array[StringName] = _ids(card)
		for i: int in before.size():
			assert_eq(after[i], before[i], "old modifiers kept, in place")
		for id: StringName in after:
			assert_eq(after.count(id), 1, "no duplicate")


func test_reroll_redraws_all_modifiers_with_the_same_rarity() -> void:
	var uid: int = _add(8, &"rare")
	TestFactory.give(_session, REROLL, 1)
	assert_true(_session.cards.use_currency(uid, REROLL).ok)
	var card: MapCard = _session.cards.get_card(uid)
	assert_eq(card.rarity, &"rare")
	assert_between(card.mods.size(), 3, 4)
	var magic: int = _add(8, &"magic")
	TestFactory.give(_session, REROLL, 1)
	assert_true(_session.cards.use_currency(magic, REROLL).ok)
	assert_eq(_session.cards.get_card(magic).rarity, &"magic")


func test_refusals_in_order() -> void:
	var uid: int = _add(2, &"common")
	TestFactory.give(_session, TO_RARE, 1)
	assert_eq(_session.cards.use_currency(99, TO_MAGIC).reason, Reasons.UNKNOWN_ID, "unknown Card first")
	assert_eq(_session.cards.use_currency(uid, &"test_log").reason, Reasons.NOT_EQUIPPABLE, "not a currency")
	_session.cards.set_locked(uid, true)
	assert_eq(_session.cards.use_currency(uid, TO_MAGIC).reason, Reasons.ITEM_LOCKED, "locked before rarity")
	_session.cards.set_locked(uid, false)
	assert_eq(_session.cards.use_currency(uid, TO_RARE).reason, Reasons.REQUIREMENT_NOT_MET, "to_rare needs a magic Card")
	assert_eq(_session.cards.use_currency(uid, REROLL).reason, Reasons.REQUIREMENT_NOT_MET, "reroll needs magic or rare")
	assert_eq(_session.cards.use_currency(uid, TO_MAGIC).reason, Reasons.NOT_ENOUGH_ITEMS, "no crystal in the Bank")


func test_to_magic_refuses_a_magic_card() -> void:
	var uid: int = _add(2, &"magic")
	TestFactory.give(_session, TO_MAGIC, 1)
	assert_eq(_session.cards.use_currency(uid, TO_MAGIC).reason, Reasons.REQUIREMENT_NOT_MET)
	assert_eq(_session.bank.get_count(TO_MAGIC), 1, "nothing consumed")


func test_failures_are_atomic() -> void:
	var uid: int = _add(5, &"magic")
	var snapshot: Dictionary = _session.cards.get_card(uid).to_dict()
	var rng_before: Dictionary = _session.rng.to_save()
	TestFactory.give(_session, TO_MAGIC, 1)
	_changes.clear()
	assert_false(_session.cards.use_currency(uid, TO_MAGIC).ok)
	_session.cards.set_locked(uid, true)
	snapshot["locked"] = true
	_changes.clear()
	assert_false(_session.cards.use_currency(uid, TO_RARE).ok)
	assert_eq(_session.cards.get_card(uid).to_dict(), snapshot)
	assert_eq(_session.bank.get_count(TO_MAGIC), 1)
	assert_eq(_changes, [], "no event on a failure")
	assert_eq(_session.rng.to_save(), rng_before, "no draw consumed by a refused use")
