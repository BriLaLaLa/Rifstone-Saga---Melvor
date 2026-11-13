extends GutTest
## Smoke test of the Forging page sub-tabs (M18-02) with a TestFactory session on the M10 fixtures (never a real slot):
## the tabs follow the production chain, each tab has a caption and shows only its own section.

const BlueprintData := preload("res://tests/systems/actions/blueprint_data.gd")
const SCENE: PackedScene = preload("res://ui/pages/skill/skill_page.tscn")

var _session: GameSession
var _page: SkillPage
var _host: Control


func before_each() -> void:
	_session = TestFactory.session(1234, BlueprintData.data())
	_page = SCENE.instantiate() as SkillPage
	_page.page_id = StringName(PageHost.ROUTE_SKILL + PageHost.ROUTE_SEPARATOR + "forging")
	_host = autofree(Control.new())
	_host.size = Vector2(1600, 900)
	add_child(_host)
	_host.add_child(_page)
	_page.bind(_session)


func after_each() -> void:
	if is_instance_valid(_page):
		_page.free()
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func test_tabs_follow_the_production_chain_and_show_one_section() -> void:
	var ids: Array[StringName] = []
	for tab: Dictionary in ForgeTabs.TABS:
		ids.append(tab["id"])
	assert_eq(ids, [ForgeTabs.TAB_INGOTS, ForgeTabs.TAB_PLATES, ForgeTabs.TAB_BLUEPRINTS, ForgeTabs.TAB_BENCH])
	var bar: SubTabBar = _page.find_child("SubTabs", true, false) as SubTabBar
	var caption: Label = _page.find_child("TabCaption", true, false) as Label
	var blueprints: Control = _page.get_node("%Extras").get_child(0) as Control
	var bench: Control = _page.get_node("%Extras").get_child(1) as Control
	assert_not_null(bar)
	assert_not_null(caption)
	assert_eq(caption.text, ForgeTabs.CAPTIONS[ForgeTabs.TAB_INGOTS])
	assert_false(blueprints.visible)
	assert_false(bench.visible)
	(bar.find_child("Tab_%s" % ForgeTabs.TAB_BLUEPRINTS, true, false) as Button).pressed.emit()
	assert_true(blueprints.visible)
	assert_false(bench.visible)
	assert_eq(caption.text, ForgeTabs.CAPTIONS[ForgeTabs.TAB_BLUEPRINTS])
	(bar.find_child("Tab_%s" % ForgeTabs.TAB_BENCH, true, false) as Button).pressed.emit()
	assert_true(bench.visible)
	assert_false(blueprints.visible)
