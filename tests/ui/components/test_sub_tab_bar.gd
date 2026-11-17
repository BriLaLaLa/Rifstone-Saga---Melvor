extends GutTest
## SubTabBar (M14-06) and the sub-tabs of the Forging and Engraver pages (GDD §29), real data.

const SCENE: PackedScene = preload("res://ui/pages/skill/skill_page.tscn")

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


func _open(skill: StringName) -> void:
	_page = SCENE.instantiate() as SkillPage
	_page.page_id = StringName("skill:%s" % skill)
	add_child(_page)
	_page.bind(_session)


func _bar() -> SubTabBar:
	return _page.find_child("SubTabs", true, false) as SubTabBar


func _shown(node_name: String) -> bool:
	return (_page.find_child(node_name, true, false) as Control).is_visible_in_tree()


func test_bar_selects_the_first_tab_quietly_and_emits_on_select() -> void:
	var bar: SubTabBar = SubTabBar.new()
	add_child_autofree(bar)
	var seen: Array[StringName] = []
	bar.tab_selected.connect(func(id: StringName) -> void: seen.append(id))
	bar.setup([{"id": &"a", "label": "A"}, {"id": &"b", "label": "B"}])
	assert_eq(bar.current(), &"a")
	assert_eq(seen.size(), 0)
	bar.select(&"b")
	assert_eq(bar.current(), &"b")
	assert_eq(seen, [&"b"] as Array[StringName])
	bar.select(&"zzz")
	assert_eq(bar.current(), &"b")


func test_select_releases_the_previous_tab_in_the_group() -> void:
	var bar: SubTabBar = SubTabBar.new()
	add_child_autofree(bar)
	bar.setup([{"id": &"a", "label": "A"}, {"id": &"b", "label": "B"}])
	bar.select(&"b")
	assert_false((bar.get_node("Tab_a") as Button).button_pressed)
	assert_true((bar.get_node("Tab_b") as Button).button_pressed)


func test_every_engraver_action_belongs_to_exactly_one_tab() -> void:
	for action: ActionDef in TestFactory.real_data().actions_for_skill(&"riftbinding"):
		assert_ne(EngraverSections.tab_of(EngraverSections.section_of(action)), &"", String(action.id))


func test_gathering_pages_have_no_sub_tabs() -> void:
	_open(&"forestry")
	assert_null(_bar())
