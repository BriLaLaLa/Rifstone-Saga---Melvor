extends GutTest
## Save of the Cards (docs/05_INTERFACES.md §5.23, §6): `cards` round-trip through the session file, a missing block is an
## empty store, and a tolerant load (unknown modifier, step out of range, base that is not a Card, duplicate uid, next_uid).

var _session: GameSession = null


func before_each() -> void:
	_session = TestFactory.session(51)
	add_child_autofree(_session)


func _entry(uid: int, base: String = "fracture_card_2", rarity: String = "magic", mods: Array = [], locked: bool = false
) -> Dictionary:
	return {"uid": uid, "base": base, "rarity": rarity, "mods": mods, "locked": locked}


func test_round_trip_through_the_session_file() -> void:
	_session.cards.create(3, &"rare")
	var uid: int = _session.cards.create(2, &"magic")
	_session.cards.set_locked(uid, true)
	var expected: Array[Dictionary] = []
	for card: MapCard in _session.cards.cards():
		expected.append(card.to_dict())
	var saved: Dictionary = JSON.parse_string(JSON.stringify(_session.to_save(1000)))  # as written to disk
	var other: GameSession = TestFactory.session(52)
	add_child_autofree(other)
	assert_true(other.from_save(saved).ok)
	var loaded: Array[Dictionary] = []
	for card: MapCard in other.cards.cards():
		loaded.append(card.to_dict())
	assert_eq(loaded.size(), 2)
	assert_eq(JSON.stringify(loaded), JSON.stringify(expected))
	assert_eq(other.cards.to_save()["next_uid"], 3)
	assert_eq(other.deposit.used() - other.cards.used(), _session.deposit.used() - _session.cards.used())


func test_save_has_the_documented_shape() -> void:
	var uid: int = _session.cards.create(2, &"magic")
	var block: Dictionary = _session.to_save(1000)["modules"]["cards"]
	assert_eq(block.keys(), ["next_uid", "items"])
	var entry: Dictionary = (block["items"] as Array)[0]
	assert_eq(entry.keys(), ["uid", "base", "rarity", "mods", "locked"])
	assert_eq(entry["uid"], uid)
	assert_eq(entry["base"], "fracture_card_2")
	for mod: Dictionary in entry["mods"]:
		assert_eq(mod.keys(), ["mod", "step"])


func test_a_missing_block_is_an_empty_store() -> void:
	_session.cards.create(1, &"common")
	var saved: Dictionary = _session.to_save(1000)
	(saved["modules"] as Dictionary).erase("cards")
	assert_true(_session.from_save(saved).ok)
	assert_eq(_session.cards.used(), 0)
	assert_eq(_session.cards.create(1, &"common"), 1, "uids restart")


func test_tolerant_load_drops_bad_entries() -> void:
	var items: Array = [
		_entry(1, "fracture_card_2", "magic", [{"mod": "sturdy", "step": 5}]),
		_entry(2, "fracture_card_2", "magic", [{"mod": "no_such_mod", "step": 1}]),
		_entry(3, "fracture_card_2", "magic", [{"mod": "assault", "step": 11}]),
		_entry(4, "fracture_card_2", "magic", [{"mod": "assault", "step": -1}]),
		_entry(5, "test_log", "common"),
		_entry(6, "no_such_base", "common"),
		_entry(1, "fracture_card_3", "common"),
		_entry(7, "fracture_card_4", "epic"),
		_entry(8, "fracture_card_5", "rare", [{"mod": "sturdy", "step": 1}, {"mod": "sturdy", "step": 2}]),
		"not an object",
		_entry(9, "fracture_card_6", "common", [], true),
	]
	_session.cards.from_save({"next_uid": 4, "items": items})
	var uids: Array[int] = []
	for card: MapCard in _session.cards.cards():
		uids.append(card.uid)
	assert_eq(uids, [1, 9], "only the valid entries stay; the duplicate uid keeps the first")
	assert_eq(_session.cards.get_card(1).grade, 2, "the grade is that of the base")
	assert_eq(_session.cards.get_card(1).mods[0].step, 5)
	assert_true(_session.cards.get_card(9).locked)
	assert_eq(_session.cards.create(1, &"common"), 10, "next_uid raised above the highest uid")


func test_next_uid_is_kept_when_higher() -> void:
	_session.cards.from_save({"next_uid": 50, "items": [_entry(3)]})
	assert_eq(_session.cards.create(1, &"common"), 50)


func test_a_malformed_block_is_empty() -> void:
	_session.cards.from_save({"items": "nope"})
	assert_eq(_session.cards.used(), 0)
	_session.cards.from_save({})
	assert_eq(_session.cards.used(), 0)


func test_the_capacity_is_not_checked_on_load() -> void:
	var items: Array = []
	for uid: int in range(1, _session.deposit.capacity() + 5):
		items.append(_entry(uid, "fracture_card_1", "common"))
	_session.cards.from_save({"next_uid": 1, "items": items})
	assert_eq(_session.cards.used(), items.size())


func test_cards_are_a_deposit_occupant_after_a_load() -> void:
	var items: Array = [_entry(1, "fracture_card_1", "common"), _entry(2, "fracture_card_2", "common")]
	var before: int = _session.deposit.used()
	_session.cards.from_save({"next_uid": 3, "items": items})
	assert_eq(_session.deposit.used(), before + 2)
