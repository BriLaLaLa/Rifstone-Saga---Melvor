class_name PieceDrag
extends RefCounted
## Drag-and-drop payload of the Equipment page: a piece (its uid) dragged from the inventory (`from` = &"") or from a
## worn slot (`from` = the slot). The payload carries only identifiers: the model decides what a drop does.

const TYPE_KEY: String = "type"
const TYPE_PIECE: StringName = &"piece"
const UID_KEY: String = "uid"
const FROM_KEY: String = "from"
const PREVIEW_SIZE := Vector2(48, 48)
const PREVIEW_ALPHA: float = 0.85


static func payload(uid: int, from_slot: StringName) -> Dictionary:
	return {TYPE_KEY: TYPE_PIECE, UID_KEY: uid, FROM_KEY: from_slot}


static func is_piece(data: Variant) -> bool:
	return data is Dictionary and (data as Dictionary).get(TYPE_KEY, &"") == TYPE_PIECE


## Uid of the dragged piece; 0 if `data` is not a piece payload.
static func uid_of(data: Variant) -> int:
	return int((data as Dictionary).get(UID_KEY, 0)) if is_piece(data) else 0


## Slot the piece comes from; &"" if it comes from the inventory.
static func from_of(data: Variant) -> StringName:
	return (data as Dictionary).get(FROM_KEY, &"") if is_piece(data) else &""


## Small translucent icon that follows the cursor while dragging.
static func preview(texture: Texture2D) -> Control:
	var icon: TextureRect = TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = PREVIEW_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate.a = PREVIEW_ALPHA
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon
