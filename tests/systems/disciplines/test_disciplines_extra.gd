extends GutTest
## Disciplines of M25-11 (docs/05_INTERFACES_M25.md §5.31b): the Incisore as a production, the extra slot (`extra`, `is_extra`,
## `free_slots` never negative), tolerant reading of `extra`, and the refusals for a skill that is not a discipline (fixtures).

const E: StringName = &"riftbinding"

var _s: GameSession = null
var _d: Disciplines = null


func before_each() -> void:
	_s = autofree(TestFactory.session_no_kit(1, TestFactory.real_data()))
	_d = _s.disciplines
	_d.new_game()
	_s.wallet.add_gold(10000000)


func test_the_engraver_is_learned_like_any_production() -> void:
	assert_true(_d.is_discipline(E))
	assert_eq(_d.category_of(E), &"artisan")
	assert_true(_d.learn(E).ok)
	assert_eq(_d.grade(E), 1)
	assert_eq(_d.next_grade_cost(E), 250)
	assert_false(_d.is_extra(E))


func test_two_of_four_productions_the_engraver_counts() -> void:
	assert_true(_d.learn(&"forging").ok)
	assert_true(_d.learn(E).ok)
	assert_eq(_d.free_slots(&"artisan"), 0)
	assert_eq(_d.learn(&"woodwright").reason, Reasons.DISCIPLINE_SLOTS_FULL)
	assert_eq(_d.learn(&"hearthcraft").reason, Reasons.DISCIPLINE_SLOTS_FULL)


func test_without_the_engraver_its_actions_are_not_queued() -> void:
	assert_eq(_s.actions.enqueue(E, &"crystallize_spark", 1, true).reason, Reasons.NOT_LEARNED)
	_d.learn(E)
	assert_ne(_s.actions.enqueue(E, &"crystallize_spark", 1, true).reason, Reasons.NOT_LEARNED)


func test_salvage_without_the_engraver_gives_no_xp() -> void:
	assert_eq(_s.skills.add_xp(E, 500), 0)
	assert_eq(_d.xp_max(E), 0)


func test_unlearn_clears_the_xp() -> void:
	_d.learn(E)
	_s.skills.add_xp(E, 300)
	assert_true(_d.unlearn(E).ok)
	assert_eq(_s.skills.get_xp(E), 0)


# --- the extra slot ------------------------------------------------------------------------------------------------------------

func _with_extra() -> void:
	TestFactory.learn_discipline(_s, &"forging", 2)
	TestFactory.learn_discipline(_s, &"hearthcraft", 2)
	TestFactory.learn_discipline(_s, E, 2)
	_d.from_save(_d.to_save().merged({"extra": ["riftbinding"]}, true))


func test_the_extra_slot_is_read_and_written() -> void:
	_with_extra()
	assert_true(_d.is_extra(E))
	assert_false(_d.is_extra(&"forging"))
	assert_eq(_d.to_save()["extra"], ["riftbinding"])
	assert_eq(_d.learned(&"artisan").size(), 3)


func test_free_slots_is_never_negative() -> void:
	_with_extra()
	assert_eq(_d.free_slots(&"artisan"), 0)
	assert_eq(_d.learn(&"woodwright").reason, Reasons.DISCIPLINE_SLOTS_FULL)


func test_unlearning_a_normal_production_ends_the_extra_slot() -> void:
	_with_extra()
	assert_true(_d.unlearn(&"forging").ok)
	assert_false(_d.is_extra(E))
	assert_eq(_d.to_save()["extra"], [])
	assert_eq(_d.free_slots(&"artisan"), 0)


func test_unlearning_the_extra_one_removes_it() -> void:
	_with_extra()
	assert_true(_d.unlearn(E).ok)
	assert_eq(_d.to_save()["extra"], [])
	assert_eq(_d.free_slots(&"artisan"), 0)


func test_an_extra_that_is_not_needed_is_dropped_on_load() -> void:
	_d.from_save({"learned": {"forging": 2, "riftbinding": 1}, "recipes": [], "extra": ["riftbinding"]})
	assert_true(_d.is_learned(E))
	assert_false(_d.is_extra(E), "within the limit: no extra slot")


func test_a_bad_extra_is_tolerated() -> void:
	_d.from_save({"learned": {"forging": 2}, "recipes": [], "extra": ["riftbinding", "nope", "forestry", 5]})
	assert_eq(_d.to_save()["extra"], [])
	_d.from_save({"learned": {"forging": 2}, "recipes": [], "extra": "oops"})
	assert_eq(_d.to_save()["extra"], [])
	_d.from_save({"learned": {"forging": 2}})
	assert_eq(_d.to_save()["extra"], [], "an older save without the key")


func test_a_third_production_beyond_the_extra_is_dropped() -> void:
	_d.from_save({"learned": {"forging": 1, "hearthcraft": 1, "woodwright": 1, "riftbinding": 1}, "recipes": [], "extra": ["riftbinding"]})
	assert_eq(_d.learned(&"artisan"), [&"forging", &"hearthcraft", &"woodwright"] as Array[StringName], "max + the extra, the first by order")
	assert_eq(_d.to_save()["extra"], [], "the extra one was dropped, no extra slot is left")


func test_new_game_has_no_extra() -> void:
	_with_extra()
	_d.new_game()
	assert_false(_d.is_extra(E))
	assert_eq(_d.to_save()["extra"], [])


# --- a skill that is not a discipline (fixtures) ---------------------------------------------------------------------------

func test_a_skill_that_is_not_a_discipline_is_refused() -> void:
	var s: GameSession = autofree(TestFactory.session_no_kit(1, TestFactory.fixture_data()))
	var d: Disciplines = s.disciplines
	assert_true(d.is_learned(E), "not a discipline: always usable")
	assert_eq(d.category_of(E), &"")
	assert_eq(d.next_grade_cost(E), -1)
	assert_eq(d.learn(E).reason, Reasons.NOT_A_DISCIPLINE)
	assert_eq(d.train(E).reason, Reasons.NOT_A_DISCIPLINE)
	assert_eq(d.unlearn(E).reason, Reasons.NOT_A_DISCIPLINE)
