extends GutTest
## ToastManager (M1-17): signals of a fresh GameEvents become toasts; bank increases are grouped per item over
## UiStyle.TOAST_GROUP_MS; at most UiStyle.TOAST_MAX_VISIBLE toasts at once. Time comes from a fake clock and
## `_process` is driven with gut.simulate, so grouping and lifetime are deterministic.

const ITEM := &"test_log"
const OTHER_ITEM := &"test_ore"
const SKILL := &"test_skill"

var _events: GameEvents
var _manager: ToastManager
var _now_ms: int = 0


func before_each() -> void:
	_now_ms = 0
	_events = GameEvents.new()
	_manager = ToastManager.new()
	_manager.events = _events
	_manager.time_source = func() -> int: return _now_ms
	add_child(_manager)


func after_each() -> void:
	# The manager disconnects from the bus when it leaves the tree, so it goes first.
	_manager.free()
	_events.free()


func test_ten_bank_increases_in_one_second_make_one_toast_with_the_sum() -> void:
	for i: int in range(10):
		_now_ms = i * 100
		_events.bank_changed.emit(ITEM, i + 1, 1)
	_tick()
	assert_eq(_toasts().size(), 0, "no toast before the group window closes")
	_now_ms = UiStyle.TOAST_GROUP_MS
	_tick()
	assert_eq(_texts(), PackedStringArray(["+10 test_log"]))


func test_item_already_in_bank_plus_one_shows_plus_one() -> void:
	_events.bank_changed.emit(ITEM, 101, 1)
	_advance(UiStyle.TOAST_GROUP_MS)
	assert_eq(_texts(), PackedStringArray(["+1 test_log"]), "the delta counts, not the new total")


func test_deltas_are_summed_with_thousands_separator() -> void:
	_events.bank_changed.emit(ITEM, 1200, 1200)
	_events.bank_changed.emit(ITEM, 1250, 50)
	_advance(UiStyle.TOAST_GROUP_MS)
	assert_eq(_texts(), PackedStringArray(["+1.250 test_log"]))


func test_decreases_make_no_toast() -> void:
	_events.bank_changed.emit(ITEM, 5, 5)
	_advance(UiStyle.TOAST_GROUP_MS)
	_events.bank_changed.emit(ITEM, 2, -3)
	_events.bank_changed.emit(ITEM, 0, -2)
	_events.bank_changed.emit(ITEM, 0, 0)
	_advance(UiStyle.TOAST_GROUP_MS)
	assert_eq(_texts(), PackedStringArray(["+5 test_log"]), "only the increase is shown")


func test_decrease_inside_a_window_does_not_reduce_the_group() -> void:
	_events.bank_changed.emit(ITEM, 4, 4)
	_events.bank_changed.emit(ITEM, 1, -3)
	_events.bank_changed.emit(ITEM, 3, 2)
	_advance(UiStyle.TOAST_GROUP_MS)
	assert_eq(_texts(), PackedStringArray(["+6 test_log"]), "4 gained, 3 lost (ignored), 2 gained")


func test_groups_are_per_item() -> void:
	_events.bank_changed.emit(ITEM, 2, 2)
	_events.bank_changed.emit(OTHER_ITEM, 3, 3)
	_events.bank_changed.emit(ITEM, 5, 3)
	_advance(UiStyle.TOAST_GROUP_MS)
	assert_eq(_texts(), PackedStringArray(["+5 test_log", "+3 test_ore"]))


func test_increase_after_the_window_starts_a_new_group() -> void:
	_events.bank_changed.emit(ITEM, 1, 1)
	_now_ms = UiStyle.TOAST_GROUP_MS
	_events.bank_changed.emit(ITEM, 3, 2)
	assert_eq(_texts(), PackedStringArray(["+1 test_log"]), "the closed group is shown before the new one starts")
	_advance(UiStyle.TOAST_GROUP_MS)
	assert_eq(_texts(), PackedStringArray(["+1 test_log", "+2 test_log"]))


func test_name_resolver_gives_the_display_name() -> void:
	_manager.name_resolver = func(id: StringName) -> String: return "Nome di " + String(id)
	_events.bank_changed.emit(ITEM, 7, 7)
	_events.level_up.emit(SKILL, 12)
	_advance(UiStyle.TOAST_GROUP_MS)
	assert_eq(_texts(), PackedStringArray(["Nome di test_skill: livello 12", "+7 Nome di test_log"]))


func test_session_end_drops_open_groups() -> void:
	_events.bank_changed.emit(ITEM, 10, 10)
	_events.session_ended.emit(1)
	_advance(UiStyle.TOAST_GROUP_MS)
	assert_eq(_toasts().size(), 0, "the group of the ended session is not shown")
	_events.bank_changed.emit(ITEM, 4, 4)
	_advance(UiStyle.TOAST_GROUP_MS)
	assert_eq(_texts(), PackedStringArray(["+4 test_log"]))


func test_notification_requested_shows_the_text_with_its_kind() -> void:
	_events.notification_requested.emit("Salvataggio riuscito", &"warning")
	var toasts: Array[Toast] = _toasts()
	assert_eq(_texts(), PackedStringArray(["Salvataggio riuscito"]))
	assert_eq(_accent(toasts[0]), UiStyle.BAD, "warning accent")


func test_push_kinds_have_their_accent_colors() -> void:
	_manager.push("a", &"info")
	_manager.push("b", &"success")
	_manager.push("c", &"warning")
	var toasts: Array[Toast] = _toasts()
	assert_eq(_accent(toasts[0]), UiStyle.GOLD)
	assert_eq(_accent(toasts[1]), UiStyle.GOOD)
	assert_eq(_accent(toasts[2]), UiStyle.BAD)


func test_level_up_shows_skill_and_level() -> void:
	_events.level_up.emit(SKILL, 2)
	assert_eq(_texts(), PackedStringArray(["test_skill: livello 2"]))
	assert_eq(_accent(_toasts()[0]), UiStyle.GOOD)


func test_action_stopped_shows_the_reason() -> void:
	_events.action_stopped.emit(&"main", SKILL, Reasons.BANK_FULL)
	_events.action_stopped.emit(&"main", SKILL, Reasons.NOT_RUNNING)
	assert_eq(_texts(), PackedStringArray([
		"test_skill: azione fermata (bank piena)",
		"test_skill: azione fermata (interrotta)",
	]))
	assert_eq(_accent(_toasts()[0]), UiStyle.BAD)


func test_action_stopped_by_the_player_is_silent() -> void:
	_events.action_stopped.emit(&"main", SKILL, Reasons.STOPPED_BY_USER)
	_events.action_stopped.emit(&"main", SKILL, Reasons.REPLACED)
	assert_eq(_toasts().size(), 0)


func test_at_most_max_visible_toasts_and_the_rest_waits() -> void:
	for i: int in range(UiStyle.TOAST_MAX_VISIBLE + 2):
		_manager.push("t%d" % i, &"info")
	assert_eq(_toasts().size(), UiStyle.TOAST_MAX_VISIBLE)
	assert_eq(_texts()[0], "t0", "oldest first")


func test_expired_toast_leaves_and_the_next_one_shows() -> void:
	_manager.push("t0", &"info")
	_now_ms = 100
	for i: int in range(1, UiStyle.TOAST_MAX_VISIBLE + 1):
		_manager.push("t%d" % i, &"info")
	var first: Toast = _toasts()[0]
	_now_ms = UiStyle.TOAST_LIFETIME_MS
	_tick()
	assert_eq(_toasts().size(), UiStyle.TOAST_MAX_VISIBLE, "fading toast still counts, nothing spawned yet")
	await wait_for_signal(first.dismissed, 2.0, "first toast fades out")
	await wait_physics_frames(1)
	var texts: PackedStringArray = _texts()
	assert_eq(texts.size(), UiStyle.TOAST_MAX_VISIBLE)
	assert_false(texts.has("t0"), "expired toast is gone")
	assert_eq(texts[texts.size() - 1], "t%d" % UiStyle.TOAST_MAX_VISIBLE, "queued toast is shown")


func test_toast_stays_until_its_lifetime() -> void:
	_manager.push("resta", &"info")
	_advance(UiStyle.TOAST_LIFETIME_MS - 1)
	assert_eq(_texts(), PackedStringArray(["resta"]))


func test_disconnects_when_leaving_the_tree() -> void:
	remove_child(_manager)
	assert_eq(_events.bank_changed.get_connections().size(), 0)
	assert_eq(_events.notification_requested.get_connections().size(), 0)
	assert_eq(_events.level_up.get_connections().size(), 0)
	assert_eq(_events.action_stopped.get_connections().size(), 0)
	add_child(_manager)
	assert_eq(_events.bank_changed.get_connections().size(), 1, "reconnects on re-enter")


func _advance(ms: int) -> void:
	_now_ms += ms
	_tick()


func _tick() -> void:
	gut.simulate(_manager, 1, 0.0)


func _toasts() -> Array[Toast]:
	var out: Array[Toast] = []
	var stack: Node = _manager.get_node("Stack")
	for child: Node in stack.get_children():
		var toast: Toast = child as Toast
		if toast != null and not toast.is_queued_for_deletion():
			out.append(toast)
	return out


func _texts() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for toast: Toast in _toasts():
		out.append((toast.get_node("%MessageLabel") as Label).text)
	return out


func _accent(toast: Toast) -> Color:
	var sb: StyleBoxFlat = toast.get_theme_stylebox("panel") as StyleBoxFlat
	return sb.border_color if sb != null else Color.TRANSPARENT
