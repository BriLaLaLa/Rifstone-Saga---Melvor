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
