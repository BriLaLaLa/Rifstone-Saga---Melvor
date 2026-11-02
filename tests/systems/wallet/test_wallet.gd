extends GutTest
## Wallet: start gold, add_gold / spend with their gold_changed, invalid amounts, save round trip.

const START_GOLD_KEY: String = "start.gold"

var _session: GameSession = null


func before_each() -> void:
	_session = autofree(TestFactory.session())


func _start_gold() -> int:
	return int(_session.data.balance_value(START_GOLD_KEY))


func test_new_game_starts_with_start_gold() -> void:
	assert_gt(_start_gold(), 0)
	assert_eq(_session.wallet.get_gold(), _start_gold())


func test_new_game_resets_gold() -> void:
	_session.wallet.add_gold(900)
	_session.new_game()
	assert_eq(_session.wallet.get_gold(), _start_gold())


func test_add_gold_adds_and_emits_new_amount_and_delta() -> void:
	watch_signals(_session.events)
	_session.wallet.add_gold(120)
	assert_eq(_session.wallet.get_gold(), _start_gold() + 120)
	assert_signal_emit_count(_session.events, "gold_changed", 1)
	assert_signal_emitted_with_parameters(_session.events, "gold_changed", [_start_gold() + 120, 120])


func test_add_gold_rejects_non_positive_amounts() -> void:
	watch_signals(_session.events)
	_session.wallet.add_gold(0)
	_session.wallet.add_gold(-5)
	assert_push_error(2, "amount must be > 0")
	assert_eq(_session.wallet.get_gold(), _start_gold())
	assert_signal_not_emitted(_session.events, "gold_changed")


func test_spend_removes_gold_and_emits_negative_delta() -> void:
	_session.wallet.add_gold(100)
	watch_signals(_session.events)
	var result: CommandResult = _session.wallet.spend(30)
	assert_true(result.ok)
	assert_eq(_session.wallet.get_gold(), _start_gold() + 70)
	assert_signal_emitted_with_parameters(_session.events, "gold_changed", [_start_gold() + 70, -30])


func test_spend_everything_leaves_zero() -> void:
	assert_true(_session.wallet.spend(_start_gold()).ok)
	assert_eq(_session.wallet.get_gold(), 0)


func test_spend_more_than_owned_fails_and_changes_nothing() -> void:
	watch_signals(_session.events)
	var result: CommandResult = _session.wallet.spend(_start_gold() + 1)
	assert_false(result.ok)
	assert_eq(result.reason, Reasons.NOT_ENOUGH_GOLD)
	assert_eq(_session.wallet.get_gold(), _start_gold())
	assert_signal_not_emitted(_session.events, "gold_changed")


func test_spend_non_positive_is_invalid_amount() -> void:
	assert_eq(_session.wallet.spend(0).reason, Reasons.INVALID_AMOUNT)
	assert_eq(_session.wallet.spend(-10).reason, Reasons.INVALID_AMOUNT)
	assert_eq(_session.wallet.get_gold(), _start_gold())


func test_to_save_format() -> void:
	_session.wallet.add_gold(1200)
	assert_eq(_session.wallet.to_save(), {"gold": _start_gold() + 1200})


func test_round_trip_through_json() -> void:
	_session.wallet.add_gold(1200)
	var text: String = SaveCodec.encode(_session.to_save(0))
	var other: GameSession = autofree(TestFactory.session(9))
	assert_true(other.from_save(SaveCodec.decode(text)).ok)
	assert_eq(other.wallet.get_gold(), _start_gold() + 1200)


func test_from_save_with_bad_gold_loads_zero() -> void:
	for bad: Variant in [-3, 2.5, "many", null]:
		_session.wallet.from_save({"gold": bad})
		assert_eq(_session.wallet.get_gold(), 0, "gold %s" % str(bad))


func test_from_save_does_not_emit() -> void:
	watch_signals(_session.events)
	_session.wallet.from_save({"gold": 40.0})
	assert_eq(_session.wallet.get_gold(), 40)
	assert_signal_not_emitted(_session.events, "gold_changed")
