extends GutTest
## NumberFormat (M1-14, from M1-16): Italian integers and decimals used by every UI text.


func test_format_int_thousands() -> void:
	assert_eq(NumberFormat.format_int(0), "0")
	assert_eq(NumberFormat.format_int(999), "999")
	assert_eq(NumberFormat.format_int(1250), "1.250")
	assert_eq(NumberFormat.format_int(1000000), "1.000.000")
	assert_eq(NumberFormat.format_int(-12345), "-12.345")


func test_format_number_decimals() -> void:
	assert_eq(NumberFormat.format_number(1250.5), "1.250,5")
	assert_eq(NumberFormat.format_number(2.4), "2,4")
	assert_eq(NumberFormat.format_number(3.0), "3")
	assert_eq(NumberFormat.format_number(0.125), "0,13", "rounded to two decimals")
	assert_eq(NumberFormat.format_number(-3.5), "-3,5")
	assert_eq(NumberFormat.format_number(-0.001), "0", "no sign on a value that rounds to zero")


func test_single_definition() -> void:
	var lines: ItemTooltipLines = ItemTooltipLines.new()
	assert_false(lines.has_method(&"format_int"), "format_int lives only in NumberFormat")
	assert_false(lines.has_method(&"format_number"), "format_number lives only in NumberFormat")
	assert_eq(ItemTooltipLines.format_stat("flat", 1500.0), "+1.500", "tooltips use NumberFormat")


func test_format_seconds_has_at_least_one_decimal() -> void:
	assert_eq(NumberFormat.format_seconds(3000), "3,0 s")
	assert_eq(NumberFormat.format_seconds(2700), "2,7 s")
	assert_eq(NumberFormat.format_seconds(250), "0,25 s")
	assert_eq(NumberFormat.format_seconds(12500), "12,5 s")
	assert_eq(NumberFormat.format_seconds(0), "0,0 s")
	assert_eq(NumberFormat.format_seconds(3_600_000), "3.600,0 s")


func test_format_compact_keeps_small_values_full() -> void:
	assert_eq(NumberFormat.format_compact(0), "0")
	assert_eq(NumberFormat.format_compact(1250), "1.250")
	assert_eq(NumberFormat.format_compact(9999), "9.999", "last value below COMPACT_FROM")


func test_format_compact_three_significant_digits() -> void:
	assert_eq(NumberFormat.format_compact(10000), "10K")
	assert_eq(NumberFormat.format_compact(12345), "12,3K")
	assert_eq(NumberFormat.format_compact(123456), "123K")
	assert_eq(NumberFormat.format_compact(999999), "999K", "truncated, never rounded up to 1000K")
	assert_eq(NumberFormat.format_compact(1000000), "1M")
	assert_eq(NumberFormat.format_compact(1050000), "1,05M")
	assert_eq(NumberFormat.format_compact(1234567), "1,23M")
	assert_eq(NumberFormat.format_compact(1200000), "1,2M", "no trailing zeros")
	assert_eq(NumberFormat.format_compact(2500000000), "2,5Mld")
	assert_eq(NumberFormat.format_compact(-12345), "-12,3K")


func test_format_compact_largest_int() -> void:
	assert_eq(NumberFormat.format_compact(9223372036854775807), "9,22Trl", "int64 max has a suffix")


func test_format_compact_is_short() -> void:
	for value: int in [9999, 10000, 99999, 100000, 999999, 9999999, 99999999, 999999999]:
		assert_true(NumberFormat.format_compact(value).length() <= 5, "%d fits a cell" % value)
