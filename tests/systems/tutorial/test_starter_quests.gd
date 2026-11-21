extends GutTest
## StarterQuests (docs/05_INTERFACES_M30.md §5.42) on the fixture quests: reach_level_2 (measure, money + xp), kill_two (event x2, money),
## eat_once (event, items).

var _s: GameSession
var _q: StarterQuests


func before_each() -> void:
	_s = autofree(TestFactory.session())
	_q = _s.tutorial.starter
	watch_signals(_s.events)


func _kill(n: int) -> void:
	for i: int in n:
		_s.events.monster_killed.emit(i, &"test_monster_a")


func _listeners(sig: Signal) -> int:
	var n: int = 0
	for c: Dictionary in sig.get_connections():
		if (c["callable"] as Callable).get_object() == _q:
			n += 1
	return n


func test_lists_are_in_file_order() -> void:
	assert_eq(_q.total(), 3)
	assert_eq(_q.next_open().id, &"reach_level_2")
	assert_eq(_q.claimable().size(), 0)
	assert_eq(_q.claimed_count(), 0)
	assert_eq(_q.target(&"kill_two"), 2)
	assert_eq(_q.target(&"reach_level_2"), 2)


func test_inactive_during_the_tutorial() -> void:
	var s: GameSession = autofree(TestFactory.session(1234, null, false, true))
	for i: int in 5:
		s.events.monster_killed.emit(i, &"test_monster_a")
	assert_false(s.tutorial.starter.is_enabled())
	assert_eq(s.tutorial.starter.progress(&"kill_two"), 0)
	assert_eq(s.tutorial.starter.can_claim(&"kill_two").reason, Reasons.TUTORIAL_INACTIVE)
	assert_eq(s.tutorial.starter.can_claim(&"nope").reason, Reasons.UNKNOWN_ID)


func test_a_counted_event_goes_up_and_signals() -> void:
	_kill(1)
	assert_eq(_q.progress(&"kill_two"), 1)
	assert_false(_q.is_complete(&"kill_two"))
	assert_signal_emit_count(_s.events, "starter_quests_changed", 1)
	_kill(3)
	assert_eq(_q.progress(&"kill_two"), 2, "capped to count")
	assert_true(_q.is_complete(&"kill_two"))
	assert_signal_emit_count(_s.events, "starter_quest_completed", 1)
	assert_signal_emitted_with_parameters(_s.events, "starter_quest_completed", [&"kill_two"])
	assert_eq(_q.can_claim(&"kill_two").ok, true)


func test_a_measure_is_complete_when_true_and_announced_once() -> void:
	TestFactory.set_character_level(_s, 2)
	assert_true(_q.is_complete(&"reach_level_2"))
	assert_eq(_q.progress(&"reach_level_2"), 2)
	TestFactory.set_character_level(_s, 4)
	assert_eq(_q.progress(&"reach_level_2"), 2, "min(value, gte)")
	assert_signal_emit_count(_s.events, "starter_quest_completed", 1)
	assert_eq(_listeners(_s.events.character_level_up), 0, "the measure is not reread once announced")


func test_a_measure_already_true_is_claimable_at_load_without_a_signal() -> void:
	TestFactory.set_character_level(_s, 3)
	var saved: Dictionary = _s.to_save(0)
	var other: GameSession = autofree(TestFactory.session(9))
	watch_signals(other.events)
	assert_true(other.from_save(saved).ok)
	assert_true(other.tutorial.starter.is_complete(&"reach_level_2"))
	assert_eq(other.tutorial.starter.claimable().size(), 1)
	assert_signal_not_emitted(other.events, "starter_quest_completed")
	assert_signal_not_emitted(other.events, "starter_quests_changed")


func test_claim_pays_xp_and_posts_one_message_once() -> void:
	TestFactory.set_character_level(_s, 2)
	var xp_before: int = _s.character.get_xp()
	assert_true(_q.claim(&"reach_level_2").ok)
	assert_gt(_s.character.get_xp(), xp_before)
	assert_eq(_s.mail.count(), 1)
	var m: Dictionary = _s.mail.messages()[0]
	assert_eq(m["kind"], &"starter_reward")
	assert_eq(m["money"], 1500)
	assert_true(_q.is_claimed(&"reach_level_2"))
	assert_eq(_q.claimed_count(), 1)
	assert_eq(_q.claim(&"reach_level_2").reason, Reasons.ALREADY_CLAIMED)
	assert_eq(_s.mail.count(), 1)
	assert_signal_emitted(_s.events, "starter_quests_changed")
	assert_eq(_q.next_open().id, &"kill_two")


func test_rewards_never_merge_and_items_go_in_the_attachment() -> void:
	_kill(2)
	_s.events.food_eaten.emit(&"seared_brookfin", 5)
	assert_true(_q.claim(&"kill_two").ok)
	assert_true(_q.claim(&"eat_once").ok)
	assert_eq(_s.mail.count(), 2)
	var found_items: bool = false
	for m: Dictionary in _s.mail.messages():
		found_items = found_items or ((m["items"] as Array).size() == 1 and int(m["money"]) == 0)
	assert_true(found_items)


func test_an_incomplete_quest_is_refused() -> void:
	assert_eq(_q.claim(&"kill_two").reason, Reasons.QUEST_INCOMPLETE)
	assert_eq(_s.mail.count(), 0)


func test_a_full_mailbox_refuses_and_changes_nothing() -> void:
	_kill(2)
	TestFactory.set_character_level(_s, 2)
	for i: int in _s.mail.capacity():
		_s.mail.post(&"auction_sold", {"item": &"test_twig", "qty": 1, "listing": i + 1, "money": 1})
	var xp_before: int = _s.character.get_xp()
	var saved: Dictionary = _q.to_save()
	assert_eq(_q.claim(&"reach_level_2").reason, Reasons.MAILBOX_FULL)
	assert_eq(_q.claim(&"kill_two").reason, Reasons.MAILBOX_FULL)
	assert_eq(_s.character.get_xp(), xp_before)
	assert_eq(_q.to_save(), saved)
	assert_eq(_s.mail.count(), _s.mail.capacity())


func test_claimable_and_next_open_follow_file_order() -> void:
	_s.events.food_eaten.emit(&"seared_brookfin", 5)
	_kill(2)
	var ids: Array[StringName] = []
	for def: StarterQuestDef in _q.claimable():
		ids.append(def.id)
	assert_eq(ids, [&"kill_two", &"eat_once"])
	assert_eq(_q.next_open().id, &"reach_level_2")
	_q.claim(&"kill_two")
	_q.claim(&"eat_once")
	assert_eq(_q.next_open().id, &"reach_level_2")


func test_an_event_is_counted_only_after_the_activation_and_is_saved() -> void:
	var s: GameSession = autofree(TestFactory.session(1234, null, false, true))
	for i: int in 3:
		s.events.monster_killed.emit(i, &"test_monster_a")
	s.tutorial.from_save({"completed": true, "step": "", "visited": []})
	assert_eq(s.tutorial.starter.progress(&"kill_two"), 0, "kills before the activation do not count")
	s.events.monster_killed.emit(0, &"test_monster_a")
	assert_eq(s.tutorial.starter.progress(&"kill_two"), 1)
	var saved: Dictionary = s.tutorial.to_save()
	assert_eq((saved["starter"] as Dictionary)["progress"], {"kill_two": 1})
	var other: GameSession = autofree(TestFactory.session(3))
	other.tutorial.from_save(JSON.parse_string(JSON.stringify(saved)) as Dictionary)
	assert_eq(other.tutorial.starter.progress(&"kill_two"), 1)
	other.events.monster_killed.emit(0, &"test_monster_a")
	assert_true(other.tutorial.starter.is_complete(&"kill_two"))


func test_the_events_of_a_finished_quest_are_not_listened_to_any_more() -> void:
	assert_eq(_listeners(_s.events.food_eaten), 1)
	_s.events.food_eaten.emit(&"seared_brookfin", 5)
	assert_eq(_listeners(_s.events.food_eaten), 0)
	_s.events.food_eaten.emit(&"seared_brookfin", 5)
	assert_signal_emit_count(_s.events, "starter_quest_completed", 1)
