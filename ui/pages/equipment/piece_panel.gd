class_name PiecePanel
extends PanelContainer
## Item card of the selected piece on the Equipment page (docs/UI_GDR.md §3): icon, name in the rarity color, the line
## "slot · item level · +N", requirements, base stats, a separator, affixes, the sockets as icons and the buttons
## "Equipaggia" (a one-handed weapon: "In mano" / "Seconda mano"), "Rimuovi", "Blocca", "Smantella" and "Vendi".
## There is no comparison here: it appears only in the hover tooltip. Refine, sockets and currencies live at the
## Forge bench of the Forging page.
##
## Internal to EquipmentPage. It keeps only the uid it shows and the session of the last `show_piece` (to read,
## never a copy of the state); every call re-reads the armory, the equipment and the character. It never changes game
## state: the buttons emit signals and the page sends the commands.

signal equip_requested(uid: int, slot: StringName)
signal unequip_requested(slot: StringName)
signal lock_requested(uid: int, locked: bool)
signal sell_requested(uid: int)
signal salvage_requested(uid: int)
signal close_requested

const EQUIP_TEXT: String = "Equipaggia"
const MAIN_HAND_TEXT: String = "In mano"
const OFFHAND_TEXT: String = "Seconda mano"
const UNEQUIP_TEXT: String = "Rimuovi"
const LOCK_TEXT: String = "Blocca"
const UNLOCK_TEXT: String = "Sblocca"
const SALVAGE_TEXT: String = "Smantella"
const SELL_TEXT: String = "Vendi (%s oro)"
const SELL_LOCKED_TEXT: String = "Sblocca il pezzo per venderlo."
const SELL_WORN_TEXT: String = "Rimuovi il pezzo per venderlo."
const SELL_NOT_SELLABLE_TEXT: String = "Questo pezzo non si vende."
const WORN_STATE_TEXT: String = "Indossato: %s"
const LOCKED_STATE_TEXT: String = "Bloccato: non si vende."
const IN_ARMORY_TEXT: String = "Nell'Armeria."
const CLOSE_ICON: String = "x"
const CLOSE_TOOLTIP: String = "Chiudi"
const UNIQUE_TOOL_NOTE: String = "Attrezzo unico: si raffina dalla pagina del suo mestiere."
const OFFHAND_SLOT: StringName = &"offhand"
const WEAPON_SLOT: StringName = &"weapon"
const ICON_SIZE := Vector2(64, 64)

var _uid: int = 0
## Session of the last `show_piece` (read at every use, never a copy of its state).
var _session: GameSession = null
## Presentation: whether the salvage confirmation is open.
var _salvage_open: bool = false

@onready var _icon: TextureRect = %Icon
@onready var _name_label: Label = %NameLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _close_box: HBoxContainer = %CloseBox
@onready var _state_label: Label = %StateLabel
@onready var _stats_label: RichTextLabel = %StatsLabel
@onready var _affix_label: RichTextLabel = %AffixLabel
@onready var _lines_separator: HSeparator = %LinesSeparator
@onready var _socket_icons: SocketIcons = %SocketIcons
@onready var _equip_button: Button = %EquipButton
@onready var _offhand_button: Button = %OffhandButton
@onready var _unequip_button: Button = %UnequipButton
@onready var _lock_button: Button = %LockButton
@onready var _salvage_button: Button = %SalvageButton
@onready var _salvage_box: SalvageBox = %SalvageBox
@onready var _sell_note: Label = %SellNote
@onready var _sell_button: Button = %SellButton


func _ready() -> void:
	_icon.custom_minimum_size = ICON_SIZE
	_name_label.theme_type_variation = &"HeaderLabel"
	var close: Button = UiStyle.icon_button(CLOSE_ICON, CLOSE_TOOLTIP, UiStyle.WINDOW_CLOSE_BUTTON_SIDE)
	close.name = "CloseButton"
	close.flat = true
	close.pressed.connect(func() -> void: close_requested.emit())
	_close_box.add_child(close)
	_equip_button.pressed.connect(_on_equip_pressed.bind(&""))
	_offhand_button.pressed.connect(_on_equip_pressed.bind(OFFHAND_SLOT))
	_offhand_button.text = OFFHAND_TEXT
	_unequip_button.text = UNEQUIP_TEXT
	_unequip_button.pressed.connect(_on_unequip_pressed)
	_lock_button.pressed.connect(_on_lock_pressed)
	_salvage_button.text = SALVAGE_TEXT
	_salvage_button.pressed.connect(_toggle_salvage)
	_salvage_box.salvage_confirmed.connect(_on_salvage_confirmed)
	_salvage_box.cancelled.connect(_toggle_salvage)
	_sell_button.pressed.connect(_on_sell_pressed)
	for button: Button in [_equip_button, _offhand_button, _unequip_button, _lock_button, _salvage_button,
			_sell_button]:
		button.custom_minimum_size.y = UiStyle.MENU_BUTTON_HEIGHT
	clear()


## Shows the piece `uid` as it is now in the armory of `session`. False (and clear) if it is not there any more.
func show_piece(session: GameSession, uid: int) -> bool:
	var inst: ItemInstance = session.armory.get_instance(uid) if session != null else null
	var base: ItemDef = session.data.item(inst.base_id) if inst != null else null
	if base == null or base.equip == null:
		clear()
		return false
	if uid != _uid:
		_salvage_open = false
	_uid = uid
	_session = session
	var worn_slot: StringName = session.equipment.slot_of(uid)
	_icon.texture = ItemSlotView.icon_of(base.icon)
	_name_label.text = base.name
	_name_label.add_theme_color_override("font_color", UiStyle.rarity_color(inst.rarity))
	_subtitle_label.text = ArmoryTexts.card_subtitle(inst, base, session.data)
	_refresh_state(inst, worn_slot)
	_stats_label.text = "\n".join(ArmoryTexts.card_top_lines(session, uid))
	var affixes: PackedStringArray = ArmoryTexts.card_affix_lines(session, uid)
	_affix_label.text = "\n".join(affixes)
	_affix_label.visible = not affixes.is_empty()
	_lines_separator.visible = true
	_socket_icons.show_for(session, uid)
	_refresh_actions(inst, base, worn_slot)
	_apply_salvage()
	visible = true
	return true


## Hides the panel and forgets the piece.
func clear() -> void:
	_uid = 0
	_salvage_open = false
	_salvage_box.visible = false
	_session = null
	_icon.texture = null
	_name_label.text = ""
	_subtitle_label.text = ""
	_state_label.text = ""
	_stats_label.text = ""
	_affix_label.text = ""
	for button: Button in [_equip_button, _offhand_button, _unequip_button]:
		button.visible = false
	visible = false


## Uid of the piece shown now; 0 if the panel is closed.
func uid() -> int:
	return _uid


func _refresh_state(inst: ItemInstance, worn_slot: StringName) -> void:
	if worn_slot != &"":
		_state_label.text = WORN_STATE_TEXT % EquipmentStatsText.slot_text(worn_slot, _session.data)
		_state_label.add_theme_color_override("font_color", UiStyle.GOOD)
	elif inst.locked:
		_state_label.text = LOCKED_STATE_TEXT
		_state_label.add_theme_color_override("font_color", UiStyle.GOLD_LIGHT)
	else:
		_state_label.text = IN_ARMORY_TEXT
		_state_label.add_theme_color_override("font_color", UiStyle.TEXT_2)


func _refresh_actions(inst: ItemInstance, base: ItemDef, worn_slot: StringName) -> void:
	var worn: bool = worn_slot != &""
	var weapon: WeaponInfo = base.equip.weapon
	var one_handed_weapon: bool = base.equip.slot == WEAPON_SLOT and weapon != null and not weapon.two_handed
	# M10: a unique tool stays in its slot: no Rimuovi, Blocca, Smantella or Vendi.
	var unique_tool: bool = worn_slot.begins_with(EquipmentStatsText.TOOL_SLOT_PREFIX)
	_lock_button.visible = not unique_tool
	_salvage_button.visible = not unique_tool
	_sell_button.visible = not unique_tool
	if unique_tool:
		_salvage_open = false
		_sell_note.text = UNIQUE_TOOL_NOTE
		_sell_note.visible = true
		_equip_button.visible = false
		_offhand_button.visible = false
		_unequip_button.visible = false
		return
	_equip_button.visible = not worn
	_equip_button.text = MAIN_HAND_TEXT if one_handed_weapon else EQUIP_TEXT
	_offhand_button.visible = not worn and one_handed_weapon
	_unequip_button.visible = worn
	_lock_button.text = UNLOCK_TEXT if inst.locked else LOCK_TEXT
	var gold: int = _session.shop.sell_value(inst.base_id, 1)
	var note: String = ""
	if worn:
		note = SELL_WORN_TEXT
	elif inst.locked:
		note = SELL_LOCKED_TEXT
	elif gold <= 0:
		note = SELL_NOT_SELLABLE_TEXT
	_sell_note.text = note
	_sell_note.visible = not note.is_empty()
	_sell_button.text = SELL_TEXT % NumberFormat.format_int(gold)
	_sell_button.disabled = not note.is_empty()
	_salvage_button.disabled = worn or inst.locked


func _on_equip_pressed(slot: StringName) -> void:
	if _uid != 0 and _session != null:
		equip_requested.emit(_uid, slot)


func _on_unequip_pressed() -> void:
	if _uid != 0 and _session != null:
		unequip_requested.emit(_session.equipment.slot_of(_uid))


func _on_lock_pressed() -> void:
	if _uid != 0 and _session != null:
		var inst: ItemInstance = _session.armory.get_instance(_uid)
		if inst != null:
			lock_requested.emit(_uid, not inst.locked)


func _on_sell_pressed() -> void:
	if _uid != 0 and _session != null:
		sell_requested.emit(_uid)


# --- Salvage confirmation (presentation only) -------------------------------------------------------------------

func _toggle_salvage() -> void:
	_salvage_open = not _salvage_open
	_apply_salvage()


func _apply_salvage() -> void:
	_salvage_box.visible = _salvage_open and _uid != 0
	if _salvage_box.visible:
		_salvage_box.show_for(_session, _uid)


func _on_salvage_confirmed() -> void:
	if _uid != 0 and _session != null:
		var uid: int = _uid
		_salvage_open = false
		salvage_requested.emit(uid)
