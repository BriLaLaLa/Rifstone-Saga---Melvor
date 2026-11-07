extends GutTest
## RiftAltar: sockets by Riftbinding level (1, 20, 40, 60, 80), socketing, destroying, unique, modifiers, save.
## Uses the fixture infusion test_infusion (skill_interval_pct -3, unique) and the real rift.sockets.

const INF: StringName = &"test_infusion"
const STAT: StringName = &"skill_interval_pct"

var _session: GameSession = null
var _rift: RiftAltar = null


func before_each() -> void:
	_session = autofree(TestFactory.session())
	_rift = _session.rift
	TestFactory.give(_session, INF, 3)


func _total() -> float:
	return _session.modifiers.total(STAT, ModifierContext.for_skill(&"forestry"))


func _level_to(level: int) -> void:
	_session.skills.add_xp(RiftAltar.SKILL, 100000000)
	assert(_session.skills.get_level(RiftAltar.SKILL) >= level)


func test_socket_total_and_unlocks() -> void:
	assert_eq(_rift.socket_total(), 5)
	assert_true(_rift.is_unlocked(0))
	assert_false(_rift.is_unlocked(1))
	assert_false(_rift.is_unlocked(5))
	assert_false(_rift.is_unlocked(-1))


func test_all_unlocked_at_high_level() -> void:
	_level_to(80)
	for i: int in 5:
		assert_true(_rift.is_unlocked(i), "socket %d" % i)


func test_socket_takes_item_and_applies_modifier() -> void:
	var r: CommandResult = _rift.socket(0, INF)
	assert_true(r.ok)
	assert_eq(_rift.get_socket(0), INF)
	assert_eq(_session.bank.get_count(INF), 2)
	assert_eq(_total(), -3.0)


func test_socket_emits_event() -> void:
	watch_signals(_session.events)
	_rift.socket(0, INF)
	assert_signal_emitted_with_parameters(_session.events, "infusion_socketed", [0, INF])


func test_locked_socket() -> void:
	var r: CommandResult = _rift.socket(1, INF)
	assert_false(r.ok)
	assert_eq(r.reason, Reasons.SOCKET_LOCKED)
	assert_eq(_session.bank.get_count(INF), 3)
	assert_eq(_rift.socket(9, INF).reason, Reasons.SOCKET_LOCKED)


func test_occupied_socket() -> void:
	_rift.socket(0, INF)
	assert_eq(_rift.socket(0, INF).reason, Reasons.SOCKET_OCCUPIED)


func test_not_an_infusion() -> void:
	assert_eq(_rift.socket(0, &"no_such_item").reason, Reasons.NOT_EQUIPPABLE)
	assert_eq(_rift.socket(0, &"rift_shard").reason, Reasons.NOT_EQUIPPABLE)


func test_not_enough_items() -> void:
	_session.bank.remove(INF, 3)
	var r: CommandResult = _rift.socket(0, INF)
	assert_false(r.ok)
	assert_eq(r.reason, Reasons.NOT_ENOUGH_ITEMS)
	assert_eq(_rift.get_socket(0), &"")


func test_unique_only_once() -> void:
	_level_to(20)
	assert_true(_rift.socket(0, INF).ok)
	var r: CommandResult = _rift.socket(1, INF)
	assert_eq(r.reason, Reasons.REQUIREMENT_NOT_MET)
	assert_eq(_session.bank.get_count(INF), 2)


func test_clear_destroys_and_removes_modifier() -> void:
	_rift.socket(0, INF)
	watch_signals(_session.events)
	assert_true(_rift.clear_socket(0).ok)
	assert_eq(_rift.get_socket(0), &"")
	assert_eq(_session.bank.get_count(INF), 2)
	assert_eq(_total(), 0.0)
	assert_signal_emitted_with_parameters(_session.events, "infusion_removed", [0, INF])


func test_clear_empty_socket() -> void:
	assert_eq(_rift.clear_socket(0).reason, Reasons.SLOT_EMPTY)
	assert_eq(_rift.clear_socket(7).reason, Reasons.SLOT_EMPTY)


func test_save_round_trip_rebuilds_modifiers() -> void:
	_rift.socket(0, INF)
	var saved: Dictionary = _rift.to_save()
	assert_eq(saved, {"sockets": ["test_infusion", "", "", "", ""]})
	var other: GameSession = autofree(TestFactory.session())
	other.rift.from_save(saved)
	other.rift.rebuild_modifiers()
	assert_eq(other.rift.get_socket(0), INF)
	assert_eq(other.modifiers.total(STAT, ModifierContext.for_skill(&"forestry")), -3.0)


func test_from_save_tolerant() -> void:
	_rift.from_save({"sockets": ["no_such", "test_infusion", 5]})
	assert_eq(_rift.get_socket(0), &"")
	assert_eq(_rift.get_socket(1), INF)
	_rift.from_save({"sockets": "bad"})
	assert_eq(_rift.get_socket(1), &"")
	_rift.from_save({})
	assert_eq(_rift.socket_total(), 5)


func test_new_game_clears() -> void:
	_rift.socket(0, INF)
	_rift.new_game()
	_rift.rebuild_modifiers()
	assert_eq(_rift.get_socket(0), &"")
	assert_eq(_total(), 0.0)
