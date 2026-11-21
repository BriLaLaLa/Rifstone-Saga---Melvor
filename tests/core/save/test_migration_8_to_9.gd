extends GutTest
## v8 -> v9 (M25-11, docs/05_INTERFACES_M25.md §6c, docs/01_GDD_M25.md §37.2): the Incisore becomes a production discipline; the
## migration keeps it learned when it has xp or a job, as an extra slot when two other productions are already learned.

const Step := preload("res://core/save/migrations/migration_8_to_9.gd")
const E: String = "riftbinding"


func _xp_of(level: int) -> int:
	return TestFactory.real_data().xp_table().xp_for_level(level)


# A v8 save: the given learned productions, the Incisore at `level` (0 = no xp), `jobs`.
func _v8(learned: Dictionary, level: int = 0, jobs: Array = []) -> Dictionary:
	return {"format_version": 8, "player_name": "x", "modules": {
		"wallet": {"gold": 1234},
		"skills": {"forging": {"xp": 500}, E: {"xp": _xp_of(level) if level > 0 else 0}},
		"mastery": {E: {"pool": 3, "actions": {"crystallize_spark": 7}, "nodes": []}},
		"disciplines": {"learned": learned, "recipes": []},
		"actions": {"jobs": jobs, "elapsed_ms": 40},
		"rift": {"sockets": ["inf_swift_hands", "", "", "", ""]}}}


func _disciplines(out: Dictionary) -> Dictionary:
	return (out["modules"] as Dictionary)["disciplines"] as Dictionary


func test_the_current_version_is_9() -> void:
	assert_eq(SaveMigrator.CURRENT_VERSION, 12)
	assert_eq(SaveMigrator.migrate(_v8({}))["format_version"], 12)


func test_xp_and_one_production_the_engraver_is_learned_at_the_grade_of_its_level() -> void:
	var out: Dictionary = Step.migrate(_v8({"forging": 2}, 30))
	assert_eq(_disciplines(out), {"learned": {"forging": 2, E: 2}, "recipes": [], "extra": []}, "level 30 -> grade 2 (cap 40)")


func test_level_99_is_grade_5() -> void:
	assert_eq(_disciplines(Step.migrate(_v8({}, 99)))["learned"], {E: 5})


func test_xp_and_two_productions_take_an_extra_slot() -> void:
	var out: Dictionary = Step.migrate(_v8({"forging": 2, "hearthcraft": 1}, 45))
	assert_eq(_disciplines(out), {"learned": {"forging": 2, "hearthcraft": 1, E: 3}, "recipes": [], "extra": [E]})


func test_xp_zero_with_a_job_is_grade_1() -> void:
	var jobs: Array = [{"skill": E, "action": "crystallize_spark", "remaining": 0, "repeat": true}]
	var out: Dictionary = Step.migrate(_v8({"forging": 1}, 0, jobs))
	assert_eq(_disciplines(out)["learned"], {"forging": 1, E: 1})
	assert_eq(_disciplines(out)["extra"], [])


func test_xp_zero_and_no_job_is_not_learned() -> void:
	var out: Dictionary = Step.migrate(_v8({"forging": 1}))
	assert_eq(_disciplines(out), {"learned": {"forging": 1}, "recipes": [], "extra": []})


func test_a_job_of_another_skill_is_not_progress() -> void:
	var jobs: Array = [{"skill": "forging", "action": "x", "remaining": 0, "repeat": true}]
	assert_false(_disciplines(Step.migrate(_v8({"forging": 1}, 0, jobs)))["learned"].has(E))


func test_nothing_else_changes() -> void:
	var before: Dictionary = _v8({"forging": 2, "hearthcraft": 1}, 60, [{"skill": E, "action": "crystallize_spark", "remaining": 0, "repeat": true}])
	var out: Dictionary = Step.migrate(before)
	for key: String in ["wallet", "skills", "mastery", "actions", "rift"]:
		assert_eq((out["modules"] as Dictionary)[key], (before["modules"] as Dictionary)[key], key)
	assert_eq((before["modules"] as Dictionary)["disciplines"], {"learned": {"forging": 2, "hearthcraft": 1}, "recipes": []}, "input untouched")


func test_an_already_learned_engraver_is_untouched() -> void:
	var out: Dictionary = Step.migrate(_v8({"forging": 2, E: 4}, 70))
	assert_eq(_disciplines(out)["learned"], {"forging": 2, E: 4})


# --- in the game ---------------------------------------------------------------------------------------------------------------

func _load(save: Dictionary) -> GameSession:
	var s: GameSession = autofree(TestFactory.session_no_kit(3, TestFactory.real_data()))
	assert_true(s.from_save(SaveMigrator.migrate(save)).ok)
	return s


func _session_v8(learned: Array[StringName], level: int) -> Dictionary:
	var s: GameSession = autofree(TestFactory.session_no_kit(1, TestFactory.real_data()))
	s.disciplines.new_game()
	for id: StringName in learned:
		TestFactory.learn_discipline(s, id, 3)
		s.skills.add_xp(id, 100)
	TestFactory.learn_discipline(s, &"riftbinding", 5)
	s.skills.add_xp(&"riftbinding", _xp_of(level))
	s.wallet.add_gold(50)
	var d: Dictionary = s.to_save(0)
	d["format_version"] = 8
	var disciplines: Dictionary = (d["modules"] as Dictionary)["disciplines"] as Dictionary
	(disciplines["learned"] as Dictionary).erase(E)
	disciplines.erase("extra")
	return d


func test_two_productions_and_the_engraver_extra_in_the_game() -> void:
	var saved: Dictionary = _session_v8([&"forging", &"woodwright"], 30)
	var xp: int = int(((saved["modules"] as Dictionary)["skills"] as Dictionary)[E]["xp"])
	var s: GameSession = _load(saved)
	assert_true(s.disciplines.is_learned(E))
	assert_eq(s.disciplines.grade(E), 2)
	assert_true(s.disciplines.is_extra(E))
	assert_eq(s.skills.get_xp(&"riftbinding"), xp, "no xp lost")
	assert_eq(s.wallet.get_gold(), int(((saved["modules"] as Dictionary)["wallet"] as Dictionary)["copper"]), "no gold taken")
	assert_eq(s.disciplines.free_slots(&"artisan"), 0)
	assert_true(s.disciplines.can_learn(&"hearthcraft").ok, "the Cook is free")
	s.wallet.add_gold(10000000)
	assert_true(s.disciplines.unlearn(&"forging").ok)
	assert_false(s.disciplines.is_extra(E), "back within the limit: the extra slot goes away")
	assert_true(s.disciplines.is_learned(E))
	assert_eq(s.disciplines.free_slots(&"artisan"), 0)
	assert_eq(s.disciplines.to_save()["extra"], [])


func test_one_production_the_engraver_takes_a_normal_slot() -> void:
	var s: GameSession = _load(_session_v8([&"forging"], 30))
	assert_true(s.disciplines.is_learned(E))
	assert_false(s.disciplines.is_extra(E))
	assert_eq(s.disciplines.free_slots(&"artisan"), 0)


func test_unlearning_the_extra_engraver_removes_the_slot() -> void:
	var s: GameSession = _load(_session_v8([&"forging", &"woodwright"], 30))
	s.wallet.add_gold(10000000)
	assert_true(s.disciplines.unlearn(E).ok)
	assert_false(s.disciplines.is_extra(E))
	assert_eq(s.disciplines.free_slots(&"artisan"), 0, "the two other productions stay")
	assert_eq(s.skills.get_xp(&"riftbinding"), 0)


func test_save_load_save_is_identical() -> void:
	var s: GameSession = _load(_session_v8([&"forging", &"woodwright"], 50))
	var first: Dictionary = s.to_save(0)
	var other: GameSession = autofree(TestFactory.session_no_kit(4, TestFactory.real_data()))
	assert_true(other.from_save(JSON.parse_string(JSON.stringify(first)) as Dictionary).ok)
	assert_eq(other.to_save(0)["modules"], first["modules"])
	assert_eq((first["modules"] as Dictionary)["disciplines"]["extra"], [E])


func test_the_chain_from_v7_keeps_the_xp_of_the_engraver() -> void:
	var xp: int = _xp_of(61)
	var v7: Dictionary = {"format_version": 7, "player_name": "x", "modules": {
		"skills": {"forging": {"xp": _xp_of(20)}, "hearthcraft": {"xp": _xp_of(10)}, E: {"xp": xp}},
		"actions": {"lanes": {}}}}
	var out: Dictionary = SaveMigrator.migrate(v7)
	var m: Dictionary = out["modules"]
	assert_eq(out["format_version"], 12)
	assert_eq(m["skills"][E]["xp"], xp)
	assert_eq(m["disciplines"]["learned"][E], 4, "level 61 -> grade 4")
	assert_eq(m["disciplines"]["extra"], [E], "forging and hearthcraft were learned by v8")
