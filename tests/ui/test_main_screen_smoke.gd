extends GutTest
## Main screen (M1-14): instantiated with a TestFactory session (never Game.session, never a real slot), top bar
## and sidebar read from the session, PageHost routes, signals disconnected on page change and on session_ended,
## menu button through the injected `menu_action`.

const SCENE: PackedScene = preload("res://ui/screens/main/main_screen.tscn")

var _session: GameSession
var _events: GameEvents
var _screen: MainScreen
var _menu_calls: int = 0
## Connections of the observed signals before the screen exists (the session's own systems may have some).
var _baseline: Dictionary[StringName, int] = {}


func before_each() -> void:
	_open(TestFactory.session())


func after_each() -> void:
	# The screen first (it unbinds from the session), then the session.
	if is_instance_valid(_screen):
		_screen.free()
	if is_instance_valid(_session):
		_session.free()
	# Replaced pages and the ToastManager are freed with queue_free: let them go before the orphan count.
	await wait_physics_frames(1)


func test_scene_instantiates_with_injected_session() -> void:
	assert_eq(_page_host().current_page_id(), &"skill:test_gather", "first skill with a page")
	assert_eq(_label(_top_bar(), "%GoldLabel").text, NumberFormat.format_int(_session.wallet.get_gold()))
	assert_eq(_label(_top_bar(), "%BankLabel").text, "%s / %s" % [
		NumberFormat.format_int(_session.bank.used()), NumberFormat.format_int(_session.bank.capacity())])
	assert_true(_label(_top_bar(), "%SlotLabel").text.contains("Slot %d" % _session.slot))
	assert_not_null(_screen.find_child("ToastManager", true, false), "the toasts live in the screen")


func test_show_page_of_every_valid_route() -> void:
	var host: PageHost = _page_host()
	watch_signals(host)
	for page_id: StringName in [&"bank", &"skill:test_craft", &"skill:test_gather"]:
		assert_true(host.has_page(page_id), "%s available" % page_id)
		host.show_page(page_id)
		assert_eq(host.current_page_id(), page_id)
		assert_signal_emitted_with_parameters(host, "page_changed", [page_id])
		assert_eq(_pages(host).size(), 1, "one page at a time")
	for route: StringName in PageHost.ROUTES:
		assert_true(ResourceLoader.exists(PageHost.ROUTES[route]), "scene of route %s" % route)


func test_unavailable_pages_are_refused() -> void:
	var host: PageHost = _page_host()
	for page_id: StringName in [&"shop", &"equipment", &"combat", &"rift", &"settings", &"skill:blade",
			&"skill:not_a_skill", &"bank:extra", &"skill:"]:
		assert_false(host.has_page(page_id), "%s not available" % page_id)
		host.show_page(page_id)
		assert_eq(host.current_page_id(), &"skill:test_gather", "%s keeps the current page" % page_id)


func test_changing_page_disconnects_the_old_page() -> void:
	var host: PageHost = _page_host()
	# Events connected by the SkillPage (M1-15), each exactly once.
	var skill_page_signals: Array[StringName] = [&"xp_gained", &"level_up", &"action_started", &"action_stopped",
			&"mastery_xp_gained", &"modifiers_changed"]
	var on_skill: Dictionary[StringName, int] = {}
	for signal_name: StringName in skill_page_signals:
		on_skill[signal_name] = _count(signal_name)
	# Events connected by the BankPage (M1-18), each exactly once.
	var bank_page_signals: Array[StringName] = [&"bank_changed", &"bank_capacity_changed"]
	var bank_on_skill: Dictionary[StringName, int] = {}
	for signal_name: StringName in bank_page_signals:
		bank_on_skill[signal_name] = _count(signal_name)
	var old_page: Page = _pages(host)[0]
	host.show_page(&"bank")
	for signal_name: StringName in skill_page_signals:
		assert_eq(_count(signal_name), on_skill[signal_name] - 1, "skill page disconnected from %s" % signal_name)
	for signal_name: StringName in bank_page_signals:
		assert_eq(_count(signal_name), bank_on_skill[signal_name] + 1, "bank page connected to %s" % signal_name)
	host.show_page(&"skill:test_gather")
	for signal_name: StringName in bank_page_signals:
		assert_eq(_count(signal_name), bank_on_skill[signal_name], "bank page disconnected from %s" % signal_name)
	assert_false(old_page.is_inside_tree(), "old page removed")
	await wait_physics_frames(1)
	assert_false(is_instance_valid(old_page), "old page freed")


func test_sidebar_rows_from_data() -> void:
	var rows: Node = _sidebar().get_node("%Entries")
	var gather: Button = rows.get_node("SkillTestGather") as Button
	assert_eq(gather.text, "Raccolta di prova")
	assert_false(gather.disabled)
	assert_true(gather.button_pressed, "row of the current page highlighted")
	var blade: Button = rows.get_node("SkillBlade") as Button
	assert_true(blade.disabled, "combat skill page not available yet")
	assert_eq(blade.tooltip_text, "In arrivo")
	for page_name: String in ["Shop", "Equipment", "Combat", "Rift", "Settings"]:
		var row: Button = rows.get_node(page_name) as Button
		assert_true(row.disabled, "%s disabled" % page_name)
		assert_eq(_label(row, "Side").text, "In arrivo")
	assert_false((rows.get_node("Bank") as Button).disabled)
	var skill_rows: int = 0
	for child: Node in rows.get_children():
		if child is Button and child.visible and String(child.name).begins_with("Skill"):
			skill_rows += 1
	assert_eq(skill_rows, _session.data.skills().size(), "one row per skill of the data")


func test_sidebar_row_opens_its_page() -> void:
	var bank: Button = _sidebar().get_node("%Entries/Bank") as Button
	bank.pressed.emit()
	assert_eq(_page_host().current_page_id(), &"bank")
	assert_true(bank.button_pressed)


func test_sidebar_level_follows_level_up() -> void:
	var side: Label = _label(_sidebar().get_node("%Entries/SkillTestGather"), "Side")
	assert_eq(side.text, "Liv. 1")
	TestFactory.set_level(_session, &"test_gather", 12)
	assert_eq(side.text, "Liv. 12")


func test_top_bar_follows_gold_and_bank() -> void:
	_session.wallet.add_gold(1250)
	assert_eq(_label(_top_bar(), "%GoldLabel").text, NumberFormat.format_int(_session.wallet.get_gold()))
	TestFactory.give(_session, &"test_twig", 3)
	assert_eq(_label(_top_bar(), "%BankLabel").text, "%s / %s" % [
		NumberFormat.format_int(_session.bank.used()), NumberFormat.format_int(_session.bank.capacity())])


func test_session_ended_disconnects_everything() -> void:
	_events.session_ended.emit(_session.slot)
	for signal_name: StringName in _baseline:
		assert_eq(_count(signal_name), _baseline[signal_name], "%s back to the baseline" % signal_name)
	assert_eq(_page_host().current_page_id(), &"", "page unbound and freed")
	var gold_text: String = _label(_top_bar(), "%GoldLabel").text
	_session.wallet.add_gold(10)
	assert_eq(_label(_top_bar(), "%GoldLabel").text, gold_text, "no redraw after the end of the session")


func test_freeing_the_screen_disconnects_everything() -> void:
	_screen.free()
	for signal_name: StringName in _baseline:
		assert_eq(_count(signal_name), _baseline[signal_name], "%s back to the baseline" % signal_name)


func test_menu_button_runs_the_menu_action() -> void:
	(_top_bar().get_node("%MenuButton") as Button).pressed.emit()
	assert_eq(_menu_calls, 1)


func test_real_data_sidebar_and_first_page() -> void:
	_screen.free()
	_session.free()
	_open(TestFactory.session(1234, TestFactory.real_data()))
	assert_eq(_page_host().current_page_id(), &"skill:forestry")
	var rows: Node = _sidebar().get_node("%Entries")
	assert_eq((rows.get_node("SkillForestry") as Button).text, "Selvicoltura")
	assert_true((rows.get_node("SkillQuarrying") as Button).disabled, "no actions in the data yet")


func _open(session: GameSession) -> void:
	_session = session
	_events = session.events
	_menu_calls = 0
	_baseline.clear()
	for signal_name: StringName in [&"level_up", &"gold_changed", &"bank_capacity_changed", &"bank_changed",
			&"session_ended", &"notification_requested", &"action_stopped"]:
		_baseline[signal_name] = _count(signal_name)
	_screen = SCENE.instantiate() as MainScreen
	_screen.session = session
	_screen.menu_action = func() -> void: _menu_calls += 1
	add_child(_screen)


func _count(signal_name: StringName) -> int:
	return _events.get_signal_connection_list(signal_name).size()


func _page_host() -> PageHost:
	return _screen.get_node("%PageHost") as PageHost


func _top_bar() -> TopBar:
	return _screen.get_node("%TopBar") as TopBar


func _sidebar() -> Sidebar:
	return _screen.get_node("%Sidebar") as Sidebar


func _label(node: Node, path: String) -> Label:
	return node.get_node(path) as Label


func _pages(host: PageHost) -> Array[Page]:
	var pages: Array[Page] = []
	for child: Node in host.get_children():
		if child is Page:
			pages.append(child as Page)
	return pages
