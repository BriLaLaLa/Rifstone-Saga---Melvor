class_name CurrencyBox
extends VBoxContainer
## Rift currencies of the piece panel (docs/01_GDD.md §26): the currency chosen among the ones in the bank, the text
## preview of its effect on this piece (and whether the rarity fits) and "Usa valuta". The ritiro (`reroll`) asks for a
## confirmation because it loses the current affixes. Emits `currency_requested`; the page sends `armory.use_currency`
## and shows a refusal. It keeps presentation state only: the currency chosen and the pending confirmation.

signal currency_requested(currency_id: StringName)

const SEPARATION: int = 4

var _selected: StringName = &""
var _confirming: bool = false
var _uid: int = 0


func _ready() -> void:
	add_theme_constant_override("separation", SEPARATION)


## Draws the box for the piece `uid` of `session`; hidden-looking (only a hint) when the bank has no currency.
func show_for(session: GameSession, uid: int) -> void:
	if uid != _uid:
		_confirming = false
	_uid = uid
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var inst: ItemInstance = session.armory.get_instance(uid)
	if inst == null:
		return
	add_child(_label(SocketTexts.CURRENCY_TITLE_TEXT, &"HeaderLabel", "Title"))
	var owned: Array[Dictionary] = RiftTexts.owned(session, &"currency")
	if owned.is_empty():
		_confirming = false
		add_child(_label(SocketTexts.NO_CURRENCIES_TEXT, &"MutedLabel", "NoCurrencies"))
		return
	var option := OptionButton.new()
	option.name = "CurrencyOption"
	option.focus_mode = Control.FOCUS_NONE
	var select: int = 0
	for i: int in owned.size():
		var def: ItemDef = owned[i]["item"] as ItemDef
		option.add_item("%s  x%s" % [def.name, NumberFormat.format_int(int(owned[i]["count"]))])
		option.set_item_metadata(i, def.id)
		if def.id == _selected:
			select = i
	option.select(select)
	var chosen: StringName = option.get_item_metadata(select) as StringName
	if chosen != _selected:
		_confirming = false
	_selected = chosen
	option.item_selected.connect(_on_option_selected.bind(option, session))
	add_child(option)
	var effect: StringName = session.data.item(_selected).currency_effect
	add_child(_label(SocketTexts.currency_preview(effect, inst), &"", "Preview"))
	if effect == CurrencyUse.REROLL and _confirming:
		add_child(_label(SocketTexts.REROLL_WARNING_TEXT, &"MutedLabel", "Warning"))
	var button := Button.new()
	button.name = "UseButton"
	button.text = SocketTexts.CONFIRM_USE_TEXT if effect == CurrencyUse.REROLL and _confirming else SocketTexts.USE_TEXT
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = UiStyle.MENU_BUTTON_HEIGHT
	button.pressed.connect(_on_use_pressed.bind(effect, session))
	add_child(button)


func _on_option_selected(index: int, option: OptionButton, session: GameSession) -> void:
	_selected = option.get_item_metadata(index) as StringName
	_confirming = false
	show_for(session, _uid)


func _on_use_pressed(effect: StringName, session: GameSession) -> void:
	if effect == CurrencyUse.REROLL and not _confirming:
		_confirming = true
		show_for(session, _uid)
		return
	_confirming = false
	currency_requested.emit(_selected)


func _label(text: String, variation: StringName, node_name: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if variation != &"":
		label.theme_type_variation = variation
	return label
