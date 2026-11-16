extends GutTest
## M24-07: the M24 UI on the real data and the real engine (one check per link, not texts): `NodeColorPreview` loads the real
## `EncounterCycle` and the gathering card of the real SkillPage shows the colour line; `CombatTexts.color_id` reads the real
## shape of `get_state()["node"]["color"]` and the NodeCard draws a worked node.

const SKILL_SCENE: PackedScene = preload("res://ui/pages/skill/skill_page.tscn")
const FORESTRY: StringName = &"forestry"
const AREA: StringName = &"redrock_plains"

var _session: GameSession
var _page: SkillPage


func before_each() -> void:
	_session = TestFactory.session(2407, TestFactory.real_data())
	TestFactory.set_character_level(_session, 55)
	_session.modifiers.set_source(&"test:hero", [Modifier.make(&"power_bonus", 100000.0), Modifier.make(&"max_hp_flat", 100000.0),
			Modifier.make(&"armor", 100000.0), Modifier.make(&"evasion_bonus", 80000.0)])
	TestFactory.make_roomy(_session)


func after_each() -> void:
	if is_instance_valid(_page):
		_page.free()
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func test_the_colour_preview_loads_the_real_cycle() -> void:
	assert_true(ResourceLoader.exists(NodeColorPreview.cycle_script_path), "the path of the cycle exists")
	var action: ActionDef = _session.data.actions_for_skill(FORESTRY)[0]
	var preview: Dictionary = NodeColorPreview.of(_session, action)
	assert_false(preview.is_empty(), "a real answer, not the empty fallback")
	assert_eq(preview["id"], &"orange", "level 1 on the first step")
	assert_true(preview.has("xp_pct"))


func test_the_real_gathering_card_shows_the_colour_line() -> void:
	_page = SKILL_SCENE.instantiate() as SkillPage
	_page.page_id = StringName(PageHost.ROUTE_SKILL + PageHost.ROUTE_SEPARATOR + FORESTRY)
	add_child(_page)
	_page.bind(_session)
	var first: ActionDef = _session.data.actions_for_skill(FORESTRY)[0]
	var card: ActionCard = _page.find_child(String(first.id).to_pascal_case(), true, false) as ActionCard
	assert_not_null(card)
	var shown: int = 0
	for label: Node in card.find_children("*", "Label", true, false):
		if (label as Label).visible and (label as Label).text.begins_with("Colore ora"):
			shown += 1
	assert_eq(shown, 1, "the card of a gathering resource has its colour line")


func test_the_real_node_state_is_read_by_the_texts_and_the_panel() -> void:
	_session.disciplines.new_game()
	assert_true(_session.disciplines.learn(FORESTRY).ok)
	assert_true(_session.combat.start(AREA).ok)
	var found: bool = false
	for _i: int in 20000:
		_session.advance(500)
		var state: Dictionary = _session.combat.get_state()
		var node: Dictionary = state["node"]
		if _session.combat.state() == CombatEngine.STATE_NODE and not bool(node["skipped"]):
			found = true
			var id: StringName = CombatTexts.color_id(node["color"])
			assert_true(CombatTexts.NODE_COLORS.has(id), "the real color '%s' is one the UI knows" % str(node["color"]))
			var panel: NodeCard = NodeCard.new()
			add_child_autofree(panel)
			panel.refresh(state, _session.data)
			var label: Label = panel.find_child("ColorLabel", true, false) as Label
			assert_true(label.visible)
			assert_ne(label.text, "", "the colour line is drawn")
			break
	assert_true(found, "a worked node was reached")
