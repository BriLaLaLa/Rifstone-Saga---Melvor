class_name TopBar
extends PanelContainer
## Top bar of the main screen (docs/03_ARCHITECTURE.md §11): gold, bank slots used / capacity, slot name, menu.
##
## Every value is read from the session (`wallet.get_gold`, `bank.used`/`capacity`, `player_name`, `slot`) and
## redrawn on `gold_changed` and `deposit_changed`. The menu button emits `menu_requested`; the main screen
## ends the session. It keeps no game state: only the session reference and its nodes.

signal menu_requested

const GOLD_ICON: String = "coins"
const BANK_ICON: String = "box"
const MENU_ICON: String = "door-exit"
const BANK_TEXT: String = "%s / %s"
const SLOT_TEXT: String = "%s  ·  Slot %d"

var _session: GameSession = null

@onready var _gold_icon: TextureRect = %GoldIcon
@onready var _gold_label: Label = %GoldLabel
@onready var _bank_icon: TextureRect = %BankIcon
@onready var _bank_label: Label = %BankLabel
@onready var _slot_label: Label = %SlotLabel
@onready var _menu_button: Button = %MenuButton


func _ready() -> void:
	custom_minimum_size.y = UiStyle.TOP_BAR_HEIGHT
	_gold_icon.texture = UiStyle.icon(GOLD_ICON)
	_gold_icon.modulate = UiStyle.GOLD
	_bank_icon.texture = UiStyle.icon(BANK_ICON)
	_bank_icon.modulate = UiStyle.GOLD
	_menu_button.icon = UiStyle.icon(MENU_ICON)
	_menu_button.pressed.connect(_on_menu_button_pressed)


## Reads the state of `session` and follows its gold and bank capacity.
func bind(session: GameSession) -> void:
	unbind()
	_session = session
	_session.events.gold_changed.connect(_on_events_gold_changed)
	_session.events.deposit_changed.connect(_on_events_deposit_changed)
	_session.events.player_renamed.connect(_on_events_player_renamed)
	_redraw_slot()
	_redraw_gold()
	_redraw_bank()


## Disconnects from the session's events; the texts stay as they are.
func unbind() -> void:
	if _session == null:
		return
	if is_instance_valid(_session):
		if _session.events.gold_changed.is_connected(_on_events_gold_changed):
			_session.events.gold_changed.disconnect(_on_events_gold_changed)
		if _session.events.deposit_changed.is_connected(_on_events_deposit_changed):
			_session.events.deposit_changed.disconnect(_on_events_deposit_changed)
		if _session.events.player_renamed.is_connected(_on_events_player_renamed):
			_session.events.player_renamed.disconnect(_on_events_player_renamed)
	_session = null


func _exit_tree() -> void:
	unbind()


func _redraw_slot() -> void:
	_slot_label.text = SLOT_TEXT % [_session.player_name, _session.slot]


func _on_events_player_renamed(_new_name: String) -> void:
	_redraw_slot()


func _redraw_gold() -> void:
	_gold_label.text = NumberFormat.format_int(_session.wallet.get_gold())


func _redraw_bank() -> void:
	_bank_label.text = BANK_TEXT % [NumberFormat.format_int(_session.deposit.used()),
			NumberFormat.format_int(_session.deposit.capacity())]


func _on_events_gold_changed(_new_amount: int, _delta: int) -> void:
	_redraw_gold()


func _on_events_deposit_changed(_used: int, _capacity: int) -> void:
	_redraw_bank()


func _on_menu_button_pressed() -> void:
	menu_requested.emit()
