extends GutTest
## GameWindow (M1-16, moved out of test_tooltip.gd in M1-14): title bar built on `_ready`, open/close/toggle signals,
## first placement inside the parent (UiStyle.WINDOW_* layout constants).

var _host: Control
var _window: GameWindow


func before_each() -> void:
	_host = Control.new()
	_host.size = Vector2(1200, 700)
	add_child_autofree(_host)
	_window = GameWindow.new()
	_window.title = "Bank"
	var page := VBoxContainer.new()
	page.name = "VBox"
	_window.add_child(page)
	_host.add_child(_window)


func test_ready_adds_title_bar_and_separator() -> void:
	var page: VBoxContainer = _window.get_node("VBox") as VBoxContainer
	assert_eq(String(page.get_child(0).name), "Header")
	assert_true(page.get_child(1) is HSeparator)
	var title_label: Label = page.get_child(0).get_child(0) as Label
	assert_eq(title_label.text, "BANK")
	assert_false(_window.visible, "starts closed")


func test_toggle_opens_and_closes_with_signals() -> void:
	watch_signals(_window)
	_window.toggle()
	assert_true(_window.visible)
	assert_signal_emit_count(_window, "opened", 1)
	_window.toggle()
	assert_false(_window.visible)
	assert_signal_emit_count(_window, "closed", 1)
	_window.close_window()
	assert_signal_emit_count(_window, "closed", 1, "closing a closed window emits nothing")


func test_first_open_fits_inside_parent() -> void:
	_window.open_window()
	var area: Rect2 = Rect2(Vector2.ZERO, _host.size)
	assert_true(area.encloses(Rect2(_window.position, _window.size)), "%s in %s" % [
		Rect2(_window.position, _window.size), area])
