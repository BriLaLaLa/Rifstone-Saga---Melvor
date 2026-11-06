class_name EquipmentDoll
extends Control
## The paper doll of the Equipment page (docs/mockups/equipment.dc.html): an original silhouette with the 12 slots
## of `Equipment.SLOTS` around it (head on top, neck and ring on the right, hands on the left, body / legs / feet in
## the middle, the weapon and the second hand tall on the two sides, the three tools in a row below).
##
## Pure layout: the slot rectangles are expressed in a design space (`DESIGN_SIZE`, x relative to the centre) and
## scaled to fit the available area, so the doll works at 1600x900 and at 1280x720. It builds one
## `EquipmentSlotView` per slot and hands them out with `slot_view`; it holds no game state.

const DESIGN_SIZE := Vector2(360, 552)
const MAX_SCALE: float = 1.25
## Slot -> rectangle in the design space; x is relative to the horizontal centre of the doll.
const SLOT_RECTS: Dictionary[StringName, Rect2] = {
	&"head": Rect2(-40, 0, 80, 80),
	&"neck": Rect2(70, 20, 64, 64),
	&"ring": Rect2(70, 100, 64, 64),
	&"body": Rect2(-50, 110, 100, 120),
	&"hands": Rect2(-160, 110, 72, 72),
	&"weapon": Rect2(-180, 200, 92, 170),
	&"offhand": Rect2(88, 200, 92, 170),
	&"legs": Rect2(-45, 250, 90, 110),
	&"feet": Rect2(-40, 380, 80, 72),
	&"tool_forestry": Rect2(-150, 480, 72, 72),
	&"tool_quarrying": Rect2(-36, 480, 72, 72),
	&"tool_angling": Rect2(78, 480, 72, 72),
}
## Silhouette (viewBox 60 x 150 of the mockup) drawn as outlines.
const SILHOUETTE_HEAD_CENTER := Vector2(30, 14)
const SILHOUETTE_HEAD_RADIUS: float = 10.0
const SILHOUETTE_BODY: PackedVector2Array = [
	Vector2(14, 30), Vector2(46, 30), Vector2(52, 76), Vector2(44, 76), Vector2(40, 46), Vector2(40, 86),
	Vector2(44, 140), Vector2(34, 140), Vector2(30, 96), Vector2(26, 140), Vector2(16, 140), Vector2(20, 86),
	Vector2(20, 46), Vector2(16, 76), Vector2(8, 76),
]
const SILHOUETTE_SIZE := Vector2(60, 150)
const SILHOUETTE_SCALE: float = 3.0
const SILHOUETTE_TOP: float = 20.0
const SILHOUETTE_LINE_WIDTH: float = 1.5
const SILHOUETTE_COLOR := Color("5e4c26")
const HEAD_POINTS: int = 32

var _views: Dictionary[StringName, EquipmentSlotView] = {}


func _init() -> void:
	custom_minimum_size = DESIGN_SIZE * 0.6
	clip_contents = true
	resized.connect(_layout)


## Creates the 12 slot views; `label_of` is `(slot: StringName) -> String`.
func build(label_of: Callable) -> void:
	for view: EquipmentSlotView in _views.values():
		remove_child(view)
		view.queue_free()
	_views.clear()
	for slot: StringName in Equipment.SLOTS:
		var view: EquipmentSlotView = EquipmentSlotView.new()
		add_child(view)
		view.setup(slot, label_of.call(slot) as String)
		_views[slot] = view
	_layout()


func slot_view(slot: StringName) -> EquipmentSlotView:
	return _views.get(slot)


func slot_views() -> Array[EquipmentSlotView]:
	return _views.values()


func _draw_scale() -> float:
	return minf(minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y), MAX_SCALE)


func _layout() -> void:
	var factor: float = _draw_scale()
	var origin: Vector2 = Vector2((size.x - DESIGN_SIZE.x * factor) / 2.0 + DESIGN_SIZE.x * factor / 2.0, 0.0)
	for slot: StringName in _views:
		var rect: Rect2 = SLOT_RECTS[slot]
		_views[slot].position = origin + rect.position * factor
		_views[slot].size = rect.size * factor
	queue_redraw()


func _draw() -> void:
	var factor: float = _draw_scale()
	var scale_value: float = SILHOUETTE_SCALE * factor
	var top_left: Vector2 = Vector2(size.x / 2.0 - SILHOUETTE_SIZE.x * scale_value / 2.0, SILHOUETTE_TOP * factor)
	var body: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in SILHOUETTE_BODY:
		body.append(top_left + point * scale_value)
	body.append(body[0])
	draw_polyline(body, SILHOUETTE_COLOR, SILHOUETTE_LINE_WIDTH, true)
	draw_arc(top_left + SILHOUETTE_HEAD_CENTER * scale_value, SILHOUETTE_HEAD_RADIUS * scale_value, 0.0, TAU,
			HEAD_POINTS, SILHOUETTE_COLOR, SILHOUETTE_LINE_WIDTH, true)
