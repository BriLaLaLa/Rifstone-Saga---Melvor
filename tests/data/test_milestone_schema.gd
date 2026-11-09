extends GutTest
## Validator rules of the mastery milestones (docs/04_DATA_SCHEMA.md §3, §4, §6; F-103, F-108): the balance section, the
## 3 `milestones` of every gathering action in the order 25/50/99, no `mastery_bonuses` for gathering skills, different
## trees. One broken thing per test, in a copy of the fixture data. The real data are checked too.

const V: GDScript = preload("res://tests/core/data/test_data_validator.gd")
const ACTIONS: String = "test_gather.json"


func _twig(raw: Dictionary) -> Dictionary:
	return V.entry_of(raw, "actions", ACTIONS, "actions", 1)


func _milestone(raw: Dictionary, index: int) -> Dictionary:
	return (_twig(raw)["milestones"] as Array)[index] as Dictionary


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


func test_fixtures_are_valid() -> void:
	assert_eq(V.validate(V.fixture_raw()), PackedStringArray())



func test_all_24_real_gathering_actions_have_the_3_milestones() -> void:
	var data: GameData = TestFactory.real_data()
	assert_true(data.is_valid())
	var count: int = 0
	for skill: StringName in [&"forestry", &"quarrying", &"angling"]:
		for action: ActionDef in data.actions_for_skill(skill):
			count += 1
			assert_eq(action.milestones.size(), 3, action.id)
			assert_eq([action.milestones[0].at, action.milestones[1].at, action.milestones[2].at], [25, 50, 99], action.id)
	assert_eq(count, 24)


func test_a_gathering_action_without_milestones_is_refused() -> void:
	var r: Dictionary = V.fixture_raw()
	_twig(r).erase("milestones")
	_expect(r, [ACTIONS, "gather_twig", "missing field 'milestones'"])


func test_milestones_are_parsed() -> void:
	var twig: ActionDef = TestFactory.fixture_data().action(&"gather_twig")
	assert_eq(twig.milestones.size(), 3)
	assert_eq(twig.milestones[0].type, &"byproduct")
	assert_eq(twig.milestones[0].item, &"test_resin")
	assert_eq(twig.milestones[1].at, 50)
	assert_eq(twig.milestones[1].modifiers[0].scope_kind, &"action", "default scope of a resource milestone")
	assert_eq(twig.milestones[1].modifiers[0].scope_id, &"gather_twig")
	assert_eq(twig.milestones[2].modifiers[0].scope_kind, &"skill", "default scope of a trade milestone")
	assert_eq(twig.milestones[2].modifiers[0].scope_id, &"test_gather")
	assert_eq(twig.milestone_of(&"trade").at, 99)
	assert_null(TestFactory.fixture_data().action(&"craft_plank").milestone_of(&"trade"))


func test_balance_section_rules() -> void:
	var raw: Dictionary = V.fixture_raw()
	var milestones: Dictionary = (V.file_of(raw, "balance", V.BALANCE)["mastery"] as Dictionary)["milestones"]
	milestones["resource_at"] = 20
	_expect(raw, [V.BALANCE, "mastery.milestones.resource_at"])
	raw = V.fixture_raw()
	milestones = (V.file_of(raw, "balance", V.BALANCE)["mastery"] as Dictionary)["milestones"]
	milestones["byproduct_chance_pct"] = 120.0
	_expect(raw, [V.BALANCE, "byproduct_chance_pct"])
	raw = V.fixture_raw()
	((V.file_of(raw, "balance", V.BALANCE)["mastery"] as Dictionary)["milestones"] as Dictionary).erase("trade_at")
	_expect(raw, [V.BALANCE, "mastery.milestones.trade_at"])


func test_a_gathering_action_needs_its_milestones() -> void:
	var raw: Dictionary = V.fixture_raw()
	_twig(raw).erase("milestones")
	_expect(raw, [ACTIONS, "action 'gather_twig'", "missing field 'milestones'"])


func test_exactly_three_in_order() -> void:
	var raw: Dictionary = V.fixture_raw()
	(_twig(raw)["milestones"] as Array).pop_back()
	_expect(raw, ["action 'gather_twig'", "exactly 3 entries"])
	raw = V.fixture_raw()
	var list: Array = _twig(raw)["milestones"] as Array
	var first: Variant = list[0]
	list[0] = list[1]
	list[1] = first
	_expect(raw, ["action 'gather_twig'", "milestones[0].type", "byproduct"])


func test_at_must_match_the_balance() -> void:
	var raw: Dictionary = V.fixture_raw()
	_milestone(raw, 1)["at"] = 51
	_expect(raw, ["action 'gather_twig'", "milestones[1].at", "resource_at"])


func test_the_byproduct_is_a_material() -> void:
	var raw: Dictionary = V.fixture_raw()
	_milestone(raw, 0)["item"] = "seared_brookfin"
	_expect(raw, ["action 'gather_twig'", "milestones[0].item", "not a material"])
	raw = V.fixture_raw()
	_milestone(raw, 0)["item"] = "no_such_item"
	_expect(raw, ["action 'gather_twig'", "milestones[0].item", "unknown item"])


func test_bonus_milestones_need_modifiers_with_the_right_scope() -> void:
	var raw: Dictionary = V.fixture_raw()
	_milestone(raw, 1)["modifiers"] = []
	_expect(raw, ["action 'gather_twig'", "milestones[1].modifiers", "at least 1"])
	raw = V.fixture_raw()
	((_milestone(raw, 1)["modifiers"] as Array)[0] as Dictionary)["scope"] = "action:gather_log"
	_expect(raw, ["action 'gather_twig'", "milestones[1].modifiers", "scope must be 'action:gather_twig'"])
	raw = V.fixture_raw()
	((_milestone(raw, 2)["modifiers"] as Array)[0] as Dictionary)["scope"] = "global"
	_expect(raw, ["action 'gather_twig'", "milestones[2].modifiers", "scope must be 'skill:test_gather'"])
	raw = V.fixture_raw()
	_milestone(raw, 0)["modifiers"] = [{"stat": "double_item_chance", "value": 1}]
	_expect(raw, ["action 'gather_twig'", "milestones[0].modifiers", "byproduct"])


func test_milestones_only_for_gathering_actions() -> void:
	var raw: Dictionary = V.fixture_raw()
	V.entry_of(raw, "actions", "test_craft.json", "actions", 0)["milestones"] = _twig(raw)["milestones"]
	_expect(raw, ["test_craft.json", "milestones", "only for gathering"])



func test_gathering_trees_must_differ() -> void:
	var raw: Dictionary = V.fixture_raw()
	var tree: Dictionary = (V.file_of(raw, "mastery", "test_gather.json")).duplicate(true)
	tree["skill"] = "test_gather_b"
	for node: Variant in tree["nodes"]:
		(node as Dictionary)["id"] = String((node as Dictionary)["id"]).replace("test_gather_", "test_gather_b_")
		(node as Dictionary)["requires"] = ((node as Dictionary)["requires"] as Array).map(
				func(id: String) -> String: return id.replace("test_gather_", "test_gather_b_"))
	(raw["mastery"] as Dictionary)["res://fixtures/test_gather_b.json"] = tree
	_expect(raw, ["test_gather_b.json", "too similar", "test_gather"])
	# Changing three nodes makes the trees different.
	var nodes: Array = tree["nodes"]
	for index: int in nodes.size():
		((nodes[index] as Dictionary)["modifiers"] as Array)[0]["value"] = 77 + index
	assert_eq(V.validate(raw), PackedStringArray())
