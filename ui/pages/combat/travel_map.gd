class_name TravelMap
extends Control
## Little map shown in the Combat page, in place of the enemy zone, while the party travels to the next encounter
## (state `travel`): a sketched landscape (hills, trees, a winding path) and the icon of the character walking along
## the path. It shows neither nodes nor enemies: it only gives the idea of the journey. Drawn by code, no assets.
##
## `refresh(state)` reads `combat.get_state()` (`state`, `travel_ms`, `travel_total_ms`): the position of the icon is
## `1 - travel_ms / travel_total_ms`. Visible only while travelling. The little walking bob stops with "Effetti visivi
## ridotti". No game state here.

const PLAYER_ICON: String = "user"
const MIN_HEIGHT: float = 220.0
const ICON_SIDE: float = 40.0
const PATH_WIDTH: float = 6.0
const PATH_STEPS: int = 48
const EDGE: float = 0.08  ## fraction of the width left free at both ends of the path
const BOB_PIXELS: float = 3.0
const BOB_SPEED: float = 7.0
const SKY_TOP := Color("26304a")
const SKY_BOTTOM := Color("4a5a6e")
const HILL_FAR := Color("2f4a3c")
const HILL_NEAR := Color("3b5c42")
const GROUND := Color("33472f")
const PATH_COLOR := Color("b49a68")
const TRUNK_COLOR := Color("4b3524")
const LEAF_COLOR := Color("224a2b")
const BORDER_WIDTH: int = 2
## Trees: x fraction, y fraction (feet), height in pixels.
const TREES: Array[Vector3] = [Vector3(0.05, 0.86, 54.0), Vector3(0.14, 0.40, 34.0), Vector3(0.27, 0.9, 62.0),
		Vector3(0.40, 0.44, 30.0), Vector3(0.58, 0.42, 36.0), Vector3(0.70, 0.92, 58.0), Vector3(0.83, 0.46, 32.0),
		Vector3(0.94, 0.88, 56.0)]

var _progress: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(0, MIN_HEIGHT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	visible = false
	resized.connect(queue_redraw)


## Draws the travel in `state` (combat.get_state()); hidden outside the `travel` state.
func refresh(state: Dictionary) -> void:
	var total: int = int(state.get("travel_total_ms", 0))
	var left: int = int(state.get("travel_ms", 0))
	visible = state.get("state", &"") == CombatTexts.STATE_TRAVEL
	_progress = clampf(1.0 - float(left) / float(total), 0.0, 1.0) if total > 0 else 0.0
	if visible:
		queue_redraw()


## Position of the icon along the path, 0 (start) to 1 (end), as last drawn.
func progress() -> float:
	return _progress


## Point of the path at `t` (0..1), in the coordinates of a rectangle of `area` size.
static func path_point(t: float, area: Vector2) -> Vector2:
	var x: float = lerpf(area.x * EDGE, area.x * (1.0 - EDGE), t)
	var y: float = area.y * (0.66 + 0.12 * sin(t * TAU * 1.25 + 0.6))
	return Vector2(x, y)


func _draw() -> void:
	var area: Vector2 = size
	if area.x <= 0.0 or area.y <= 0.0:
		return
	var horizon: float = area.y * 0.42
	draw_rect(Rect2(Vector2.ZERO, Vector2(area.x, horizon)), SKY_TOP)
	for i: int in 6:  # soft band of sky near the horizon
		var band: float = float(i) / 6.0
		draw_rect(Rect2(0.0, horizon * band, area.x, horizon / 6.0 + 1.0), SKY_TOP.lerp(SKY_BOTTOM, band))
	draw_rect(Rect2(0.0, horizon, area.x, area.y - horizon), GROUND)
	_draw_hill(area, 0.22, 0.28, 0.26, HILL_FAR)
	_draw_hill(area, 0.62, 0.34, 0.2, HILL_FAR)
	_draw_hill(area, 0.45, 0.4, 0.14, HILL_NEAR)
	_draw_hill(area, 0.93, 0.26, 0.12, HILL_NEAR)
	var points := PackedVector2Array()
	for i: int in PATH_STEPS + 1:
		points.append(path_point(float(i) / PATH_STEPS, area))
	draw_polyline(points, PATH_COLOR.darkened(0.45), PATH_WIDTH + 4.0, true)
	draw_polyline(points, PATH_COLOR, PATH_WIDTH, true)
	for tree: Vector3 in TREES:
		_draw_tree(Vector2(area.x * tree.x, area.y * tree.y), tree.z)
	var bob: float = 0.0
	if not CombatFx.reduced():
		bob = absf(sin(Time.get_ticks_msec() * 0.001 * BOB_SPEED)) * BOB_PIXELS
	var at: Vector2 = path_point(_progress, area)
	var icon_rect := Rect2(at - Vector2(ICON_SIDE * 0.5, ICON_SIDE + bob - 4.0), Vector2(ICON_SIDE, ICON_SIDE))
	draw_circle(at + Vector2(0.0, 2.0), ICON_SIDE * 0.3, Color(0.0, 0.0, 0.0, 0.3))
	draw_texture_rect(UiStyle.icon(PLAYER_ICON), icon_rect, false, UiStyle.GOLD_LIGHT)
	draw_rect(Rect2(Vector2.ZERO, area), UiStyle.COMBAT_ENEMY_BORDER, false, float(BORDER_WIDTH))


func _process(_delta: float) -> void:
	if visible and not CombatFx.reduced():
		queue_redraw()  # the walking bob


func _draw_hill(area: Vector2, center: float, half_width: float, height: float, color: Color) -> void:
	var horizon: float = area.y * 0.42
	var points := PackedVector2Array()
	for i: int in 13:
		var u: float = float(i) / 12.0 * 2.0 - 1.0  # -1..1 across the hill
		points.append(Vector2(area.x * (center + u * half_width), horizon + area.y * 0.04 - area.y * height * (1.0 - u * u)))
	draw_colored_polygon(points, color)


func _draw_tree(feet: Vector2, tree_height: float) -> void:
	var trunk := Rect2(feet.x - tree_height * 0.06, feet.y - tree_height * 0.3, tree_height * 0.12, tree_height * 0.3)
	draw_rect(trunk, TRUNK_COLOR)
	draw_colored_polygon(PackedVector2Array([Vector2(feet.x, feet.y - tree_height),
			Vector2(feet.x + tree_height * 0.28, feet.y - tree_height * 0.25),
			Vector2(feet.x - tree_height * 0.28, feet.y - tree_height * 0.25)]), LEAF_COLOR)
