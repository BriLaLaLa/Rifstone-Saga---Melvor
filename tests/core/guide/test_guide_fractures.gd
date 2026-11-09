extends GutTest
## The Guide of the Fractures (M13-05, docs/05_INTERFACES.md §7.v): the page `guide_fractures` with its "?" route, the tables
## generated from the data (grades F-110, modifiers F-111, bosses F-112), source and use of every Card without exceptions.

const FIXTURE_ROOT: String = "res://tests/fixtures/data"
const CONFIG_ROOT: String = "res://data/config"
const REAL_ROOT: String = "res://data"

var _fixture: GameData = null
var _real: GameData = null
var _index: GuideIndex = null


func before_all() -> void:
	_fixture = GameData.load_from_dirs(FIXTURE_ROOT, CONFIG_ROOT)
	_real = GameData.load_from_dirs(REAL_ROOT, CONFIG_ROOT)
	_index = GuideIndex.new(_real)


func test_new_tables_are_declared_and_built() -> void:
	for id: String in ["fracture_grades", "map_mods", "bosses"]:
		assert_true(GuideTables.ids().has(id), id)
		assert_gt(GuideTables.build(id, _real).size(), 1, "%s on the real data" % id)
		assert_gt(GuideTables.build(id, _fixture).size(), 1, "%s on the fixtures" % id)


func test_grade_table_has_a_row_per_grade_with_the_values_of_the_data() -> void:
	var rows: Array[Array] = GuideTables.build("fracture_grades", _real)
	assert_eq(rows.size(), (_real.balance_value("fracture.grades") as Array).size() + 1)
	var def: FractureGradeDef = _real.fracture_grade(3)
	assert_eq(rows[3][0], "3")
	assert_eq(rows[3][2], str(def.recommended_level))
	assert_eq(rows[3][3], "x%s" % GuideIndex.num(def.hp_mult))


func test_modifier_table_lists_every_modifier_with_range() -> void:
	var rows: Array[Array] = GuideTables.build("map_mods", _real)
	assert_eq(rows.size(), _real.map_mods().size() + 1)
	var first: MapModDef = _real.map_mods()[0]
	assert_eq(rows[1][0], first.name)
	assert_true((rows[1][2] as String).contains("+%d%%" % int(first.risk.min_value)), rows[1][2])
	assert_true((rows[1][3] as String).contains("+%d%%" % int(first.reward.max_value)), rows[1][3])


func test_boss_table_names_the_ability_of_each_boss() -> void:
	var rows: Array[Array] = GuideTables.build("bosses", _real)
	assert_eq(rows.size(), (_real.balance_value("fracture.grades") as Array).size() + 1)
	for index: int in range(1, rows.size()):
		var boss: BossDef = _real.boss_for_grade(index)
		assert_eq(rows[index][1], boss.name)
		assert_true((rows[index][3] as String).begins_with(MapEffectLabels.ability_name(boss.ability.type)), rows[index][3])
		assert_eq(rows[index][4], "%d - %d" % [boss.dust_min, boss.dust_max])


func test_the_page_exists_with_the_fractures_route_and_the_tables() -> void:
	var page: GuidePageDef = _real.guide_page(&"guide_fractures")
	assert_not_null(page)
	assert_true(page.help_for.has("fractures"))
	assert_eq(HelpButton.entry_for(_real, &"fractures"), GuideIndex.entry(&"page", GuideIndex.PAGE_FRACTURES))
	var sources: Array[String] = []
	for block: Dictionary in page.blocks:
		if block.get("type") == "table":
			sources.append(block["source"] as String)
	for id: String in ["fracture_grades", "map_mods", "bosses"]:
		assert_true(sources.has(id), id)


func test_every_card_has_source_and_use_without_exceptions() -> void:
	for item: ItemDef in _real.items():
		if not item.is_map():
			continue
		assert_false(_index.sources_of(item.id).is_empty(), "source of %s" % item.id)
		assert_false(_index.uses_of(item.id).is_empty(), "use of %s" % item.id)
		assert_false(_index.items_without_source().has(item.id))
		assert_false(_index.items_without_use().has(item.id))
	var exceptions: Dictionary = _real.guide_exceptions()
	for key: String in ["no_source", "no_use"]:
		for id: Variant in exceptions[key] as Array:
			assert_false(String(id).begins_with("fracture_card_"), "%s still lists %s" % [key, id])


func test_card_source_names_the_fractures_and_the_grade_range() -> void:
	var refs: Array[GuideRef] = _index.sources_of(&"fracture_card_5")
	var found: GuideRef = null
	for ref: GuideRef in refs:
		if ref.kind == GuideRef.KIND_FRACTURE:
			found = ref
	assert_not_null(found)
	assert_eq(found.target, GuideIndex.entry(&"page", GuideIndex.PAGE_FRACTURES))
	assert_eq(found.detail, "Frattura di grado 3-5")
	var use: GuideRef = _index.uses_of(&"fracture_card_1")[0]
	assert_eq(use.label, GuideIndex.LABEL_FRACTURE_OPEN)
