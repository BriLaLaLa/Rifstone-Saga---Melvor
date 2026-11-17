extends GutTest
## MoneyLabel (M27-04, docs/05_INTERFACES_M27.md §7.o, F-177): coins drawn for each non-zero part, copper for zero.

var _params: CurrencyParams = null


func before_all() -> void:
	_params = CurrencyParams.from_dict({
		"copper_per_silver": 100, "silver_per_gold": 100,
		"symbols": {"gold": "o", "silver": "a", "copper": "r"},
		"names": {"gold": "oro", "silver": "argento", "copper": "rame"},
	})


func _make(copper: int) -> MoneyLabel:
	var label: MoneyLabel = add_child_autofree(MoneyLabel.new())
	label.set_amount(copper, _params)
	return label


func test_zero_is_the_copper_coin() -> void:
	var label: MoneyLabel = _make(0)
	assert_eq(label.shown_coins(), [&"copper"] as Array[StringName])
	assert_eq(label.plain_text(), "0r")


func test_seven_is_copper_only() -> void:
	var label: MoneyLabel = _make(7)
	assert_eq(label.shown_coins(), [&"copper"] as Array[StringName])
	assert_eq(label.plain_text(), Money.text(7, _params))


func test_12540_is_one_gold_25_silver_40_copper() -> void:
	var label: MoneyLabel = _make(12540)
	assert_eq(label.shown_coins(), [&"gold", &"silver", &"copper"] as Array[StringName])
	assert_eq(label.plain_text(), "1o 25a 40r")


func test_zero_parts_are_left_out() -> void:
	var label: MoneyLabel = _make(1000005)
	assert_eq(label.shown_coins(), [&"gold", &"copper"] as Array[StringName])
	assert_eq(label.plain_text(), Money.text(1000005, _params))
	var silver_only: MoneyLabel = _make(300)
	assert_eq(silver_only.shown_coins(), [&"silver"] as Array[StringName])


func test_redraw_replaces_the_previous_amount() -> void:
	var label: MoneyLabel = _make(12540)
	label.set_amount(5, _params)
	await get_tree().process_frame
	assert_eq(label.shown_coins(), [&"copper"] as Array[StringName])
	assert_eq(label.get_child_count(), 2, "one number and one icon")


func test_negative_amount_has_a_minus_sign() -> void:
	var label: MoneyLabel = _make(-250)
	assert_eq(label.plain_text(), Money.text(-250, _params))
