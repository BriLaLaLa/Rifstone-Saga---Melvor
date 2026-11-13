extends GutTest
## Quests (docs/05_INTERFACES.md §5.28): slots follow quest_slots, progress from the events, claim and abandon, save.
## Real data; numbers of docs/02_FORMULAS.md F-134/F-135 (character 1: tier 1 quests in file order).

var _session: GameSession
var _quests: Quests
var _changed: int = 0
var _progress_log: Array = []
var _completed_log: Array = []


func before_each() -> void:
	_start(TestFactory.real_data())


func _start(data: GameData) -> void:
	if _session != null:
		_session.free()
	_session = TestFactory.session_no_kit(5, data)
	add_child(_session)
	_quests = _session.quests
	_changed = 0
	_progress_log = []
	_completed_log = []
	_session.events.quests_changed.connect(func() -> void: _changed += 1)
	_session.events.quest_progress.connect(func(s: int, p: int, t: int) -> void: _progress_log.append([s, p, t]))
	_session.events.quest_completed.connect(func(id: StringName, s: int) -> void: _completed_log.append([id, s]))


func after_each() -> void:
	if _session != null:
		_session.free()
		_session = null


func _board(level: int) -> void:
	var mod: Modifier = Modifier.from_dict({"stat": "quest_slots", "value": float(level), "scope": "global"})
	_session.modifiers.set_source(&"test:board", [mod])


func _kill(count: int) -> void:
	for i: int in count:
		_session.events.monster_killed.emit(0, &"any")


func test_slots_follow_quest_slots() -> void:
	assert_eq(_quests.slot_count(), 0)
	assert_eq(_quests.quest_at(0), &"")
	assert_eq(_quests.can_claim(0).reason, Reasons.UNKNOWN_ID)
	_board(3)
	assert_eq(_quests.slot_count(), 3)
	assert_eq(_quests.quest_at(0), &"kill_any_t1")
	assert_eq(_quests.quest_at(1), &"gather_forestry_t1")
	assert_eq(_quests.quest_at(2), &"gather_quarrying_t1")
	assert_eq(_quests.quest_at(3), &"")
	assert_gt(_changed, 0)
	_board(5)
	assert_eq(_quests.slot_count(), 5)
	assert_eq(_quests.quest_at(3), &"gather_angling_t1")
	assert_eq(_quests.quest_at(4), &"craft_forging_t1")
	_board(20)
	assert_eq(_quests.slot_count(), 8, "capped by the stat maximum")


func test_refill_is_idempotent_and_silent_when_nothing_changes() -> void:
	_board(2)
	var before: int = _changed
	_quests.refill()
	_quests.refill()
	assert_eq(_changed, before)


func test_kill_progress_caps_at_the_target_and_completes_once() -> void:
	_board(1)
	assert_eq(_quests.target_at(0), 40)
	_kill(39)
	assert_eq(_quests.progress_at(0), 39)
	assert_false(_quests.is_complete(0))
	assert_eq(_completed_log.size(), 0)
	_kill(5)
	assert_eq(_quests.progress_at(0), 40, "never above the target")
	assert_true(_quests.is_complete(0))
	assert_eq(_completed_log, [[&"kill_any_t1", 0]])
	assert_eq(_progress_log.size(), 40, "one signal per change, none after the cap")
	assert_eq(_progress_log.back(), [0, 40, 40])


func test_gather_counts_player_and_helper_cycles_craft_only_the_player() -> void:
	_board(5)
	var events: GameEvents = _session.events
	events.action_completed.emit(&"main", &"forestry", &"cut_redbirch", {&"redbirch_log": 3})
	events.helper_completed.emit(&"forestry", &"cut_redbirch", {&"redbirch_log": 2})
	events.action_completed.emit(&"main", &"quarrying", &"x", {&"emberbronze_ore": 4})
	assert_eq(_quests.progress_at(1), 5)
	assert_eq(_quests.progress_at(2), 4)
	events.helper_completed.emit(&"forging", &"forge", {&"emberbronze_plate": 7})
	assert_eq(_quests.progress_at(4), 0, "helpers do not craft")
	events.action_completed.emit(&"main", &"forging", &"forge_emberbronze_plate", {&"emberbronze_plate": 6})
	assert_eq(_quests.progress_at(4), 6)
	events.action_completed.emit(&"main", &"forestry", &"cut_ashpine", {&"ashpine_log": 9})
	assert_eq(_quests.progress_at(1), 5, "another item")


func test_progress_counts_only_while_active() -> void:
	_session.events.action_completed.emit(&"main", &"forestry", &"cut_redbirch", {&"redbirch_log": 50})
	_board(2)
	assert_eq(_quests.progress_at(1), 0)
	_kill(2)
	_board(1)
	assert_eq(_quests.progress_at(0), 2, "the quest stays and keeps its progress")


func test_can_claim_reasons_in_order() -> void:
	assert_eq(_quests.can_claim(0).reason, Reasons.UNKNOWN_ID)
	_board(2)
	assert_eq(_quests.can_claim(-1).reason, Reasons.UNKNOWN_ID)
	assert_eq(_quests.can_claim(2).reason, Reasons.UNKNOWN_ID)
	assert_eq(_quests.can_claim(0).reason, Reasons.QUEST_INCOMPLETE)
	assert_eq(_quests.claim(0).reason, Reasons.QUEST_INCOMPLETE)


func test_empty_slot_is_slot_empty() -> void:
	_board(8)
	assert_eq(_quests.quest_at(6), &"craft_woodwright_t1")
	assert_eq(_quests.quest_at(7), &"", "only seven tier 1 quests exist: the eighth slot stays empty")
	assert_eq(_quests.can_claim(7).reason, Reasons.SLOT_EMPTY)
	assert_eq(_quests.abandon(7).reason, Reasons.SLOT_EMPTY)
	assert_eq(_quests.abandon(8).reason, Reasons.UNKNOWN_ID)


func test_claim_pays_gold_food_and_assigns_the_next_quest() -> void:
	_board(3)
	_kill(40)
	var gold: int = _session.wallet.get_gold()
	var food: int = _session.bank.get_count(&"seared_brookfin")
	var log: Array = []
	_session.events.gold_changed.connect(func(_a: int, d: int) -> void: log.append(["gold", d]))
	_session.events.quests_changed.connect(func() -> void: log.append(["quests"]))
	assert_true(_quests.can_claim(0).ok)
	assert_true(_quests.claim(0).ok)
	assert_eq(_session.wallet.get_gold(), gold + 80)
	assert_eq(_session.bank.get_count(&"seared_brookfin"), food + 20)
	assert_eq(_quests.completed_total(), 1)
	assert_eq(_quests.quest_at(0), &"gather_angling_t1", "kill_any_t1 is in the memory")
	assert_eq(_quests.progress_at(0), 0)
	assert_eq(log[0], ["gold", 80])
	assert_eq(log.back(), ["quests"])
	assert_eq(_quests.quest_at(1), &"gather_forestry_t1", "the other slots do not change")


func test_claim_pays_skill_xp() -> void:
	_board(2)
	_session.events.action_completed.emit(&"main", &"forestry", &"cut_redbirch", {&"redbirch_log": 150})
	var xp: int = _session.skills.get_xp(&"forestry")
	assert_true(_quests.claim(1).ok)
	assert_eq(_session.skills.get_xp(&"forestry") - xp, 400)
	assert_eq(_session.wallet.get_gold() - int(_session.data.balance_value("start.gold")), 60)


func test_bank_full_changes_nothing() -> void:
	_start(TestFactory.data_with_deposit("res://data", 1))
	_board(1)
	TestFactory.give(_session, &"redbirch_log", 1)
	_kill(40)
	var gold: int = _session.wallet.get_gold()
	assert_eq(_quests.can_claim(0).reason, Reasons.BANK_FULL)
	assert_eq(_quests.claim(0).reason, Reasons.BANK_FULL)
	assert_eq(_session.wallet.get_gold(), gold)
	assert_eq(_quests.quest_at(0), &"kill_any_t1")
	assert_eq(_quests.progress_at(0), 40)
	assert_eq(_quests.completed_total(), 0)


func test_abandon_discards_without_reward_and_remembers() -> void:
	_board(1)
	_kill(10)
	var gold: int = _session.wallet.get_gold()
	assert_true(_quests.abandon(0).ok)
	assert_eq(_session.wallet.get_gold(), gold)
	assert_eq(_quests.completed_total(), 0)
	assert_eq(_quests.quest_at(0), &"gather_forestry_t1", "the abandoned quest is in the memory")
	assert_eq(_quests.progress_at(0), 0)


func test_new_game_clears() -> void:
	_board(2)
	_kill(3)
	_quests.new_game()
	assert_eq(_quests.quest_at(0), &"")
	assert_eq(_quests.to_save(), {"slots": [], "cursor": 0, "recent": [], "completed": 0})


func test_save_round_trip() -> void:
	_board(3)
	_kill(40)
	_quests.claim(0)
	_kill(7)
	var saved: Dictionary = _quests.to_save()
	assert_eq(saved["completed"], 1)
	assert_eq(saved["recent"], ["kill_any_t1"])
	assert_eq((saved["slots"] as Array).size(), 3)
	var copy: Dictionary = JSON.parse_string(JSON.stringify(saved)) as Dictionary
	_quests.new_game()
	_quests.from_save(copy)
	assert_eq(_quests.quest_at(0), &"gather_angling_t1")
	assert_eq(_quests.quest_at(2), &"gather_quarrying_t1")
	assert_eq(_quests.completed_total(), 1)
	assert_eq(_quests.to_save(), saved)


func test_from_save_is_tolerant() -> void:
	_board(3)
	_quests.from_save({"slots": "oops", "cursor": "x", "recent": 3, "completed": -4})
	assert_eq(_quests.quest_at(0), &"")
	assert_eq(_quests.completed_total(), 0)
	_quests.from_save({
		"slots": [{"id": "kill_any_t1", "progress": 9999}, {"id": "nope", "progress": 1}, 5, {"id": "gather_forestry_t1", "progress": -3}, {}, {}, {}, {}, {"id": "kill_any_t1"}],
		"cursor": 1000, "recent": ["kill_any_t1", "nope", "gather_angling_t1", "craft_forging_t1", "craft_hearthcraft_t1", "craft_woodwright_t1", "kill_any_t2"],
		"completed": 12.0})
	assert_eq(_quests.progress_at(0), 40, "capped at the target")
	assert_eq(_quests.quest_at(1), &"")
	assert_eq(_quests.quest_at(2), &"")
	assert_eq(_quests.quest_at(3), &"", "outside the three slots")
	assert_eq(_quests.completed_total(), 12)
	var saved: Dictionary = _quests.to_save()
	assert_eq(saved["cursor"], 1000 % _session.data.quests().size())
	assert_eq((saved["recent"] as Array).size(), 6, "memory limited and unknown ids dropped")
	assert_eq((saved["slots"] as Array).size(), 4, "the ninth entry is ignored; the last assigned slot is the fourth")


func test_session_save_and_load_keep_the_quests() -> void:
	_board(2)
	_kill(4)
	var file: Dictionary = JSON.parse_string(JSON.stringify(_session.to_save(0))) as Dictionary
	assert_true(_session.from_save(file).ok)
	assert_eq(_quests.slot_count(), 0, "the load rebuilds the modifiers: this test's source is gone")
	_board(2)
	assert_eq(_quests.progress_at(0), 4, "the saved quests come back with the Bacheca")
	var without: Dictionary = file.duplicate(true)
	(without["modules"] as Dictionary).erase("quests")
	assert_true(_session.from_save(without).ok)
	_board(2)
	assert_eq(_quests.progress_at(0), 0, "a save without quests starts from zero")
	assert_eq(_quests.quest_at(0), &"kill_any_t1")
