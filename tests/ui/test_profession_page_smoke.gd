extends GutTest
## Smoke test of the production page (recipe list, detail, queue strip) with a TestFactory session (never a real slot):
## the fixture `test_craft` (craft_plank from 2 test_log) and the real Forging / Engraver data for the categories.

const SCENE: PackedScene = preload("res://ui/pages/skill/skill_page.tscn")
const CRAFT: StringName = &"test_craft"
const PLANK: StringName = &"craft_plank"

var _session: GameSession
var _page: SkillPage
var _host: Control


func before_each() -> void:
	_session = TestFactory.session()


func after_each() -> void:
	if is_instance_valid(_page):
		_page.free()
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func test_list_shows_the_recipe_and_the_detail_shows_reagents_and_product() -> void:
	_open(CRAFT)
	var row: RecipeRow = _page.find_child("Row_%s" % PLANK, true, false) as RecipeRow
	assert_not_null(row, "one row per recipe")
	var view: ProfessionView = _page.find_child("ProfessionView", true, false) as ProfessionView
	assert_eq(view.picked(), PLANK, "the first recipe is picked")
	var text: Label = _page.find_child("IngredientTestLog", true, false).find_child("Text", true, false) as Label
	assert_eq(text.text, ProfessionTexts.REAGENT_TEXT % [_session.data.item(&"test_log").name, "0", "2"])
	assert_eq(text.get_theme_color("font_color"), UiStyle.BAD, "short reagent in red")
	_session.bank.add(&"test_log", 5)
	assert_eq(text.text, ProfessionTexts.REAGENT_TEXT % [_session.data.item(&"test_log").name, "5", "2"], "redrawn on bank_changed")
	assert_ne(text.get_theme_color("font_color"), UiStyle.BAD)
	assert_not_null(_page.find_child("Products", true, false), "the product box")
	assert_eq(RecipeList.craftable_count(_session.data.action(PLANK), _session), 2, "5 owned / 2 needed")


func test_queue_button_sends_the_command_and_the_strip_cancels_it() -> void:
	_session.bank.add(&"test_log", 20)
	_open(CRAFT)
	(_page.find_child("QuantitySpin", true, false) as SpinBox).value = 3.0
	(_page.find_child("EnqueueButton", true, false) as Button).pressed.emit()
	assert_eq(_session.actions.jobs().size(), 1)
	assert_eq(_session.actions.jobs()[0]["remaining"], 3)
	var panel: ProductionQueuePanel = _page.find_child("ProductionQueue", true, false) as ProductionQueuePanel
	assert_not_null(panel.find_child("QueueRow_0", true, false))
	(panel.find_child("CancelButton", true, false) as Button).pressed.emit()
	assert_eq(_session.actions.jobs().size(), 0)


func test_a_refused_command_shows_its_reason() -> void:
	_open(CRAFT)
	for _i: int in _session.actions.capacity() + 1:
		_session.actions.enqueue(CRAFT, PLANK, 1, false)
	(_page.find_child("EnqueueButton", true, false) as Button).pressed.emit()
	assert_true((_page.get_node("%MessageLabel") as Label).visible, "the reason, in Italian")


func test_search_and_craftable_filter_hide_rows() -> void:
	_open(CRAFT)
	var row: RecipeRow = _page.find_child("Row_%s" % PLANK, true, false) as RecipeRow
	(_page.find_child("Search", true, false) as LineEdit).text = "zzz"
	(_page.find_child("Search", true, false) as LineEdit).text_changed.emit("zzz")
	assert_false(row.visible)
	(_page.find_child("Search", true, false) as LineEdit).text = ""
	(_page.find_child("Search", true, false) as LineEdit).text_changed.emit("")
	assert_true(row.visible)
	(_page.find_child("OnlyCraftable", true, false) as CheckBox).button_pressed = true
	assert_false(row.visible, "no ingredients: not craftable")


func test_forging_and_engraver_categories_and_special_pages() -> void:
	_session.free()
	_session = TestFactory.session(1234, TestFactory.real_data())
	_open(&"forging")
	assert_not_null(_page.find_child("Section_ingots", true, false))
	assert_not_null(_page.find_child("Section_plates", true, false))
	var blueprints: Control = _page.find_child("BlueprintSection", true, false) as Control
	var bench: Control = _page.find_child("ForgeBench", true, false) as Control
	assert_false(blueprints.visible)
	(_page.find_child("Page_%s" % ForgeTabs.TAB_BLUEPRINTS, true, false) as Button).pressed.emit()
	assert_true(blueprints.is_visible_in_tree())
	assert_false(_page.find_child("RecipeDetail", true, false).visible)
	(_page.find_child("Page_%s" % ForgeTabs.TAB_BENCH, true, false) as Button).pressed.emit()
	assert_true(bench.is_visible_in_tree())
	assert_false(blueprints.visible)
	_page.free()
	_open(&"riftbinding")
	for tab: Dictionary in EngraverSections.TABS:
		assert_not_null(_page.find_child("Section_%s" % tab["id"], true, false), String(tab["id"]))
	assert_null(_page.find_child("Row_%s" % BlueprintCraft.ACTION, true, false), "the blueprint craft is no recipe row")


func test_forging_shows_difficulty_colors_progress_origin_and_unlocks() -> void:
	_session.free()
	_session = TestFactory.session(1234, TestFactory.real_data())
	_open(&"forging")
	var row: RecipeRow = _page.find_child("Row_smelt_emberbronze", true, false) as RecipeRow
	assert_not_null(row, "a coloured recipe row")
	assert_not_null(_page.find_child("ProgressLabel", true, false), "the progress line")
	assert_not_null(_page.find_child("OriginLabel", true, false), "the origin line")
	assert_not_null(_page.find_child("ProfessionUnlocks", true, false), "the next unlocks box")
	(_page.find_child("Page_%s" % ForgeTabs.TAB_BENCH, true, false) as Button).pressed.emit()
	assert_false((_page.find_child("ProfessionUnlocks", true, false) as Control).visible, "hidden on the special pages")


func test_unbind_disconnects_and_layout_fits_both_resolutions() -> void:
	var before: int = _session.events.bank_changed.get_connections().size()
	_open(CRAFT)
	assert_gt(_session.events.bank_changed.get_connections().size(), before)
	for size: Vector2 in [Vector2(1600, 900), Vector2(1280, 720)]:
		_host.size = size
		await wait_process_frames(2)
		assert_lte((_page.find_child("ProfessionView", true, false) as Control).get_global_rect().end.x,
				_page.get_global_rect().end.x + 0.5)
	_page.unbind()
	assert_eq(_session.events.bank_changed.get_connections().size(), before)


func _open(skill: StringName) -> void:
	_page = SCENE.instantiate() as SkillPage
	_page.page_id = StringName("skill:%s" % skill)
	_host = autofree(Control.new())
	_host.size = Vector2(1600, 900)
	add_child(_host)
	_host.add_child(_page)
	_page.bind(_session)
