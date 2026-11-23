extends GutTest
## M35-D F-195: `Disciplines.focus_of/set_focus` (refusals, removal, signal), unlearning, and the save. Real data (Minatore = quarrying:
## Rame level 1, Ferro 10, Ferro scuro 20, Ferro nero 30, Argento runico 45, Ossidiana 60).

const QUARRYING: StringName = &"quarrying"
const COPPER: StringName = &"quarry_emberbronze"
const IRON: StringName = &"quarry_ashlead"
const SILVER: StringName = &"quarry_glimmerite"
const OBSIDIAN: StringName = &"quarry_palecinnabar"

var _s: GameSession = null
var _changes: Array = []


func before_each() -> void:
	_s = autofree(TestFactory.session_no_kit(31, TestFactory.real_data()))
	_s.disciplines.new_game()
	_s.events.gather_focus_changed.connect(func(skill: StringName, action: StringName) -> void: _changes.append([skill, action]))
	_changes.clear()


func _learn_at(level: int) -> void:
	TestFactory.learn_discipline(_s, QUARRYING)
	TestFactory.set_level(_s, QUARRYING, level)


func test_automatico_is_the_default() -> void:
	assert_eq(_s.disciplines.focus_of(QUARRYING), &"")


func test_set_focus_refusals_in_order() -> void:
	assert_eq(_s.disciplines.set_focus(QUARRYING, &"no_such_action").reason, Reasons.UNKNOWN_ID)
	assert_eq(_s.disciplines.set_focus(QUARRYING, &"cut_redbirch").reason, Reasons.UNKNOWN_ID, "an action of another skill")
	assert_eq(_s.disciplines.set_focus(&"forging", &"smelt_emberbronze").reason, Reasons.UNKNOWN_ID, "not a gathering discipline")
	assert_eq(_s.disciplines.set_focus(QUARRYING, COPPER).reason, Reasons.NOT_LEARNED)
	_learn_at(45)
	assert_eq(_s.disciplines.set_focus(QUARRYING, OBSIDIAN).reason, Reasons.LEVEL_TOO_LOW)
	assert_eq(_s.disciplines.focus_of(QUARRYING), &"")
	assert_eq(_changes.size(), 0, "a refusal emits nothing")


func test_set_focus_and_clear() -> void:
	_learn_at(45)
	assert_true(_s.disciplines.set_focus(QUARRYING, COPPER).ok)
	assert_eq(_s.disciplines.focus_of(QUARRYING), COPPER)
	assert_true(_s.disciplines.set_focus(QUARRYING, SILVER).ok, "the level of the resource <= the level of the discipline")
	assert_eq(_changes, [[QUARRYING, COPPER], [QUARRYING, SILVER]])
	assert_true(_s.disciplines.set_focus(QUARRYING, SILVER).ok)
	assert_eq(_changes.size(), 2, "the same choice again: no signal")
	assert_true(_s.disciplines.set_focus(QUARRYING, &"").ok)
	assert_eq(_s.disciplines.focus_of(QUARRYING), &"")
	assert_eq(_changes.back(), [QUARRYING, &""])
	assert_true(_s.disciplines.set_focus(QUARRYING, &"").ok, "clearing is always ok")
	assert_eq(_changes.size(), 3, "...and silent when there was no choice")


func test_clearing_works_even_when_not_learned() -> void:
	assert_true(_s.disciplines.set_focus(QUARRYING, &"").ok)


func test_unlearn_removes_the_choice() -> void:
	_learn_at(10)
	assert_true(_s.disciplines.set_focus(QUARRYING, IRON).ok)
	_s.wallet.add_gold(10_000_000)
	_changes.clear()
	assert_true(_s.disciplines.unlearn(QUARRYING).ok)
	assert_eq(_s.disciplines.focus_of(QUARRYING), &"")
	assert_eq(_changes, [[QUARRYING, &""]])


func test_the_choice_survives_a_level_up() -> void:
	_learn_at(10)
	assert_true(_s.disciplines.set_focus(QUARRYING, IRON).ok)
	TestFactory.set_level(_s, QUARRYING, 30)
	assert_eq(_s.disciplines.focus_of(QUARRYING), IRON)


func test_save_round_trip_and_no_signal() -> void:
	_learn_at(45)
	assert_true(_s.disciplines.set_focus(QUARRYING, SILVER).ok)
	var saved: Dictionary = _s.disciplines.to_save()
	assert_eq(saved["focus"], {"quarrying": "quarry_glimmerite"})
	_changes.clear()
	_s.disciplines.from_save(saved)
	assert_eq(_s.disciplines.focus_of(QUARRYING), SILVER)
	_s.disciplines.new_game()
	assert_eq(_s.disciplines.focus_of(QUARRYING), &"")
	assert_eq(_changes.size(), 0, "from_save and new_game never emit")


func test_invalid_entries_are_ignored() -> void:
	_learn_at(45)
	var saved: Dictionary = _s.disciplines.to_save()
	saved["focus"] = {"quarrying": "cut_redbirch", "forestry": "cut_redbirch", "forging": "smelt_emberbronze", "angling": "no_such", "nope": "x"}
	_s.disciplines.from_save(saved)
	assert_eq(_s.disciplines.focus_of(QUARRYING), &"", "an action of another skill")
	assert_eq(_s.disciplines.focus_of(&"forestry"), &"", "a discipline that is not learned")
	assert_eq(_s.disciplines.focus_of(&"forging"), &"", "not a gathering discipline")
	saved["focus"] = "not a dictionary"
	_s.disciplines.from_save(saved)
	assert_eq(_s.disciplines.to_save()["focus"], {})
	saved.erase("focus")
	_s.disciplines.from_save(saved)
	assert_eq(_s.disciplines.focus_of(QUARRYING), &"", "an old save without the field")
