extends GutTest
## Toast "Nuovo: <oggetto>" on `item_discovered` (M14-07, docs/05_INTERFACES.md §7.u) and the LockedCell. The gate of the
## manager keeps the starting kit of `new_game` (state loading) and the offline simulation silent.

var _events: GameEvents
var _manager: ToastManager
var _now_ms: int = 0
var _open: bool = true


func before_each() -> void:
	_now_ms = 0
	_open = true
	_events = GameEvents.new()
	_manager = ToastManager.new()
	_manager.events = _events
	_manager.time_source = func() -> int: return _now_ms
	_manager.discovery_gate = func() -> bool: return _open
	_manager.name_resolver = func(id: StringName) -> String: return "Nome %s" % id
	add_child(_manager)


func after_each() -> void:
	_manager.free()
	_events.free()


func _texts() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for toast: Node in _manager.find_children("*", "Toast", true, false):
		result.append((toast as Toast).text())
	return result


func test_a_discovery_makes_one_nuovo_toast() -> void:
	_events.item_discovered.emit(&"redbirch_log")
	assert_eq(_texts(), PackedStringArray(["Nuovo: Nome redbirch_log"]))


func test_no_toast_while_the_gate_is_closed() -> void:
	_open = false
	_events.item_discovered.emit(&"redbirch_log")
	assert_eq(_texts().size(), 0)


func test_default_gate_is_closed_outside_the_playing_state() -> void:
	var fresh: ToastManager = ToastManager.new()
	fresh.events = _events
	add_child(fresh)
	assert_ne(Game.state, Game.STATE_PLAYING)
	_events.item_discovered.emit(&"redbirch_log")
	assert_eq(fresh.find_children("*", "Toast", true, false).size(), 0)
	fresh.free()


func test_new_game_kit_discoveries_do_not_toast() -> void:
	# The real session runs `new_game` while `Game.state` is not playing: the default gate stays closed.
	var session: GameSession = TestFactory.session(1234, TestFactory.real_data())
	var fresh: ToastManager = ToastManager.new()
	fresh.events = session.events
	add_child(fresh)
	session.discoveries.new_game()
	assert_gt(session.discoveries.items().size(), 0, "the kit counts as obtained")
	assert_eq(fresh.find_children("*", "Toast", true, false).size(), 0)
	fresh.free()
	session.free()


func test_locked_cell_hides_everything_then_shows_name_and_pct() -> void:
	var data: GameData = TestFactory.real_data()
	var cell: LockedCell = LockedCell.new()
	add_child_autofree(cell)
	cell.setup(data)
	assert_true(cell.is_locked())
	assert_eq(cell.shown_name(), "???")
	assert_eq(cell.shown_chance(), "")
	cell.show_item(&"redbirch_log", 0.0208)
	assert_false(cell.is_locked())
	assert_eq(cell.shown_name(), data.item(&"redbirch_log").name)
	assert_eq(cell.shown_chance(), "0.0208%")
	cell.show_item(&"redbirch_log", -1.0)
	assert_eq(cell.shown_chance(), "")
	cell.show_locked()
	assert_eq(cell.shown_name(), "???")
