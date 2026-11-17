extends GutTest
## MailBox (F-183, docs/05_INTERFACES_M27.md §5.40): delivery and merging, capacity, collecting (atomic on bank_full), Collect all, order, signals.

var _session: GameSession = null


func before_each() -> void:
	_session = autofree(TestFactory.session())


func _sold(listing: int, qty: int, money: int) -> int:
	return _session.mail.post(&"auction_sold", {"item": &"test_plank", "qty": qty, "price": 250, "listing": listing, "money": money})


func _parts(item: StringName, qty: int) -> Dictionary:
	return {"item": item, "qty": qty, "items": [{"item": item, "qty": qty}]}


func _fill_deposit() -> void:
	var free: int = _session.deposit.free_slots()
	_session.deposit.register_occupant(&"test:fill", func() -> int: return free)


# --- delivery and merging -----------------------------------------------------------------------------------------

func test_sold_messages_of_the_same_listing_merge() -> void:
	var first: int = _sold(1, 261, 61987)
	var second: int = _sold(1, 339, 80512)
	assert_eq(first, 1)
	assert_eq(second, 1)
	assert_eq(_session.mail.count(), 1)
	var m: Dictionary = _session.mail.get_message(1)
	assert_eq(m["qty"], 600)
	assert_eq(m["money"], 142499)  # F-183 example: 61987 + 80512


func test_a_merge_makes_the_message_unread_again() -> void:
	_sold(1, 10, 100)
	_session.mail.mark_read(1)
	assert_eq(_session.mail.unread(), 0)
	_sold(1, 10, 100)
	assert_eq(_session.mail.unread(), 1)


func test_sold_messages_of_different_listings_stay_apart() -> void:
	_sold(1, 10, 100)
	_sold(2, 10, 100)
	assert_eq(_session.mail.count(), 2)


func test_collecting_then_selling_again_gives_a_new_message() -> void:
	_sold(1, 339, 80512)
	assert_true(_session.mail.collect(1).ok)
	assert_eq(_sold(1, 261, 61987), 2)  # F-183 example: a new message, id 2
	assert_eq(_session.mail.get_message(2)["money"], 61987)


func test_sales_of_the_same_item_merge_and_other_items_do_not() -> void:
	var a: int = _session.mail.post(&"auction_sale", {"item": &"test_twig", "qty": 100, "price": 3, "money": 300})
	var b: int = _session.mail.post(&"auction_sale", {"item": &"test_twig", "qty": 50, "price": 3, "money": 150})
	var c: int = _session.mail.post(&"auction_sale", {"item": &"test_log", "qty": 5, "price": 3, "money": 15})
	assert_eq(a, b)
	assert_ne(a, c)
	assert_eq(_session.mail.get_message(a)["qty"], 150)
	assert_eq(_session.mail.get_message(a)["money"], 450)
	assert_eq(_session.mail.count(), 2)


func test_messages_with_items_and_other_kinds_never_merge() -> void:
	_session.mail.post(&"auction_expired", _parts(&"test_twig", 5))
	_session.mail.post(&"auction_expired", _parts(&"test_twig", 5))
	_session.mail.post(&"auction_cancelled", _parts(&"test_twig", 5))
	assert_eq(_session.mail.count(), 3)


func test_messages_are_shown_newest_first() -> void:
	_sold(1, 1, 1)
	_sold(2, 1, 1)
	_sold(3, 1, 1)
	var ids: Array[int] = []
	for m: Dictionary in _session.mail.messages():
		ids.append(m["id"])
	assert_eq(ids, [3, 2, 1] as Array[int])


func test_accessors_give_copies() -> void:
	_sold(1, 1, 1)
	var m: Dictionary = _session.mail.messages()[0]
	m["money"] = 999
	assert_eq(_session.mail.get_message(1)["money"], 1)
	assert_true(_session.mail.get_message(77).is_empty())


func test_invalid_posts_are_rejected() -> void:
	assert_eq(_session.mail.post(&"nonsense", {"item": &"test_twig", "qty": 1}), 0)
	assert_eq(_session.mail.post(&"auction_sale", {"item": &"test_twig", "qty": 1, "money": -5}), 0)
	var both: Dictionary = _parts(&"test_twig", 1)
	both["money"] = 10
	assert_eq(_session.mail.post(&"auction_cancelled", both), 0)
	assert_push_error(3)
	assert_eq(_session.mail.count(), 0)


# --- capacity -------------------------------------------------------------------------------------------------------

func test_capacity_comes_from_balance_and_post_always_delivers() -> void:
	assert_eq(_session.mail.capacity(), 50)
	for i: int in 50:
		_session.mail.post(&"auction_expired", _parts(&"test_twig", 1))
	assert_true(_session.mail.is_full())
	assert_gt(_session.mail.post(&"auction_sold", {"item": &"test_plank", "qty": 1, "listing": 9, "money": 5}), 0)
	assert_eq(_session.mail.count(), 51)


# --- collecting -------------------------------------------------------------------------------------------------------

func test_collect_money_goes_to_the_wallet_and_removes_the_message() -> void:
	_sold(1, 10, 500)
	var before: int = _session.wallet.get_gold()
	watch_signals(_session.events)
	assert_true(_session.mail.collect(1).ok)
	assert_eq(_session.wallet.get_gold(), before + 500)
	assert_eq(_session.mail.count(), 0)
	assert_signal_emitted_with_parameters(_session.events, "mail_changed", [0, 0])


func test_nothing_is_credited_without_collect() -> void:
	var before: int = _session.wallet.get_gold()
	_sold(1, 10, 500)
	_session.mail.post(&"auction_expired", _parts(&"test_twig", 5))
	assert_eq(_session.wallet.get_gold(), before)
	assert_eq(_session.bank.get_count(&"test_twig"), 0)


func test_collect_items_go_to_the_bank() -> void:
	_session.mail.post(&"auction_expired", _parts(&"test_twig", 7))
	assert_true(_session.mail.collect(1).ok)
	assert_eq(_session.bank.get_count(&"test_twig"), 7)


func test_unknown_ids_fail() -> void:
	assert_eq(_session.mail.collect(5).reason, Reasons.UNKNOWN_ID)
	assert_eq(_session.mail.can_collect(5).reason, Reasons.UNKNOWN_ID)
	assert_eq(_session.mail.mark_read(5).reason, Reasons.UNKNOWN_ID)


func test_bank_full_leaves_the_message_untouched() -> void:
	_session.mail.post(&"auction_expired", _parts(&"riftite_plate", 100))
	_fill_deposit()
	var result: CommandResult = _session.mail.collect(1)
	assert_false(result.ok)
	assert_eq(result.reason, Reasons.BANK_FULL)
	assert_eq(_session.mail.can_collect(1).reason, Reasons.BANK_FULL)
	assert_eq(_session.mail.get_message(1)["items"][0]["qty"], 100)
	assert_eq(_session.bank.get_count(&"riftite_plate"), 0)


func test_collect_all_takes_what_it_can_and_counts() -> void:
	_sold(1, 10, 500)
	_session.mail.post(&"auction_expired", _parts(&"riftite_plate", 100))
	_fill_deposit()
	assert_eq(_session.mail.collect_all(), 1)  # F-183 example: money collected, the items stay
	assert_eq(_session.mail.count(), 1)
	assert_eq(_session.mail.get_message(2)["kind"], &"auction_expired")


func test_collect_all_signals_once_and_goes_oldest_first() -> void:
	_sold(1, 1, 10)
	_session.mail.post(&"auction_expired", _parts(&"test_twig", 1))
	_sold(2, 1, 20)
	watch_signals(_session.events)
	assert_eq(_session.mail.collect_all(), 3)
	assert_signal_emit_count(_session.events, "mail_changed", 1)
	assert_signal_emitted_with_parameters(_session.events, "mail_changed", [0, 0])
	assert_eq(_session.mail.collect_all(), 0)
	assert_signal_emit_count(_session.events, "mail_changed", 1)


# --- signals ----------------------------------------------------------------------------------------------------------

func test_mail_changed_follows_post_merge_and_mark_read() -> void:
	watch_signals(_session.events)
	_sold(1, 1, 10)
	assert_signal_emitted_with_parameters(_session.events, "mail_changed", [1, 1], 0)
	_sold(1, 1, 10)
	assert_signal_emit_count(_session.events, "mail_changed", 2)
	_session.mail.mark_read(1)
	assert_signal_emitted_with_parameters(_session.events, "mail_changed", [0, 1], 2)


func test_new_game_and_from_save_stay_silent() -> void:
	_sold(1, 1, 10)
	var saved: Dictionary = _session.mail.to_save()
	watch_signals(_session.events)
	_session.mail.from_save(saved)
	_session.mail.new_game()
	assert_signal_not_emitted(_session.events, "mail_changed")
	assert_eq(_session.mail.count(), 0)
