extends GutTest
## Hand-written Guide pages (docs/01_GDD.md §27, 04_DATA_SCHEMA §19) on the real data: every listed page exists, the "?" routes
## are covered, no hand-written digits, no superfluous exceptions.

const REAL_ROOT: String = "res://data"
const CONFIG_ROOT: String = "res://data/config"
const REQUIRED_PAGES: Array[StringName] = [
	&"guide_first_steps", &"guide_bank_shop", &"guide_character_level", &"guide_setups", &"guide_triangle",
	&"guide_traits", &"guide_abilities", &"guide_food", &"guide_death", &"guide_packs", &"guide_rarity",
	&"guide_refining", &"guide_sockets", &"guide_currencies", &"guide_salvage", &"guide_rift_stones",
	&"guide_blueprints", &"guide_stones_runes", &"guide_mastery", &"guide_tools", &"guide_altar", &"guide_offline"]
## Game pages whose "?" must lead to a guide page (GDD §27).
const GAME_ROUTES: Array[String] = ["combat", "equipment", "armory", "character", "altar", "rift", "bank", "shop"]
const MAX_WORDS: int = 160

var _data: GameData = null
var _index: GuideIndex = null


func before_all() -> void:
	_data = GameData.load_from_dirs(REAL_ROOT, CONFIG_ROOT)
	_index = GuideIndex.new(_data)


func test_real_data_loads_without_errors() -> void:
	assert_eq(_data.errors.size(), 0, "no load errors: %s" % str(_data.errors))


func test_every_listed_page_exists() -> void:
	for id: StringName in REQUIRED_PAGES:
		assert_not_null(_data.guide_page(id), "page %s" % id)


func test_help_for_covers_game_pages() -> void:
	var covered: Dictionary = {}
	for page: GuidePageDef in _data.guide_pages():
		for route: String in page.help_for:
			covered[route] = true
	for route: String in GAME_ROUTES:
		assert_true(covered.has(route), "route %s has a guide page" % route)
	for skill: SkillDef in _data.skills():
		assert_true(covered.has("skill:%s" % skill.id), "skill route %s" % skill.id)


func test_no_hand_written_digits_and_short_pages() -> void:
	var digits := RegEx.create_from_string("[0-9]")
	for page: GuidePageDef in _data.guide_pages():
		var words: int = 0
		for block: Dictionary in page.blocks:
			if block["type"] == "text":
				var raw: String = block["text"] as String
				while raw.contains("{"):
					var a: int = raw.find("{")
					raw = raw.substr(0, a) + " x " + raw.substr(raw.find("}", a) + 1)
				words += raw.split(" ", false).size()
				if not page.allow_digits:
					assert_null(digits.search(raw), "digits in %s" % page.id)
		assert_lt(words, MAX_WORDS, "%s is short enough" % page.id)


func test_exceptions_are_not_superfluous_and_cover_the_rest() -> void:
	assert_eq(_index.items_without_source().size(), 0, "items without source: %s" % str(_index.items_without_source()))
	assert_eq(_index.items_without_use().size(), 0, "items without use: %s" % str(_index.items_without_use()))
	var exceptions: Dictionary = _data.guide_exceptions()
	for id: StringName in exceptions["no_source"]:
		assert_true(_index.sources_of(id).is_empty(), "%s really has no source" % id)
	for id: StringName in exceptions["no_use"]:
		assert_true(_index.uses_of(id).is_empty(), "%s really has no use" % id)
