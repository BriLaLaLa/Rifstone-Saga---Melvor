extends GutTest
## GameSession: slot file header, fixed advance order, save/load through the joined systems, modifier rebuild.
##
## Real systems arrive with M1-07+; here fake systems join a ProbeSession (test subclass) through the same
## registration used by `_create_systems`.

const NOW_MS: int = 1793603600000
const SOURCE_STAT: StringName = &"bank_slots"
const SESSION_SOURCE: String = "res://core/session/game_session.gd"
const MAX_SESSION_LINES: int = 200


## Fake SaveParticipant with an advance and a modifier source; every call is written to a shared log.
class FakeSystem:
	extends RefCounted

	var key: StringName
	var value: int = 0
	var _session: GameSession
	var _log: Array[String]

	func _init(k: StringName, session: GameSession, call_log: Array[String]) -> void:
		key = k
		_session = session
		_log = call_log

	func new_game() -> void:
		value = 0
		_log.append("%s:new_game" % key)

	func to_save() -> Dictionary:
		return {"value": value}

	func from_save(d: Dictionary) -> void:
		value = int(d["value"])
		_log.append("%s:from_save" % key)

	func rebuild_modifiers() -> void:
		var mods: Array[Modifier] = [Modifier.make(SOURCE_STAT, float(value))]
		_session.modifiers.set_source(StringName("fake:%s" % key), mods)

	func advance(delta_ms: int) -> void:
		_log.append("%s:%d" % [key, delta_ms])


## GameSession whose test code joins fake systems after construction.
class ProbeSession:
	extends GameSession

	var calls: Array[String] = []

	func _init(game_data: GameData, game_events: GameEvents, rng_seed: int) -> void:
		super(game_data, game_events, rng_seed)

	# Fake systems own the advance phases here: the ticks of the real systems (actions) are not registered.
	func _tick(phase: int, advance_fn: Callable) -> void:
		if advance_fn.get_object() is FakeSystem:
			super(phase, advance_fn)

	func add_fake(key: StringName, phase: int = -1) -> FakeSystem:
		var fake: FakeSystem = FakeSystem.new(key, self, calls)
		_join(key, fake.new_game, fake.to_save, fake.from_save, fake.rebuild_modifiers)
		if phase >= 0:
			_tick(phase, fake.advance)
		return fake

	func phase_fractures() -> int:
		return _PHASE_FRACTURES

	func phase_actions() -> int:
		return _PHASE_ACTIONS

	func phase_combat() -> int:
		return _PHASE_COMBAT


func test_new_session_creates_rng_modifiers_and_registered_systems() -> void:
	var session: GameSession = _session()
	assert_not_null(session.rng)
	assert_not_null(session.modifiers)
	assert_not_null(session.wallet)
	assert_not_null(session.bank)
	assert_not_null(session.skills)
	assert_not_null(session.mastery)
	assert_not_null(session.actions)
	assert_eq(session.play_time_ms, 0)


func test_to_save_writes_the_header() -> void:
	var session: GameSession = _session(918273)
	session.slot = 2
	session.player_name = "Davide"
	session.created_at_unix_ms = 1793600000000
	session.advance(3600000)
	var saved: Dictionary = session.to_save(NOW_MS)
	assert_eq(saved["format_version"], SaveMigrator.CURRENT_VERSION)
	assert_eq(saved["game_version"], str(ProjectSettings.get_setting("application/config/version")))
	assert_eq(saved["slot"], 2)
	assert_eq(saved["player_name"], "Davide")
	assert_eq(saved["created_at_unix_ms"], 1793600000000)
	assert_eq(saved["saved_at_unix_ms"], NOW_MS)
	assert_eq(saved["play_time_ms"], 3600000)
	assert_eq(saved["total_level"], session.data.skills().size() + 1)
	assert_eq(saved["rng"], session.rng.to_save())
	assert_eq((saved["rng"] as Dictionary)["seed"], 918273)
	var modules: Dictionary = saved["modules"]
	assert_eq(modules[String(Wallet.SAVE_KEY)], session.wallet.to_save())
	assert_eq(modules[String(Bank.SAVE_KEY)], session.bank.to_save())
	assert_eq(modules[String(SkillsSystem.SAVE_KEY)], session.skills.to_save())
	assert_eq(modules[String(MasterySystem.SAVE_KEY)], session.mastery.to_save())
	assert_eq(modules[String(ActionRunner.SAVE_KEY)], session.actions.to_save())


func test_to_save_header_is_readable_as_slot_info_header() -> void:
	var saved: Dictionary = SaveCodec.decode(SaveCodec.encode(_session().to_save(NOW_MS)))
	assert_true(SaveMigrator.can_load(saved))
	var keys: Array = saved.keys()
	keys.sort()
	assert_eq(keys, ["created_at_unix_ms", "format_version", "game_version", "modules", "play_time_ms",
			"player_name", "rng", "saved_at_unix_ms", "slot", "total_level"])


func test_to_save_writes_each_joined_module() -> void:
	var session: ProbeSession = _probe()
	session.add_fake(&"alpha").value = 4
	session.add_fake(&"beta").value = 9
	var modules: Dictionary = session.to_save(NOW_MS)["modules"]
	assert_eq(modules["alpha"], {"value": 4})
	assert_eq(modules["beta"], {"value": 9})


func test_advance_without_systems_only_counts_play_time() -> void:
	var session: GameSession = _session()
	session.advance(100)
	session.advance(250)
	assert_eq(session.play_time_ms, 350)


func test_advance_follows_fixed_order_whatever_the_join_order() -> void:
	var session: ProbeSession = _probe()
	session.add_fake(&"combat", session.phase_combat())
	session.add_fake(&"lanes", session.phase_actions())
	session.add_fake(&"fractures", session.phase_fractures())
	session.advance(100)
	session.advance(40)
	assert_eq(session.calls, ["fractures:100", "lanes:100", "combat:100", "fractures:40", "lanes:40", "combat:40"])
	assert_eq(session.play_time_ms, 140)


func test_advance_skips_missing_systems() -> void:
	var session: ProbeSession = _probe()
	session.add_fake(&"lanes", session.phase_actions())
	session.add_fake(&"ledger")
	session.advance(100)
	assert_eq(session.calls, ["lanes:100"])


func test_new_game_resets_systems_in_join_order_and_rebuilds_modifiers_once() -> void:
	var session: ProbeSession = _probe()
	session.add_fake(&"alpha").value = 5
	session.add_fake(&"beta").value = 6
	session.advance(500)
	watch_signals(session.events)
	session.new_game()
	assert_eq(session.calls, ["alpha:new_game", "beta:new_game"])
	assert_eq(session.play_time_ms, 0)
	assert_signal_emit_count(session.events, "modifiers_changed", 1)
	assert_true(session.modifiers.has_source(&"fake:alpha"))


func test_rebuild_modifiers_replaces_all_sources_with_one_signal() -> void:
	var session: ProbeSession = _probe()
	var fake: FakeSystem = session.add_fake(&"alpha")
	session.modifiers.set_source(&"stale", [Modifier.make(SOURCE_STAT, 50.0)] as Array[Modifier])
	fake.value = 3
	watch_signals(session.events)
	session.rebuild_modifiers()
	assert_signal_emit_count(session.events, "modifiers_changed", 1)
	assert_false(session.modifiers.has_source(&"stale"))
	assert_eq(session.modifiers.total(SOURCE_STAT), 3.0)


func test_round_trip_restores_header_rng_and_modules() -> void:
	var a: ProbeSession = _probe(918273)
	a.add_fake(&"alpha").value = 12
	a.add_fake(&"beta").value = 7
	a.slot = 3
	a.player_name = "Bri"
	a.created_at_unix_ms = 1793600000000
	a.advance(4500)
	a.rng.randf()
	var text: String = SaveCodec.encode(a.to_save(NOW_MS))
	var b: ProbeSession = _probe(1)
	var alpha_b: FakeSystem = b.add_fake(&"alpha")
	b.add_fake(&"beta")
	watch_signals(b.events)
	var result: CommandResult = b.from_save(SaveCodec.decode(text))
	assert_true(result.ok, str(result.reason))
	assert_eq(SaveCodec.encode(b.to_save(NOW_MS)), text)
	assert_eq(b.rng.randf(), a.rng.randf())
	assert_eq(b.modifiers.total(SOURCE_STAT), 19.0)
	assert_signal_emit_count(b.events, "modifiers_changed", 1)
	assert_eq(alpha_b.value, 12)


func test_from_save_missing_module_starts_as_new_game() -> void:
	var a: ProbeSession = _probe()
	a.add_fake(&"alpha").value = 2
	var saved: Dictionary = SaveCodec.decode(SaveCodec.encode(a.to_save(NOW_MS)))
	var b: ProbeSession = _probe()
	b.add_fake(&"alpha")
	var beta: FakeSystem = b.add_fake(&"beta")
	beta.value = 8
	assert_true(b.from_save(saved).ok)
	assert_eq(b.calls, ["alpha:from_save", "beta:new_game"])
	assert_eq(beta.value, 0)


func test_from_save_ignores_unknown_modules() -> void:
	var saved: Dictionary = SaveCodec.decode(SaveCodec.encode(_session().to_save(NOW_MS)))
	saved["modules"] = {"ghost": {"value": 1}}
	var b: ProbeSession = _probe()
	b.add_fake(&"alpha")
	assert_true(b.from_save(saved).ok)
	assert_eq(b.calls, ["alpha:new_game"])


func test_from_save_with_bad_header_changes_nothing() -> void:
	var session: GameSession = _session()
	session.player_name = "Keep"
	var saved: Dictionary = SaveCodec.decode(SaveCodec.encode(_session().to_save(NOW_MS)))
	saved["player_name"] = "Other"
	saved["play_time_ms"] = "oops"
	var result: CommandResult = session.from_save(saved)
	assert_false(result.ok)
	assert_eq(result.reason, Reasons.CORRUPTED)
	assert_eq(session.player_name, "Keep")


func test_from_save_without_format_version_is_corrupted() -> void:
	var saved: Dictionary = _session().to_save(NOW_MS)
	saved.erase("format_version")
	assert_eq(_session().from_save(saved).reason, Reasons.CORRUPTED)


func test_from_save_of_other_version_is_unsupported() -> void:
	var saved: Dictionary = _session().to_save(NOW_MS)
	saved["format_version"] = SaveMigrator.CURRENT_VERSION + 1
	assert_eq(_session().from_save(saved).reason, Reasons.VERSION_UNSUPPORTED)


func test_factory_session_uses_its_own_events_and_fixtures() -> void:
	var session: GameSession = autofree(TestFactory.session(77))
	assert_ne(session.events, EventBus)
	assert_eq(session.data, TestFactory.fixture_data())
	assert_true(session.data.is_valid())
	assert_not_null(session.data.action(&"gather_twig"))
	assert_eq(session.rng.to_save()["seed"], 77)


func test_snapshot_reads_registered_systems() -> void:
	var session: GameSession = autofree(TestFactory.session())
	var skill_id: StringName = session.data.skills()[0].id
	TestFactory.set_level(session, skill_id, 2)
	TestFactory.give(session, &"test_log", 3)
	session.wallet.add_gold(7)
	var snapshot: SessionSnapshot = SessionSnapshot.take(session)
	assert_eq(snapshot.xp.size(), session.data.skills().size() + 1)
	assert_eq(snapshot.levels.size(), session.data.skills().size() + 1)
	assert_eq(snapshot.xp[skill_id], session.skills.get_xp(skill_id))
	assert_eq(snapshot.levels[skill_id], 2)
	assert_eq(snapshot.bank.size(), session.bank.used())
	assert_eq(snapshot.bank[&"test_log"], 3)
	assert_eq(snapshot.gold, int(session.data.balance_value("start.gold")) + 7)
	assert_eq(snapshot.kills, {})
	assert_eq(snapshot.deaths, 0)
	assert_eq(snapshot.food_eaten, 0)


func test_game_session_file_stays_within_200_lines() -> void:
	var text: String = FileAccess.get_file_as_string(SESSION_SOURCE)
	assert_gt(text.length(), 0)
	assert_lte(text.count("\n"), MAX_SESSION_LINES)


func _session(seed_value: int = 1234) -> GameSession:
	var events: GameEvents = autofree(GameEvents.new())
	return autofree(GameSession.new(TestFactory.fixture_data(), events, seed_value))


func _probe(seed_value: int = 1234) -> ProbeSession:
	var events: GameEvents = autofree(GameEvents.new())
	return autofree(ProbeSession.new(TestFactory.fixture_data(), events, seed_value))


func test_real_session_total_level_includes_character() -> void:
	var session: GameSession = autofree(TestFactory.session())
	session.new_game()
	assert_eq(session.total_level(), session.skills.total_level() + session.character.get_level())
	assert_true(((session.to_save(0))["modules"] as Dictionary).has("character"))
	assert_eq((session.to_save(0))["format_version"], 2)
