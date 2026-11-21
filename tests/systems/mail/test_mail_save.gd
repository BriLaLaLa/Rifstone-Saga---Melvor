extends GutTest
## MailBox save (docs/05_INTERFACES_M27.md §5.40, §6e): round trip, tolerant loading, session integration, offline summary.

var _session: GameSession = null


func before_each() -> void:
	_session = autofree(TestFactory.session())


func _good(id: int) -> Dictionary:
	return {"id": id, "kind": "auction_sold", "item": "test_plank", "qty": 5, "price": 9, "listing": 2, "money": 45, "items": [], "read": false}


func test_save_load_save_is_identical_through_json() -> void:
	_session.mail.post(&"auction_sold", {"item": &"test_plank", "qty": 5, "price": 9, "listing": 2, "money": 45})
	_session.mail.post(&"auction_expired", {"item": &"test_twig", "qty": 3, "items": [{"item": &"test_twig", "qty": 3}]})
	_session.mail.mark_read(2)
	var first: Dictionary = _session.mail.to_save()
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(first)) as Dictionary
	var other: GameSession = autofree(TestFactory.session())
	other.mail.from_save(parsed)
	assert_eq(JSON.stringify(other.mail.to_save()), JSON.stringify(first))
	assert_eq(other.mail.unread(), 1)


func test_messages_are_saved_with_ascending_ids() -> void:
	_session.mail.post(&"auction_sold", {"item": &"test_plank", "qty": 1, "listing": 1, "money": 1})
	_session.mail.post(&"auction_sold", {"item": &"test_plank", "qty": 1, "listing": 2, "money": 1})
	var ids: Array = []
	for m: Dictionary in (_session.mail.to_save()["messages"] as Array):
		ids.append(m["id"])
	assert_eq(ids, [1, 2])
	assert_eq(_session.mail.to_save()["next_id"], 3)


func test_the_slot_file_carries_the_module_and_loads_back() -> void:
	_session.mail.post(&"auction_sold", {"item": &"test_plank", "qty": 1, "listing": 1, "money": 7})
	var saved: Dictionary = _session.to_save(0)
	assert_true((saved["modules"] as Dictionary).has("mail"))
	var other: GameSession = autofree(TestFactory.session())
	assert_true(other.from_save(JSON.parse_string(JSON.stringify(saved)) as Dictionary).ok)
	assert_eq(other.mail.get_message(1)["money"], 7)


func test_a_slot_without_the_module_starts_with_an_empty_mailbox() -> void:
	var saved: Dictionary = _session.to_save(0)
	(saved["modules"] as Dictionary).erase("mail")
	_session.mail.post(&"auction_sold", {"item": &"test_plank", "qty": 1, "listing": 1, "money": 7})
	assert_true(_session.from_save(saved).ok)
	assert_eq(_session.mail.count(), 0)


func test_from_save_drops_bad_messages_and_keeps_good_ones() -> void:
	var unknown_kind: Dictionary = _good(2)
	unknown_kind["kind"] = "gift"
	var duplicate: Dictionary = _good(1)
	var low_id: Dictionary = _good(0)
	var negative: Dictionary = _good(3)
	negative["money"] = -1
	var unknown_item: Dictionary = _good(4)
	unknown_item["money"] = 0
	unknown_item["items"] = [{"item": "nonexistent_thing", "qty": 1}]
	var zero_qty: Dictionary = _good(5)
	zero_qty["money"] = 0
	zero_qty["items"] = [{"item": "test_twig", "qty": 0}]
	var both: Dictionary = _good(6)
	both["items"] = [{"item": "test_twig", "qty": 1}]
	var kept: Dictionary = _good(7)
	_session.mail.from_save({"next_id": 2, "messages": [_good(1), unknown_kind, duplicate, low_id, negative, unknown_item, zero_qty, both, kept, "junk"]})
	var ids: Array[int] = []
	for m: Dictionary in _session.mail.messages():
		ids.append(m["id"])
	assert_eq(ids, [7, 1] as Array[int])
	assert_eq(_session.mail.to_save()["next_id"], 8, "next_id above the highest id")


func test_from_save_of_garbage_gives_an_empty_mailbox() -> void:
	_session.mail.from_save({"messages": "nope", "next_id": "x"})
	assert_eq(_session.mail.count(), 0)
	assert_eq(_session.mail.to_save()["next_id"], 1)


func test_new_game_resets_the_counter() -> void:
	_session.mail.post(&"auction_sold", {"item": &"test_plank", "qty": 1, "listing": 1, "money": 1})
	_session.new_game()
	assert_eq(_session.mail.count(), 0)
	assert_eq(_session.mail.post(&"auction_sold", {"item": &"test_plank", "qty": 1, "listing": 1, "money": 1}), 1)


func test_offline_summary_counts_the_new_unread_messages() -> void:
	_session.mail.post(&"auction_sold", {"item": &"test_plank", "qty": 1, "listing": 1, "money": 1})
	var before: SessionSnapshot = SessionSnapshot.take(_session)
	_session.mail.post(&"auction_sold", {"item": &"test_plank", "qty": 1, "listing": 2, "money": 1})
	_session.mail.post(&"auction_expired", {"item": &"test_twig", "qty": 1, "items": [{"item": &"test_twig", "qty": 1}]})
	var summary: OfflineSummary = OfflineSummary.from_snapshots(before, SessionSnapshot.take(_session), 1000, false, [] as Array[StringName])
	assert_eq(summary.mail_new, 2)
	assert_false(summary.is_empty())
	_session.mail.collect_all()
	var after_collect: OfflineSummary = OfflineSummary.from_snapshots(before, SessionSnapshot.take(_session), 1000, false, [] as Array[StringName])
	assert_eq(after_collect.mail_new, 0, "never negative")


func test_collected_total_counts_the_collected_messages_and_is_saved() -> void:
	assert_eq(_session.mail.collected_total(), 0)
	var a: int = _session.mail.post(&"tutorial_gift", {"money": 100})
	var b: int = _session.mail.post(&"starter_reward", {"money": 50})
	_session.mail.post(&"starter_reward", {"money": 50})
	assert_true(_session.mail.collect(a).ok)
	assert_eq(_session.mail.collected_total(), 1)
	_session.mail.collect_all()
	assert_eq(_session.mail.collected_total(), 3)
	assert_eq(b, 2, "the tutorial kinds never merge")
	var saved: Dictionary = _session.mail.to_save()
	assert_eq(saved["collected"], 3)
	var other: GameSession = autofree(TestFactory.session())
	other.mail.from_save(JSON.parse_string(JSON.stringify(saved)) as Dictionary)
	assert_eq(other.mail.collected_total(), 3)
	other.mail.new_game()
	assert_eq(other.mail.collected_total(), 0)


func test_a_bad_collected_value_is_zero() -> void:
	for bad: Variant in ["x", -4, 2.5]:
		_session.mail.from_save({"messages": [], "collected": bad})
		assert_eq(_session.mail.collected_total(), 0)
	_session.mail.from_save({"messages": []})
	assert_eq(_session.mail.collected_total(), 0)
