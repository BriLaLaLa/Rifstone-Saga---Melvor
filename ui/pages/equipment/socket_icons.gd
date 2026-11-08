class_name SocketIcons
extends HBoxContainer
## Sockets of the item card as icons (read only): the stone set in each socket, a dark frame for a free one, a grey
## frame for a socket the piece has not unlocked yet (F-89). Rebuilt from the armory at every `show_for`; the work on
## sockets is done at the Forge bench. Hidden when the piece has no sockets.

const ICON_SIZE := Vector2(28, 28)
const SEPARATION: int = 6
const FREE_TOOLTIP: String = "Castone libero"
const LOCKED_TOOLTIP: String = "Castone non ancora aperto"
const LOCKED_TINT := Color(0.4, 0.4, 0.4, 0.6)


func _ready() -> void:
	add_theme_constant_override("separation", SEPARATION)


## Draws the sockets of the piece `uid` of `session`.
func show_for(session: GameSession, uid: int) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var inst: ItemInstance = session.armory.get_instance(uid)
	var count: int = session.armory.socket_count(uid) if inst != null else 0
	var total: int = maxi(count, inst.sockets.size()) if inst != null else 0
	visible = total > 0
	for i: int in total:
		var frame: PanelContainer = PanelContainer.new()
		frame.name = "Socket%d" % i
		frame.theme_type_variation = &"SlotPanel"
		frame.custom_minimum_size = ICON_SIZE
		var icon: TextureRect = TextureRect.new()
		icon.name = "Icon"
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(icon)
		if i < inst.sockets.size():
			var stone: ItemDef = session.data.item(inst.sockets[i])
			icon.texture = ItemSlotView.icon_of(stone.icon) if stone != null else null
			frame.tooltip_text = stone.name if stone != null else String(inst.sockets[i])
		elif i < count:
			frame.tooltip_text = FREE_TOOLTIP
		else:
			frame.tooltip_text = LOCKED_TOOLTIP
			frame.modulate = LOCKED_TINT
		add_child(frame)
