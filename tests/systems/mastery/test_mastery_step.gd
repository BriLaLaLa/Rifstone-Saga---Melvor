extends GutTest
## F-122 (M14): a bonus every 10 levels of mastery, for gathering and crafting; MasteryMath.step_bonus / next_step,
## MasterySystem.step_info and the `mastery_step:<action_id>` sources. Examples of 02_FORMULAS.md F-122.

const GATHERING: StringName = &"gathering"
const CRAFTING: StringName = &"crafting"
const INTERVAL: StringName = &"skill_interval_pct"
const DOUBLE: StringName = &"double_item_chance"
const PRESERVE: StringName = &"preservation_chance"

var _data: GameData
var _table: XpTable


func before_all() -> void:
	_data = TestFactory.real_data()
	_table = _data.mastery_table()


func _totals(mods: Array[Modifier]) -> Dictionary:
	var result: Dictionary = {}
	for mod: Modifier in mods:
		result[mod.stat] = float(result.get(mod.stat, 0.0)) + mod.value
	return result


func test_level_9_has_no_bonus_and_the_next_is_at_10() -> void:
	assert_eq(MasteryMath.step_count(9, _data), 0)
	assert_true(MasteryMath.step_bonus(9, GATHERING, _data).is_empty())
	var next: Dictionary = MasteryMath.next_step(9, GATHERING, _data)
	assert_eq(next["level"], 10)
	assert_eq(_totals(next["modifiers"]), {INTERVAL: -2.0, DOUBLE: 1.0})


func test_gathering_examples() -> void:
	assert_eq(_totals(MasteryMath.step_bonus(10, GATHERING, _data)), {INTERVAL: -2.0, DOUBLE: 1.0})
	assert_eq(_totals(MasteryMath.step_bonus(47, GATHERING, _data)), {INTERVAL: -8.0, DOUBLE: 4.0}, "n = 4")
	assert_eq(_totals(MasteryMath.step_bonus(99, GATHERING, _data)), {INTERVAL: -18.0, DOUBLE: 9.0}, "n = 9")


func test_crafting_examples() -> void:
	assert_eq(_totals(MasteryMath.step_bonus(30, CRAFTING, _data)), {PRESERVE: 6.0, INTERVAL: -6.0}, "n = 3")
	assert_eq(_totals(MasteryMath.step_bonus(99, CRAFTING, _data)), {PRESERVE: 18.0, INTERVAL: -18.0})


func test_next_step_none_at_the_last_step() -> void:
	assert_eq(MasteryMath.next_step(99, GATHERING, _data), {})
	assert_eq(MasteryMath.next_step(90, CRAFTING, _data), {}, "the next would be at 100, above the maximum level")
	assert_eq(MasteryMath.next_step(89, CRAFTING, _data)["level"], 90)


func test_step_kind_follows_the_skill_category() -> void:
	assert_eq(MasteryMath.step_kind(&"gathering"), GATHERING)
	assert_eq(MasteryMath.step_kind(&"artisan"), CRAFTING)


func _session(skill: StringName, action: StringName, level: int) -> GameSession:
	var session: GameSession = autofree(TestFactory.session_no_kit(1, _data))
	session.mastery.from_save({skill: {"actions": {action: _table.xp_for_level(level)}}})
	session.rebuild_modifiers()
	return session


func test_gathering_action_gets_the_step_bonus_in_its_own_scope() -> void:
	var session: GameSession = _session(&"forestry", &"cut_redbirch", 47)
	var ctx: ModifierContext = ModifierContext.for_action(&"forestry", &"cut_redbirch")
	assert_eq(session.modifiers.total(INTERVAL, ctx), -8.0, "the resource milestone starts at 50")
	assert_eq(session.modifiers.total(DOUBLE, ctx), 4.0)
	assert_true(session.modifiers.has_source(&"mastery_step:cut_redbirch"))
	assert_eq(session.modifiers.total(DOUBLE, ModifierContext.for_action(&"forestry", &"cut_ashpine")), 0.0)


func test_crafting_action_gets_the_step_bonus() -> void:
	var skill: StringName = _data.skills_by_category(&"artisan")[0].id
	var action: ActionDef = null
	for candidate: ActionDef in _data.actions_for_skill(skill):
		if candidate.mastery:
			action = candidate
			break
	assert_not_null(action, "an artisan action with mastery")
	var session: GameSession = _session(skill, action.id, 30)
	var ctx: ModifierContext = ModifierContext.for_action(skill, action.id)
	assert_eq(session.modifiers.total(PRESERVE, ctx), 6.0)
	assert_eq(session.modifiers.total(INTERVAL, ctx), -6.0)


func test_step_bonus_updates_once_on_the_level_that_crosses_the_step() -> void:
	var session: GameSession = autofree(TestFactory.session_no_kit(1, _data))
	var action: ActionDef = _data.action(&"cut_redbirch")
	var ctx: ModifierContext = ModifierContext.for_action(&"forestry", action.id)
	assert_eq(session.modifiers.total(DOUBLE, ctx), 0.0)
	session.mastery.from_save({"forestry": {"actions": {action.id: _table.xp_for_level(9)}, "pool": 10000000}})
	session.rebuild_modifiers()
	var need: int = _table.xp_for_level(10) - _table.xp_for_level(9)
	assert_true(session.mastery.spend_pool_on_action(action.id, need).ok)
	assert_eq(session.mastery.get_mastery_level(action.id), 10)
	assert_eq(session.modifiers.total(DOUBLE, ctx), 1.0)


func test_step_info_for_the_ui() -> void:
	var session: GameSession = _session(&"forestry", &"cut_redbirch", 39)
	var info: Dictionary = session.mastery.step_info(&"forestry", &"cut_redbirch")
	assert_eq(info["level"], 39)
	assert_eq(info["n"], 3)
	assert_eq(_totals(info["current"]), {INTERVAL: -6.0, DOUBLE: 3.0})
	assert_eq(info["next"]["level"], 40)
	assert_string_contains(info["next"]["text"], "Al livello 40:")
	assert_string_contains(info["next"]["text"], "-2%")
	assert_string_contains(info["next"]["text"], "+1%")


func test_step_info_at_99_has_no_next_and_unknown_action_is_empty() -> void:
	var session: GameSession = _session(&"forestry", &"cut_redbirch", 99)
	var info: Dictionary = session.mastery.step_info(&"forestry", &"cut_redbirch")
	assert_eq(info["n"], 9)
	assert_eq(info["next"], {})
	assert_eq(session.mastery.step_info(&"forestry", &"no_such_action"), {})


func test_no_mastery_bonuses_are_left_in_the_skill_data() -> void:
	for skill: SkillDef in _data.skills():
		assert_false("mastery_bonuses" in skill, "SkillDef has no mastery_bonuses (F-122 replaces F-11)")
