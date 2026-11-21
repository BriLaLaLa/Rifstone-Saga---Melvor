extends GutTest
## M32: a discipline with `free_slot` (the Cook) is always learnable and does not count in the slots of its category.

const C: StringName = &"hearthcraft"

var _s: GameSession = null
var _d: Disciplines = null


func before_each() -> void:
	_s = autofree(TestFactory.session_no_kit(1, TestFactory.real_data()))
	_d = _s.disciplines
	_d.new_game()
	_s.wallet.add_gold(10000000)


func test_the_cook_is_learnable_with_two_productions_taken() -> void:
	assert_true(_d.is_free_slot(C))
	assert_false(_d.is_free_slot(&"forging"))
	assert_true(_d.learn(&"forging").ok)
	assert_true(_d.learn(&"woodwright").ok)
	assert_eq(_d.free_slots(&"artisan"), 0)
	assert_true(_d.can_learn(C).ok)
	assert_true(_d.learn(C).ok)
	assert_eq(_d.grade(C), 1)


func test_the_other_productions_stay_blocked_at_the_third() -> void:
	_d.learn(C)
	_d.learn(&"forging")
	_d.learn(&"woodwright")
	assert_eq(_d.learn(&"riftbinding").reason, Reasons.DISCIPLINE_SLOTS_FULL)


func test_free_slots_does_not_change_with_the_cook() -> void:
	var before: int = _d.free_slots(&"artisan")
	_d.learn(C)
	assert_eq(_d.free_slots(&"artisan"), before)
	assert_eq(_d.free_slots(&"gathering"), 2)


func test_unlearn_and_relearn_are_consistent() -> void:
	_d.learn(&"forging")
	_d.learn(C)
	assert_eq(_d.free_slots(&"artisan"), 1)
	assert_true(_d.unlearn(C).ok)
	assert_eq(_d.free_slots(&"artisan"), 1)
	assert_true(_d.learn(C).ok)
	assert_eq(_d.free_slots(&"artisan"), 1)


func test_a_v12_save_with_the_cook_frees_a_slot() -> void:
	_d.from_save({"learned": {"forging": 1, "hearthcraft": 1, "woodwright": 1}, "recipes": [], "extra": []})
	assert_eq(_d.learned(&"artisan").size(), 3, "all three kept")
	assert_eq(_d.free_slots(&"artisan"), 0)
	_d.unlearn(&"forging")
	assert_eq(_d.free_slots(&"artisan"), 1)
	assert_eq(_d.to_save()["extra"], [])
