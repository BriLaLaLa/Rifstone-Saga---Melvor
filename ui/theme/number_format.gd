class_name NumberFormat
extends RefCounted
## Italian number formatting for every text of the UI (09_CONVENTIONS.md §3): thousands with ".", decimals with ",".
## Static functions only; the single definition of these formats (tooltips, toasts, top bar, pages).

## Numbers are shown with at most two decimals.
const HUNDREDTHS: int = 100
const THOUSANDS_SEPARATOR: String = "."
const DECIMAL_SEPARATOR: String = ","
const MS_PER_SECOND: float = 1000.0
const SECONDS_TEXT: String = "%s s"
## Compact format: values from COMPACT_FROM up are shown with three significant digits (truncated, never rounded up)
## and the Italian suffix of their power of 1000: mila, milioni, miliardi, bilioni, biliardi, trilioni.
const COMPACT_FROM: int = 10000
const COMPACT_SUFFIXES: PackedStringArray = ["K", "M", "Mld", "Bln", "Bld", "Trl"]
const COMPACT_STEP: int = 1000
const COMPACT_SIGNIFICANT_DIGITS: int = 3


## Integer with "." as thousands separator (1250 -> "1.250").
static func format_int(value: int) -> String:
	var digits: String = str(absi(value))
	var out: String = ""
	while digits.length() > 3:
		out = THOUSANDS_SEPARATOR + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out


## Number in Italian notation: thousands with ".", decimals with "," (at most two, no trailing zeros).
@warning_ignore("integer_division")
static func format_number(value: float) -> String:
	var hundredths: int = roundi(absf(value) * HUNDREDTHS)
	var text: String = ("-" if value < 0.0 and hundredths > 0 else "") + format_int(hundredths / HUNDREDTHS)
	var fraction: String = ("%02d" % (hundredths % HUNDREDTHS)).rstrip("0")
	if not fraction.is_empty():
		text += DECIMAL_SEPARATOR + fraction
	return text


## Milliseconds as seconds with at least one decimal (at most two): 3000 -> "3,0 s", 2700 -> "2,7 s", 250 -> "0,25 s".
static func format_seconds(ms: int) -> String:
	var text: String = format_number(ms / MS_PER_SECOND)
	if not text.contains(DECIMAL_SEPARATOR):
		text += DECIMAL_SEPARATOR + "0"
	return SECONDS_TEXT % text


## Short integer for narrow places (item cells): below COMPACT_FROM as `format_int` (9999 -> "9.999"); from there on,
## three significant digits truncated and a suffix: 12345 -> "12,3K", 123456 -> "123K", 1234567 -> "1,23M".
## The full value stays in the tooltip.
@warning_ignore("integer_division")
static func format_compact(value: int) -> String:
	var magnitude: int = absi(value)
	if magnitude < COMPACT_FROM:
		return format_int(value)
	var unit: int = COMPACT_STEP
	var index: int = 0
	while magnitude / unit >= COMPACT_STEP and index < COMPACT_SUFFIXES.size() - 1:
		unit *= COMPACT_STEP
		index += 1
	var whole: int = magnitude / unit
	var text: String = format_int(whole)
	var decimals: int = maxi(0, COMPACT_SIGNIFICANT_DIGITS - str(whole).length())
	if decimals > 0:
		var scale: int = int(pow(10.0, decimals))
		var fraction: String = str((magnitude / (unit / scale)) % scale).pad_zeros(decimals).rstrip("0")
		if not fraction.is_empty():
			text += DECIMAL_SEPARATOR + fraction
	return ("-" if value < 0 else "") + text + COMPACT_SUFFIXES[index]
