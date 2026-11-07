extends GutTest
## OfflineSimulator: F-40 elapsed, F-41 chunks and equivalence, signals, summary of gathering, crafting and combat,
## the Armory filter with a full bank (bank_rejected counted), play time untouched, 12 h combat timing.
##
## Real data, fixed seeds, yield_frames = false (no frame waits in tests). No slot is written.

const SEED: int = 4242
const NOW_MS: int = 1793603600000
const AREA: StringName = &"redrock_plains"
const SWORD: StringName = &"emberbronze_sword"
const RING: StringName = &"emberbronze_ring"
const INGOT: StringName = &"emberbronze_ingot"
const HOUR_MS: int = 3600000
const CAP_MS: int = 43200000
const CHUNK_MS: int = 60000
const HERO: StringName = &"test:hero"
const ROOMY: StringName = &"test:room"

var _progress: Array[Vector2i] = []
var _completed: Array[OfflineSummary] = []
var _started: Array[Vector2i] = []


func _session(seed_value: int = SEED, data: GameData = null) -> GameSession:
	var s: GameSession = autofree(TestFactory.session(seed_value, data if data != null else TestFactory.real_data()))
	_progress = []
	_completed = []
	_started = []
	s.events.offline_started.connect(func(e: int, c: bool) -> void: _started.append(Vector2i(e, int(c))))
	s.events.offline_progress.connect(func(d: int, t: int) -> void: _progress.append(Vector2i(d, t)))
	s.events.offline_completed.connect(func(sum: OfflineSummary) -> void: _completed.append(sum))
	return s


func _geared(seed_value: int = SEED) -> GameSession:
	var s: GameSession = _session(seed_value)
	assert_true(s.equipment.equip(TestFactory.give_piece(s, SWORD)).ok)
	s.modifiers.set_source(HERO, [Modifier.make(&"power_bonus", 5000.0), Modifier.make(&"max_hp_flat", 100000.0)])
	return s


func _run(s: GameSession, elapsed_ms: int, capped: bool = false) -> OfflineSummary:
	return await OfflineSimulator.new().run(s, elapsed_ms, capped, false)


# --- F-40 / F-41 -------------------------------------------------------------------------------------------------

func test_f40_elapsed_examples() -> void:
	assert_eq(OfflineSimulator.compute_elapsed(0, 5 * HOUR_MS, CAP_MS), 18000000)
	assert_false(OfflineSimulator.is_capped(0, 5 * HOUR_MS, CAP_MS))
	assert_eq(OfflineSimulator.compute_elapsed(0, 20 * HOUR_MS, CAP_MS), 43200000)
	assert_true(OfflineSimulator.is_capped(0, 20 * HOUR_MS, CAP_MS))
	assert_eq(OfflineSimulator.compute_elapsed(10 * HOUR_MS, 5 * HOUR_MS, CAP_MS), 0, "clock set back")
	assert_false(OfflineSimulator.is_capped(10 * HOUR_MS, 5 * HOUR_MS, CAP_MS))
	assert_false(OfflineSimulator.is_capped(0, CAP_MS, CAP_MS), "exactly the cap is not capped")


func test_f40_balance_values() -> void:
	var data: GameData = TestFactory.real_data()
	assert_eq(int(data.balance_value("offline.cap_ms")), CAP_MS)
	assert_eq(int(data.balance_value("offline.min_ms")), 60000)
	assert_eq(int(data.balance_value("offline.chunk_ms")), CHUNK_MS)


func test_f41_chunk_counts() -> void:
	assert_eq(OfflineSimulator.chunk_count(CAP_MS, CHUNK_MS), 720)
	assert_eq(OfflineSimulator.chunk_count(90000, CHUNK_MS), 2)
	assert_eq(OfflineSimulator.chunk_count(0, CHUNK_MS), 0)


func test_f41_ninety_seconds_run_in_two_blocks_with_progress() -> void:
	var s: GameSession = _session()
	var summary: OfflineSummary = await _run(s, 90000, true)
	assert_eq(_progress, [Vector2i(60000, 90000), Vector2i(90000, 90000)] as Array[Vector2i])
	assert_eq(_started, [Vector2i(90000, 1)] as Array[Vector2i])
	assert_eq(_completed.size(), 1)
	assert_eq(_completed[0], summary)
	assert_eq(summary.elapsed_ms, 90000)
	assert_true(summary.capped)


func test_f41_one_block_or_ten_gives_the_same_state() -> void:
	var one: GameSession = _geared()
	var ten: GameSession = _geared()
	assert_true(one.combat.start(AREA).ok)
	assert_true(ten.combat.start(AREA).ok)
	one.advance(600000)
	await _run(ten, 600000)
	one.play_time_ms = 0
	ten.play_time_ms = 0
	assert_eq(_progress.size(), 10)
	assert_eq(SaveCodec.encode(ten.to_save(NOW_MS)), SaveCodec.encode(one.to_save(NOW_MS)))


# --- summary ----------------------------------------------------------------------------------------------------

func test_gathering_for_an_hour_gives_xp_and_items_and_keeps_play_time() -> void:
	var s: GameSession = _session()
	s.play_time_ms = 777
	assert_true(s.actions.start(&"angling", &"catch_brookfin").ok)
	var summary: OfflineSummary = await _run(s, HOUR_MS)
	assert_gt(summary.xp.get(&"angling", 0), 0)
	assert_false(summary.items.is_empty())
	assert_true(summary.levels.has(&"angling"), "an hour of angling raises the level")
	assert_eq(summary.levels[&"angling"].x, 1)
	assert_gt(summary.levels[&"angling"].y, 1)
	assert_eq(s.play_time_ms, 777, "play time counts online time only")
	assert_false(summary.is_empty())


func test_crafting_runs_out_of_ingredients_and_reports_when() -> void:
	var s: GameSession = _session()
	TestFactory.give(s, &"emberbronze_ore", 10)
	assert_true(s.actions.start(&"forging", &"smelt_emberbronze").ok)
	var summary: OfflineSummary = await _run(s, 30 * 60000)
	assert_eq(summary.items.get(&"emberbronze_ore", 0), -10)
	assert_eq(summary.items.get(INGOT, 0), 5)
	assert_eq(summary.stop_reasons, [Reasons.MISSING_INPUTS] as Array[StringName])
	assert_eq(summary.stop_times_ms.size(), 1)
	assert_between(summary.stop_times_ms[0], 0, 30 * 60000, "block start of the stop")
	assert_false(s.actions.is_running())


func test_idle_session_simulates_nothing() -> void:
	var s: GameSession = _session()
	var summary: OfflineSummary = await _run(s, HOUR_MS)
	assert_true(summary.is_empty())
	assert_eq(_progress.size(), 60)


func test_combat_for_an_hour_counts_kills_xp_and_gold() -> void:
	var s: GameSession = _geared()
	assert_true(s.combat.start(AREA).ok)
	var summary: OfflineSummary = await _run(s, HOUR_MS)
	var total_kills: int = 0
	for n: int in summary.kills.values():
		total_kills += n
	assert_gt(total_kills, 100)
	assert_gt(summary.xp.get(CharacterSystem.SAVE_KEY, 0), 0)
	assert_eq(summary.deaths, 0)
	assert_eq(summary.gold_delta, s.wallet.get_gold() - int(s.data.balance_value("start.gold")))


func test_death_stops_the_combat_and_the_rest_of_the_time_passes_empty() -> void:
	var s: GameSession = _session()
	s.modifiers.set_source(HERO, [Modifier.make(&"max_hp_flat", -(float(s.combat.player_stats().max_hp) - 1.0))])
	assert_true(s.combat.start(AREA).ok)
	var summary: OfflineSummary = await _run(s, 2 * HOUR_MS)
	assert_eq(summary.deaths, 1)
	assert_true(summary.stop_reasons.has(Reasons.PLAYER_DIED))
	assert_false(s.combat.is_active())


# --- Armory filter and bank_rejected (nota M7-02) -----------------------------------------------------------------

func _drop_data() -> GameData:
	var data: GameData = GameData.load_from_dirs(TestFactory.REAL_CONTENT_ROOT, TestFactory.CONFIG_ROOT)
	for monster_id: StringName in data.area(AREA).monster_ids:
		var list: Array[DropEntry] = []
		for item_id: StringName in [SWORD, RING]:
			var entry := DropEntry.new()
			entry.item_id = item_id
			entry.chance_pct = 100.0
			entry.qty_min = 1
			entry.qty_max = 1
			list.append(entry)
		data.monster(monster_id).drops = list
	return data


func test_filtered_drops_are_counted_as_dismantled_and_pieces_as_stored() -> void:
	var s: GameSession = _session(SEED, _drop_data())
	s.modifiers.set_source(HERO, [Modifier.make(&"power_bonus", 5000.0), Modifier.make(&"max_hp_flat", 100000.0)])
	s.modifiers.set_source(ROOMY, [Modifier.make(&"armory_slots", 500.0), Modifier.make(&"bank_slots", 100.0)])
	assert_true(s.armory.set_filter(&"weapon", &"magic", 1).ok)
	assert_true(s.combat.start(AREA).ok)
	var summary: OfflineSummary = await _run(s, 20 * 60000)
	assert_gt(summary.pieces_dismantled, 0)
	assert_gt(summary.pieces_stored, 0)
	assert_eq(summary.pieces_stored, s.armory.used())
	assert_eq(summary.pieces_rejected, 0)
	assert_true(summary.bank_rejected.is_empty())
	assert_eq(summary.items.get(INGOT, 0), summary.pieces_dismantled, "one ingot per salvaged sword")


func test_full_armory_and_full_bank_report_bank_rejected() -> void:
	var s: GameSession = _session(SEED, _drop_data())
	s.modifiers.set_source(HERO, [Modifier.make(&"power_bonus", 5000.0), Modifier.make(&"max_hp_flat", 100000.0)])
	for i: int in s.armory.capacity():
		TestFactory.give_piece(s, RING)
	for item: ItemDef in s.data.items():
		if s.bank.used() >= s.bank.capacity():
			break
		if item.category == &"material" and item.id != INGOT and item.id != &"rift_shard":
			s.bank.add(item.id, 1)
	assert_eq(s.bank.used(), s.bank.capacity())
	assert_true(s.combat.start(AREA).ok)
	var summary: OfflineSummary = await _run(s, 10 * 60000)
	assert_gt(summary.pieces_dismantled, 0)
	assert_eq(summary.pieces_stored, 0)
	assert_false(summary.bank_rejected.is_empty(), "yields lost to a full bank are counted, never silent")
	assert_eq(summary.bank_rejected.get(INGOT, 0) > 0, true)
	assert_false(summary.is_empty())


# --- performance (measure only; the formal test is M9-07) ---------------------------------------------------------

func test_twelve_hours_of_combat_is_simulated_and_timed() -> void:
	var s: GameSession = _geared()
	s.modifiers.set_source(ROOMY, [Modifier.make(&"armory_slots", 500.0), Modifier.make(&"bank_slots", 100.0)])
	assert_true(s.combat.start(AREA).ok)
	var started_us: int = Time.get_ticks_usec()
	var summary: OfflineSummary = await _run(s, CAP_MS, true)
	var took_ms: int = (Time.get_ticks_usec() - started_us) / 1000
	gut.p("12 h of combat offline: %d ms" % took_ms)
	assert_eq(_progress.size(), 720)
	assert_gt(summary.kills.size(), 0)
	assert_lt(took_ms, 120000, "sanity bound only; the 10 s target is checked by M9-07")
