class_name AltarSocketColumn
extends AltarColumn
## Step 1 of the Altar page: the sockets as a list. Each row says at a glance whether the socket is locked (and by what
## level), free or holding a rune. Picking a row emits `socket_selected`.

signal socket_selected(index: int)


func _init() -> void:
	name = "SocketColumn"
	custom_minimum_size.x = 260
	size_flags_stretch_ratio = 3.0
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _ready() -> void:
	setup(1, RiftTexts.STEP1_TITLE_TEXT, RiftTexts.STEP1_HINT_TEXT)


func refresh(session: GameSession, selected: int) -> void:
	_clear_body()
	var rift: RiftAltar = session.rift
	for i: int in rift.socket_total():
		var item_id: StringName = rift.get_socket(i)
		var detail: String
		var icon: Texture2D = null
		if item_id != &"":
			icon = ItemSlotView.icon_of(session.data.item(item_id).icon)
		if not rift.is_unlocked(i):
			detail = color_text(UiStyle.TEXT_DISABLED, RiftTexts.LOCKED_SHORT_TEXT % RiftTexts.unlock_level(session, i))
			if item_id != &"":
				detail = color_text(UiStyle.TEXT_DISABLED, "%s — %s" % [ItemTooltipLines.escape(session.data.item(item_id).name),
						RiftTexts.OFF_SHORT_TEXT])
		elif item_id == &"":
			detail = color_text(UiStyle.GOOD, RiftTexts.FREE_TEXT)
		else:
			var def: ItemDef = session.data.item(item_id)
			detail = color_text(UiStyle.GOLD_LIGHT, ItemTooltipLines.escape(def.name))
		var button: Button = _row("Socket%d" % i, RiftTexts.SOCKET_TITLE_TEXT % (i + 1), detail, i == selected, icon)
		button.pressed.connect(func() -> void: socket_selected.emit(i))
