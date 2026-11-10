extends GutTest
## F-128 (docs/02_FORMULAS.md §5f): the skip setting of the Rift Stones, a state of the slot (saved in the combat module).
## Real data (the Plains pool is 5, 10, 15); fixed seeds.

const AREA: StringName = &"redrock_plains"


func _session(seed_value: int = 3) -> GameSession:
	return autofree(TestFactory.session_no_kit(seed_value, TestFactory.real_data()))


# A combat save with a pending stone (the engine idle: the stone comes with the next `start`).
func _pending(s: GameSession, stone_id: String, skip: int) -> void:
	var d: Dictionary = s.combat.to_save()
	d["stone"] = {"since": 12, "pending": true, "stone_id": stone_id}
	d["skip_stone_level"] = skip
	s.combat.from_save(d)


func test_new_slot_starts_at_the_balance_value() -> void:
	var s: GameSession = _session()
	assert_eq(s.combat.skip_stone_level(), 0)
	assert_eq(s.combat.get_state()["skip_stone_level"], 0)


func test_set_validates_and_signals() -> void:
	var s: GameSession = _session()
	watch_signals(s.events)
	assert_eq(s.combat.set_skip_stone_level(-1).reason, Reasons.INVALID_CHOICE)
	assert_eq(s.combat.set_skip_stone_level(100).reason, Reasons.INVALID_CHOICE)
	assert_eq(s.combat.skip_stone_level(), 0, "nothing changed")
	assert_signal_not_emitted(s.events, "skip_stone_changed")
	assert_true(s.combat.set_skip_stone_level(10).ok)
	assert_eq(s.combat.skip_stone_level(), 10)
	assert_signal_emitted_with_parameters(s.events, "skip_stone_changed", [10])
	assert_true(s.combat.set_skip_stone_level(99).ok)
	assert_true(s.combat.set_skip_stone_level(0).ok)


func test_pending_stone_at_or_under_the_level_is_discarded() -> void:
	var s: GameSession = _session()
	_pending(s, "redrock_plains_stone_10", 10)
	watch_signals(s.events)
	s.combat.start(AREA)
	assert_eq(s.combat.state(), CombatEngine.STATE_ENCOUNTER, "a normal pack, not the stone")
	assert_signal_emitted_with_parameters(s.events, "rift_stone_skipped", [&"redrock_plains_stone_10"])
	var stone: Dictionary = s.combat.to_save()["stone"]
	assert_eq(stone["pending"], false)
	assert_eq(stone["since"], 0, "since restarts")
	assert_true(s.combat.total_kills().is_empty(), "not a kill")


func test_pending_stone_over_the_level_is_fought() -> void:
	var s: GameSession = _session()
	_pending(s, "redrock_plains_stone_15", 10)
	watch_signals(s.events)
	s.combat.start(AREA)
	assert_eq(s.combat.state(), CombatEngine.STATE_RIFTSTONE)
	assert_signal_not_emitted(s.events, "rift_stone_skipped")
	assert_eq(s.combat.get_state()["stone"]["id"], &"redrock_plains_stone_15")


func test_level_zero_never_skips_and_99_skips_everything() -> void:
	var off: GameSession = _session()
	_pending(off, "redrock_plains_stone_5", 0)
	off.combat.start(AREA)
	assert_eq(off.combat.state(), CombatEngine.STATE_RIFTSTONE, "0 = off")
	var all: GameSession = _session()
	_pending(all, "redrock_plains_stone_15", 99)
	all.combat.start(AREA)
	assert_eq(all.combat.state(), CombatEngine.STATE_ENCOUNTER, "99 skips every stone")


func test_a_stone_that_appears_under_the_level_is_discarded_at_once() -> void:
	var s: GameSession = _session(5)
	s.combat.set_skip_stone_level(99)
	var stone := RiftStone.new(s)
	stone.skip_level = 99
	stone.since = int(s.data.balance_value("rift_stone.pity_kills")) - 1
	watch_signals(s.events)
	stone.on_kill(AREA)
	assert_false(stone.pending, "never pending")
	assert_eq(stone.since, 0)
	assert_signal_emitted(s.events, "rift_stone_skipped")
	assert_signal_not_emitted(s.events, "rift_stone_appeared")
	stone.skip_level = 0
	stone.since = int(s.data.balance_value("rift_stone.pity_kills")) - 1
	stone.on_kill(AREA)
	assert_true(stone.pending, "without the setting the stone appears")
	assert_signal_emitted(s.events, "rift_stone_appeared")
	assert_true(s.data.has_rift_stone(stone.stone_id))
	assert_eq(s.data.rift_stone(stone.stone_id).area_id, AREA)


func test_the_draw_covers_the_pool_uniformly() -> void:
	var s: GameSession = _session(8)
	var stone := RiftStone.new(s)
	var counts: Dictionary = {}
	for _i: int in 600:
		stone.pending = false
		stone.since = int(s.data.balance_value("rift_stone.pity_kills")) - 1
		stone.on_kill(AREA)
		counts[stone.stone_id] = counts.get(stone.stone_id, 0) + 1
	assert_eq(counts.keys().size(), 3, "5, 10 and 15 of the Plains")
	for id: Variant in counts:
		assert_between(int(counts[id]), 140, 260, "about a third each: %s" % id)


func test_the_setting_is_saved_loaded_and_survives_stop() -> void:
	var s: GameSession = _session()
	s.combat.set_skip_stone_level(35)
	s.combat.start(AREA)
	s.combat.stop()
	assert_eq(s.combat.skip_stone_level(), 35, "stop does not reset a slot setting")
	var saved: Dictionary = s.combat.to_save()
	assert_eq(saved["skip_stone_level"], 35)
	var other: GameSession = _session()
	other.combat.from_save(saved)
	assert_eq(other.combat.skip_stone_level(), 35)
	assert_eq(other.combat.to_save(), saved)
	other.combat.new_game()
	assert_eq(other.combat.skip_stone_level(), 0, "a new game starts from the balance value")


func test_a_malformed_setting_loads_as_zero() -> void:
	var s: GameSession = _session()
	for bad: Variant in ["x", 100, -3, 2.5, null]:
		var d: Dictionary = s.combat.to_save()
		d["skip_stone_level"] = bad
		s.combat.from_save(d)
		assert_eq(s.combat.skip_stone_level(), 0, "malformed %s" % str(bad))
	var absent: Dictionary = s.combat.to_save()
	absent.erase("skip_stone_level")
	s.combat.from_save(absent)
	assert_eq(s.combat.skip_stone_level(), 0, "absent = a new slot")


func test_an_unknown_pending_stone_id_is_dropped() -> void:
	var s: GameSession = _session()
	_pending(s, "no_such_stone", 0)
	assert_eq(s.combat.to_save()["stone"], {"since": 12, "pending": false, "stone_id": ""})


func test_migration_5_to_6_adds_the_skip_setting_and_drops_the_old_stone() -> void:
	var v5: Dictionary = {"format_version": 5, "modules": {"combat": {"state": "riftstone", "area": "redrock_plains",
		"enemies": [{"monster": "redrock_stone", "hp": 30, "timer_ms": 100}], "loot": [],
		"stone": {"since": 41, "pending": true}}}}
	var combat: Dictionary = SaveMigrator.migrate(v5)["modules"]["combat"]
	assert_eq(combat["skip_stone_level"], 0)
	assert_eq(combat["stone"], {"since": 41, "pending": false, "stone_id": ""})
	assert_eq(combat["state"], "between", "the old stone vanishes")
	assert_eq(combat["enemies"], [])
	assert_eq(v5["modules"]["combat"]["state"], "riftstone", "input untouched")
