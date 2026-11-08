extends GutTest
## GuidePage (M11-04) with a TestFactory session on the real data: opening, one page per entity, search, links,
## history, unknown page, minimum layout sizes and the PageHost routes.

const SCENE: PackedScene = preload("res://ui/pages/guide/guide_page.tscn")
const FIRST_PAGE := &"page:guide_first_steps"

var _session: GameSession
var _page: GuidePage
var _nav: GuideNav


func before_each() -> void:
	_session = TestFactory.session(1234, TestFactory.real_data())
	_nav = GuideNav.new(_session.data)


func after_each() -> void:
	if is_instance_valid(_page):
		_page.free()
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func test_opens_on_first_steps_with_index_and_content() -> void:
	_open()
	assert_eq(_page.current_entry(), FIRST_PAGE)
	assert_eq(_body_title(), "Primi passi")
	assert_gt((_tree().get_root().get_child_count()), 0, "index groups")
	assert_true(_back().disabled)


func test_every_entity_has_a_page_that_opens() -> void:
	_open()
	var kinds: Dictionary[String, bool] = {}
	for id: StringName in GuideTables.page_ids(_session.data):
		assert_true(_nav.has_entry(id), "entry %s" % id)
		_page.open_entry(id)
		assert_eq(_page.current_entry(), id)
		assert_eq(_body_title(), _nav.title_of(id))
		kinds[String(id).get_slice(":", 0)] = true
	for kind: String in ["page", "item", "monster", "area", "skill", "stat", "trait", "ability"]:
		assert_true(kinds.has(kind), "kind %s" % kind)


func test_item_page_shows_sources_and_uses() -> void:
	_open()
	_page.open_entry(GuideIndex.entry(&"item", &"redbirch_log"))
	var headings: PackedStringArray = []
	for node: Node in _page.find_children("*", "Label", true, false):
		headings.append((node as Label).text)
	assert_true(headings.has("Si ottiene da"))
	assert_true(headings.has("Serve a"))


func test_search_by_name_ignores_case_and_accents() -> void:
	_open()
	assert_eq(_page.search("").size(), _nav.ids().size(), "empty query = whole index")
	var found: Array[StringName] = _page.search("ABILITA")
	assert_true(found.has(&"page:guide_abilities"))
	for id: StringName in found:
		assert_true(GuideNav.normalize(_nav.title_of(id)).contains("abilita"))
	assert_true(_page.search("zzzz-nessuno").is_empty())
	_search_edit().text = "abilita"
	_search_edit().text_changed.emit("abilita")
	assert_true(_results().visible)
	assert_false(_tree().visible)
	assert_eq(_results().item_count, found.size())
	_results().item_selected.emit(0)
	assert_eq(_page.current_entry(), found[0])
	_search_edit().text = ""
	_search_edit().text_changed.emit("")
	assert_true(_tree().visible)


func test_clicking_a_link_opens_its_page_and_back_returns() -> void:
	_open()
	var link: RichTextLabel = null
	var target: StringName = &""
	var pattern: RegEx = RegEx.create_from_string("\\[url=([^\\]]+)\\]")
	for node: Node in _page.find_children("*", "RichTextLabel", true, false):
		var hit: RegExMatch = pattern.search((node as RichTextLabel).text)
		if hit != null:
			link = node as RichTextLabel
			target = StringName(hit.get_string(1))
			break
	assert_not_null(link, "a page with a link")
	link.meta_clicked.emit(String(target))
	assert_eq(_page.current_entry(), target)
	assert_false(_back().disabled)
	assert_true(_page.go_back())
	assert_eq(_page.current_entry(), FIRST_PAGE)


func test_go_back_walks_the_history_and_false_when_empty() -> void:
	_open()
	assert_false(_page.go_back(), "empty history")
	_page.open_entry(&"page:guide_death")
	_page.open_entry(GuideIndex.entry(&"item", &"redbirch_log"))
	_back().pressed.emit()
	assert_eq(_page.current_entry(), &"page:guide_death")
	assert_true(_page.go_back())
	assert_eq(_page.current_entry(), FIRST_PAGE)
	assert_false(_page.go_back())
	assert_true(_back().disabled)


func test_unknown_page_reports_and_stays() -> void:
	_open()
	_page.open_entry(&"item:non_esiste")
	assert_push_error("[ERROR] guide: unknown page 'item:non_esiste'")
	assert_eq(_page.current_entry(), FIRST_PAGE)
	assert_ne(_message().text, "")
	_page.open_entry(&"page:guide_death")
	assert_eq(_message().text, "")


func test_route_argument_opens_the_entry_and_the_host_accepts_it() -> void:
	_page = SCENE.instantiate() as GuidePage
	_page.page_id = &"guide:area:redrock_plains"
	add_child(_page)
	_page.bind(_session)
	assert_eq(_page.current_entry(), &"area:redrock_plains")
	var host: PageHost = PageHost.new()
	add_child_autofree(host)
	host.setup(_session)
	assert_true(host.has_page(&"guide"))
	assert_true(host.has_page(&"help:item:redbirch_log"))
	host.show_page(&"guide:item:redbirch_log")
	assert_eq(host.current_page_id(), &"guide:item:redbirch_log")
	host.show_page(&"help:page:guide_death")
	assert_eq(host.current_page_id(), &"guide:item:redbirch_log", "live Guide navigates itself")


func test_layout_fits_the_minimum_window() -> void:
	for size: Vector2 in [Vector2(1280, 720), Vector2(1600, 900)]:
		_open()
		_page.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_page.size = size - Vector2(UiStyle.SIDEBAR_WIDTH, UiStyle.TOP_BAR_HEIGHT)
		_page.open_entry(GuideIndex.entry(&"skill", &"forestry"))
		await wait_physics_frames(2)
		var minimum: Vector2 = _page.get_combined_minimum_size()
		assert_lte(minimum.x, _page.size.x, "min width at %s" % size)
		assert_lte(minimum.y, _page.size.y, "min height at %s" % size)
		_page.free()
		_page = null


func _open() -> void:
	_page = SCENE.instantiate() as GuidePage
	_page.page_id = &"guide"
	add_child(_page)
	_page.bind(_session)


func _body_title() -> String:
	return (_page.find_child("PageTitle", true, false) as Label).text


func _label(path: String) -> Label:
	return _page.get_node(path) as Label


func _tree() -> Tree:
	return _page.get_node("%IndexTree") as Tree


func _back() -> Button:
	return _page.get_node("%BackButton") as Button


func _message() -> Label:
	return _page.get_node("%MessageLabel") as Label


func _search_edit() -> LineEdit:
	return _page.get_node("%SearchEdit") as LineEdit


func _results() -> ItemList:
	return _page.get_node("%ResultsList") as ItemList
