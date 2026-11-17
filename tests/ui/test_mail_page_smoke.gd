extends GutTest
## Mail page smoke test (M27-07, docs/05_INTERFACES_M27.md §7.o) on the main screen with a real session: the "Posta" row of the
## sidebar opens the page with a REAL mouse click, a click on a message row opens it (read), Ritira and Ritira tutto are clicked
## for real and send one command each, a full Deposit leaves the message in the Mail with the reason shown, the unread counter of the
## sidebar follows `mail_changed`, unbind disconnects everything. No exact texts.

const SCENE: PackedScene = preload("res://ui/screens/main/main_screen.tscn")
const ITEM: StringName = &"dungeon_ticket_monkey_den"

var _s: GameSession = null
var _screen: MainScreen = null


func before_each() -> void:
	_s = TestFactory.session(77, TestFactory.real_data())
	TestFactory.make_roomy(_s)
	_s.mail.post(&"auction_sold", {"item": ITEM, "qty": 4, "price": 250, "listing": 1, "money": 1000})
	_s.mail.post(&"auction_cancelled", {"item": ITEM, "qty": 3, "items": [{"item": ITEM, "qty": 3}]})
	_screen = SCENE.instantiate() as MainScreen
	_screen.session = _s
	add_child(_screen)
	# the output panel of the GUT runner sits over the top right corner of the window: it must not catch the test's clicks
	for layer: Node in get_tree().root.find_children("GutLayer", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	await _settle()


func after_each() -> void:
	if is_instance_valid(_screen):
		_screen.free()
	if is_instance_valid(_s):
		_s.free()
	await wait_physics_frames(1)


func test_sidebar_click_opens_the_page_then_rows_and_buttons_work_with_real_clicks() -> void:
	var host: PageHost = _screen.find_child("PageHost", true, false) as PageHost
	var row: Button = _screen.find_child("Mail", true, false) as Button
	assert_not_null(row)
	assert_false(row.disabled)
	assert_string_contains((row.get_node("Side") as Label).text, "2", "two unread messages on the sidebar row")
	await _click(row)
	assert_eq(host.current_page_id(), &"mail")
	var page: MailPage = _screen.find_child("Page", true, false) as MailPage
	assert_not_null(page)
	# a message row, clicked for real: opens it and marks it read
	var message_row: MailRow = page.find_child("Row_2", true, false) as MailRow
	assert_true(message_row.is_unread())
	await _click(message_row)
	assert_eq(_s.mail.unread(), 1)
	assert_true(page.find_child("Message", true, false).visible)
	assert_string_contains((row.get_node("Side") as Label).text, "1")
	# Ritira on the items message
	var items_before: int = _s.bank.get_count(ITEM)
	await _click(page.find_child("CollectButton", true, false) as Button)
	assert_eq(_s.mail.count(), 1, "one command, one message collected")
	assert_eq(_s.bank.get_count(ITEM), items_before + 3)
	# Ritira tutto on the rest
	var gold_before: int = _s.wallet.get_gold()
	await _click(page.find_child("CollectAllButton", true, false) as Button)
	assert_eq(_s.mail.count(), 0)
	assert_eq(_s.wallet.get_gold(), gold_before + 1000)
	assert_true((page.find_child("CollectAllButton", true, false) as Button).disabled, "nothing left to collect")


func test_full_deposit_keeps_the_message_and_shows_the_reason() -> void:
	var free: int = _s.deposit.free_slots()
	_s.deposit.register_occupant(&"test:fill", func() -> int: return free)
	_s.mail.collect(1)  # the money message goes away, the items one stays
	var host: PageHost = _screen.find_child("PageHost", true, false) as PageHost
	host.show_page(&"mail")
	await _settle()
	var page: MailPage = _screen.find_child("Page", true, false) as MailPage
	var message_row: MailRow = page.find_child("Row_2", true, false) as MailRow
	await _click(message_row)
	var button: Button = page.find_child("CollectButton", true, false) as Button
	assert_true(button.disabled)
	assert_true(page.find_child("ReasonLabel", true, false).visible)
	assert_true((page.find_child("CollectAllButton", true, false) as Button).disabled)
	assert_eq(_s.mail.count(), 1, "no loss")


func test_unbind_disconnects_everything() -> void:
	var host: PageHost = _screen.find_child("PageHost", true, false) as PageHost
	host.show_page(&"mail")
	var page: MailPage = _screen.find_child("Page", true, false) as MailPage
	var before: int = _s.events.mail_changed.get_connections().size()
	page.unbind()
	assert_eq(_s.events.mail_changed.get_connections().size(), before - 1)


func _settle() -> void:
	await wait_process_frames(3)


## A real left click (press and release) on the centre of `control`.
func _click(control: Control) -> void:
	var at: Vector2 = control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()  # the mouse arrives over the control first, as with a real hand
	motion.position = at
	motion.global_position = at
	get_viewport().push_input(motion, true)
	await wait_process_frames(1)
	assert_eq(get_viewport().gui_get_hovered_control(), control, "the click lands on the control")
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.position = at
		event.global_position = at
		get_viewport().push_input(event, true)
		await wait_process_frames(1)
	await _settle()
