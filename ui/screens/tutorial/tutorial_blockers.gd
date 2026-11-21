class_name TutorialBlockers
extends Control
## The STOP rectangles of the tutorial overlay: they cover the sidebar and the top bar (the rectangles are given by the
## overlay every frame) except the "holes" (the menu button and, when the step needs it, the sidebar row of the page to go
## to). The page area is never covered. Presentation only: the rectangles are the only thing it keeps.

var _rects: Array[Rect2] = []
var _pool: Array[Control] = []


## Global rectangles covered, minus the global rectangles left free. Redraws only when the result changes.
func set_areas(covered: Array[Rect2], holes: Array[Rect2]) -> void:
	var result: Array[Rect2] = []
	for rect: Rect2 in covered:
		var pieces: Array[Rect2] = [rect]
		for hole: Rect2 in holes:
			var next: Array[Rect2] = []
			for piece: Rect2 in pieces:
				next.append_array(subtract(piece, hole))
			pieces = next
		result.append_array(pieces)
	if result == _rects:
		return
	_rects = result
	_apply()


## `rect` minus `hole`: up to four rectangles (above, below, left and right of the hole).
static func subtract(rect: Rect2, hole: Rect2) -> Array[Rect2]:
	var cut: Rect2 = rect.intersection(hole)
	if cut.size.x <= 0.0 or cut.size.y <= 0.0:
		return [rect]
	var pieces: Array[Rect2] = []
	if cut.position.y > rect.position.y:
		pieces.append(Rect2(rect.position, Vector2(rect.size.x, cut.position.y - rect.position.y)))
	if cut.end.y < rect.end.y:
		pieces.append(Rect2(Vector2(rect.position.x, cut.end.y), Vector2(rect.size.x, rect.end.y - cut.end.y)))
	if cut.position.x > rect.position.x:
		pieces.append(Rect2(Vector2(rect.position.x, cut.position.y), Vector2(cut.position.x - rect.position.x, cut.size.y)))
	if cut.end.x < rect.end.x:
		pieces.append(Rect2(Vector2(cut.end.x, cut.position.y), Vector2(rect.end.x - cut.end.x, cut.size.y)))
	return pieces


## The rectangles now covered (global), for tests.
func covered_rects() -> Array[Rect2]:
	return _rects.duplicate()


func _apply() -> void:
	while _pool.size() < _rects.size():
		var stop: Control = Control.new()
		stop.mouse_filter = Control.MOUSE_FILTER_STOP
		stop.name = "Stop%d" % _pool.size()
		add_child(stop)
		_pool.append(stop)
	for i: int in _pool.size():
		_pool[i].visible = i < _rects.size()
		if i < _rects.size():
			_pool[i].global_position = _rects[i].position
			_pool[i].size = _rects[i].size
