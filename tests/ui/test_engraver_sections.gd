extends GutTest
## Engraver page (M12-06, docs/05_INTERFACES.md §7.w): the generic SkillPage of `riftbinding` with its recipes in sections
## (Lastra, Fondere, Cristalli, Incidere, Potenziare), "Probabilità: N%" and "Fallimento: perdi M Polvere" on the
## crystallizations (EngraverResolver, F-104) and the source of the ingredients (GuideIndex). Real data.

const SCENE: PackedScene = preload("res://ui/pages/skill/skill_page.tscn")
const SKILL := &"riftbinding"

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


func test_sections_in_the_documented_order() -> void:
	_open()
	var titles: Array[String] = []
	for section: StringName in EngraverSections.SECTIONS:
		var heading: Label = _page.find_child(EngraverSections.SECTION_NODE % section, true, false) as Label
		assert_not_null(heading, String(section))
		titles.append(heading.text)
	assert_eq(titles, ["Lastra", "Fondere", "Cristalli", "Incidere", "Potenziare"])


func test_every_action_has_a_card_in_its_section() -> void:
	_open()
	for action: ActionDef in _session.data.actions_for_skill(SKILL):
		var card: ActionCard = _page.find_child(String(action.id).to_pascal_case(), true, false) as ActionCard
		assert_not_null(card, String(action.id))
		var flow: Node = card.get_parent()
		assert_eq(flow.name, "Flow_%s" % EngraverSections.section_of(action))


func test_crystallization_shows_chance_and_loss_from_the_formulas() -> void:
	_open()
	var action: ActionDef = _session.data.action(&"crystallize_spark")
	var card: Node = _page.find_child(String(action.id).to_pascal_case(), true, false)
	var chance: float = EngraverResolver.crystal_chance_pct(_session.skills.get_level(SKILL), _session.data)
	assert_eq((card.find_child("ChanceLabel", true, false) as Label).text, "Probabilità: %s%%" % NumberFormat.format_number(chance))
	var lost: int = EngraverResolver.fail_loss(action.inputs[0].qty, _session.data)
	assert_eq((card.find_child("LossLabel", true, false) as Label).text,
			"Fallimento: perdi %d %s" % [lost, _session.data.item(action.inputs[0].item_id).name])


func test_chance_follows_the_level() -> void:
	TestFactory.set_level(_session, SKILL, 50)
	_open()
	var card: Node = _page.find_child("CrystallizeSpark", true, false)
	var chance: float = EngraverResolver.crystal_chance_pct(50, _session.data)
	assert_string_contains((card.find_child("ChanceLabel", true, false) as Label).text, NumberFormat.format_number(chance))


func test_other_recipes_have_no_chance_line() -> void:
	_open()
	var card: Node = _page.find_child("MakeRuneSlab", true, false)
	assert_not_null(card)
	assert_null(card.find_child("ChanceLabel", true, false))


func test_ingredients_say_where_they_come_from() -> void:
	_open()
	var card: Node = _page.find_child("CrystallizeSpark", true, false)
	var line: Label = card.find_child("SourceRiftDust", true, false) as Label
	assert_not_null(line)
	assert_true(line.text.begins_with("Da: "), line.text)
	assert_gt(line.text.length(), 4)


func test_crystallize_starts_with_dust_only() -> void:
	_open()
	var button: Button = _page.find_child("CrystallizeSpark", true, false).find_child("ToggleButton", true, false) as Button
	assert_true(button.disabled, "no Dust")
	TestFactory.give(_session, &"rift_dust", 100)
	TestFactory.set_level(_session, SKILL, 5)
	assert_false(button.disabled, "Dust and level")


func _open() -> void:
	_page = SCENE.instantiate() as SkillPage
	_page.page_id = StringName(PageHost.ROUTE_SKILL + PageHost.ROUTE_SEPARATOR + SKILL)
	add_child(_page)
	_page.bind(_session)
