extends GutTest
## SkillPage (M1-15, M24-06) with a TestFactory session (never Game.session, never a real slot) on the fixture `test_gather`
## and `test_craft`: header and cards read from the session, interval = actions.current_interval_ms, a gathering page is
## read only, a recipe card puts the job in the queue (`actions.enqueue`) and the queue panel shows and cancels it, unbind
## disconnects everything. Also the base components it uses: ActionProgressBar, XpBar, ItemSlotView.

const SCENE: PackedScene = preload("res://ui/pages/skill/skill_page.tscn")
const XP_BAR_SCENE: PackedScene = preload("res://ui/components/progress/xp_bar.tscn")
const ITEM_SLOT_SCENE: PackedScene = preload("res://ui/components/item_slot/item_slot.tscn")
const SKILL := &"test_gather"
const TWIG := &"gather_twig"
const LOG := &"gather_log"
const BUNDLE := &"gather_bundle"
const INTERVAL_STAT := &"skill_interval_pct"
## Every event a page may connect to (the SkillPage uses a subset).
const OBSERVED: Array[StringName] = [&"xp_gained", &"level_up", &"action_started", &"action_stopped",
		&"action_completed", &"mastery_xp_gained", &"modifiers_changed", &"bank_changed", &"production_queue_changed",
		&"discipline_changed", &"recipe_learned"]

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


func test_header_and_rows_read_the_skill() -> void:
	_open(SKILL)
	assert_eq(_label(_page, "%NameLabel").text, "Raccolta di prova")
	assert_eq(_label(_page, "%LevelLabel").text, "Livello 1")
	var next_xp: int = _session.data.xp_table().xp_for_level(2)
	assert_eq(_xp_bar(_page).shown_text(), "0 / %s XP" % NumberFormat.format_int(next_xp))
	var expected: Array[StringName] = []
	for action: ActionDef in _session.data.actions_for_skill(SKILL):
		expected.append(action.id)
	assert_eq(_table().row_ids(), expected, "one row per action, in data order")


func test_row_shows_level_stock_and_mastery() -> void:
	_open(SKILL)
	var twig: ResourceRow = _row(TWIG)
	assert_not_null(twig)
	var texts: PackedStringArray = _label_texts(twig)
	assert_true(texts.has("Raccogliere rametti di prova"), "name")
	assert_true(texts.has(ResourceTexts.MASTERY_TEXT % "1"), "mastery level of an action with mastery (in the detail)")
	assert_true(_label_texts(_row(BUNDLE)).has(ResourceTexts.NO_MASTERY_TEXT), "action without mastery")


func test_gathering_page_is_read_only() -> void:
	_open(SKILL)
	for id: StringName in _table().row_ids():
		assert_null(_row(id).find_child("ToggleButton", true, false), "no Avvia/Ferma on a gathering row")
		assert_null(_row(id).find_child("EnqueueButton", true, false))
	assert_null(_page.find_child("ProductionQueue", true, false), "no queue on a gathering page")
	assert_not_null(_page.find_child("FoundInLabel", true, false))


func test_gathering_row_shows_the_colour_from_the_model() -> void:
	var saved: String = NodeColorPreview.cycle_script_path
	NodeColorPreview.cycle_script_path = "res://tests/helpers/combat_cycle_stub.gd"
	_open(SKILL)
	var text: String = _row(TWIG).color_text()
	assert_true(text.contains("arancione"), "the colour comes from EncounterCycle.color (double)")
	NodeColorPreview.cycle_script_path = saved


func test_unbind_disconnects_everything() -> void:
	var baseline: Dictionary[StringName, int] = _counts()
	_open(SKILL)
	var bound: Dictionary[StringName, int] = _counts()
	var connected: int = 0
	for signal_name: StringName in OBSERVED:
		var added: int = bound[signal_name] - baseline[signal_name]
		assert_true(added == 0 or added == 1, "%s connected at most once" % signal_name)
		connected += added
	assert_eq(connected, 9, "xp, level, start, stop, mastery xp, modifiers, queue, discipline, recipe")
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


func test_gathering_page_has_no_production_view() -> void:
	_open(SKILL)
	assert_null(_page.find_child("ProfessionView", true, false))
	assert_false(_table().row_ids().is_empty())


func test_real_data_forestry_page_is_read_only_and_lists_its_areas() -> void:
	_session.free()
	_session = TestFactory.session(1234, TestFactory.real_data())
	_open(&"forestry")
	assert_eq(_table().row_ids().size(), 8)
	assert_eq(_label(_page, "%NameLabel").text, "Boscaiolo")
	assert_true((_page.find_child("FoundInLabel", true, false) as Label).text.length() > 0)


func test_seconds_text() -> void:
	# Single definition: the card uses NumberFormat.format_seconds.
	for ms: int in [3000, 2700, 250, 12500]:
		assert_eq(ActionCard.seconds_text(ms), NumberFormat.format_seconds(ms))
	assert_eq(ActionCard.seconds_text(3000), "3,0 s")
	var card_constants: Dictionary = (load("res://ui/pages/skill/action_card.gd") as Script).get_script_constant_map()
	assert_false(card_constants.has("DECIMAL_SEPARATOR"), "the separator lives only in NumberFormat")


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


func _counts() -> Dictionary[StringName, int]:
	var counts: Dictionary[StringName, int] = {}
	for signal_name: StringName in OBSERVED:
		counts[signal_name] = _session.events.get_signal_connection_list(signal_name).size()
	return counts


func _table() -> ResourceTable:
	return _page.find_child("ResourceTable", true, false) as ResourceTable


func _row(action_id: StringName) -> ResourceRow:
	return _page.find_child("ResourceRow_%s" % action_id, true, false) as ResourceRow


func _label_texts(node: Node) -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for label: Node in node.find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	return texts


func _xp_bar(node: Node, path: String = "%XpBar") -> XpBar:
	return node.get_node(path) as XpBar


func _label(node: Node, path: String) -> Label:
	return node.get_node(path) as Label
