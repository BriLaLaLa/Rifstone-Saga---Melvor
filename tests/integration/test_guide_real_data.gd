extends GutTest
## Guide on the real data (M11-06, docs/01_GDD.md §27 Accettazione): one page per entity, no broken link, no unresolved
## placeholder, no hand-written number, every table source builds, every "?" opens an existing page, the Guide keeps no
## game state. Complements tests/core/guide (fixtures), tests/data/test_guide_texts.gd and tests/ui/{guide,help}.

const TABLE_PREFIXES: PackedStringArray = ["actions:", "area_monsters:", "monster_drops:", "mastery_milestones:"]
const PAGE_KINDS: PackedStringArray = ["page", "item", "monster", "area", "skill", "stat", "trait", "ability"]

var _session: GameSession
var _data: GameData
var _nav: GuideNav


func before_each() -> void:
	_session = TestFactory.session(1234, TestFactory.real_data())
	_data = _session.data
	_nav = GuideNav.new(_data)


func after_each() -> void:
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func test_every_entity_has_a_guide_entry_with_a_title() -> void:
	var pages: Array[StringName] = GuideTables.page_ids(_data)
	var kinds: Dictionary[String, int] = {}
	for id: StringName in pages:
		assert_true(_nav.has_entry(id), "nav has %s" % id)
		assert_false(_nav.title_of(id).is_empty(), "title of %s" % id)
		var kind: String = String(id).get_slice(":", 0)
		kinds[kind] = kinds.get(kind, 0) + 1
	for kind: String in PAGE_KINDS:
		assert_true(kinds.has(kind), "kind %s present" % kind)
	assert_eq(kinds["item"], _data.items().size(), "one page per item")
	assert_eq(kinds["stat"], _data.stats.ids().size(), "one page per stat")
	assert_eq(kinds["skill"], _data.skills().size(), "one page per skill (mestiere)")


func test_hand_written_texts_have_no_broken_links_or_unresolved_placeholders() -> void:
	var checked: int = 0
	for page: GuidePageDef in _data.guide_pages():
		for block: Dictionary in page.blocks:
			if block["type"] != "text":
				continue
			var raw: String = block["text"] as String
			checked += 1
			var errors: PackedStringArray = GuideText.validate(raw, _data, page.allow_digits)
			assert_eq(errors.size(), 0, "%s: %s" % [page.id, str(errors)])
			for link: Dictionary in GuideText.parse_links(raw):
				var target: StringName = GuideIndex.entry(StringName(link["kind"]), StringName(link["id"]))
				assert_true(_nav.has_entry(target), "%s: link to %s" % [page.id, target])
			var resolved: String = GuideText.resolve(raw, _data)
			assert_false(resolved.contains("{") or resolved.contains("}"), "%s: unresolved in '%s'" % [page.id, resolved])
	assert_gt(checked, 20, "texts were actually checked")


func test_every_table_block_builds_with_rows() -> void:
	var fixed: PackedStringArray = GuideTables.ids()
	for page: GuidePageDef in _data.guide_pages():
		for block: Dictionary in page.blocks:
			if block["type"] != "table":
				continue
			var source: String = block["source"] as String
			var known: bool = fixed.has(source)
			for prefix: String in TABLE_PREFIXES:
				known = known or source.begins_with(prefix)
			assert_true(known, "%s: table source %s is known" % [page.id, source])
			assert_gt(GuideTables.build(source, _data).size(), 0, "%s: table %s has rows" % [page.id, source])


func test_every_item_has_source_and_use_or_a_declared_exception() -> void:
	var index: GuideIndex = GuideIndex.new(_data)
	# M14: pieces and blueprints get their sources from the drop pool and the legendaries (F-121, F-120, F-124).
	assert_eq(index.items_without_source().size(), 0, "no item without source: %s" % str(index.items_without_source()))
	assert_eq(index.items_without_use().size(), 0, "no item without use: %s" % str(index.items_without_use()))


func test_ref_targets_point_to_existing_pages() -> void:
	var index: GuideIndex = GuideIndex.new(_data)
	for item: ItemDef in _data.items():
		for ref: GuideRef in index.sources_of(item.id) + index.uses_of(item.id):
			if ref.target != &"":
				assert_true(_nav.has_entry(ref.target), "%s: target %s" % [item.id, ref.target])


func test_every_stat_page_text_comes_from_stats_json() -> void:
	for stat_id: StringName in _data.stats.ids():
		var info: Dictionary = _data.stats.info(stat_id)
		assert_false(String(info.get("description", "")).is_empty(), "stat %s has a description" % stat_id)
		assert_eq(_nav.title_of(GuideIndex.entry(&"stat", stat_id)), String(info.get("name", "")), "title of %s" % stat_id)


func test_every_game_route_of_the_host_has_a_help_page() -> void:
	var host: PageHost = PageHost.new()
	add_child_autofree(host)
	host.setup(_session)
	var routes: Array[StringName] = []
	for route: StringName in PageHost.ROUTES:
		if route not in [PageHost.ROUTE_GUIDE, PageHost.ROUTE_HELP, PageHost.ROUTE_SKILL]:
			routes.append(route)
	for skill: SkillDef in _data.skills():
		if host.has_page(StringName("skill:%s" % skill.id)):
			routes.append(StringName("skill:%s" % skill.id))
	assert_gt(routes.size(), 6)
	for route: StringName in routes:
		var entry: StringName = HelpButton.entry_for(_data, route)
		assert_ne(entry, &"", "route %s has a Guide page" % route)
		assert_true(_nav.has_entry(entry), "route %s opens an existing page" % route)


func test_flow_open_search_follow_link_and_go_back() -> void:
	var host: PageHost = PageHost.new()
	add_child_autofree(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.setup(_session)
	host.show_page(&"guide")
	await wait_physics_frames(1)
	var guide: GuidePage = host.find_child("Page", false, false) as GuidePage
	assert_not_null(guide)
	var item: ItemDef = _data.items()[0]
	var found: Array[StringName] = guide.search(item.name)
	assert_true(found.has(GuideIndex.entry(&"item", item.id)), "search finds an item by its name")
	var start: StringName = guide.current_entry()
	guide.open_entry(found[0])
	assert_eq(guide.current_entry(), found[0])
	guide.open_entry(GuideIndex.entry(&"stat", _data.stats.ids()[0]))
	assert_true(guide.go_back())
	assert_eq(guide.current_entry(), found[0])
	assert_true(guide.go_back())
	assert_eq(guide.current_entry(), start)
	assert_false(guide.go_back(), "history exhausted")


func test_guide_keeps_no_state_in_the_save() -> void:
	var host: PageHost = PageHost.new()
	add_child_autofree(host)
	host.setup(_session)
	host.show_page(&"guide")
	await wait_physics_frames(1)
	var save: Dictionary = _session.to_save(0)
	var modules: Dictionary = save[GameSession.MODULES_KEY]
	for key: Variant in modules:
		assert_false(String(key).contains("guide"), "no guide module in the save (%s)" % key)
	assert_false(JSON.stringify(save).to_lower().contains("guide"), "no trace of the Guide in the save")
