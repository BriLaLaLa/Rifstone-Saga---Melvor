extends GutTest
## DungeonEnemyGrid (M22-11, docs/05_INTERFACES.md §7.q): 1, 3, 8, 12 and 16 cells fit the zone of ~760x300 px without scroll nor
## overlap and never go under the minimum side; every enemy is a cell (no "xN"); the boss is a bigger gold cell.

const AREA := Vector2(760.0, 300.0)

var _session: GameSession
var _grid: DungeonEnemyGrid


func before_each() -> void:
	_session = TestFactory.session(1234, TestFactory.real_data())
	_grid = DungeonEnemyGrid.new()
	_grid.size = AREA
	add_child(_grid)


func after_each() -> void:
	if is_instance_valid(_grid):
		_grid.free()
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func _state(ids: Array[StringName], target: int = 0) -> Dictionary:
	var enemies: Array[Dictionary] = []
	for id: StringName in ids:
		enemies.append({"monster": id, "hp": 50, "max_hp": 100, "timer_ms": 0, "interval_ms": 1000})
	return {"enemies": enemies, "target": target}


func _ids(count: int, boss_at: int = -1) -> Array[StringName]:
	var ids: Array[StringName] = []
	for i: int in count:
		ids.append(&"monkey_gorom" if i == boss_at else &"monkey_guard")
	return ids


func test_layout_fits_without_overlap_for_every_count() -> void:
	for count: int in [1, 3, 8, 12, 16]:
		for boss_index: int in [-1, 0]:
			var placed: Dictionary = DungeonEnemyGrid.layout(count, AREA, boss_index)
			var rects: Array = placed["rects"]
			assert_eq(rects.size(), count)
			assert_lte(int(placed["side"]), DungeonEnemyGrid.MAX_SIDE)
			if count <= 16 and boss_index < 0:
				assert_gte(int(placed["side"]), DungeonEnemyGrid.MIN_SIDE, "%d cells" % count)
			for i: int in rects.size():
				var rect: Rect2 = rects[i]
				assert_true(Rect2(Vector2.ZERO, AREA).encloses(rect), "cell %d of %d inside" % [i, count])
				for j: int in range(i + 1, rects.size()):
					assert_false(rect.intersects(rects[j]), "cells %d and %d of %d do not overlap" % [i, j, count])


func test_the_boss_cell_is_bigger_than_the_others() -> void:
	var rects: Array = DungeonEnemyGrid.layout(5, AREA, 0)["rects"]
	assert_gt((rects[0] as Rect2).size.x, (rects[1] as Rect2).size.x)


func test_every_enemy_is_a_cell_with_no_multiplier_text() -> void:
	for count: int in [1, 3, 8, 12, 16]:
		_grid.refresh(_session, _state(_ids(count)), {})
		assert_eq(_grid.cell_count(), count)
		for label: Node in _grid.find_children("*", "Label", true, false):
			var text: String = (label as Label).text
			assert_false(text.length() > 1 and text.begins_with("x") and text.substr(1).is_valid_int(), "no xN: '%s'" % text)


func test_boss_cell_is_marked_and_a_dead_one_is_dimmed() -> void:
	var state: Dictionary = _state(_ids(4, 1))
	(state["enemies"][2] as Dictionary)["hp"] = 0
	_grid.refresh(_session, state, {"stage": {"monster": &"monkey_gorom"}})
	assert_eq(_grid.boss_cell_index(), 1)
	assert_true(_grid.cell(1).boss)
	assert_not_null(_grid.cell(1).tag_label)
	assert_null(_grid.cell(0).tag_label)
	assert_lt(_grid.cell(2).modulate.a, 1.0, "dead enemy dimmed")
