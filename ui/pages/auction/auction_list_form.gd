class_name AuctionListForm
extends VBoxContainer
## "Metti in vendita" (docs/05_INTERFACES_M27.md §7.o, F-180/F-181): the price in three fields (gold, silver, copper) put together
## with `Money.from_parts` and prefilled with the suggested price, the duration, the deposit and the proceeds read from
## `AuctionHouse`, and the button with the reason of `can_list`. The quantity comes from the detail panel. No game state of its own:
## only the fields' values (presentation); the page issues the command.

signal list_requested(item_id: StringName, qty: int, price: int, duration_id: StringName)

const COINS: Array[StringName] = [&"gold", &"silver", &"copper"]

var _auction: Object = null
var _currency: CurrencyParams = null
var _item_id: StringName = &""
var _qty: int = 1
var _spins: Array[SpinBox] = []
var _duration: OptionButton = null
var _deposit_label: Label = null
var _net_label: Label = null
var _reason_label: Label = null
var _button: Button = null


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	var caption: Label = Label.new()
	caption.theme_type_variation = &"HeaderLabel"
	caption.text = AuctionTexts.LIST_TITLE_TEXT
	add_child(caption)
	var price_row: HBoxContainer = HBoxContainer.new()
	price_row.name = "PriceRow"
	add_child(price_row)
	for key: String in ["Gold", "Silver", "Copper"]:
		var spin: SpinBox = SpinBox.new()
		spin.name = "Price%s" % key
		spin.min_value = 0
		spin.step = 1
		spin.rounded = true
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spin.value_changed.connect(func(_v: float) -> void: _redraw())
		price_row.add_child(spin)
		_spins.append(spin)
	var suggest: Button = Button.new()
	suggest.name = "SuggestButton"
	suggest.text = AuctionTexts.SUGGESTED_TEXT
	suggest.focus_mode = Control.FOCUS_NONE
	suggest.pressed.connect(reset_price)
	add_child(suggest)
	_duration = OptionButton.new()
	_duration.name = "DurationPicker"
	_duration.focus_mode = Control.FOCUS_NONE
	_duration.item_selected.connect(func(_i: int) -> void: _redraw())
	add_child(_duration)
	_deposit_label = Label.new()
	_deposit_label.name = "DepositLabel"
	_deposit_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_deposit_label)
	_net_label = Label.new()
	_net_label.name = "NetLabel"
	_net_label.add_theme_color_override("font_color", UiStyle.GOLD_LIGHT)
	_net_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_net_label)
	_button = Button.new()
	_button.name = "ListButton"
	_button.theme_type_variation = &"AccentButton"
	_button.text = AuctionTexts.LIST_BUTTON_TEXT
	_button.custom_minimum_size.y = 44.0
	_button.focus_mode = Control.FOCUS_NONE
	_button.pressed.connect(_on_pressed)
	add_child(_button)
	_reason_label = Label.new()
	_reason_label.name = "ListReasonLabel"
	_reason_label.add_theme_color_override("font_color", UiStyle.BAD)
	_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_reason_label)


## Rereads the form for `item_id` and the quantity `qty`; the price is prefilled with the suggested one when the item changes.
func refresh(auction: Object, session: GameSession, item_id: StringName, qty: int) -> void:
	_auction = auction
	_currency = session.data.currency()
	_qty = qty
	var changed: bool = item_id != _item_id
	_item_id = item_id
	var durations: Array = auction.durations()
	if _duration.item_count != durations.size():
		_duration.clear()
		for duration: AuctionDuration in durations:
			_duration.add_item(AuctionTexts.DURATION_TEXT % duration.hours)
			_duration.set_item_metadata(_duration.item_count - 1, duration.id)
	_spins[2].max_value = _currency.copper_per_silver - 1
	_spins[1].max_value = _currency.copper_per_gold() / _currency.copper_per_silver - 1
	_spins[0].max_value = Money.split(int(auction.max_price(item_id)), _currency).x
	for index: int in 3:
		_spins[index].suffix = String(_currency.symbols[COINS[index]])
	if changed:
		reset_price()
	else:
		_redraw()


## Puts the suggested price of the current item back in the three fields.
func reset_price() -> void:
	if _auction == null or _item_id == &"":
		return
	var parts: Vector3i = Money.split(int(_auction.suggested_price(_item_id)), _currency)
	for index: int in 3:
		_spins[index].set_value_no_signal(float(parts[index]))
	_redraw()


func _price() -> int:
	return Money.from_parts(int(_spins[0].value), int(_spins[1].value), int(_spins[2].value), _currency)


func _duration_id() -> StringName:
	if _duration.item_count == 0:
		return &""
	return _duration.get_item_metadata(maxi(_duration.selected, 0))


func _redraw() -> void:
	if _auction == null or _item_id == &"":
		return
	var price: int = _price()
	var duration_id: StringName = _duration_id()
	_deposit_label.text = AuctionTexts.DEPOSIT_LIST_TEXT % Money.text(
			int(_auction.listing_deposit(_item_id, _qty, duration_id)), _currency)
	_net_label.text = AuctionTexts.NET_TEXT % Money.text(int(_auction.listing_net(_item_id, _qty, price)), _currency)
	var can: CommandResult = _auction.can_list(_item_id, _qty, price, duration_id)
	var reason: String = "" if can.ok else AuctionTexts.refused(can.reason)
	_button.disabled = not can.ok
	_button.tooltip_text = reason
	_reason_label.text = reason
	_reason_label.visible = not can.ok


func _on_pressed() -> void:
	list_requested.emit(_item_id, _qty, _price(), _duration_id())
