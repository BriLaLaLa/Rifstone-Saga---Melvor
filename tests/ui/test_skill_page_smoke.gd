extends GutTest
## SkillPage (M1-15) with a TestFactory session (never Game.session, never a real slot) on the fixture `test_gather`:
## header and cards read from the session, interval = actions.current_interval_ms, locked card refused, start/stop
## commands, progress bar read every frame (gut.simulate drives `_process`), unbind disconnects everything.
## Also the base components it uses: ActionProgressBar, XpBar, ItemSlotView.

const SCENE: PackedScene = preload("res://ui/pages/skill/skill_page.tscn")
const XP_BAR_SCENE: PackedScene = preload("res://ui/components/progress/xp_bar.tscn")
const ITEM_SLOT_SCENE: PackedScene = preload("res://ui/components/item_slot/item_slot.tscn")
const SKILL := &"test_gather"
const TWIG := &"gather_twig"
const LOG := &"gather_log"
const BUNDLE := &"gather_bundle"
const INTERVAL_STAT := &"skill_interval_pct"
const LANE_ACTION_KEY: String = "action"
## Every event a page may connect to (the SkillPage uses a subset).
const OBSERVED: Array[StringName] = [&"xp_gained", &"level_up", &"action_started", &"action_stopped",
		&"action_completed", &"mastery_xp_gained", &"mastery_level_up", &"modifiers_changed", &"bank_changed"]

var _session: GameSession
var _page: SkillPage


func before_each() -> void:
	_session = TestFactory.session()


func after_each() -> void:
	# The page first (it unbinds from the session), then the session.
	if is_instance_valid(_page):
		_page.free()
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func test_header_and_cards_read_the_skill() -> void:
	_open(SKILL)
	assert_eq(_label(_page, "%NameLabel").text, "Raccolta di prova")
	assert_eq(_label(_page, "%LevelLabel").text, "Livello 1")
	assert_eq(_label(_page, "%StatusLabel").text, "Nessuna azione in corso")
	var next_xp: int = _session.data.xp_table().xp_for_level(2)
	assert_eq(_xp_bar(_page).shown_text(), "0 / %s XP" % NumberFormat.format_int(next_xp))
	var ids: Array[StringName] = []
	for card: ActionCard in _cards():
		ids.append(card.action_id())
	var expected: Array[StringName] = []
	for action: ActionDef in _session.data.actions_for_skill(SKILL):
		expected.append(action.id)
	assert_eq(ids, expected, "one card per action, in data order")


func test_card_shows_xp_interval_product_and_mastery() -> void:
	_open(SKILL)
	var twig: ActionCard = _card(TWIG)
	assert_eq(_label(twig, "%NameLabel").text, "Raccogliere rametti di prova")
	assert_eq(_label(twig, "%RequirementLabel").text, "Livello 1")
	assert_eq(_label(twig, "%XpValue").text, "10 XP")
	assert_eq(_label(twig, "%IntervalValue").text, "3,0 s")
	assert_eq(_label(twig, "%IntervalValue").text,
			ActionCard.seconds_text(_session.actions.current_interval_ms(TWIG)))
	var product: ItemSlotView = twig.get_node("%Products/ProductTestTwig") as ItemSlotView
	assert_eq(product.item_id(), &"test_twig")
	assert_eq(_label(product, "%CountLabel").text, "1")
	assert_eq(_label(twig, "%Products/ProductTestTwigLabel").text, "Rametto di prova")
	assert_eq(_label(twig, "%MasteryValue").text, "Liv. 1")
	assert_true(_xp_bar(twig, "%MasteryBar").visible)
	var bundle: ActionCard = _card(BUNDLE)
	assert_eq(_label(bundle, "%MasteryValue").text, "Nessuna", "action without mastery")
	assert_false(_xp_bar(bundle, "%MasteryBar").visible)
	assert_eq(_label(bundle.get_node("%Products/ProductTestTwig"), "%CountLabel").text, "2")


func test_interval_shown_is_current_interval_ms() -> void:
	_open(SKILL)
	var mods: Array[Modifier] = [Modifier.make(INTERVAL_STAT, -10.0, &"skill", SKILL)]
	_session.modifiers.set_source(&"test", mods)
	assert_eq(_session.actions.current_interval_ms(TWIG), 2700)
	for card: ActionCard in _cards():
		assert_eq(_label(card, "%IntervalValue").text,
				ActionCard.seconds_text(_session.actions.current_interval_ms(card.action_id())),
				"%s redrawn on modifiers_changed" % card.action_id())
	assert_eq(_label(_card(TWIG), "%IntervalValue").text, "2,7 s")
	assert_eq(_label(_card(LOG), "%IntervalValue").text, "3,6 s")


func test_locked_card_does_not_start() -> void:
	_open(SKILL)
	var locked: ActionCard = _card(LOG)
	assert_eq(_label(locked, "%RequirementLabel").text, "Richiede il livello 5")
	assert_true(_button(locked).disabled, "button disabled below the level")
	# Even if the button fired, the command is refused and the reason is shown.
	_button(locked).pressed.emit()
	assert_false(_session.actions.is_running(), "level_too_low: nothing started")
	var message: Label = _label(_page, "%MessageLabel")
	assert_true(message.visible)
	assert_eq(message.text, SkillPage.REFUSED_TEXTS[Reasons.LEVEL_TOO_LOW])


func test_level_up_unlocks_the_card() -> void:
	_open(SKILL)
	TestFactory.set_level(_session, SKILL, 5)
	var card: ActionCard = _card(LOG)
	assert_false(_button(card).disabled)
	assert_eq(_label(card, "%RequirementLabel").text, "Livello 5")
	assert_eq(_label(_page, "%LevelLabel").text, "Livello 5")
	_button(card).pressed.emit()
	assert_eq(_running_action(), LOG)


func test_start_and_stop_from_the_card() -> void:
	_open(SKILL)
	watch_signals(_session.events)
	var twig: ActionCard = _card(TWIG)
	_button(twig).pressed.emit()
	assert_eq(_running_action(), TWIG)
	assert_eq(_button(twig).text, "Ferma")
	assert_eq(_button(_card(BUNDLE)).text, "Avvia")
	assert_eq(_label(_page, "%StatusLabel").text, "In corso: Raccogliere rametti di prova")
	_button(_card(BUNDLE)).pressed.emit()
	assert_eq(_running_action(), BUNDLE, "another card replaces the running action")
	assert_eq(_button(twig).text, "Avvia")
	_button(_card(BUNDLE)).pressed.emit()
	assert_false(_session.actions.is_running())
	assert_signal_emitted_with_parameters(_session.events, "action_stopped",
			[ActionRunner.MAIN, SKILL, Reasons.STOPPED_BY_USER])
	assert_eq(_button(_card(BUNDLE)).text, "Avvia")
	assert_eq(_label(_page, "%StatusLabel").text, "Nessuna azione in corso")
	assert_false(_label(_page, "%MessageLabel").visible)


func test_progress_bar_reads_get_progress_every_frame() -> void:
	_open(SKILL)
	_button(_card(TWIG)).pressed.emit()
	_session.advance(1200)
	assert_eq(_bar(_card(TWIG)).value, 0.0, "nothing drawn before the frame")
	gut.simulate(_page, 1, 0.0)
	assert_almost_eq(_bar(_card(TWIG)).value, _session.actions.get_progress(), 0.0001)
	assert_almost_eq(_bar(_card(TWIG)).value, 0.4, 0.0001, "F-04: 1200 / 3000")
	assert_eq(_bar(_card(BUNDLE)).value, 0.0, "only the running card fills")
	_session.advance(2400)
	gut.simulate(_page, 1, 0.0)
	assert_almost_eq(_bar(_card(TWIG)).value, _session.actions.get_progress(), 0.0001, "next cycle")
	assert_almost_eq(_bar(_card(TWIG)).value, 0.2, 0.0001, "600 / 3000")
	_session.actions.stop()
	gut.simulate(_page, 1, 0.0)
	assert_eq(_bar(_card(TWIG)).value, 0.0, "idle lane: the bar shows 0, it keeps nothing")


func test_completed_cycles_redraw_xp_and_mastery() -> void:
	_open(SKILL)
	_button(_card(TWIG)).pressed.emit()
	_session.advance(_session.actions.current_interval_ms(TWIG) * 3)
	var xp: int = _session.skills.get_xp(SKILL)
	assert_gt(xp, 0)
	var next_xp: int = _session.data.xp_table().xp_for_level(_session.skills.get_level(SKILL) + 1)
	assert_eq(_xp_bar(_page).shown_text(), "%s / %s XP" % [
		NumberFormat.format_int(xp), NumberFormat.format_int(next_xp)])
	var twig: ActionCard = _card(TWIG)
	assert_eq(_label(twig, "%MasteryValue").text,
			"Liv. %s" % NumberFormat.format_int(_session.mastery.get_mastery_level(TWIG)))
	var mastery_xp: int = _session.mastery.get_mastery_xp(TWIG)
	assert_gt(mastery_xp, 0)
	assert_almost_eq(_xp_bar(twig, "%MasteryBar").shown_progress(),
			_session.data.mastery_table().progress(mastery_xp), 0.0001)


func test_unbind_disconnects_everything() -> void:
	var baseline: Dictionary[StringName, int] = _counts()
	_open(SKILL)
	var bound: Dictionary[StringName, int] = _counts()
	var connected: int = 0
	for signal_name: StringName in OBSERVED:
		var added: int = bound[signal_name] - baseline[signal_name]
		assert_true(added == 0 or added == 1, "%s connected at most once" % signal_name)
		connected += added
	assert_eq(connected, 6, "xp, level, start, stop, mastery xp, modifiers")
	assert_true(_page.is_processing())
	_page.unbind()
	assert_eq(_counts(), baseline, "back to the baseline")
	assert_false(_page.is_processing(), "no frame reads without a session")
	_page.unbind()
	assert_eq(_counts(), baseline, "unbind twice is safe")


func test_freeing_the_page_disconnects_everything() -> void:
	var baseline: Dictionary[StringName, int] = _counts()
	_open(SKILL)
	_page.free()
	assert_eq(_counts(), baseline)


func test_artisan_skill_refuses_start_until_recipes() -> void:
	_open(&"test_craft")
	var cards: Array[ActionCard] = _cards()
	assert_false(cards.is_empty())
	_button(cards[0]).pressed.emit()
	assert_false(_session.actions.is_running())
	assert_eq(_label(_page, "%MessageLabel").text, SkillPage.REFUSED_TEXTS[Reasons.UNKNOWN_ID])


func test_real_data_forestry_page() -> void:
	_session.free()
	_session = TestFactory.session(1234, TestFactory.real_data())
	_open(&"forestry")
	var cards: Array[ActionCard] = _cards()
	assert_eq(cards.size(), 8)
	assert_eq(_label(_page, "%NameLabel").text, "Selvicoltura")
	assert_false(_button(cards[0]).disabled)
	assert_eq(_label(cards[0], "%IntervalValue").text, "3,0 s")
	for card: ActionCard in cards.slice(1):
		assert_true(_button(card).disabled, "%s locked at level 1" % card.action_id())


func test_seconds_text() -> void:
	assert_eq(ActionCard.seconds_text(3000), "3,0 s")
	assert_eq(ActionCard.seconds_text(2700), "2,7 s")
	assert_eq(ActionCard.seconds_text(250), "0,25 s")
	assert_eq(ActionCard.seconds_text(12500), "12,5 s")


func test_action_progress_bar_is_continuous_and_clamped() -> void:
	var bar: ActionProgressBar = autofree(ActionProgressBar.new()) as ActionProgressBar
	bar.set_progress(0.37)
	assert_almost_eq(bar.value, 0.37, 0.0001, "no step: continuous")
	bar.set_progress(1.5)
	assert_eq(bar.value, 1.0)
	bar.set_progress(-1.0)
	assert_eq(bar.value, 0.0)


func test_xp_bar_text_and_max_level() -> void:
	var bar: XpBar = add_child_autofree(XP_BAR_SCENE.instantiate()) as XpBar
	var table: XpTable = TestFactory.fixture_data().xp_table()
	var xp: int = table.xp_for_level(3) + 1
	bar.set_xp(table, xp)
	assert_eq(bar.shown_text(), "%s / %s XP" % [NumberFormat.format_int(xp),
		NumberFormat.format_int(table.xp_for_level(4))])
	assert_almost_eq(bar.shown_progress(), table.progress(xp), 0.0001)
	bar.set_xp(table, table.xp_for_level(table.max_level))
	assert_true(bar.shown_text().ends_with("Livello massimo"))
	assert_eq(bar.shown_progress(), 1.0)


func test_item_slot_set_and_clear() -> void:
	var slot: ItemSlotView = add_child_autofree(ITEM_SLOT_SCENE.instantiate()) as ItemSlotView
	var item: ItemDef = TestFactory.fixture_data().item(&"test_log")
	slot.set_item(item, 1250, true)
	assert_eq(slot.item_id(), &"test_log")
	assert_eq(_label(slot, "%CountLabel").text, "1.250")
	assert_true((slot.get_node("%LockMarker") as Control).visible)
	assert_not_null((slot.get_node("%Icon") as TextureRect).texture, "missing icon file: placeholder")
	slot.set_item(item, 0)
	assert_eq(_label(slot, "%CountLabel").text, "", "no quantity drawn for 0")
	assert_false((slot.get_node("%LockMarker") as Control).visible)
	slot.clear()
	assert_eq(slot.item_id(), &"")
	assert_null((slot.get_node("%Icon") as TextureRect).texture)


func _open(skill_id: StringName) -> void:
	_page = SCENE.instantiate() as SkillPage
	_page.page_id = StringName(PageHost.ROUTE_SKILL + PageHost.ROUTE_SEPARATOR + skill_id)
	add_child(_page)
	_page.bind(_session)


func _running_action() -> StringName:
	return _session.actions.get_lane().get(LANE_ACTION_KEY, &"")


func _counts() -> Dictionary[StringName, int]:
	var counts: Dictionary[StringName, int] = {}
	for signal_name: StringName in OBSERVED:
		counts[signal_name] = _session.events.get_signal_connection_list(signal_name).size()
	return counts


func _cards() -> Array[ActionCard]:
	var cards: Array[ActionCard] = []
	for child: Node in _page.get_node("%Cards").get_children():
		if child is ActionCard:
			cards.append(child as ActionCard)
	return cards


func _card(action_id: StringName) -> ActionCard:
	return _page.get_node("%Cards/" + String(action_id).to_pascal_case()) as ActionCard


func _button(card: ActionCard) -> Button:
	return card.get_node("%ToggleButton") as Button


func _bar(card: ActionCard) -> ActionProgressBar:
	return card.get_node("%ProgressBar") as ActionProgressBar


func _xp_bar(node: Node, path: String = "%XpBar") -> XpBar:
	return node.get_node(path) as XpBar


func _label(node: Node, path: String) -> Label:
	return node.get_node(path) as Label
