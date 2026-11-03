class_name MasteryNodeTree
extends Control
## Tree of the mastery nodes of one skill (docs/01_GDD.md §6.3): one MasteryNodeView per node of the data, placed by
## its `pos` ([col, row], cells of MasteryTexts.NODE_SIZE spaced by NODE_GAP), with a line from every required node.
##
## A link is drawn in gold when the required node is owned, dimmed otherwise: `_draw` reads `owns_node` from the
## session given to `redraw` (no copy of the owned nodes). The `buy_requested` of every card is forwarded; the panel
## sends the command. It keeps only references to the session and to its cards.

signal buy_requested(node_id: StringName)

const NODE_SCENE: PackedScene = preload("res://ui/pages/mastery/mastery_node_view.tscn")

var _session: GameSession = null
var _views: Dictionary[StringName, MasteryNodeView] = {}


## Builds one card per node (data order) and sizes the tree to the cells used.
func setup(nodes: Array[MasteryNodeDef], data: GameData) -> void:
	clear()
	var cells: Vector2i = Vector2i.ZERO
	for node: MasteryNodeDef in nodes:
		var view: MasteryNodeView = NODE_SCENE.instantiate() as MasteryNodeView
		add_child(view)
		view.setup(node, data)
		view.position = _cell_origin(node.pos)
		view.size = MasteryTexts.NODE_SIZE
		view.buy_requested.connect(_on_view_buy_requested)
		_views[node.id] = view
		cells = cells.max(node.pos + Vector2i.ONE)
	if cells == Vector2i.ZERO:
		custom_minimum_size = Vector2.ZERO
	else:
		custom_minimum_size = _cell_origin(cells - Vector2i.ONE) + MasteryTexts.NODE_SIZE
	queue_redraw()


## Redraws every card and the links from `session`.
func redraw(session: GameSession) -> void:
	_session = session
	for id: StringName in _views:
		_views[id].redraw(session)
	queue_redraw()


## Frees the cards and forgets the session.
func clear() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_views.clear()
	_session = null
	custom_minimum_size = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	if _session == null or not is_instance_valid(_session):
		return
	for id: StringName in _views:
		var view: MasteryNodeView = _views[id]
		for required: StringName in view.required_ids():
			if not _views.has(required):
				continue
			var from_pos: Vector2i = _views[required].grid_pos()
			var to_pos: Vector2i = view.grid_pos()
			var color: Color = UiStyle.GOLD if _session.mastery.owns_node(required) else UiStyle.GOLD_FAINT
			draw_polyline(_link_points(from_pos, to_pos), color, MasteryTexts.LINK_WIDTH, true)


static func _cell_origin(pos: Vector2i) -> Vector2:
	return Vector2(pos) * (MasteryTexts.NODE_SIZE + MasteryTexts.NODE_GAP)


## Link from the card at `from_pos` to the card at `to_pos`, kept in the gaps (not under the translucent cards):
## on different rows an elbow from the facing edge center through the middle of the gap; on one row a straight line.
static func _link_points(from_pos: Vector2i, to_pos: Vector2i) -> PackedVector2Array:
	var from: Vector2 = _anchor(from_pos, to_pos)
	var to: Vector2 = _anchor(to_pos, from_pos)
	if from_pos.y == to_pos.y:
		return PackedVector2Array([from, to])
	var middle_y: float = (from.y + to.y) * 0.5
	return PackedVector2Array([from, Vector2(from.x, middle_y), Vector2(to.x, middle_y), to])


## Point on the edge of the card at `pos` facing the card at `other`: bottom or top center when the rows differ,
## left or right center on the same row.
static func _anchor(pos: Vector2i, other: Vector2i) -> Vector2:
	var cell: Vector2 = MasteryTexts.NODE_SIZE
	var center: Vector2 = _cell_origin(pos) + cell * 0.5
	if other.y != pos.y:
		return center + Vector2(0.0, cell.y * 0.5 * signf(other.y - pos.y))
	return center + Vector2(cell.x * 0.5 * signf(other.x - pos.x), 0.0)


func _on_view_buy_requested(node_id: StringName) -> void:
	buy_requested.emit(node_id)
