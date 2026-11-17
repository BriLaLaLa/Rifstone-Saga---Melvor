class_name NodeBackdrop
extends Control
## Scene behind the node card (like the travel map): sky, hills and ground drawn by code, tinted by the colour of the
## node. Presentation only, no assets, no state.

const SKY_TOP := Color("26304a")
const SKY_BOTTOM := Color("4a5a6e")
const HILL := Color("2f4a3c")
const GROUND := Color("2b3d2a")
const TINT_AMOUNT: float = 0.18
const HORIZON: float = 0.55

var _tint: Color = Color.TRANSPARENT


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


## Colour of the node (a light wash over the scene); `Color.TRANSPARENT` for none.
func set_tint(color: Color) -> void:
	if color != _tint:
		_tint = color
		queue_redraw()


func _draw() -> void:
	var area: Vector2 = size
	var horizon: float = area.y * HORIZON
	var bands: int = 8
	for i: int in bands:
		var t: float = float(i) / bands
		draw_rect(Rect2(0.0, horizon * t, area.x, horizon / bands + 1.0), SKY_TOP.lerp(SKY_BOTTOM, t))
	draw_rect(Rect2(0.0, horizon, area.x, area.y - horizon), GROUND)
	for hill: Vector3 in [Vector3(0.18, 0.3, 0.22), Vector3(0.55, 0.38, 0.3), Vector3(0.92, 0.28, 0.2)]:
		var points := PackedVector2Array()
		for i: int in 13:
			var u: float = float(i) / 12.0 * 2.0 - 1.0
			points.append(Vector2(area.x * (hill.x + u * hill.y), horizon + area.y * 0.03 - area.y * hill.z * (1.0 - u * u)))
		draw_colored_polygon(points, HILL)
	if _tint.a > 0.0:
		draw_rect(Rect2(Vector2.ZERO, area), Color(_tint, TINT_AMOUNT))
