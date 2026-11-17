extends GutTest
## RiftAltar with the Incisore learned from a Trainer (M25-11; docs/01_GDD_M25.md §37.1): a socket that closes again keeps its
## rune but switched off, `is_active`, and the sources `rift_socket:<i>`. Real data.

const RUNE: StringName = &"inf_swift_hands"
const E: StringName = &"riftbinding"
const STAT: StringName = &"skill_interval_pct"

var _s: GameSession = null


func before_each() -> void:
	_s = autofree(TestFactory.session_no_kit(1, TestFactory.real_data()))
	_s.wallet.add_gold(10000000)
	TestFactory.give(_s, RUNE, 5)
	TestFactory.learn_discipline(_s, E, 5)
	_s.skills.add_xp(E, TestFactory.real_data().xp_table().xp_for_level(25))


func _total() -> float:
	return _s.modifiers.total(STAT, ModifierContext.for_skill(&"forestry"))


func test_a_socket_is_active_when_it_has_a_rune_and_is_unlocked() -> void:
	assert_false(_s.rift.is_active(1), "empty")
	assert_true(_s.rift.socket(1, RUNE).ok)
	assert_true(_s.rift.is_active(1))
	assert_false(_s.rift.is_active(2), "empty and locked")
	assert_false(_s.rift.is_active(-1))
	assert_eq(_total(), -3.0)


func test_unlearning_the_engraver_switches_the_rune_off_but_keeps_it() -> void:
	assert_true(_s.rift.socket(0, RUNE).ok)
	assert_true(_s.rift.socket(1, RUNE).ok)
	assert_eq(_total(), -6.0)
	assert_true(_s.disciplines.unlearn(E).ok)
	assert_eq(_s.rift.get_socket(1), RUNE, "the rune stays")
	assert_false(_s.rift.is_unlocked(1))
	assert_false(_s.rift.is_active(1))
	assert_true(_s.rift.is_active(0), "the first socket is always unlocked")
	assert_eq(_total(), -3.0, "only the first socket counts")
	assert_false(_s.modifiers.has_source(&"rift_socket:1"))
	assert_true(_s.modifiers.has_source(&"rift_socket:0"))


func test_the_rune_comes_back_on_when_the_level_is_reached_again() -> void:
	_s.rift.socket(1, RUNE)
	_s.disciplines.unlearn(E)
	assert_eq(_total(), 0.0)
	TestFactory.learn_discipline(_s, E, 5)
	_s.skills.add_xp(E, TestFactory.real_data().xp_table().xp_for_level(20))
	assert_true(_s.rift.is_active(1))
	assert_eq(_total(), -3.0)


func test_a_closed_socket_cannot_be_filled_but_can_be_cleared() -> void:
	_s.rift.socket(1, RUNE)
	_s.disciplines.unlearn(E)
	assert_eq(_s.rift.socket(1, RUNE).reason, Reasons.SOCKET_LOCKED)
	watch_signals(_s.events)
	assert_true(_s.rift.clear_socket(1).ok)
	assert_eq(_s.rift.get_socket(1), &"")
	assert_signal_emitted_with_parameters(_s.events, "infusion_removed", [1, RUNE])


func test_the_save_keeps_a_rune_in_a_closed_socket() -> void:
	_s.rift.socket(1, RUNE)
	_s.disciplines.unlearn(E)
	var saved: Dictionary = _s.rift.to_save()
	_s.rift.new_game()
	_s.rift.from_save(saved)
	assert_eq(_s.rift.get_socket(1), RUNE)
	_s.rift.rebuild_modifiers()
	assert_false(_s.rift.is_active(1))
	assert_eq(_total(), 0.0)
