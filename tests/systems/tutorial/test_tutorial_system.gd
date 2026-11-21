extends GutTest
## TutorialSystem (docs/05_INTERFACES_M30.md §5.41) on the fixture steps: intro (ack) -> kills (monster_killed x3) -> mail (mail_collected >= 1,
## gift in on_enter) -> outro (ack).

var _s: GameSession


func before_each() -> void:
	_s = autofree(TestFactory.session(1234, null, false, true))
	watch_signals(_s.events)


func _kill(n: int = 1, monster: StringName = &"test_monster_a") -> void:
	for i: int in n:
		_s.events.monster_killed.emit(i, monster)


func _to_mail_step() -> void:
	assert_true(_s.tutorial.acknowledge().ok)
	_kill(3)


func test_new_game_is_active_at_step_zero_with_nothing_visited() -> void:
	var t: TutorialSystem = _s.tutorial
	assert_true(t.is_active())
	assert_false(t.is_completed())
	assert_eq(t.step_index(), 0)
	assert_eq(t.step_count(), 4)
	assert_eq(t.current_step().id, &"intro")
	assert_false(t.has_visited(&"character"))
	assert_false(t.starter.is_enabled())
	assert_eq(t.starter.claimable().size(), 0)
	assert_signal_not_emitted(_s.events, "tutorial_step_changed")


func test_the_test_factory_completes_the_tutorial_by_default() -> void:
	var s: GameSession = autofree(TestFactory.session())
	assert_true(s.tutorial.is_completed())
	assert_eq(s.tutorial.step_index(), s.tutorial.step_count())
	assert_null(s.tutorial.current_step())
	assert_true(s.tutorial.starter.is_enabled())


func test_ack_advances_and_signals() -> void:
	assert_true(_s.tutorial.can_acknowledge())
	assert_true(_s.tutorial.acknowledge().ok)
	assert_eq(_s.tutorial.current_step().id, &"kills")
	assert_signal_emitted_with_parameters(_s.events, "tutorial_step_changed", [&"kills", 1, 4])
	assert_false(_s.tutorial.can_acknowledge())
	assert_eq(_s.tutorial.acknowledge().reason, Reasons.WRONG_STEP)


func test_event_with_filter_and_count_reports_progress() -> void:
	_s.tutorial.acknowledge()
	assert_eq(_s.tutorial.step_target_count(), 3)
	_kill(1, &"not_in_the_filter")
	assert_eq(_s.tutorial.step_progress(), 0, "the filter keeps other monsters out")
	_kill(2, &"test_monster_b")
	assert_eq(_s.tutorial.step_progress(), 2)
	assert_signal_emit_count(_s.events, "tutorial_progress", 2)
	assert_signal_emitted_with_parameters(_s.events, "tutorial_progress", [&"kills", 2, 3])
	assert_eq(_s.tutorial.current_step().id, &"kills")
	_kill(1)
	assert_eq(_s.tutorial.current_step().id, &"mail")


func test_events_before_the_step_do_not_count() -> void:
	_kill(5)
	_s.tutorial.acknowledge()
	assert_eq(_s.tutorial.step_progress(), 0)
	assert_eq(_s.tutorial.current_step().id, &"kills")


func test_on_enter_gift_arrives_once_by_mail() -> void:
	assert_eq(_s.mail.count(), 0)
	_to_mail_step()
	assert_eq(_s.mail.count(), 1)
	var m: Dictionary = _s.mail.messages()[0]
	assert_eq(m["kind"], &"tutorial_gift")
	assert_eq(m["money"], 3000)
	_kill(5)
	assert_eq(_s.mail.count(), 1)


func test_the_gift_arrives_even_with_a_full_mailbox() -> void:
	var capacity: int = _s.mail.capacity()
	for i: int in capacity:
		_s.mail.post(&"auction_sold", {"item": &"test_twig", "qty": 1, "listing": i + 1, "money": 1})
	assert_true(_s.mail.is_full())
	_to_mail_step()
	assert_eq(_s.mail.count(), capacity + 1)


func test_metric_is_reread_on_the_right_signal_and_ends_the_step() -> void:
	_to_mail_step()
	assert_eq(_s.tutorial.current_step().id, &"mail")
	assert_eq(_s.mail.collect(_s.mail.messages()[0]["id"]).ok, true)
	assert_eq(_s.tutorial.current_step().id, &"outro")


func test_metric_already_true_on_entry_ends_the_step_at_once() -> void:
	var id: int = _s.mail.post(&"starter_reward", {"money": 5})
	assert_true(_s.mail.collect(id).ok)
	_to_mail_step()
	assert_eq(_s.tutorial.current_step().id, &"outro", "mail_collected was already >= 1")
	assert_eq(_s.mail.count(), 1, "the gift was delivered anyway")


func test_the_last_ack_completes_and_activates_the_starter_quests() -> void:
	_to_mail_step()
	_s.mail.collect_all()
	assert_true(_s.tutorial.acknowledge().ok)
	assert_true(_s.tutorial.is_completed())
	assert_eq(_s.tutorial.step_index(), 4)
	assert_signal_emit_count(_s.events, "tutorial_completed", 1)
	assert_signal_emitted(_s.events, "starter_quests_changed")
	assert_true(_s.tutorial.starter.is_enabled())
	assert_eq(_s.tutorial.acknowledge().reason, Reasons.TUTORIAL_INACTIVE)
	assert_eq(_s.tutorial.skip_step().reason, Reasons.TUTORIAL_INACTIVE)


func test_the_valve_opens_after_stuck_ms_of_game_time() -> void:
	assert_false(_s.tutorial.can_skip_step(), "an ack step never offers the valve")
	_s.tutorial.acknowledge()
	assert_false(_s.tutorial.can_skip_step())
	assert_eq(_s.tutorial.skip_step().reason, Reasons.NOT_STUCK)
	var stuck: int = _s.data.tutorial_stuck_ms()
	_s.advance(stuck - 100)
	assert_false(_s.tutorial.can_skip_step())
	_s.advance(100)
	assert_true(_s.tutorial.can_skip_step())
	assert_true(_s.tutorial.skip_step().ok)
	assert_eq(_s.tutorial.current_step().id, &"mail")
	assert_signal_emitted_with_parameters(_s.events, "tutorial_step_changed", [&"mail", 2, 4])
	assert_false(_s.tutorial.can_skip_step(), "the clock restarts at the new step")


func test_page_rules() -> void:
	var t: TutorialSystem = _s.tutorial
	assert_true(t.is_page_open(&"combat"), "a step without a page opens every page")
	assert_true(t.is_page_open(&"guide"))
	t.acknowledge()
	assert_eq(t.required_route(), &"combat")
	assert_true(t.is_page_open(&"combat"))
	assert_true(t.is_page_open(&"guide"), "always open")
	assert_true(t.is_page_open(&"help"))
	assert_false(t.is_page_open(&"mail"), "a future page is closed")
	assert_false(t.is_page_open(&"bank"))
	_kill(3)
	assert_true(t.is_page_open(&"combat"), "pages already reached stay open")
	assert_true(t.is_page_open(&"mail"))
	t.from_save({"completed": true})
	assert_true(t.is_page_open(&"bank"))


func test_needs_navigation_follows_the_notified_page() -> void:
	var t: TutorialSystem = _s.tutorial
	t.acknowledge()
	assert_true(t.needs_navigation())
	t.notify_page_opened(&"bank")
	assert_true(t.needs_navigation())
	assert_eq(t.current_page(), &"bank")
	t.notify_page_opened(&"combat")
	assert_false(t.needs_navigation())
	assert_true(t.has_visited(&"bank") and t.has_visited(&"combat"))
	t.notify_page_opened(&"skill:forestry")
	assert_eq(t.current_page(), &"skill")
	assert_true(t.has_visited(&"skill:forestry"))
	assert_eq(t.step_index(), 1, "a visit never advances by itself")


func test_notify_page_opened_keeps_recording_after_the_tutorial() -> void:
	_s.tutorial.from_save({"completed": true})
	assert_false(_s.tutorial.has_visited(&"guide"))
	_s.tutorial.notify_page_opened(&"guide")
	assert_true(_s.tutorial.has_visited(&"guide"))
	assert_eq(_s.tutorial.required_route(), &"")
	assert_false(_s.tutorial.needs_navigation())


func _listeners(sig: Signal) -> int:
	var n: int = 0
	for c: Dictionary in sig.get_connections():
		if (c["callable"] as Callable).get_object() == _s.tutorial:
			n += 1
	return n


func test_the_listeners_of_a_left_step_are_disconnected() -> void:
	assert_eq(_listeners(_s.events.monster_killed), 0, "the ack step listens to nothing")
	_s.tutorial.acknowledge()
	assert_eq(_listeners(_s.events.monster_killed), 1)
	_kill(3)
	assert_eq(_listeners(_s.events.monster_killed), 0, "the mail step does not listen to kills")
	assert_eq(_listeners(_s.events.mail_changed), 1, "it listens to the signal of its measure")
