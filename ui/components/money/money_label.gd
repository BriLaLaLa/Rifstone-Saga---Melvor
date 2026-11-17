class_name MoneyLabel
extends HBoxContainer
## An amount of money (docs/05_INTERFACES_M27.md §7.o, F-177): for every non-zero part a number and a coloured coin icon
## (gold, silver, copper); zero is "0" and the copper coin; a negative amount (deltas) has a minus sign. It keeps no game
## state: it only draws what `set_amount` gives it.

const ICON_PREFIX: String = "coin_"
const ICON_SIDE: int = 16
const COIN_META: StringName = &"coin"
const TEXT_META: StringName = &"money_text"
const COIN_COLORS: Dictionary[StringName, Color] = {
	&"gold": UiStyle.GOLD_LIGHT, &"silver": UiStyle.SILVER, &"copper": UiStyle.COPPER,
}

## Text shown before the amount ("Monete:"); empty = none.
@export var caption: String = ""


func _init() -> void:
	add_theme_constant_override("separation", 3)
	mouse_filter = Control.MOUSE_FILTER_PASS


## Redraws the amount (copper) with the symbols and ratios of `params`.
func set_amount(copper: int, params: CurrencyParams) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	if not caption.is_empty():
		_add_text(caption + " ")
	if copper < 0:
		_add_text(Money.MINUS)
	var parts: Vector3i = Money.split(copper, params)
	var shown: bool = false
	for pair: Array in [[&"gold", parts.x], [&"silver", parts.y], [&"copper", parts.z]]:
		var coin: StringName = pair[0]
		var value: int = pair[1]
		if value > 0 or (coin == &"copper" and not shown):
			_add_coin(coin, value, params)
			shown = true
	tooltip_text = Money.text(copper, params)


## The coins drawn, in order (gold, silver, copper).
func shown_coins() -> Array[StringName]:
	var out: Array[StringName] = []
	for child: Node in get_children():
		if child.has_meta(COIN_META):
			out.append(child.get_meta(COIN_META) as StringName)
	return out


## The text of the drawn amount in the format of `Money.text` ("1o 25a 40r"), for tests.
func plain_text() -> String:
	var out: PackedStringArray = []
	var minus: String = ""
	for child: Node in get_children():
		if child.has_meta(TEXT_META):
			out.append(str(child.get_meta(TEXT_META)))
		elif child is Label and (child as Label).text == Money.MINUS:
			minus = Money.MINUS
	return minus + " ".join(out)


func _add_text(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)


func _add_coin(coin: StringName, value: int, params: CurrencyParams) -> void:
	var number := Label.new()
	number.text = NumberFormat.format_int(value)
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number.add_theme_color_override("font_color", COIN_COLORS[coin])
	number.set_meta(TEXT_META, "%d%s" % [value, params.symbols[coin]])
	number.set_meta(COIN_META, coin)
	add_child(number)
	var icon := TextureRect.new()
	icon.texture = UiStyle.icon(ICON_PREFIX + String(coin))
	icon.custom_minimum_size = Vector2(ICON_SIDE, ICON_SIDE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)
