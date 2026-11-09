class_name FracturesPage
extends Page
## Fractures page (docs/05_INTERFACES.md §7.v, docs/01_GDD.md §17, route `fractures`). Outside a Fracture: the Cards of the
## Deposit (`session.cards`) with "Apri", "Blocca/Sblocca", "Smantella" and "Cristalli", and the pending loot with
## "Raccogli". During a Fracture: the progress, the modifiers, the Fracture bag and "Abbandona" (with a confirmation).
##
## Every redraw reads the session (`cards`, `fractures`, `bank`, `data`); the page keeps its nodes and one presentation
## value (the Card whose Crystals are being chosen). Player actions are commands; a refusal shows its reason in Italian.

const DUST_ITEM: StringName = &"rift_dust"

var _session: GameSession = null
## Signal, callable pairs connected in `bind` (disconnected in `unbind`).
var _connections: Array[Array] = []
## Presentation state: the Card that is choosing a Crystal (0 = none) and the selected Crystal.
var _crystal_uid: int = 0
var _crystal_item: StringName = &""

@onready var _margin: MarginContainer = %Margin
@onready var _title_label: Label = %TitleLabel
@onready var _intro_label: Label = %IntroLabel
@onready var _message_label: Label = %MessageLabel
@onready var _pending_box: PanelContainer = %PendingBox
@onready var _pending_text: Label = %PendingText
@onready var _collect_button: Button = %CollectButton
@onready var _run_box: PanelContainer = %RunBox
@onready var _run_panel: FractureRunPanel = %RunPanel
@onready var _abandon_button: Button = %AbandonButton
@onready var _cards_section: VBoxContainer = %CardsSection
@onready var _cards_title: Label = %CardsTitle
@onready var _cards_list: VBoxContainer = %CardsList
@onready var _no_cards_label: Label = %NoCardsLabel
@onready var _crystal_box: PanelContainer = %CrystalBox
@onready var _crystal_content: VBoxContainer = %CrystalContent


func _ready() -> void:
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		_margin.add_theme_constant_override(side, UiStyle.ARMORY_MARGIN)
	_title_label.text = FractureTexts.TITLE_TEXT
	_intro_label.text = FractureTexts.INTRO_TEXT
	_cards_title.text = FractureTexts.CARDS_TITLE_TEXT
	_no_cards_label.text = FractureTexts.NO_CARDS_TEXT
	_collect_button.text = FractureTexts.COLLECT_TEXT
	_abandon_button.text = FractureTexts.ABANDON_TEXT
	_message_label.add_theme_color_override("font_color", UiStyle.BAD)
	_collect_button.pressed.connect(_on_collect_pressed)
	_abandon_button.pressed.connect(_on_abandon_pressed)


func bind(session: GameSession) -> void:
	unbind()
	_session = session
	HelpButton.attach(_title_label.get_parent(), session.data, &"fractures", _title_label)
	_crystal_uid = 0
	_message_label.visible = false
	var events: GameEvents = session.events
	_connect(events.card_changed, _redraw_from_event.unbind(2))
	_connect(events.deposit_changed, _redraw_from_event.unbind(2))
	_connect(events.fracture_opened, _redraw_from_event.unbind(1))
	_connect(events.fracture_group_cleared, _redraw_from_event.unbind(2))
	_connect(events.fracture_boss_started, _redraw_from_event.unbind(1))
	_connect(events.fracture_finished, _redraw_from_event.unbind(5))
	_connect(events.fracture_bag_changed, _redraw_from_event.unbind(3))
	_connect(events.fracture_loot_lost, _redraw_from_event.unbind(3))
	_connect(events.bank_changed, _redraw_from_event.unbind(3))
	_redraw()


func unbind() -> void:
	for pair: Array in _connections:
		var source: Signal = pair[0]
		var callable: Callable = pair[1]
		if source.is_connected(callable):
			source.disconnect(callable)
	_connections.clear()
	_session = null


func _exit_tree() -> void:
	unbind()


func _connect(source: Signal, callable: Callable) -> void:
	source.connect(callable)
	_connections.append([source, callable])


func _redraw_from_event() -> void:
	_redraw()


func _redraw() -> void:
	if _session == null:
		return
	var fractures: FractureSystem = _session.fractures
	var active: bool = fractures.is_active()
	_run_box.visible = active
	_cards_section.visible = not active
	if active:
		_run_panel.redraw(_session)
	_redraw_pending()
	if not active:
		_redraw_cards()
	_redraw_crystals()


func _redraw_pending() -> void:
	var has_pending: bool = _session.fractures.has_pending()
	_pending_box.visible = has_pending
	if has_pending:
		_pending_text.text = "%s: %s" % [FractureTexts.PENDING_TITLE_TEXT, FractureTexts.bag_text(_session.fractures.pending())]


func _redraw_cards() -> void:
	for child: Node in _cards_list.get_children():
		_cards_list.remove_child(child)
		child.queue_free()
	var cards: Array[MapCard] = _session.cards.cards()
	cards.sort_custom(func(a: MapCard, b: MapCard) -> bool:
		return a.grade > b.grade or (a.grade == b.grade and a.uid < b.uid))
	_no_cards_label.visible = cards.is_empty()
	var can_open: bool = not _session.fractures.has_pending()
	for card: MapCard in cards:
		var row := CardRow.new()
		_cards_list.add_child(row)
		row.show_card(_session, card, can_open)
		row.open_requested.connect(_on_open_requested)
		row.lock_requested.connect(_on_lock_requested)
		row.salvage_requested.connect(_on_salvage_requested)
		row.currency_requested.connect(_on_currency_requested)


# --- Crystals -------------------------------------------------------------------------------------------------

func _redraw_crystals() -> void:
	for child: Node in _crystal_content.get_children():
		_crystal_content.remove_child(child)
		child.queue_free()
	var card: MapCard = _session.cards.get_card(_crystal_uid) if _crystal_uid > 0 else null
	_crystal_box.visible = card != null and not _session.fractures.is_active()
	if not _crystal_box.visible:
		_crystal_uid = 0
		return
	_crystal_content.add_child(_label("CrystalTitle", FractureTexts.CRYSTAL_TITLE_TEXT % card.grade, &"HeaderLabel"))
	var owned: Array[Dictionary] = RiftTexts.owned(_session, &"currency")
	if owned.is_empty():
		_crystal_content.add_child(_label("NoCrystals", FractureTexts.CRYSTAL_NONE_TEXT, &"MutedLabel"))
	else:
		var option := OptionButton.new()
		option.name = "CrystalOption"
		option.focus_mode = Control.FOCUS_NONE
		var select: int = 0
		for i: int in owned.size():
			var def: ItemDef = owned[i]["item"] as ItemDef
			option.add_item(FractureTexts.CRYSTAL_OPTION_TEXT % [def.name, NumberFormat.format_int(int(owned[i]["count"]))])
			option.set_item_metadata(i, def.id)
			option.set_item_tooltip(i, def.description)
			if def.id == _crystal_item:
				select = i
		option.select(select)
		_crystal_item = option.get_item_metadata(select) as StringName
		option.item_selected.connect(func(index: int) -> void: _crystal_item = option.get_item_metadata(index) as StringName)
		_crystal_content.add_child(option)
		_crystal_content.add_child(_button("UseCrystalButton", FractureTexts.CRYSTAL_USE_TEXT, _on_use_crystal_pressed))
	_crystal_content.add_child(_button("CloseCrystalButton", FractureTexts.CRYSTAL_CLOSE_TEXT, _on_close_crystals_pressed))


func _label(node_name: String, text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if variation != &"":
		label.theme_type_variation = variation
	return label


func _button(node_name: String, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = UiStyle.MENU_BUTTON_HEIGHT
	button.pressed.connect(callback)
	return button


# --- Commands -------------------------------------------------------------------------------------------------

func _show_result(result: CommandResult, success_text: String = "") -> void:
	_message_label.visible = not result.ok or success_text != ""
	_message_label.add_theme_color_override("font_color", UiStyle.GOOD if result.ok else UiStyle.BAD)
	_message_label.text = success_text if result.ok else FractureTexts.refusal(result.reason)


func _on_open_requested(uid: int) -> void:
	if _session != null:
		_crystal_uid = 0
		_show_result(_session.fractures.open(uid))
		_redraw()


func _on_lock_requested(uid: int, locked: bool) -> void:
	if _session != null:
		_show_result(_session.cards.set_locked(uid, locked))


func _on_salvage_requested(uid: int) -> void:
	if _session == null:
		return
	var before: int = _session.bank.get_count(DUST_ITEM)
	var result: CommandResult = _session.cards.salvage(uid)
	_show_result(result, FractureTexts.SALVAGED_TEXT % NumberFormat.format_int(_session.bank.get_count(DUST_ITEM) - before))
	_redraw()


func _on_currency_requested(uid: int) -> void:
	_crystal_uid = 0 if _crystal_uid == uid else uid
	_message_label.visible = false
	_redraw()


func _on_use_crystal_pressed() -> void:
	if _session != null and _crystal_uid > 0:
		_show_result(_session.cards.use_currency(_crystal_uid, _crystal_item), FractureTexts.USED_TEXT)
		_redraw()


func _on_close_crystals_pressed() -> void:
	_crystal_uid = 0
	_redraw()


func _on_collect_pressed() -> void:
	if _session != null:
		_show_result(_session.fractures.collect(), FractureTexts.COLLECTED_TEXT)
		_redraw()


func _on_abandon_pressed() -> void:
	var accepted: bool = await ConfirmDialog.ask(self, FractureTexts.ABANDON_TITLE_TEXT, FractureTexts.ABANDON_QUESTION_TEXT)
	if accepted and _session != null:
		_show_result(_session.fractures.abandon())
		_redraw()
