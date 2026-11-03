extends GutTest
## MasteryPanel (M2-03) opened from the SkillPage with a TestFactory session (never Game.session, never a real slot)
## on the fixture `test_gather` (2 actions with mastery, pool cap 2 × 300.000, 3 nodes): pool bar and 95% warning,
## action rows, pool spending with the slider, node tree by `pos` with the four states, commands through
## MasterySystem with the reason shown on error, connections only while open.
## The pool is set through `mastery.from_save` (no signals) before opening, or changed by commands while open.

const PAGE_SCENE: PackedScene = preload("res://ui/pages/skill/skill_page.tscn")
const SKILL := &"test_gather"
const TWIG := &"gather_twig"
const LOG := &"gather_log"
const BUNDLE := &"gather_bundle"
const N1 := &"test_gather_n1"
const N2 := &"test_gather_n2"
const N3 := &"test_gather_n3"
const CAP: int = 600000
const OBSERVED: Array[StringName] = [&"mastery_pool_changed", &"mastery_node_purchased", &"mastery_xp_gained",
		&"mastery_level_up", &"modifiers_changed"]

var _session: GameSession
var _page: SkillPage


func before_each() -> void:
	_session = TestFactory.session()


func after_each() -> void:
	if is_instance_valid(_page):
		_page.free()
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func test_button_opens_and_closes_the_panel() -> void:
	_open_page(SKILL)
	var button: Button = _page.get_node("%MasteryButton") as Button
	assert_true(button.visible, "skill with mastery")
	assert_eq(button.text, "Maestria")
	button.pressed.emit()
	var panel: MasteryPanel = _panel()
	assert_not_null(panel)
	assert_true(panel.visible)
	var title: Label = panel.get_node("VBox/Header").get_child(0) as Label
	assert_eq(title.text, "MAESTRIA: RACCOLTA DI PROVA")
	button.pressed.emit()
	assert_false(panel.visible, "the button toggles the window")
	button.pressed.emit()
	assert_true(panel.visible)
	assert_eq(_page.get_children().filter(func(n: Node) -> bool: return n is MasteryPanel).size(), 1,
			"one window per page")


func test_no_button_for_skill_without_mastery() -> void:
	_open_page(&"riftbinding")
	assert_false((_page.get_node("%MasteryButton") as Button).visible)


func test_pool_bar_reads_pool_and_cap() -> void:
	_set_mastery(150000)
	_open_panel()
	assert_eq(_session.mastery.get_pool_cap(SKILL), CAP)
	assert_eq(_label("%PoolLabel").text, "150.000 / 600.000 XP")
	assert_almost_eq((_panel().get_node("%PoolBar") as ProgressBar).value, 0.25, 0.0001)
	assert_false(_label("%PoolWarning").visible, "25%: no warning")


func test_pool_warning_from_the_balance_threshold_on_pool_changed() -> void:
	var pct: float = float(_session.data.balance_value(MasteryPanel.POOL_WARNING_KEY))
	assert_eq(pct, 95.0, "01_GDD.md §6.2, from balance.json")
	var threshold: int = ceili(CAP * pct / 100.0)
	_set_mastery(threshold - 1)
	_open_panel()
	assert_false(_label("%PoolWarning").visible, "just below 95%")
	var twig: ActionDef = _session.data.action(TWIG)
	for i: int in 100:
		if _session.mastery.get_pool(SKILL) >= threshold:
			break
		_session.mastery.add_for_action(twig)
	assert_gte(_session.mastery.get_pool(SKILL), threshold)
	assert_true(_label("%PoolWarning").visible, "redrawn on mastery_pool_changed")
	assert_eq(_label("%PoolLabel").text, "%s / 600.000 XP" % NumberFormat.format_int(_session.mastery.get_pool(SKILL)))


func test_action_rows_show_mastery_actions() -> void:
	_set_mastery(0, {TWIG: _session.data.mastery_table().xp_for_level(3)})
	_open_panel()
	var ids: Array[StringName] = []
	for row: MasteryActionRow in _rows():
		ids.append(row.action_id())
	var expected: Array[StringName] = []
	for action: ActionDef in _session.data.mastery_actions_for_skill(SKILL):
		expected.append(action.id)
	assert_eq(ids, expected, "one row per action with mastery, data order")
	assert_false(ids.has(BUNDLE), "no row for an action without mastery")
	var twig: MasteryActionRow = _row(TWIG)
	assert_eq(_label("%LevelLabel", twig).text, "Liv. 3")
	assert_almost_eq((twig.get_node("%MasteryBar") as XpBar).shown_progress(),
			_session.data.mastery_table().progress(_session.mastery.get_mastery_xp(TWIG)), 0.0001)
	var first: StringName = expected[0]
	assert_eq(_button("%SelectButton", _row(first)).text, "Scelta", "first action chosen by default")
	assert_eq(_label("%SpendTarget").text, "Spendi il pool su: %s" % _session.data.action(first).name)


func test_spend_pool_on_the_chosen_action() -> void:
	_set_mastery(1000)
	_open_panel()
	_button("%SelectButton", _row(TWIG)).pressed.emit()
	assert_eq(_button("%SelectButton", _row(TWIG)).text, "Scelta")
	assert_eq(_button("%SelectButton", _row(LOG)).text, "Scegli")
	var slider: HSlider = _panel().get_node("%SpendSlider") as HSlider
	assert_eq(slider.max_value, 1000.0, "slider up to the pool")
	assert_eq(slider.value, 1000.0, "starts at the whole pool")
	slider.value = 400
	assert_eq(_label("%SpendAmount").text, "400 XP")
	_button("%SpendButton").pressed.emit()
	assert_eq(_session.mastery.get_mastery_xp(TWIG), 400, "F-14: 1 pool xp = 1 mastery xp")
	assert_eq(_session.mastery.get_pool(SKILL), 600)
	assert_false(_label("%MessageLabel").visible)
	assert_eq(_label("%PoolLabel").text, "600 / 600.000 XP")
	assert_eq(slider.max_value, 600.0)
	assert_almost_eq((_row(TWIG).get_node("%MasteryBar") as XpBar).shown_progress(),
			_session.data.mastery_table().progress(400), 0.0001, "row redrawn on mastery_xp_gained")
	assert_eq(_label("%LevelLabel", _row(TWIG)).text,
			"Liv. %s" % NumberFormat.format_int(_session.mastery.get_mastery_level(TWIG)))


func test_spend_errors_show_the_reason() -> void:
	_set_mastery(0)
	_open_panel()
	_button("%SpendButton").pressed.emit()
	assert_true(_label("%MessageLabel").visible)
	assert_eq(_label("%MessageLabel").text, MasteryTexts.reason_text(Reasons.POOL_INSUFFICIENT))
	var max_xp: int = _session.data.mastery_table().xp_for_level(_session.data.mastery_table().max_level)
	_set_mastery(500, {TWIG: max_xp})
	_close_and_reopen()
	_button("%SelectButton", _row(TWIG)).pressed.emit()
	_button("%SpendButton").pressed.emit()
	assert_eq(_label("%MessageLabel").text, MasteryTexts.reason_text(Reasons.MASTERY_MAX))
	assert_eq(_session.mastery.get_pool(SKILL), 500, "nothing spent")
	assert_ne(MasteryTexts.reason_text(Reasons.POOL_INSUFFICIENT), MasteryTexts.REASON_TEXT_DEFAULT)


func test_node_tree_is_laid_out_by_pos() -> void:
	_open_panel()
	var step: Vector2 = UiStyle.MASTERY_NODE_SIZE + UiStyle.MASTERY_NODE_GAP
	for node: MasteryNodeDef in _session.data.mastery_nodes(SKILL):
		var view: MasteryNodeView = _view(node.id)
		assert_eq(view.position, Vector2(node.pos) * step, "%s at pos %s" % [node.id, node.pos])
		assert_eq(_label("%NameLabel", view).text, node.name)
		assert_eq(view.tooltip_text, node.description)
	var tree: MasteryNodeTree = _panel().get_node("%NodeTree") as MasteryNodeTree
	assert_eq(tree.custom_minimum_size, step * Vector2(1, 2) + UiStyle.MASTERY_NODE_SIZE, "2 columns × 3 rows")
	var mods: String = (_view(N1).get_node("%ModifiersLabel") as RichTextLabel).get_parsed_text()
	assert_true(mods.begins_with("Velocità delle azioni -3%"), "stat label of the registry: %s" % mods)
	assert_eq(_label("%CostLabel", _view(N1)).text, "Costo: 30.000 XP (5% del tetto)")
	assert_eq(_label("%CostLabel", _view(N3)).text, "Costo: 120.000 XP (20% del tetto)")


func test_node_states_follow_the_model() -> void:
	_set_mastery(0)
	_open_panel()
	assert_eq(MasteryNodeView.state_of(_session, N1), MasteryTexts.STATE_UNAFFORDABLE)
	assert_eq(_label("%StateLabel", _view(N1)).text, "Pool insufficiente")
	assert_true(_button("%BuyButton", _view(N1)).disabled)
	assert_eq(MasteryNodeView.state_of(_session, N2), MasteryTexts.STATE_LOCKED)
	assert_eq(_label("%StateLabel", _view(N2)).text, "Richiede: Primo nodo")
	assert_eq(_label("%StateLabel", _view(N3)).text, "Richiede: Primo nodo, Secondo nodo")
	_set_mastery(100000)
	_close_and_reopen()
	assert_eq(MasteryNodeView.state_of(_session, N1), MasteryTexts.STATE_BUYABLE)
	assert_eq(_label("%StateLabel", _view(N1)).text, "Disponibile")
	assert_false(_button("%BuyButton", _view(N1)).disabled)


func test_buy_nodes_through_the_model() -> void:
	_set_mastery(100000)
	_open_panel()
	_button("%BuyButton", _view(N1)).pressed.emit()
	assert_true(_session.mastery.owns_node(N1))
	assert_eq(_session.mastery.get_pool(SKILL), 70000, "F-15: 5% of 600.000")
	assert_eq(_label("%StateLabel", _view(N1)).text, "Acquistato")
	assert_false(_button("%BuyButton", _view(N1)).visible)
	assert_eq(_label("%PoolLabel").text, "70.000 / 600.000 XP")
	assert_eq(_label("%StateLabel", _view(N2)).text, "Disponibile", "prerequisite owned")
	_button("%BuyButton", _view(N2)).pressed.emit()
	assert_true(_session.mastery.owns_node(N2))
	assert_eq(_session.mastery.get_pool(SKILL), 10000)
	assert_eq(MasteryNodeView.state_of(_session, N3), MasteryTexts.STATE_UNAFFORDABLE)
	assert_eq(_label("%StateLabel", _view(N3)).text, "Pool insufficiente")
	assert_false(_label("%MessageLabel").visible)


func test_refused_buy_shows_the_reason_and_changes_nothing() -> void:
	_set_mastery(100000)
	_open_panel()
	watch_signals(_session.events)
	assert_false(_button("%BuyButton", _view(N2)).visible, "locked: no Buy button")
	_button("%BuyButton", _view(N2)).pressed.emit()
	assert_false(_session.mastery.owns_node(N2))
	assert_eq(_session.mastery.get_pool(SKILL), 100000)
	assert_signal_not_emitted(_session.events, "mastery_node_purchased")
	assert_eq(_label("%MessageLabel").text, MasteryTexts.reason_text(Reasons.NODE_PREREQ_MISSING))
	_button("%BuyButton", _view(N1)).pressed.emit()
	assert_false(_label("%MessageLabel").visible, "a successful command clears the message")
	_button("%BuyButton", _view(N1)).pressed.emit()
	assert_eq(_label("%MessageLabel").text, MasteryTexts.reason_text(Reasons.NODE_OWNED))


func test_connected_only_while_open() -> void:
	var empty: Dictionary[StringName, int] = _counts()
	_open_page(SKILL)
	var baseline: Dictionary[StringName, int] = _counts()
	_open_panel()
	var open: Dictionary[StringName, int] = _counts()
	assert_eq(open[&"mastery_pool_changed"] - baseline[&"mastery_pool_changed"], 1)
	assert_eq(open[&"mastery_node_purchased"] - baseline[&"mastery_node_purchased"], 1)
	assert_eq(open[&"mastery_xp_gained"] - baseline[&"mastery_xp_gained"], 1)
	assert_eq(open[&"mastery_level_up"], baseline[&"mastery_level_up"])
	assert_eq(open[&"modifiers_changed"], baseline[&"modifiers_changed"])
	_panel().close_window()
	assert_eq(_counts(), baseline, "closing the window disconnects")
	_open_panel()
	_page.unbind()
	assert_eq(_counts(), empty, "page unbind closes the window")
	_page.bind(_session)
	_open_panel()
	_page.free()
	assert_eq(_counts(), empty, "freeing the page disconnects")


func test_real_data_forestry_tree() -> void:
	_session.free()
	_session = TestFactory.session(1234, TestFactory.real_data())
	_open_page(&"forestry")
	(_page.get_node("%MasteryButton") as Button).pressed.emit()
	var tree: MasteryNodeTree = _panel().get_node("%NodeTree") as MasteryNodeTree
	var step: Vector2 = UiStyle.MASTERY_NODE_SIZE + UiStyle.MASTERY_NODE_GAP
	assert_eq(tree.custom_minimum_size, step * Vector2(2, 3) + UiStyle.MASTERY_NODE_SIZE, "3 columns × 4 rows")
	var nodes: Array[MasteryNodeDef] = _session.data.mastery_nodes(&"forestry")
	assert_eq(tree.get_child_count(), nodes.size())
	for node: MasteryNodeDef in nodes:
		var expected: StringName = MasteryTexts.STATE_UNAFFORDABLE if node.requires.is_empty() \
				else MasteryTexts.STATE_LOCKED
		assert_eq(MasteryNodeView.state_of(_session, node.id), expected, "%s on a new game" % node.id)
	assert_eq(_rows().size(), _session.data.mastery_actions_for_skill(&"forestry").size())


func _open_page(skill_id: StringName) -> void:
	_page = PAGE_SCENE.instantiate() as SkillPage
	_page.page_id = StringName(PageHost.ROUTE_SKILL + PageHost.ROUTE_SEPARATOR + skill_id)
	add_child(_page)
	_page.bind(_session)


func _open_panel() -> void:
	if not is_instance_valid(_page):
		_open_page(SKILL)
	var panel: MasteryPanel = _panel()
	if panel == null or not panel.visible:
		(_page.get_node("%MasteryButton") as Button).pressed.emit()


func _close_and_reopen() -> void:
	_panel().close_window()
	_open_panel()


## Sets the pool of SKILL and the mastery xp of some of its actions (through the save, no signals).
func _set_mastery(pool: int, xp: Dictionary = {}) -> void:
	var save: Dictionary = _session.mastery.to_save()
	var entry: Dictionary = save[String(SKILL)]
	entry["pool"] = pool
	for action_id: StringName in xp:
		entry["actions"][String(action_id)] = xp[action_id]
	_session.mastery.from_save(save)
	assert_eq(_session.mastery.get_pool(SKILL), pool)


func _panel() -> MasteryPanel:
	return _page.get_node_or_null("MasteryPanel") as MasteryPanel


func _rows() -> Array[MasteryActionRow]:
	var rows: Array[MasteryActionRow] = []
	for child: Node in _panel().get_node("%ActionList").get_children():
		if child is MasteryActionRow and not child.is_queued_for_deletion():
			rows.append(child as MasteryActionRow)
	return rows


func _row(action_id: StringName) -> MasteryActionRow:
	return _panel().get_node("%ActionList/" + String(action_id).to_pascal_case()) as MasteryActionRow


func _view(node_id: StringName) -> MasteryNodeView:
	return _panel().get_node("%NodeTree/" + String(node_id).to_pascal_case()) as MasteryNodeView


func _counts() -> Dictionary[StringName, int]:
	var counts: Dictionary[StringName, int] = {}
	for signal_name: StringName in OBSERVED:
		counts[signal_name] = _session.events.get_signal_connection_list(signal_name).size()
	return counts


func _label(path: String, node: Node = null) -> Label:
	return (node if node != null else _panel()).get_node(path) as Label


func _button(path: String, node: Node = null) -> Button:
	return (node if node != null else _panel()).get_node(path) as Button
