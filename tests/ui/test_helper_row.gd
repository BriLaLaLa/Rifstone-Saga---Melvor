extends GutTest
## HelperRow inside the SkillPage of the gathering skills (M12-06, docs/05_INTERFACES.md §7.w): "Aiutante: nessuno",
## hire from a contract, "Aiutante: <grado> — lavora: <risorsa>", change / stop, the waiting text for a full Deposit, the
## bar read from `helpers.get_progress`, redraw on the helper events, unbind. Real data, TestFactory session.

const SCENE: PackedScene = preload("res://ui/pages/skill/skill_page.tscn")
const SKILL := &"forestry"
const CONTRACT := &"contract_forestry_journeyman"
const ACTION := &"cut_redbirch"

var _session: GameSession
var _page: SkillPage


func before_each() -> void:
	_session = TestFactory.session(1234, TestFactory.real_data())


func after_each() -> void:
	if is_instance_valid(_page):
		_page.free()
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func test_gathering_pages_have_a_row_and_the_others_do_not() -> void:
	_open(SKILL)
	assert_not_null(_row())
	assert_eq(_label("HelperLabel"), "Aiutante: nessuno")
	assert_false(_node("HireButton").visible, "no contract owned")
	_page.free()
	_open(&"forging")
	assert_null(_row())


func test_hiring_shows_the_grade_and_the_resource() -> void:
	TestFactory.give(_session, CONTRACT, 1)
	_open(SKILL)
	assert_true(_node("HireButton").visible)
	_row().hire_requested.emit(CONTRACT)
	assert_eq(_session.helpers.get_grade(SKILL), &"journeyman")
	assert_eq(_label("HelperLabel"), "Aiutante: Garzone — nessuna risorsa scelta")
	assert_true(_node("ChangeButton").visible)
	assert_false(_node("HireButton").visible, "the contract was used")
	_row().change_requested.emit(SKILL, ACTION)
	assert_eq(_session.helpers.get_action(SKILL), ACTION)
	var resource: String = _session.data.item(_session.data.action(ACTION).outputs[0].item_id).name
	assert_eq(_label("HelperLabel"), "Aiutante: Garzone — lavora: %s" % resource)
	assert_true(_node("StopButton").visible)
	assert_true(_node("HelperBar").visible)


func test_stop_removes_the_action_but_keeps_the_helper() -> void:
	_hire_and_work()
	_open(SKILL)
	_row().stop_requested.emit(SKILL)
	assert_eq(_session.helpers.get_action(SKILL), &"")
	assert_eq(_session.helpers.get_grade(SKILL), &"journeyman")
	assert_false(_node("StopButton").visible)


func test_a_worse_contract_is_refused_with_its_reason() -> void:
	_hire_and_work()
	TestFactory.give(_session, &"contract_forestry_apprentice", 1)
	_open(SKILL)
	_row().hire_requested.emit(&"contract_forestry_apprentice")
	var message: Label = _page.get_node("%MessageLabel")
	assert_true(message.visible)
	assert_eq(message.text, HelperTexts.refused(Reasons.HELPER_NOT_BETTER))
	assert_eq(_session.bank.get_count(&"contract_forestry_apprentice"), 1, "not consumed")


func test_the_bar_reads_the_progress_of_the_helper_every_frame() -> void:
	_hire_and_work()
	_open(SKILL)
	var interval: int = _session.helpers.interval_ms(SKILL)
	assert_gt(interval, 0)
	_session.helpers.advance(interval / 2)
	_row()._process(0.0)
	assert_almost_eq((_node("HelperBar") as ProgressBar).value, _session.helpers.get_progress(SKILL), 0.001)
	assert_gt((_node("HelperBar") as ProgressBar).value, 0.3)


func test_full_deposit_shows_the_waiting_text() -> void:
	_hire_and_work()
	for item: ItemDef in _session.data.items():
		if _session.deposit.has_room() and item.id != &"redbirch_log" and item.category == &"material":
			TestFactory.give(_session, item.id, 1)
	assert_false(_session.deposit.has_room(), "the Deposit is full")
	_open(SKILL)
	assert_false(_node("BlockedLabel").visible)
	_session.helpers.advance(_session.helpers.interval_ms(SKILL) + 1)
	assert_true(_session.helpers.is_blocked(SKILL), "no box for a new item")
	assert_true(_node("BlockedLabel").visible)
	assert_eq(_label("BlockedLabel"), "In attesa: Deposito pieno")


func test_unbind_disconnects_the_helper_events() -> void:
	var names: Array[StringName] = [&"helper_changed", &"helper_completed", &"helper_blocked"]
	var baseline: Dictionary[StringName, int] = {}
	for name: StringName in names:
		baseline[name] = _session.events.get_signal_connection_list(name).size()
	_open(SKILL)
	assert_gt(_session.events.get_signal_connection_list(&"helper_changed").size(), baseline[&"helper_changed"])
	_page.unbind()
	for name: StringName in names:
		assert_eq(_session.events.get_signal_connection_list(name).size(), baseline[name], String(name))


func _hire_and_work() -> void:
	TestFactory.give(_session, CONTRACT, 1)
	assert_true(_session.helpers.hire(CONTRACT).ok)
	assert_true(_session.helpers.set_action(SKILL, ACTION).ok)


func _open(skill_id: StringName) -> void:
	_page = SCENE.instantiate() as SkillPage
	_page.page_id = StringName(PageHost.ROUTE_SKILL + PageHost.ROUTE_SEPARATOR + skill_id)
	add_child(_page)
	_page.bind(_session)


func _row() -> HelperRow:
	return _page.find_child("HelperRow", true, false) as HelperRow


func _node(node_name: String) -> Control:
	return _row().get_node(node_name) as Control


func _label(node_name: String) -> String:
	return (_node(node_name) as Label).text
