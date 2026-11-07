extends GutTest
## F-87 Rift Stones in the CombatEngine: the pity counter and the chance, the stone encounter, the pulse (F-25, F-75),
## the rewards (F-28, F-84), the save and the equivalence of the steps. Fixture data: `test_stone_area` (monster A only)
## has the stone `test_stone` (60 hp, xp 240, pulse 7 every 3000 ms, 2-4 shards, 2 test_log). Seeds are fixed.

const PreRun := preload("res://tests/helpers/gut_pre_run.gd")
const CONFIG_ROOT: String = "res://data/config"
const CONTENT_ROOT: String = "res://tests/fixtures/data"
const AREA: StringName = &"test_stone_area"
const STONE: StringName = &"test_stone"
const MONSTER_A: StringName = &"test_monster_a"
const SOURCE: StringName = &"test:boost"

var _tmp_config: String = PreRun.test_dir("test_rift_stone")


func after_all() -> void:
	if not DirAccess.dir_exists_absolute(_tmp_config):
		return
	for file_name: String in DirAccess.get_files_at(_tmp_config):
		DirAccess.remove_absolute(_tmp_config.path_join(file_name))
	DirAccess.remove_absolute(_tmp_config)


# Fixture data with `rift_stone.chance_pct` / `pity_kills` replaced (a private GameData).
func _data(chance: float, pity: int) -> GameData:
	DirAccess.make_dir_recursive_absolute(_tmp_config)
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_ROOT.path_join("balance.json")))
	balance["rift_stone"] = {"chance_pct": chance, "pity_kills": pity}
	_write("balance.json", JSON.stringify(balance))
	_write("stats.json", FileAccess.get_file_as_string(CONFIG_ROOT.path_join("stats.json")))
	var data: GameData = GameData.load_from_dirs(CONTENT_ROOT, _tmp_config)
	assert_true(data.is_valid(), "data valid: %s" % ", ".join(data.errors))
	return data


func _write(file_name: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(_tmp_config.path_join(file_name), FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _session(data: GameData, seed_value: int = 5) -> GameSession:
	var s: GameSession = autofree(TestFactory.session(seed_value, data))
	return s


func _hero(s: GameSession) -> void:
	s.modifiers.set_source(SOURCE, [Modifier.make(&"power_bonus", 5000.0), Modifier.make(&"max_hp_flat", 100000.0)])


# A combat save in the stone state: `hp` of the stone, the player waits `player_timer_ms`.
func _stone_save(stone_hp: int, player_hp: int, player_timer_ms: int, stone_timer_ms: int = 3000) -> Dictionary:
	return {"state": "riftstone", "area": String(AREA), "player_hp": player_hp, "player_timer_ms": player_timer_ms,
		"hand": 0, "between_ms": 0, "loot": [], "kills": {}, "deaths": 0, "food_eaten": 0,
		"enemies": [{"monster": String(STONE), "hp": stone_hp, "timer_ms": stone_timer_ms}],
		"stone": {"since": 0, "pending": false}}


func _total_kills(s: GameSession) -> int:
	var n: int = 0
	for id: StringName in s.combat.total_kills():
		n += s.combat.total_kills()[id]
	return n


func _stone_state(s: GameSession) -> Dictionary:
	return s.combat.to_save()["stone"]


# Fights the stone area until `limit` encounters have started; returns the monster ids of each, in order.
func _encounters(s: GameSession, limit: int) -> Array:
	var seen: Array = []
	s.events.encounter_started.connect(func(ids: Array[StringName]) -> void: seen.append(ids.duplicate()))
	s.combat.start(AREA)
	var guard: int = 0
	while seen.size() < limit and guard < 5000:
		s.combat.advance(500)
		guard += 1
	return seen


func test_pity_after_n_kills() -> void:
	var s: GameSession = _session(_data(0.0, 3))
	_hero(s)
	var appeared: Array[int] = []
	s.events.rift_stone_appeared.connect(func(_id: StringName) -> void: appeared.append(_total_kills(s)))
	var seen: Array = _encounters(s, 5)
	assert_eq(appeared, [3], "the stone appears after exactly 3 kills (chance 0): since >= pity")
	assert_eq(seen[3], [STONE], "the fourth encounter is the stone")
	assert_eq(seen[0], [MONSTER_A])
	assert_eq(_stone_state(s)["since"], 0, "since restarted at the stone; the fifth encounter is still running")


func test_chance_100_every_kill() -> void:
	var s: GameSession = _session(_data(100.0, 300))
	_hero(s)
	var seen: Array = _encounters(s, 6)
	assert_eq(seen.size(), 6)
	for i: int in 6:
		assert_eq(seen[i], [MONSTER_A] if i % 2 == 0 else [STONE], "encounter %d" % i)
	assert_eq(s.combat.total_kills().get(STONE, 0), 0, "a stone is not a counted monster kill")


func test_chance_0_and_far_pity_never() -> void:
	var s: GameSession = _session(_data(0.0, 300))
	_hero(s)
	var seen: Array = _encounters(s, 40)
	for ids: Array in seen:
		assert_false(ids.has(STONE))
	assert_eq(_stone_state(s)["pending"], false)
	assert_gte(int(_stone_state(s)["since"]), 38, "one count per kill")


func test_area_without_stone_changes_nothing() -> void:
	var s: GameSession = _session(_data(100.0, 1))
	_hero(s)
	var d: Dictionary = s.combat.to_save()
	d["stone"] = {"since": 299, "pending": false}
	s.combat.from_save(d)
	s.combat.start(&"test_area")
	var guard: int = 0
	while s.combat.total_kills().is_empty() and guard < 500:
		s.combat.advance(1000)
		guard += 1
	assert_false(s.combat.total_kills().is_empty())
	assert_eq(_stone_state(s), {"since": 299, "pending": false}, "no counting and no roll in an area without stone")


func test_pending_is_the_next_encounter_and_the_counter_survives_stop() -> void:
	var s: GameSession = _session(_data(0.0, 300))
	var d: Dictionary = s.combat.to_save()
	d["stone"] = {"since": 41, "pending": true}
	s.combat.from_save(d)
	s.combat.start(AREA)
	assert_eq(s.combat.state(), CombatEngine.STATE_RIFTSTONE, "a pending stone is the next encounter")
	assert_eq(_stone_state(s), {"since": 41, "pending": false})
	s.combat.stop()
	assert_eq(_stone_state(s)["since"], 41, "stop keeps the counter")
	s.combat.new_game()
	assert_eq(_stone_state(s), {"since": 0, "pending": false})


func test_pulse_hits_every_pulse_ms_and_ignores_the_player_timer() -> void:
	var s: GameSession = _session(_data(0.0, 300))
	s.combat.from_save(_stone_save(60, 60, 999999))
	assert_eq(s.combat.state(), CombatEngine.STATE_RIFTSTONE)
	s.combat.advance(2999)
	assert_eq(s.combat.get_state()["player_hp"], 60)
	s.combat.advance(1)
	assert_eq(s.combat.get_state()["player_hp"], 53, "pulse_damage 7")
	s.combat.advance(3000)
	assert_eq(s.combat.get_state()["player_hp"], 46)


func test_pulse_can_kill_the_player_and_loses_only_the_bag() -> void:
	var s: GameSession = _session(_data(0.0, 300))
	var save: Dictionary = _stone_save(60, 7, 999999)
	save["loot"] = [{"item": "test_log", "qty": 3}]
	s.combat.from_save(save)
	watch_signals(s.events)
	s.combat.advance(3000)
	assert_signal_emitted(s.events, "player_died")
	assert_false(s.combat.is_active())
	assert_eq(s.combat.loot.used(), 0, "the loot bag is lost")
	assert_eq(s.combat.deaths(), 1)


func test_roll_pulse_dr_and_block() -> void:
	var me := CombatantStats.new()
	me.damage_reduction = 50.0
	var rng := RngService.new(1)
	var hit: Dictionary = Encounter.roll_pulse(7, me, 0.0, rng)
	assert_eq(hit, {"hit": true, "blocked": false, "damage": 3}, "F-25: floor(7 x 0.5), never misses")
	me.damage_reduction = 0.0
	assert_eq(Encounter.roll_pulse(7, me, 0.0, rng)["damage"], 7)
	var blocked: Dictionary = Encounter.roll_pulse(7, me, 100.0, rng)
	assert_eq(blocked, {"hit": true, "blocked": true, "damage": 0}, "F-75: a block stops the pulse")


func test_killing_the_stone_gives_xp_shards_and_drops() -> void:
	var s: GameSession = _session(_data(0.0, 300))
	_hero(s)
	s.combat.from_save(_stone_save(60, 100060, 0))
	var xp: int = s.character.get_xp()
	var gold: int = s.wallet.get_gold()
	var guard: int = 0
	while s.combat.state() == CombatEngine.STATE_RIFTSTONE and guard < 200:
		s.combat.advance(100)
		guard += 1
	assert_eq(s.combat.state(), CombatEngine.STATE_BETWEEN, "the encounter is over")
	assert_eq(s.character.get_xp() - xp, 26, "F-28: floor(240 x 0.11) for the stone")
	assert_eq(s.wallet.get_gold(), gold, "no gold from a stone")
	var bag: Dictionary = {}
	for entry: Dictionary in s.combat.loot.items():
		bag[entry["item"]] = entry["qty"]
	assert_between(int(bag.get(&"rift_shard", 0)), 2, 4, "shards in the range")
	assert_eq(bag.get(&"test_log", 0), 2, "the drop of the stone")
	assert_true(s.combat.total_kills().is_empty())


func test_stone_pieces_use_the_stone_rarity_and_the_area_item_level() -> void:
	var data: GameData = _data(0.0, 300)
	var drop := DropEntry.new()
	drop.item_id = &"test_blade"
	drop.chance_pct = 100.0
	drop.qty_min = 1
	drop.qty_max = 1
	data.rift_stone_for_area(AREA).drops = [drop] as Array[DropEntry]
	var s: GameSession = _session(data)
	_hero(s)
	s.modifiers.set_source(&"test:cap", [Modifier.make(&"armory_slots", 500.0)])
	for i: int in 300:
		s.combat.from_save(_stone_save(1, 100060, 0))
		var guard: int = 0
		while s.combat.state() == CombatEngine.STATE_RIFTSTONE and guard < 100:
			s.combat.advance(100)
			guard += 1
	var better: int = 0
	var total: int = s.armory.used()
	for inst: ItemInstance in s.armory.instances():
		assert_eq(inst.ilvl, 1, "the highest combat level of the monsters of the area")
		if inst.rarity != &"common":
			better += 1
	assert_gt(total, 250, "a piece per stone (hits can miss the 1 hp stone, so not all 300)")
	assert_gt(float(better) / float(total), 0.4, "40% magic + 12% rare = 52% (monsters: 23%)")


func test_summoned_pack_fights_with_the_stone() -> void:
	var data: GameData = _data(0.0, 300)
	data.rift_stone_for_area(AREA).summon_pack = 0
	var s: GameSession = _session(data)
	var d: Dictionary = s.combat.to_save()
	d["stone"] = {"since": 0, "pending": true}
	s.combat.from_save(d)
	s.combat.start(AREA)
	var enemies: Array = s.combat.get_state()["enemies"]
	assert_eq(enemies.size(), 2)
	assert_eq(enemies[0]["monster"], STONE)
	assert_eq(enemies[1]["monster"], MONSTER_A)
	var other: GameSession = _session(data)
	other.combat.from_save(s.combat.to_save())
	assert_eq(other.combat.to_save(), s.combat.to_save(), "save -> load -> save with the stone and its pack")
	assert_eq(other.combat.state(), CombatEngine.STATE_RIFTSTONE)


func test_steps_do_not_change_the_result() -> void:
	var data: GameData = _data(0.0, 300)
	var results: Array[Dictionary] = []
	for step_ms: int in [9000, 1000, 100]:
		var s: GameSession = _session(data, 17)
		s.combat.from_save(_stone_save(60, 60, 1200))
		for i: int in 9000 / step_ms:
			s.combat.advance(step_ms)
		results.append(s.combat.to_save())
	assert_eq(results[1], results[0], "1x9000 = 9x1000")
	assert_eq(results[2], results[0], "1x9000 = 90x100")


func test_save_load_save_in_the_stone_state() -> void:
	var data: GameData = _data(0.0, 300)
	var s: GameSession = _session(data, 9)
	s.combat.from_save(_stone_save(40, 50, 700, 1200))
	var saved: Dictionary = s.combat.to_save()
	assert_eq(saved["state"], "riftstone")
	var other: GameSession = _session(data, 9)
	other.combat.from_save(saved)
	assert_eq(other.combat.to_save(), saved)
	assert_eq(other.combat.get_state()["enemies"][0]["monster"], STONE)
	assert_true(other.combat.in_encounter())


func test_stone_of_an_unknown_id_loads_as_idle() -> void:
	var s: GameSession = _session(_data(0.0, 300))
	var save: Dictionary = _stone_save(10, 10, 100)
	(save["enemies"] as Array)[0]["monster"] = "ghost_stone"
	s.combat.from_save(save)
	assert_false(s.combat.is_active())


# Q46: the area's own `rift_stone_chance_pct` wins over the global chance; absent = the global one (tests above).
func test_area_chance_overrides_the_global_one() -> void:
	var data: GameData = _data(0.0, 300)
	data.area(AREA).rift_stone_chance_pct = 100.0
	var s: GameSession = _session(data)
	_hero(s)
	var seen: Array = _encounters(s, 4)
	assert_eq(seen[0], [MONSTER_A])
	assert_eq(seen[1], [STONE], "area chance 100 over global 0: the stone after every kill")


func test_area_chance_zero_beats_a_global_100() -> void:
	var data: GameData = _data(100.0, 300)
	data.area(AREA).rift_stone_chance_pct = 0.0
	var s: GameSession = _session(data)
	_hero(s)
	for ids: Array in _encounters(s, 5):
		assert_eq(ids, [MONSTER_A], "an area chance of 0 is not 'absent': no stone")
