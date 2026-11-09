extends GutTest
## MasteryStepRow on the action cards (M14-08, docs/01_GDD.md §6.5): current bonuses and "Al livello N: ...", read from
## `MasterySystem.step_info`. Real data (forestry, F-122), and the label of the `mastery_step:` source.

const SCENE: PackedScene = preload("res://ui/pages/skill/skill_page.tscn")

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


func _open(skill: StringName) -> void:
	_page = SCENE.instantiate() as SkillPage
	_page.page_id = StringName("skill:%s" % skill)
	add_child(_page)
	_page.bind(_session)


func _raise_mastery(action_id: StringName, level: int) -> void:
	var missing: int = _session.data.mastery_table().xp_for_level(level) - _session.mastery.get_mastery_xp(action_id)
	var skill_id: StringName = _session.data.action(action_id).skill_id
	var saved: Dictionary = _session.mastery.to_save()
	var skill_save: Dictionary = saved[String(skill_id)]
	var actions: Dictionary = skill_save["actions"]
	actions[String(action_id)] = int(actions.get(String(action_id), 0)) + missing
	_session.mastery.from_save(saved)


func _first_mastery_action() -> ActionDef:
	for action: ActionDef in _session.data.actions_for_skill(&"forestry"):
		if action.mastery:
			return action
	return null


func test_card_shows_the_next_bonus_from_step_info() -> void:
	var action: ActionDef = _first_mastery_action()
	_open(&"forestry")
	var info: Dictionary = _session.mastery.step_info(&"forestry", action.id)
	var row: MasteryStepRow = _page.find_child(String(action.id).to_pascal_case(), true, false).find_child(
			"MasteryStepRow", true, false) as MasteryStepRow
	assert_not_null(row)
	assert_true(row.visible)
	assert_string_contains(row.shown_text(), info["next"]["text"])
	assert_string_contains(row.shown_text(), MasteryStepRow.NONE_TEXT)
	assert_true(str(info["next"]["text"]).begins_with("Al livello 10:"))


func test_card_follows_the_mastery_level() -> void:
	var action: ActionDef = _first_mastery_action()
	_raise_mastery(action.id, 47)
	_open(&"forestry")
	var info: Dictionary = _session.mastery.step_info(&"forestry", action.id)
	assert_eq(info["n"], 4)
	var row: MasteryStepRow = _page.find_child(String(action.id).to_pascal_case(), true, false).find_child(
			"MasteryStepRow", true, false) as MasteryStepRow
	var current: Array[Modifier] = []
	current.assign(info["current"])
	assert_string_contains(row.shown_text(), MasteryStepRow.CURRENT_TEXT % LoadoutDescribe.modifiers_text(current, _session.data))
	assert_string_contains(row.shown_text(), "Al livello 50:")


func test_max_level_says_everything_is_reached() -> void:
	var action: ActionDef = _first_mastery_action()
	_raise_mastery(action.id, 99)
	_open(&"forestry")
	var row: MasteryStepRow = _page.find_child(String(action.id).to_pascal_case(), true, false).find_child(
			"MasteryStepRow", true, false) as MasteryStepRow
	assert_string_contains(row.shown_text(), MasteryStepRow.MAX_TEXT)


func test_crafting_cards_have_the_row_too() -> void:
	_open(&"forging")
	var action: ActionDef = null
	for candidate: ActionDef in _session.data.actions_for_skill(&"forging"):
		if candidate.mastery:
			action = candidate
			break
	if action == null:
		pass_test("forging has no mastery actions in the data")
		return
	var row: Node = _page.find_child(String(action.id).to_pascal_case(), true, false).find_child("MasteryStepRow", true, false)
	assert_not_null(row)


func test_the_source_mastery_step_has_a_label() -> void:
	assert_eq(EquipmentStatsText.source_name(&"mastery_step:cut_redbirch", _session), "Maestria (bonus di livello)")
