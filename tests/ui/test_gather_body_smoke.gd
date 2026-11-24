extends GutTest
## Smoke test of the GatherBody of a gathering page (M36-1, docs/05_INTERFACES_M36.md §7.ae) on a SkillPage with a real-data session:
## three tabs opening on the Overview, heads folded at the start, the hidden containers of M36B, the tool button that opens its tab,
## "Vai" (go_to_area_requested) sent to `combat.start` with the refusal worded. No exact texts. The last test follows the whole
## chain: a real "Vai" button of the ResourceTable -> GatherBody -> `combat.start`.

const SCENE: PackedScene = preload("res://ui/pages/skill/skill_page.tscn")
const SKILL: StringName = &"quarrying"

var _s: GameSession = null
var _page: SkillPage = null
var _body: GatherBody = null


func before_each() -> void:
	_s = TestFactory.session(77, TestFactory.real_data())
	TestFactory.learn_discipline(_s, SKILL)
	_page = SCENE.instantiate() as SkillPage
	_page.page_id = StringName(PageHost.ROUTE_SKILL + PageHost.ROUTE_SEPARATOR + SKILL)
	add_child(_page)
	_page.bind(_s)
	_body = _page.find_child("GatherBody", true, false) as GatherBody


func after_each() -> void:
	if is_instance_valid(_page):
		_page.free()
	if is_instance_valid(_s):
		_s.free()
	await wait_physics_frames(1)


func test_three_tabs_open_on_the_overview() -> void:
	assert_not_null(_body)
	assert_eq((_body.find_child("GatherTabs", true, false) as TabBar).tab_count, 3)
	assert_eq(_body.current_tab(), GatherBody.TAB_OVERVIEW)
	assert_true((_body.find_child("TabOverview", true, false) as Control).visible)
	assert_false((_body.find_child("ResourceTable", true, false) as Control).visible)
	assert_false((_body.find_child("TabTool", true, false) as Control).visible)
	for section: String in ["StatsSection", "ProgressSection", "NeedsSection"]:
		var node: Control = _body.find_child(section, true, false) as Control
		assert_not_null(node, section)
		assert_false(node.visible, section)
		assert_eq(node.get_child_count(), 0, section)
	assert_not_null(_body.find_child("ZoneNowSection", true, false))


func test_overview_button_opens_the_tool_tab_and_heads_start_folded() -> void:
	(_body.find_child("OpenToolButton", true, false) as Button).pressed.emit()
	assert_eq(_body.current_tab(), GatherBody.TAB_TOOL)
	assert_true((_body.find_child("TabTool", true, false) as Control).visible)
	var fold: FoldableSection = _body.find_child("HeadsFold", true, false) as FoldableSection
	assert_true(fold.is_collapsed(), "Teste is closed at the start")
	fold.toggle()
	assert_false(fold.is_collapsed())
	assert_true((fold.find_child("FoldBody", true, false) as Control).visible)


func test_go_to_area_starts_the_combat_or_words_the_refusal() -> void:
	var message: Label = _page.get_node("%MessageLabel") as Label
	var refused: bool = false
	for area: AreaDef in _s.data.areas():
		_body.go_to_area_requested.emit(area.id)
		if not _s.combat.is_active():
			refused = true
			assert_true(message.visible, "refusal shown for %s" % area.id)
			assert_false(message.text.is_empty())
			break
		assert_eq(_s.combat.area_id(), area.id)
		assert_false(message.visible)
		_s.combat.stop()
	assert_true(refused or _s.data.areas().is_empty(), "at character level 1 some area is locked")
	TestFactory.set_character_level(_s, 99)
	var first: AreaDef = _s.data.areas()[0]
	_body.go_to_area_requested.emit(first.id)
	assert_true(_s.combat.is_active())
	assert_eq(_s.combat.area_id(), first.id)
	assert_false(message.visible)


## The whole chain of "Vai": button of an open row -> `ResourceTable.zone_requested` -> `GatherBody.go_to_area_requested` -> the page.
func test_vai_button_of_a_row_reaches_combat_start() -> void:
	var message: Label = _page.get_node("%MessageLabel") as Label
	var table: ResourceTable = _body.find_child("ResourceTable", true, false) as ResourceTable
	_body.show_tab(GatherBody.TAB_RESOURCES)
	var id: StringName = table.row_ids()[0]
	var row: ResourceRow = null
	for node: Node in table.find_children("*", "ResourceRow", true, false):
		if (node as ResourceRow).action_id() == id:
			row = node as ResourceRow
	assert_not_null(row)
	row.set_open(true)
	var area: StringName = StringName(_s.data.zones_of_action(id)[0]["area"])
	var go: Button = table.find_child("GoButton_%s_%s" % [id, area], true, false) as Button
	assert_not_null(go)
	assert_false(go.disabled)
	go.pressed.emit()
	if _s.combat.is_active():
		assert_eq(_s.combat.area_id(), area)
		_s.combat.stop()
	else:
		assert_true(message.visible, "locked area: the refusal is shown")
	TestFactory.set_character_level(_s, 99)
	row.set_open(true)
	go = table.find_child("GoButton_%s_%s" % [id, area], true, false) as Button
	go.pressed.emit()
	assert_true(_s.combat.is_active())
	assert_eq(_s.combat.area_id(), area)
	assert_false(message.visible)
