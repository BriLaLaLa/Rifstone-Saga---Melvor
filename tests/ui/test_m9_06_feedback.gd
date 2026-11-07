extends GutTest
## M9-06: hint card (queue, mark_seen, offline block), toast waiting line cap (N9), settings entry in game.

const MAIN: PackedScene = preload("res://ui/screens/main/main_screen.tscn")

var _session: GameSession
var _screen: MainScreen
var _blocked: bool = false


func before_each() -> void:
	_blocked = false
	_session = TestFactory.session()


func after_each() -> void:
	if is_instance_valid(_screen):
		_screen.free()
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func _card() -> HintCard:
	var card := HintCard.new()
	card.is_blocked = func() -> bool: return _blocked
	add_child_autofree(card)
	card.bind(_session)
	return card


func test_card_shows_title_and_text_and_close_marks_seen() -> void:
	var card: HintCard = _card()
	_session.events.hint_triggered.emit(&"test_death")
	assert_true(card.visible)
	assert_eq(card.current_hint(), &"test_death")
	assert_true(card.find_children("*", "Label", true, false).any(
			func(n: Node) -> bool: return (n as Label).text == "Sconfitta"))
	assert_false(_session.hints.is_seen(&"test_death"))
	card.close_current()
	assert_true(_session.hints.is_seen(&"test_death"))
	assert_false(card.visible)


func test_several_hints_queue_in_order() -> void:
	var card: HintCard = _card()
	_session.events.hint_triggered.emit(&"test_death")
	_session.events.hint_triggered.emit(&"test_node")
	_session.events.hint_triggered.emit(&"test_node")
	assert_eq(card.queued(), [&"test_node"] as Array[StringName])
	card.close_current()
	assert_eq(card.current_hint(), &"test_node")
	card.close_current()
	assert_eq(card.current_hint(), &"")


func test_blocked_while_offline_then_shown_on_session_started() -> void:
	var card: HintCard = _card()
	_blocked = true
	_session.events.hint_triggered.emit(&"test_death")
	assert_false(card.visible)
	_blocked = false
	_session.events.session_started.emit(1, false)
	assert_eq(card.current_hint(), &"test_death")


func test_unbind_disconnects() -> void:
	var card: HintCard = _card()
	card.unbind()
	_session.events.hint_triggered.emit(&"test_death")
	assert_false(card.visible)


func test_toast_waiting_line_is_capped() -> void:
	var toasts := ToastManager.new()
	toasts.events = _session.events
	add_child_autofree(toasts)
	for i: int in range(UiStyle.TOAST_MAX_VISIBLE + UiStyle.TOAST_PENDING_MAX + 5):
		toasts.push("t%d" % i, &"info")
	assert_eq(toasts._pending_texts.size(), UiStyle.TOAST_PENDING_MAX)


func test_menu_opens_settings_in_game_and_main_screen_has_card() -> void:
	_screen = MAIN.instantiate() as MainScreen
	_screen.session = _session
	add_child(_screen)
	assert_not_null(_screen.find_child("HintCard", true, false))
	(_screen.find_child("MenuButton", true, false) as Button).pressed.emit()
	var panel: SettingsPanel = null
	for c: Node in _screen.get_children():
		if c is SettingsPanel:
			panel = c
	assert_not_null(panel)
	assert_true(panel.in_game)
	assert_eq(_screen.get_children().find(panel), _screen.get_child_count() - 1, "drawn above toasts")


func test_card_shows_hint_triggered_before_bind() -> void:
	_session.events.session_started.emit(0, true)
	var card: HintCard = _card()
	assert_eq(card.current_hint(), &"test_first_action")
	assert_true(card.visible)
	card.close_current()
	assert_eq(_session.hints.pending(), [] as Array[StringName])
