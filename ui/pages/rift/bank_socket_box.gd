class_name BankSocketBox
extends VBoxContainer
## "Incastona" section of the bank item panel (docs/01_GDD.md §11, §26): for an infusion the button that sets it in the
## first free socket of the Altar; for a stone the choice of the piece of the Armory with a free socket and the button
## that sets the stone there. Other items: nothing shown. Read from the session at every `show_for`; it emits
## `infusion_requested` / `stone_requested` and the bank page sends the command. Presentation state only: the piece chosen.

signal infusion_requested(item_id: StringName)
signal stone_requested(item_id: StringName, uid: int)

const SEPARATION: int = 4

var _selected_uid: int = 0


func _ready() -> void:
	add_theme_constant_override("separation", SEPARATION)
	visible = false


## Draws the section for `item_id` (bank item of `session`); hidden if it is neither an infusion nor a stone.
func show_for(session: GameSession, item_id: StringName) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var def: ItemDef = session.data.item(item_id)
	visible = def != null and (def.category == &"infusion" or def.category == &"stone")
	if not visible:
		return
	if def.category == &"infusion":
		_add_button(self, "InfusionButton", SocketTexts.BANK_INFUSION_BUTTON_TEXT,
				func() -> void: infusion_requested.emit(item_id))
		return
	var title := Label.new()
	title.name = "Title"
	title.theme_type_variation = &"HeaderLabel"
	title.text = SocketTexts.BANK_SOCKET_TITLE_TEXT
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(title)
	var option := OptionButton.new()
	option.name = "PieceOption"
	option.focus_mode = Control.FOCUS_NONE
	var select: int = 0
	for inst: ItemInstance in session.armory.instances():
		var free: int = session.armory.socket_count(inst.uid) - inst.sockets.size()
		if free <= 0:
			continue
		var base: ItemDef = session.data.item(inst.base_id)
		option.add_item("%s  (%s, %d liberi)" % [base.name, ArmoryTexts.rarity_name(inst.rarity), free])
		option.set_item_metadata(option.item_count - 1, inst.uid)
		if inst.uid == _selected_uid:
			select = option.item_count - 1
	if option.item_count == 0:
		var none := Label.new()
		none.name = "NoPieces"
		none.theme_type_variation = &"MutedLabel"
		none.text = SocketTexts.BANK_NO_PIECES_TEXT
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(none)
		return
	option.select(select)
	_selected_uid = option.get_item_metadata(select) as int
	option.item_selected.connect(func(i: int) -> void: _selected_uid = option.get_item_metadata(i) as int)
	add_child(option)
	_add_button(self, "StoneButton", SocketTexts.SOCKET_BUTTON_TEXT,
			func() -> void: stone_requested.emit(item_id, _selected_uid))


func _add_button(parent: Control, node_name: String, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = UiStyle.MENU_BUTTON_HEIGHT
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
