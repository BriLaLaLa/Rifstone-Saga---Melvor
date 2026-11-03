extends GutTest
## CharacterSystem: F-71 xp and level, signals, save, mixed requirements, session integration.

const XP_PCT: StringName = &"skill_xp_pct"
const SOURCE: StringName = &"test:char_xp"
const SKILL: StringName = &"test_gather"

var _session: GameSession
var _char: CharacterSystem
var _xp_events: Array[int] = []
var _levels: Array[int] = []


func before_each() -> void:
	_session = autofree(TestFactory.session())
	_session.new_game()
	_char = _session.character
	_xp_events.clear()
	_levels.clear()
	_session.events.character_xp_gained.connect(func(a: int) -> void: _xp_events.append(a))
	_session.events.character_level_up.connect(func(l: int) -> void: _levels.append(l))


func _set_pct(pct: float) -> void:
	_session.modifiers.set_source(SOURCE, [Modifier.make(XP_PCT, pct)] as Array[Modifier])


func test_new_game_starts_with_the_start_class_at_zero_xp() -> void:
	assert_eq(_char.class_id(), StringName(str(_session.data.balance_value("character.start_class"))))
	assert_eq(_char.class_def().id, _char.class_id())
	assert_eq(_char.get_xp(), 0)
	assert_eq(_char.get_level(), 1)
	assert_eq(_char.get_progress(), 0.0)


func test_level_for_xp_example() -> void:
	assert_eq(_session.data.character_xp_table().level_for_xp(1236), 10)


func test_add_xp_without_modifiers() -> void:
	assert_eq(_char.add_xp(80), 80)
	assert_eq(_char.get_xp(), 80)


func test_add_xp_with_global_pct() -> void:
	_set_pct(15.0)
	assert_eq(_char.add_xp(80), 92)


func test_skill_scoped_modifier_does_not_apply() -> void:
	_session.modifiers.set_source(SOURCE, [Modifier.make(XP_PCT, 50.0, &"skill", SKILL)] as Array[Modifier])
	assert_eq(_char.add_xp(80), 80)


func test_xp_is_capped() -> void:
	var cap: int = int(_session.data.balance_value("character_curve.xp_cap"))
	_char.from_save({"class": String(_char.class_id()), "xp": cap - 10})
	assert_eq(_char.add_xp(80), 10)
	assert_eq(_char.get_xp(), cap)
	assert_eq(_char.add_xp(80), 0)
	assert_eq(_xp_events, [10] as Array[int])


func test_xp_cap_example_49999990() -> void:
	_char.from_save({"class": String(_char.class_id()), "xp": 49999990})
	_char.add_xp(80)
	assert_eq(_char.get_xp(), 50000000)


func test_level_ups_one_per_level_after_xp_gained() -> void:
	var order: Array[String] = []
	_session.events.character_xp_gained.connect(func(_a: int) -> void: order.append("xp"))
	_session.events.character_level_up.connect(func(_l: int) -> void: order.append("lv"))
	_char.add_xp(_session.data.character_xp_table().xp_for_level(4))
	assert_eq(_levels, [2, 3, 4] as Array[int])
	assert_eq(order, ["xp", "lv", "lv", "lv"] as Array[String])
	assert_eq(_char.get_level(), 4)


func test_negative_xp_is_ignored() -> void:
	assert_eq(_char.add_xp(-5), 0)
	assert_push_error(1)
	assert_eq(_char.get_xp(), 0)
	assert_eq(_xp_events.size(), 0)


func test_save_roundtrip_is_identical_and_silent() -> void:
	_char.add_xp(1236)
	var saved: Dictionary = _char.to_save()
	assert_eq(saved, {"class": String(_char.class_id()), "xp": 1236})
	_xp_events.clear()
	_levels.clear()
	var other: GameSession = autofree(TestFactory.session())
	other.character.from_save(SaveCodec.decode(SaveCodec.encode(saved)))
	assert_eq(other.character.to_save(), saved)
	assert_eq(_xp_events.size() + _levels.size(), 0)


func test_from_save_is_tolerant() -> void:
	var start: String = String(_char.class_id())
	_char.from_save({"class": "nope", "xp": -4})
	assert_eq(_char.to_save(), {"class": start, "xp": 0})
	_char.from_save({"class": start, "xp": "x"})
	assert_eq(_char.get_xp(), 0)
	_char.from_save({"class": start, "xp": 1e15})
	assert_eq(_char.get_xp(), 50000000)
	_char.from_save({"class": start, "xp": 120.0})
	assert_eq(_char.get_xp(), 120)
	_char.from_save({})
	assert_eq(_char.get_xp(), 0)


func test_new_game_emits_nothing() -> void:
	_char.add_xp(500)
	_xp_events.clear()
	_levels.clear()
	_char.new_game()
	assert_eq(_char.get_xp(), 0)
	assert_eq(_xp_events.size() + _levels.size(), 0)


func test_meets_requirements_mixed_keys() -> void:
	TestFactory.set_character_level(_session, 5)
	TestFactory.set_level(_session, SKILL, 3)
	assert_true(_char.meets_requirements({}))
	assert_true(_char.meets_requirements({"character": 5, String(SKILL): 3}))
	assert_false(_char.meets_requirements({"character": 6, String(SKILL): 3}))
	assert_false(_char.meets_requirements({"character": 5, String(SKILL): 4}))
	assert_true(_char.meets_requirements({&"character": 1}))


func test_meets_requirements_non_numeric_is_false() -> void:
	assert_false(_char.meets_requirements({"character": "5"}))
	assert_push_error(1)


func test_total_level_includes_the_character() -> void:
	var skills_only: int = _session.skills.total_level()
	assert_eq(_session.total_level(), skills_only + 1)
	TestFactory.set_character_level(_session, 7)
	assert_eq(_session.total_level(), skills_only + 7)


func test_snapshot_has_character_key() -> void:
	TestFactory.set_character_level(_session, 3)
	var snapshot: SessionSnapshot = SessionSnapshot.take(_session)
	assert_eq(snapshot.levels[CharacterSystem.SAVE_KEY], 3)
	assert_eq(snapshot.xp[CharacterSystem.SAVE_KEY], _char.get_xp())


func test_session_save_has_character_module_and_roundtrips() -> void:
	TestFactory.set_character_level(_session, 4)
	var saved: Dictionary = _session.to_save(0)
	assert_eq((saved["modules"] as Dictionary)["character"], _char.to_save())
	var other: GameSession = autofree(TestFactory.session())
	assert_true(other.from_save(SaveCodec.decode(SaveCodec.encode(saved))).ok)
	assert_eq(other.to_save(0), saved)
