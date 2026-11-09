extends GutTest
## Guide of the Riforma 2 (M12-06): the new generated tables (bags, helper_grades, engraver_recipes,
## mastery_milestones:<skill>), the sources from loot tables and milestones, the uses of bags and contracts, the new
## hand-written pages, the declared exceptions and the old names gone from the texts.

const REAL_ROOT: String = "res://data"
const CONFIG_ROOT: String = "res://data/config"
const NEW_PAGES: Array[StringName] = [&"guide_deposit", &"guide_helpers", &"guide_resource_mastery", &"guide_engraver"]

var _data: GameData = null
var _index: GuideIndex = null


func before_all() -> void:
	_data = GameData.load_from_dirs(REAL_ROOT, CONFIG_ROOT)
	_index = GuideIndex.new(_data)


func test_bags_table_lists_every_bag_with_its_slots() -> void:
	var rows: Array[Array] = GuideTables.build("bags", _data)
	var bags: Array[ItemDef] = _data.items().filter(func(i: ItemDef) -> bool: return i.is_bag())
	assert_eq(rows.size(), bags.size() + 1)
	assert_eq(rows[1][0], bags[0].name)
	assert_eq(rows[1][1], str(bags[0].bag_slots))


func test_helper_grades_table_follows_the_data() -> void:
	var rows: Array[Array] = GuideTables.build("helper_grades", _data)
	var grades: Array[HelperGradeDef] = _data.helper_grades()
	assert_eq(rows.size(), grades.size() + 1)
	for index: int in grades.size():
		assert_eq(rows[index + 1][0], HelperGradeNames.name_of(grades[index].id))
		assert_eq(rows[index + 1][1], "x%s" % GuideIndex.num(grades[index].interval_mult))
	assert_eq(HelperGradeNames.name_of(&"journeyman"), "Garzone", "NOMI.md")


func test_engraver_recipes_table_shows_the_chance_range_for_crystals() -> void:
	var rows: Array[Array] = GuideTables.build("engraver_recipes", _data)
	assert_eq(rows.size(), _data.actions_for_skill(&"riftbinding").size() + 1)
	var low: String = GuideIndex.num(float(_data.balance_value("engraver.crystal_chance_min_pct")))
	var high: String = GuideIndex.num(float(_data.balance_value("engraver.crystal_chance_max_pct")))
	var found: bool = false
	for row: Array in rows:
		if row[0] == _data.action(&"crystallize_spark").name:
			assert_eq(row[4], "%s - %s" % [low, high])
			found = true
	assert_true(found, "crystallization row")


func test_mastery_milestones_table_per_gathering_skill() -> void:
	for skill_id: StringName in [&"forestry", &"quarrying", &"angling"]:
		var rows: Array[Array] = GuideTables.build("mastery_milestones:%s" % skill_id, _data)
		assert_eq(rows.size(), _data.actions_for_skill(skill_id).size() + 1, String(skill_id))
		assert_eq(rows[0].size(), 4)
		var first: ActionDef = _data.actions_for_skill(skill_id)[0]
		assert_eq(rows[1][1], _data.item(first.milestones[0].item).name, "the by-product")
		assert_ne(rows[1][2], "", "the resource bonus")
		assert_ne(rows[1][3], "", "the trade bonus")


func test_milestones_table_is_empty_for_a_non_gathering_skill() -> void:
	assert_true(GuideTables.build("mastery_milestones:forging", _data).is_empty())
	assert_push_error("unknown or empty source")


func test_loot_table_drops_and_byproducts_have_sources() -> void:
	assert_false(_index.sources_of(&"rift_dust").is_empty(), "Rift dust drops from a loot table")
	var action: ActionDef = _data.actions_for_skill(&"forestry")[0]
	var byproduct: StringName = action.milestones[0].item
	var refs: Array[GuideRef] = _index.sources_of(byproduct)
	assert_false(refs.is_empty())
	assert_eq(refs[0].kind, GuideRef.KIND_MILESTONE)


func test_bags_and_contracts_have_a_use() -> void:
	assert_eq(_index.uses_of(&"bag_canvas")[0].kind, GuideRef.KIND_BAG)
	assert_eq(_index.uses_of(&"contract_forestry_apprentice")[0].kind, GuideRef.KIND_CONTRACT)


func test_exceptions_are_only_what_the_index_still_cannot_explain() -> void:
	var exceptions: Dictionary = _data.guide_exceptions()
	for id: Variant in exceptions.get("no_source", []):
		assert_true(_index.sources_of(StringName(str(id))).is_empty(), "no_source %s is superfluous" % id)
	for id: Variant in exceptions.get("no_use", []):
		assert_true(_index.uses_of(StringName(str(id))).is_empty(), "no_use %s is superfluous" % id)
	# M14-05: pieces and blueprints get their sources from the drop pool and the legendaries (M14-08, F-121, F-124).
	var missing: Array[StringName] = []
	for id: StringName in _index.items_without_source():
		if not [&"equipment", &"tool", &"blueprint"].has(_data.item(id).category):
			missing.append(id)
	assert_eq(missing.size(), 0, str(missing))
	assert_eq(_index.items_without_use().size(), 0)


func test_new_pages_exist_and_the_help_buttons_point_to_them() -> void:
	for id: StringName in NEW_PAGES:
		assert_not_null(_data.guide_page(id), String(id))
	assert_true(_data.guide_page(&"guide_deposit").help_for.has("bank"))
	assert_true(_data.guide_page(&"guide_engraver").help_for.has("skill:riftbinding"))


func test_no_old_names_in_the_guide_texts() -> void:
	for page: GuidePageDef in _data.guide_pages():
		for block: Dictionary in page.blocks:
			var text: String = str(block.get("text", ""))
			for old: String in ["Legatura del Rift", "Pietra del Rift", "Scintilla", "Sabbia del mutamento", "di furia", "d'ombra",
					"caselle acquistabili", "comprare spazio"]:
				assert_false(text.contains(old), "%s: '%s'" % [page.id, old])
