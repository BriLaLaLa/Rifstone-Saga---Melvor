extends GutTest
## GuidePageDef, GameData.guide_pages/guide_page/guide_exceptions and the rules of DataValidatorGuide
## (`data/guide/*.json`, docs/04_DATA_SCHEMA.md §19; M11-02). Helpers from test_data_validator.gd.

const V: GDScript = preload("res://tests/core/data/test_data_validator.gd")
const GUIDE_DIR: String = "res://tests/fixtures/data/guide"
const PAGES: String = "first_steps.json"
const EXCEPTIONS: String = "exceptions.json"


func _raw() -> Dictionary:
	var raw: Dictionary = V.fixture_raw()
	var errors: PackedStringArray = []
	var files: Dictionary = {}
	for path: String in JsonLoader.list_json_files(GUIDE_DIR, errors):
		files[path] = JsonLoader.load_file(path, errors)
	raw["guide"] = files
	return raw


func _page(raw: Dictionary, index: int) -> Dictionary:
	return V.entry_of(raw, "guide", PAGES, "pages", index)


func _block(raw: Dictionary, page: int, block: int) -> Dictionary:
	return (_page(raw, page)["blocks"] as Array)[block] as Dictionary


func _expect(raw: Dictionary, fragments: Array[String]) -> void:
	var errors: PackedStringArray = V.validate(raw)
	for message: String in errors:
		var matched: bool = true
		for fragment: String in fragments:
			matched = matched and message.contains(fragment)
		if matched:
			assert_true(true)
			return
	fail_test("no error with %s in %s" % [fragments, errors])


func test_fixture_guide_is_valid_and_no_folder_is_valid() -> void:
	assert_eq(V.validate(_raw()), PackedStringArray())
	assert_eq(V.validate(V.fixture_raw()), PackedStringArray(), "no raw['guide'] at all")
	var raw: Dictionary = V.fixture_raw()
	raw["guide"] = {}
	assert_eq(V.validate(raw), PackedStringArray(), "an empty guide folder")
	assert_true(TestFactory.real_data().is_valid())


func test_missing_guide_folder_is_not_an_error() -> void:
	var errors: PackedStringArray = []
	assert_eq(DataValidatorGuide.list_files("res://tests/fixtures/data/m10", errors), PackedStringArray())
	assert_eq(errors, PackedStringArray())


func test_game_data_loads_pages_ordered_by_section_order_id() -> void:
	var data: GameData = TestFactory.fixture_data()
	var ids: Array[StringName] = []
	for page: GuidePageDef in data.guide_pages():
		ids.append(page.id)
	assert_eq(ids, [&"test_guide_second", &"test_guide_start", &"test_guide_offline"] as Array[StringName])


func test_game_data_page_fields() -> void:
	var page: GuidePageDef = TestFactory.fixture_data().guide_page(&"test_guide_start")
	assert_eq([page.section, page.title, page.order], [&"first_steps", "Pagina di prova", 2])
	assert_eq(page.help_for, PackedStringArray(["combat", "skill:test_gather"]))
	assert_false(page.allow_digits)
	assert_eq(page.blocks.size(), 6)
	assert_eq(page.blocks[0], {"type": "heading", "text": "Il limite offline"})
	assert_true(TestFactory.fixture_data().guide_page(&"test_guide_second").allow_digits)


func test_unknown_page_is_null() -> void:
	assert_null(TestFactory.fixture_data().guide_page(&"nope"))
	assert_push_error("unknown guide page 'nope'")


func test_exceptions_default_and_loaded() -> void:
	assert_eq(TestFactory.fixture_data().guide_exceptions(), {"no_source": [], "no_use": []})
	var real: Dictionary = TestFactory.real_data().guide_exceptions()
	assert_eq(real.keys(), ["no_source", "no_use"])


func test_from_dict_missing_field_is_null() -> void:
	assert_null(GuidePageDef.from_dict({"id": "x", "section": "loot", "title": "t", "order": 1}))
	assert_push_error("missing field 'blocks'")


func test_optional_fields_default() -> void:
	var page: GuidePageDef = GuidePageDef.from_dict({"id": "x", "section": "loot", "title": "t", "order": 1,
			"blocks": [{"type": "text", "text": "a"}]})
	assert_eq([page.help_for, page.allow_digits], [PackedStringArray(), false])


# --- validator rules: one test per rule ---------------------------------------------------------------------------

func test_duplicate_page_id() -> void:
	var raw: Dictionary = _raw()
	_page(raw, 1)["id"] = "test_guide_start"
	_expect(raw, [PAGES, "duplicate guide page 'test_guide_start'"])


func test_bad_id_format() -> void:
	var raw: Dictionary = _raw()
	_page(raw, 0)["id"] = "Bad Id"
	_expect(raw, [PAGES, "does not match"])


func test_unknown_section() -> void:
	var raw: Dictionary = _raw()
	_page(raw, 0)["section"] = "mistery"
	_expect(raw, [PAGES, "test_guide_start", "section", "mistery"])


func test_negative_order() -> void:
	var raw: Dictionary = _raw()
	_page(raw, 0)["order"] = -1
	_expect(raw, [PAGES, "'order'"])


func test_unknown_page_field() -> void:
	var raw: Dictionary = _raw()
	_page(raw, 0)["color"] = "red"
	_expect(raw, [PAGES, "unknown field 'color'"])


func test_unknown_block_type() -> void:
	var raw: Dictionary = _raw()
	_block(raw, 0, 0)["type"] = "video"
	_expect(raw, [PAGES, "blocks[0].type", "video"])


func test_unknown_placeholder_in_text() -> void:
	var raw: Dictionary = _raw()
	_block(raw, 0, 1)["text"] = "Valore {color:red}."
	_expect(raw, [PAGES, "blocks[1].text", "unknown placeholder"])


func test_unknown_format() -> void:
	var raw: Dictionary = _raw()
	_block(raw, 0, 1)["text"] = "{balance:offline.cap_ms|giorni}"
	_expect(raw, [PAGES, "blocks[1].text", "malformed"])


func test_unknown_balance_path() -> void:
	var raw: Dictionary = _raw()
	_block(raw, 0, 1)["text"] = "{balance:offline.nothing|int}"
	_expect(raw, [PAGES, "unknown balance path 'offline.nothing'"])


func test_unknown_stat() -> void:
	var raw: Dictionary = _raw()
	_block(raw, 0, 2)["text"] = "{stat:nope}"
	_expect(raw, [PAGES, "unknown stat 'nope'"])


func test_broken_inline_link() -> void:
	var raw: Dictionary = _raw()
	_block(raw, 0, 3)["text"] = "{link:item:nothing|x}"
	_expect(raw, [PAGES, "broken link", "item 'nothing'"])


func test_unknown_link_kind() -> void:
	var raw: Dictionary = _raw()
	_block(raw, 0, 3)["text"] = "{link:planet:x|x}"
	_expect(raw, [PAGES, "unknown link kind"])


func test_broken_links_block_target() -> void:
	var raw: Dictionary = _raw()
	(_block(raw, 0, 5)["targets"] as Array)[1] = "monster:nothing"
	_expect(raw, [PAGES, "blocks[5].targets", "broken link"])


func test_malformed_links_block_target() -> void:
	var raw: Dictionary = _raw()
	(_block(raw, 0, 5)["targets"] as Array)[0] = "test_twig"
	_expect(raw, [PAGES, "blocks[5].targets", "<kind>:<id>"])


func test_broken_page_link() -> void:
	var raw: Dictionary = _raw()
	(_block(raw, 0, 5)["targets"] as Array)[2] = "page:nothing"
	_expect(raw, [PAGES, "broken link", "page 'nothing'"])


func test_unknown_help_for_route() -> void:
	var raw: Dictionary = _raw()
	(_page(raw, 0)["help_for"] as Array)[0] = "nowhere"
	_expect(raw, [PAGES, "help_for", "unknown route 'nowhere'"])


func test_unknown_help_for_skill_route() -> void:
	var raw: Dictionary = _raw()
	(_page(raw, 0)["help_for"] as Array)[1] = "skill:nothing"
	_expect(raw, [PAGES, "help_for", "skill:nothing"])


func test_unknown_table_source() -> void:
	var raw: Dictionary = _raw()
	_block(raw, 0, 4)["source"] = "monster_drops"
	_expect(raw, [PAGES, "blocks[4].source", "unknown table source"])


func test_table_source_actions_needs_a_skill() -> void:
	var raw: Dictionary = _raw()
	_block(raw, 0, 4)["source"] = "actions:test_gather"
	assert_eq(V.validate(raw), PackedStringArray())
	_block(raw, 0, 4)["source"] = "actions:nothing"
	_expect(raw, [PAGES, "unknown table source 'actions:nothing'"])


func test_every_guide_table_id_is_accepted() -> void:
	var raw: Dictionary = _raw()
	for id: String in GuideTables.ids():
		_block(raw, 0, 4)["source"] = id
		assert_eq(V.validate(raw), PackedStringArray(), "table source '%s'" % id)


func test_table_source_families_need_their_target() -> void:
	var raw: Dictionary = _raw()
	for source: String in ["area_monsters:nothing", "monster_drops:nothing"]:
		_block(raw, 0, 4)["source"] = source
		_expect(raw, [PAGES, "unknown table source '%s'" % source])


func test_hand_written_digits() -> void:
	var raw: Dictionary = _raw()
	_block(raw, 0, 1)["text"] = "Dopo 12 ore."
	_expect(raw, [PAGES, "blocks[1].text", "digits written by hand"])


func test_digits_in_the_title() -> void:
	var raw: Dictionary = _raw()
	_page(raw, 0)["title"] = "Pagina 2"
	_expect(raw, [PAGES, "title", "digits written by hand"])


func test_allow_digits_admits_digits() -> void:
	var raw: Dictionary = _raw()
	_block(raw, 0, 1)["text"] = "Dopo 12 ore."
	_page(raw, 0)["allow_digits"] = true
	assert_eq(V.validate(raw), PackedStringArray())


func test_literal_brace() -> void:
	var raw: Dictionary = _raw()
	_block(raw, 0, 1)["text"] = "Apri la { graffa."
	_expect(raw, [PAGES, "literal brace"])


func test_exception_with_unknown_item() -> void:
	var raw: Dictionary = _raw()
	V.file_of(raw, "guide", EXCEPTIONS)["no_source"] = ["nothing"]
	_expect(raw, [EXCEPTIONS, "no_source", "unknown item 'nothing'"])


func test_exception_unknown_key() -> void:
	var raw: Dictionary = _raw()
	V.file_of(raw, "guide", EXCEPTIONS)["no_price"] = []
	_expect(raw, [EXCEPTIONS, "unknown field 'no_price'"])


func test_superfluous_exceptions_are_reported() -> void:
	var exceptions: Dictionary = {"no_source": [&"a", &"b"], "no_use": [&"c"]}
	var errors: PackedStringArray = DataValidatorGuide.superfluous_exceptions(exceptions,
			func(id: StringName) -> bool: return id == &"a", func(id: StringName) -> bool: return id == &"c")
	assert_eq(errors.size(), 2)
	assert_true(errors[0].contains("no_source 'a'"))
	assert_true(errors[1].contains("no_use 'c'"))
	assert_eq(DataValidatorGuide.superfluous_exceptions(exceptions, func(_id: StringName) -> bool: return false,
			func(_id: StringName) -> bool: return false), PackedStringArray())
