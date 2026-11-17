extends GutTest
## F-177 (docs/02_FORMULAS_M27.md): split, text and recomposition of a money amount in copper.

var _p: CurrencyParams


func before_each() -> void:
	# Straight from balance.json (not through GameData): this logic test does not depend on the other data being valid.
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/config/balance.json")) as Dictionary
	_p = CurrencyParams.from_dict(balance["currency"] as Dictionary)
	assert_not_null(_p)


func test_the_split_examples() -> void:
	assert_eq(Money.split(0, _p), Vector3i(0, 0, 0))
	assert_eq(Money.split(7, _p), Vector3i(0, 0, 7))
	assert_eq(Money.split(100, _p), Vector3i(0, 1, 0))
	assert_eq(Money.split(12540, _p), Vector3i(1, 25, 40))
	assert_eq(Money.split(1000005, _p), Vector3i(100, 0, 5))
	assert_eq(Money.split(-250, _p), Vector3i(0, 2, 50), "the split is of |copper|")


func test_the_text_examples() -> void:
	var cases: Dictionary = {0: "0c", 7: "7c", 100: "1s", 10000: "1g", 12540: "1g 25s 40c", 125000: "12g 50s",
			1000005: "100g 5c", 6760916: "676g 9s 16c", -250: "−2s 50c"}
	for copper: int in cases:
		assert_eq(Money.text(copper, _p), cases[copper], "text of %d" % copper)


func test_the_recomposition_examples() -> void:
	assert_eq(Money.from_parts(1, 25, 40, _p), 12540)
	assert_eq(Money.from_parts(0, 0, 0, _p), 0)


func test_split_and_from_parts_are_inverse() -> void:
	for copper: int in [0, 1, 99, 100, 9999, 10000, 123456789]:
		var parts: Vector3i = Money.split(copper, _p)
		assert_eq(Money.from_parts(parts.x, parts.y, parts.z, _p), copper)


func test_a_negative_part_is_refused() -> void:
	assert_eq(Money.from_parts(-1, 0, 0, _p), 0)
	assert_eq(Money.from_parts(0, 5, -3, _p), 0)
	assert_push_error(2)


func test_the_symbols_come_from_the_data() -> void:
	var other: CurrencyParams = CurrencyParams.new()
	other.copper_per_silver = 10
	other.silver_per_gold = 10
	other.symbols = {&"gold": "G", &"silver": "S", &"copper": "C"}
	assert_eq(Money.text(123, other), "1G 2S 3C")
	assert_eq(other.copper_per_gold(), 100)
