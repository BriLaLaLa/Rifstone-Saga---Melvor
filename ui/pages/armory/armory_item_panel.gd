class_name ArmoryItemPanel
extends PanelContainer
## Piece panel of the Armory page (docs/01_GDD.md §21-22): icon, name with the rarity color, rarity / item level,
## worn state, requirements (red if the character does not meet them), weapon, affixes with their grade, modifiers
## of the piece, comparison with the piece worn in the same slot, and the buttons "Equipaggia" (a one-handed
## sword: "In mano" / "Seconda mano"), "Rimuovi", "Blocca" and "Vendi".
##
## Internal to ArmoryPage. It keeps only the uid it shows and the session of the last `show_piece` (to read, never a
## copy of the state); every call re-reads the armory, the equipment and the character. It never changes game
## state: the buttons emit signals and the page sends the commands.

signal equip_requested(uid: int, slot: StringName)
signal unequip_requested(slot: StringName)
signal lock_requested(uid: int, locked: bool)
signal sell_requested(uid: int)
signal close_requested

const EQUIP_TEXT: String = "Equipaggia"
const MAIN_HAND_TEXT: String = "In mano"
const OFFHAND_TEXT: String = "Seconda mano"
const UNEQUIP_TEXT: String = "Rimuovi"
const LOCK_TEXT: String = "Blocca"
const UNLOCK_TEXT: String = "Sblocca"
const SELL_TEXT: String = "Vendi (%s oro)"
const SELL_LOCKED_TEXT: String = "Sblocca il pezzo per venderlo."
const SELL_WORN_TEXT: String = "Rimuovi il pezzo per venderlo."
const SELL_NOT_SELLABLE_TEXT: String = "Questo pezzo non si vende."
const WORN_STATE_TEXT: String = "Indossato: %s"
const LOCKED_STATE_TEXT: String = "Bloccato: non si vende."
const IN_ARMORY_TEXT: String = "Nell'Armeria."
const SUBTITLE_TEXT: String = "%s  ·  %s"
const REQUIREMENTS_TITLE: String = "Requisiti"
const WEAPON_TITLE: String = "Arma"
const AFFIXES_TITLE: String = "Affissi"
const MODIFIERS_TITLE: String = "Modificatori"
const COMPARISON_TITLE: String = "Rispetto a %s"
const NO_DIFFERENCE_TEXT: String = "Nessuna differenza."
const CLOSE_ICON: String = "x"
const CLOSE_TOOLTIP: String = "Chiudi"
const COLOR_TAG: String = "[color=#%s]%s[/color]"
const OFFHAND_SLOT: StringName = &"offhand"
const WEAPON_SLOT: StringName = &"weapon"

var _uid: int = 0
## Session of the last `show_piece` (read at every use, never a copy of its state).
var _session: GameSession = null

@onready var _icon: TextureRect = %Icon
@onready var _name_label: Label = %NameLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _close_box: HBoxContainer = %CloseBox
@onready var _state_label: Label = %StateLabel
@onready var _lines_label: RichTextLabel = %LinesLabel
@onready var _equip_button: Button = %EquipButton
@onready var _offhand_button: Button = %OffhandButton
@onready var _unequip_button: Button = %UnequipButton
@onready var _lock_button: Button = %LockButton
@onready var _sell_note: Label = %SellNote
@onready var _sell_button: Button = %SellButton


func _ready() -> void:
	custom_minimum_size.x = UiStyle.ARMORY_PANEL_WIDTH
	_icon.custom_minimum_size = UiStyle.ARMORY_PANEL_ICON_SIZE
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
	_sell_button.pressed.connect(_on_sell_pressed)
	clear()


## Shows the piece `uid` as it is now in the armory of `session`. False (and clear) if it is not there any more.
func show_piece(session: GameSession, uid: int) -> bool:
	var inst: ItemInstance = session.armory.get_instance(uid) if session != null else null
	var base: ItemDef = session.data.item(inst.base_id) if inst != null else null
	if base == null or base.equip == null:
		clear()
		return false
	_uid = uid
	_session = session
	var worn_slot: StringName = session.equipment.slot_of(uid)
	_icon.texture = ItemSlotView.icon_of(base.icon)
	_name_label.text = ArmoryTexts.piece_name(inst, base)
	_name_label.add_theme_color_override("font_color", UiStyle.rarity_color(inst.rarity))
	_subtitle_label.text = SUBTITLE_TEXT % [ArmoryTexts.rarity_name(inst.rarity),
			ArmoryTexts.LEVEL_TEXT % inst.ilvl]
	_refresh_state(inst, worn_slot)
	_lines_label.text = "\n".join(_detail_lines(inst, base))
	_refresh_actions(inst, base, worn_slot)
	visible = true
	return true


## Hides the panel and forgets the piece.
func clear() -> void:
	_uid = 0
	_session = null
	_icon.texture = null
	_name_label.text = ""
	_subtitle_label.text = ""
	_state_label.text = ""
	_lines_label.text = ""
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


# --- Details ----------------------------------------------------------------------------------------------------

func _detail_lines(inst: ItemInstance, base: ItemDef) -> PackedStringArray:
	var data: GameData = _session.data
	var lines: PackedStringArray = PackedStringArray()
	_append_requirements(lines, base.equip, data)
	if base.equip.weapon != null:
		_append_section(lines, WEAPON_TITLE, PackedStringArray([ItemTooltipLines.weapon_line(base.equip.weapon)]))
	_append_section(lines, AFFIXES_TITLE, ArmoryTexts.affix_lines(inst, data))
	var mods: Array[Modifier] = _session.armory.instance_modifiers(_uid)
	_append_section(lines, MODIFIERS_TITLE, ItemTooltipLines.modifier_lines(mods, data))
	_append_comparison(lines, base, mods)
	return lines


func _append_requirements(lines: PackedStringArray, equip: EquipInfo, data: GameData) -> void:
	var keys: Array[StringName] = []
	for key: StringName in equip.requirements:
		keys.append(key)
	keys.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	var req_lines: PackedStringArray = PackedStringArray()
	for key: StringName in keys:
		var needed: int = equip.requirements[key]
		var text: String = ItemTooltipLines.requirement_text(key, needed, data)
		var met: bool = _session.character.meets_requirements({key: needed})
		req_lines.append(text if met else COLOR_TAG % [UiStyle.BAD.to_html(false), text])
	_append_section(lines, REQUIREMENTS_TITLE, req_lines)


## Difference with the piece worn in the same slot (nothing if this one is worn or the slot is empty).
func _append_comparison(lines: PackedStringArray, base: ItemDef, mods: Array[Modifier]) -> void:
	var worn_uid: int = _session.equipment.get_uid(base.equip.slot)
	if worn_uid == 0 or worn_uid == _uid:
		return
	var worn: ItemInstance = _session.armory.get_instance(worn_uid)
	var worn_base: ItemDef = _session.data.item(worn.base_id) if worn != null else null
	if worn_base == null:
		return
	var diff: PackedStringArray = ArmoryTexts.comparison_lines(mods, _session.armory.instance_modifiers(worn_uid),
			_session.data)
	if diff.is_empty():
		diff.append(NO_DIFFERENCE_TEXT)
	_append_section(lines, COMPARISON_TITLE % ItemTooltipLines.escape(ArmoryTexts.piece_name(worn, worn_base)), diff)


func _append_section(lines: PackedStringArray, title: String, body: PackedStringArray) -> void:
	if body.is_empty():
		return
	lines.append(COLOR_TAG % [UiStyle.GOLD.to_html(false), title])
	lines.append_array(body)


# --- Actions ----------------------------------------------------------------------------------------------------

func _refresh_actions(inst: ItemInstance, base: ItemDef, worn_slot: StringName) -> void:
	var worn: bool = worn_slot != &""
	var weapon: WeaponInfo = base.equip.weapon
	var one_handed_weapon: bool = base.equip.slot == WEAPON_SLOT and weapon != null and not weapon.two_handed
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
