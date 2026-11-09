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


func test_engraver_has_the_four_tabs_and_shows_one_at_a_time() -> void:
	_open(&"riftbinding")
	var bar: SubTabBar = _bar()
	assert_eq(bar.ids(), [&"slabs", &"merge", &"crystals", &"runes"] as Array[StringName])
	assert_eq([bar.label_of(&"slabs"), bar.label_of(&"merge"), bar.label_of(&"crystals"), bar.label_of(&"runes")],
			["Lastre", "Fondere", "Cristalli", "Rune"])
	assert_true(_shown("MakeRuneSlab"))
	assert_false(_shown("CrystallizeSpark"))
	bar.select(&"runes")
	assert_true(_shown("EngraveSwiftHands"))
	assert_true(_shown("UpgradeSwiftHands2"))
	assert_false(_shown("MakeRuneSlab"))
	bar.select(&"crystals")
	assert_true(_shown("CrystallizeSpark"))
	assert_false(_shown("EngraveSwiftHands"))


func test_every_engraver_action_belongs_to_exactly_one_tab() -> void:
	for action: ActionDef in TestFactory.real_data().actions_for_skill(&"riftbinding"):
		assert_ne(EngraverSections.tab_of(EngraverSections.section_of(action)), &"", String(action.id))


func test_forging_has_the_four_tabs() -> void:
	_open(&"forging")
	var bar: SubTabBar = _bar()
	assert_eq([bar.label_of(&"ingots"), bar.label_of(&"plates"), bar.label_of(&"blueprints"), bar.label_of(&"bench")],
			["Lingotti", "Piastre", "Progetti", "Banco del fabbro"])
	assert_true(_shown("SmeltEmberbronze"))
	assert_false(_shown("ForgeEmberbronzePlate"))
	bar.select(&"plates")
	assert_false(_shown("SmeltEmberbronze"))
	assert_true(_shown("ForgeEmberbronzePlate"))
	assert_false(_page._blueprints.is_visible_in_tree())
	assert_false(_page._bench.is_visible_in_tree())
	bar.select(&"blueprints")
	assert_true(_page._blueprints.is_visible_in_tree())
	assert_false(_page._bench.is_visible_in_tree())
	bar.select(&"bench")
	assert_true(_page._bench.is_visible_in_tree())
	assert_false(_page._blueprints.is_visible_in_tree())


func test_gathering_pages_have_no_sub_tabs() -> void:
	_open(&"forestry")
	assert_null(_bar())
