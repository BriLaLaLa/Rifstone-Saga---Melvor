extends GutTest
## CombatEngine (docs/01_GDD.md §10, docs/05_INTERFACES.md §5.10): commands, F-28, F-31, F-32, F-07, F-75, F-76, F-77,
## the equivalence of advance(1000) and ten advance(100), death and save. Fixture data: `test_area` has the packs
## [test_monster_a] (weight 3) and [test_monster_a, test_monster_b] (weight 1); monster A = the boar of F-34.

const AREA: StringName = &"test_area"
const MONSTER_A: StringName = &"test_monster_a"
const MONSTER_B: StringName = &"test_monster_b"
const SHIELD: StringName = &"test_shield"
const BLADE: StringName = &"test_blade"
const RATION: StringName = &"test_ration"
const SOURCE: StringName = &"test:boost"

var _session: GameSession = null
var _hits: Array[Array] = []


func before_each() -> void:
	_session = _new_session(1234)


func _new_session(seed_value: int) -> GameSession:
	var s: GameSession = autofree(TestFactory.session(seed_value))
	return s


func _boost(session: GameSession, mods: Array[Modifier]) -> void:
	session.modifiers.set_source(SOURCE, mods)


# A player that kills fast and does not die: used by the statistical tests.
func _hero(session: GameSession) -> void:
	_boost(session, [Modifier.make(&"power_bonus", 5000.0), Modifier.make(&"max_hp_flat", 100000.0)])


func _record_hits(session: GameSession) -> void:
	_hits = []
	session.events.combat_hit.connect(func(a: int, t: int, h: bool, d: int, b: bool) -> void: _hits.append([a, t, h, d, b]))


# --- start / stop ----------------------------------------------------------------------------------------------

func test_start_unknown_area_and_requirement() -> void:
	assert_eq(_session.combat.start(&"nowhere").reason, Reasons.UNKNOWN_ID)
	var real: GameSession = autofree(TestFactory.session(1, TestFactory.real_data()))
	assert_eq(real.combat.start(&"whisper_wood").reason, Reasons.REQUIREMENT_NOT_MET)
	assert_false(real.combat.is_active())
	TestFactory.set_character_level(real, 16)
	assert_true(real.combat.start(&"whisper_wood").ok)


func test_start_enters_an_encounter() -> void:
	watch_signals(_session.events)
	assert_true(_session.combat.start(AREA).ok)
	assert_eq(_session.combat.state(), CombatEngine.STATE_ENCOUNTER)
	assert_true(_session.combat.in_encounter())
	assert_eq(_session.combat.area_id(), AREA)
	assert_signal_emitted_with_parameters(_session.events, "combat_started", [AREA])
	assert_signal_emitted(_session.events, "encounter_started")
	var state: Dictionary = _session.combat.get_state()
	assert_eq(state["player_hp"], 60, "F-70 at level 1")
	assert_eq(state["player_timer_ms"], 2400, "unarmed interval")
	var enemies: Array = state["enemies"]
	assert_between(enemies.size(), 1, 2)
	assert_eq((enemies[0] as Dictionary)["hp"], 20)
	assert_eq((enemies[0] as Dictionary)["timer_ms"], 2800, "timer = own interval (F-77)")
	assert_eq(state["target"], 0)


func test_stop_returns_to_idle_with_full_hp_and_keeps_the_bag() -> void:
	_session.combat.start(AREA)
	_session.combat.loot.add(&"test_twig", 3)
	watch_signals(_session.events)
	_session.combat.stop()
	assert_eq(_session.combat.state(), CombatEngine.STATE_IDLE)
	assert_false(_session.combat.is_active())
	assert_signal_emitted_with_parameters(_session.events, "combat_stopped", [Reasons.STOPPED_BY_USER])
	assert_eq(_session.combat.loot.items().size(), 1)
	assert_eq(_session.combat.stop_reasons_log(), _ids([Reasons.STOPPED_BY_USER]))
	_session.combat.stop()
	assert_eq(_session.combat.stop_reasons_log().size(), 1, "stopping while idle does nothing")


func test_combat_and_actions_replace_each_other() -> void:
	assert_true(_session.actions.start(&"test_gather", &"gather_twig").ok)
	assert_true(_session.combat.start(AREA).ok)
	assert_false(_session.actions.is_running(), "combat stops the main lane")
	assert_eq(_session.actions.stop_reasons_log(), _ids([Reasons.REPLACED]))
	assert_true(_session.actions.start(&"test_gather", &"gather_twig").ok)
	assert_false(_session.combat.is_active(), "an action stops the combat")
	assert_eq(_session.combat.stop_reasons_log(), _ids([Reasons.REPLACED]))


func test_in_encounter_blocks_equipment_changes_not_between() -> void:
	_session.equipment.equip(TestFactory.give_piece(_session, BLADE))
	_session.combat.start(AREA)
	var uid: int = TestFactory.give_piece(_session, SHIELD)
	assert_false(_session.equipment.equip(uid, &"offhand").ok, "weapons and shields are locked in an encounter")


# --- kills, xp, gold, drops ------------------------------------------------------------------------------------

func _fight_until_kills(session: GameSession, count: int, step_ms: int = 5000) -> Array[StringName]:
	var killed: Array[StringName] = []
	session.events.monster_killed.connect(func(_i: int, id: StringName) -> void: killed.append(id))
	session.combat.start(AREA)
	var guard: int = 0
	while killed.size() < count and guard < 20000:
		session.combat.advance(step_ms)
		guard += 1
	return killed


func test_kill_grants_character_xp() -> void:
	_hero(_session)
	var before: int = _session.character.get_xp()
	var killed: Array[StringName] = _fight_until_kills(_session, 3)
	var expected: int = 0
	for id: StringName in killed:
		expected += _kill_xp(MONSTER_A if id == MONSTER_A else MONSTER_B)  # F-28: floor(xp x kill_xp_mult)
	assert_eq(_session.character.get_xp() - before, expected, "F-28: the xp of each monster killed")
	assert_eq(_session.combat.kills(MONSTER_A) + _session.combat.kills(MONSTER_B), killed.size())


func test_kill_xp_with_percent_bonus() -> void:
	# F-28 examples: plains_boar xp x kill_xp_mult, at +25% -> floor(x 1.25). The character xp passes through F-71.
	_boost(_session, [Modifier.make(&"power_bonus", 5000.0), Modifier.make(&"max_hp_flat", 100000.0),
			Modifier.make(&"skill_xp_pct", 25.0)])
	var before: int = _session.character.get_xp()
	_session.combat.start(AREA)
	var state: Dictionary = _session.combat.get_state()
	var ids: Array[StringName] = []
	for enemy: Dictionary in state["enemies"]:
		ids.append(enemy["monster"])
	if ids == _ids([MONSTER_A]):
		var guard: int = 0
		while _session.combat.total_kills().is_empty() and guard < 1000:
			_session.combat.advance(1000)
			guard += 1
		assert_eq(_session.character.get_xp() - before, floori(float(_kill_xp(MONSTER_A)) * 1.25 + 1e-9))
	else:
		pending("seed 1234 drew the two-monster pack first")


func test_gold_drop_pct() -> void:
	# Same seed -> same rolls: the gold of the first kill with +25% is floor(roll x 1.25) (F-31: 10 -> 12).
	for seed_value: int in [1, 2, 3, 4, 5, 6]:
		var plain: GameSession = _new_session(seed_value)
		var boosted: GameSession = _new_session(seed_value)
		var start_gold: int = plain.wallet.get_gold()
		_hero(plain)
		_boost(boosted, [Modifier.make(&"power_bonus", 5000.0), Modifier.make(&"max_hp_flat", 100000.0),
				Modifier.make(&"gold_drop_pct", 25.0)])
		_fight_until_kills(plain, 1)
		_fight_until_kills(boosted, 1)
		var rolled: int = plain.wallet.get_gold() - start_gold
		assert_between(rolled, 1, 12, "within the gold range of the monsters")
		assert_eq(boosted.wallet.get_gold() - start_gold, floori(rolled * 1.25), "seed %d" % seed_value)


func _gold_per_kill(session: GameSession, count: int) -> Array[int]:
	var gains: Array[int] = []
	session.events.gold_changed.connect(func(_amount: int, delta: int) -> void: gains.append(delta))
	_fight_until_kills(session, count)
	return gains


func test_gold_example_roll_ten_with_25_pct_gives_twelve() -> void:
	# F-31 example: roll 10 (monster B, gold 5-12), +25% -> 12. Same seed -> same kills and rolls in both sessions.
	var found: bool = false
	for seed_value: int in range(1, 40):
		var plain: GameSession = _new_session(seed_value)
		var boosted: GameSession = _new_session(seed_value)
		_hero(plain)
		_boost(boosted, [Modifier.make(&"power_bonus", 5000.0), Modifier.make(&"max_hp_flat", 100000.0),
				Modifier.make(&"gold_drop_pct", 25.0)])
		var a: Array[int] = _gold_per_kill(plain, 30)
		var b: Array[int] = _gold_per_kill(boosted, 30)
		assert_eq(a.size(), b.size(), "seed %d: same kills" % seed_value)
		var at: int = a.find(10)
		if at >= 0:
			assert_eq(b[at], 12, "seed %d: roll 10 with +25%% -> 12" % seed_value)
			found = true
			break
	assert_true(found, "some seed rolls 10 gold")


func test_drops_and_shard_chance() -> void:
	# F-32: test_log drops at 25% of the kills of monster A; F-07: shard chance 100 -> one per kill.
	_hero(_session)
	_boost(_session, [Modifier.make(&"power_bonus", 5000.0), Modifier.make(&"max_hp_flat", 100000.0),
			Modifier.make(&"loot_bag_slots", 8.0)])
	var killed: Array[StringName] = _fight_until_kills(_session, 400, 2000)
	var bag: Dictionary = {}
	for entry: Dictionary in _session.combat.loot.items():
		bag[entry["item"]] = entry["qty"]
	var monsters_a: int = _session.combat.kills(MONSTER_A)
	var logs: int = bag.get(&"test_log", 0)
	assert_between(float(logs) / float(monsters_a), 0.17, 0.33, "25% per kill of A")
	var shards: int = bag.get(&"rift_shard", 0)
	assert_between(float(shards) / float(killed.size()), 0.0, 0.05, "0.5% - 1% per kill")
	_session.combat.stop()
	_boost(_session, [Modifier.make(&"power_bonus", 5000.0), Modifier.make(&"max_hp_flat", 100000.0),
			Modifier.make(&"rift_shard_chance", 100.0)])
	var other: GameSession = _new_session(7)
	_boost(other, [Modifier.make(&"power_bonus", 5000.0), Modifier.make(&"max_hp_flat", 100000.0),
			Modifier.make(&"rift_shard_chance", 100.0)])
	var count: Array[StringName] = _fight_until_kills(other, 5)
	var other_shards: int = 0
	for entry: Dictionary in other.combat.loot.items():
		if entry["item"] == &"rift_shard":
			other_shards = entry["qty"]
	assert_eq(other_shards, count.size(), "chance 100: always one rift_shard")


func test_clearing_waits_respawn_ms_then_a_new_encounter() -> void:
	_hero(_session)
	watch_signals(_session.events)
	_session.combat.start(AREA)
	var guard: int = 0
	while _session.combat.state() == CombatEngine.STATE_ENCOUNTER and guard < 1000:
		_session.combat.advance(100)
		guard += 1
	assert_eq(_session.combat.state(), CombatEngine.STATE_BETWEEN)
	assert_signal_emitted(_session.events, "encounter_cleared")
	var wait: int = int(_session.data.balance_value("combat.respawn_ms"))
	var left: int = int(_session.combat.get_state()["between_ms"])
	assert_between(left, 1, wait)
	_session.combat.advance(left - 1)
	assert_eq(_session.combat.state(), CombatEngine.STATE_BETWEEN)
	_session.combat.advance(1)
	assert_eq(_session.combat.state(), CombatEngine.STATE_ENCOUNTER)
	assert_signal_emit_count(_session.events, "encounter_started", 2)


# --- order (F-76), target rules, packs -------------------------------------------------------------------------

func _tie_session(seed_value: int) -> GameSession:
	# attack_interval_pct +16.6667 makes the player's 2400 ms equal to monster A's 2800 ms.
	var s: GameSession = _new_session(seed_value)
	_boost(s, [Modifier.make(&"attack_interval_pct", 16.6667), Modifier.make(&"max_hp_flat", 100000.0)])
	_record_hits(s)
	s.combat.start(AREA)
	return s


func test_player_acts_before_the_enemies_in_the_same_instant() -> void:
	var checked: bool = false
	for seed_value: int in range(1, 40):
		var s: GameSession = _tie_session(seed_value)
		var enemies: Array = s.combat.get_state()["enemies"]
		if enemies.size() != 1:
			continue
		s.combat.advance(2800)
		assert_eq(_hits.size(), 2, "both attack at 2800 ms")
		assert_eq(_hits[0][0], CombatEngine.PLAYER, "the player first")
		assert_eq(_hits[1][0], 0)
		checked = true
		break
	assert_true(checked)


func test_a_dead_enemy_does_not_strike_in_the_same_instant() -> void:
	# 10.9: the player kills the only enemy at the instant both would attack: the enemy never attacks.
	var found: bool = false
	for seed_value: int in range(1, 60):
		var s: GameSession = _tie_session(seed_value)
		_boost(s, [Modifier.make(&"attack_interval_pct", 16.6667), Modifier.make(&"power_bonus", 5000.0),
				Modifier.make(&"max_hp_flat", 100000.0)])
		if (s.combat.get_state()["enemies"] as Array).size() != 1:
			continue
		s.combat.advance(2800)
		if _hits[0][2]:
			assert_eq(_hits.size(), 1, "seed %d: killed first, no counter-attack" % seed_value)
			assert_eq(s.combat.state(), CombatEngine.STATE_BETWEEN)
			found = true
			break
	assert_true(found)


func test_target_rules() -> void:
	# F-76: hp [0, 30, 12] (the first is dead): first = 1, lowest_hp = 2, highest_hp = 1.
	var data: GameData = _session.data
	var entries: Array = []
	for hp: int in [0, 30, 12]:
		entries.append({"monster": "test_monster_b", "hp": hp, "timer_ms": 100})
	var encounter: Encounter = Encounter.from_save(entries, data)
	assert_eq(encounter.target(Encounter.RULE_FIRST), 1)
	assert_eq(encounter.target(Encounter.RULE_LOWEST_HP), 2)
	assert_eq(encounter.target(Encounter.RULE_HIGHEST_HP), 1)
	entries[1]["hp"] = 12
	assert_eq(Encounter.from_save(entries, data).target(Encounter.RULE_LOWEST_HP), 1, "ties: lowest position")
	assert_eq(Encounter.from_save([{"monster": "test_monster_b", "hp": 0, "timer_ms": 0}], data).target(
			Encounter.RULE_FIRST), -1, "no living enemy")


func test_pack_weights() -> void:
	# F-77: weights [3, 1] -> the first pack (one monster) 72%-78% of 4000 draws.
	var area: AreaDef = _session.data.area(AREA)
	var single: int = 0
	for i: int in 4000:
		if Encounter.spawn(area, _session.data, _session.rng).enemies.size() == 1:
			single += 1
	assert_between(float(single) / 4000.0, 0.72, 0.78)


func test_same_monster_twice_is_two_instances() -> void:
	var real: GameSession = autofree(TestFactory.session(3, TestFactory.real_data()))
	var area: AreaDef = real.data.area(&"redrock_plains")
	var found: bool = false
	for i: int in 200:
		var encounter: Encounter = Encounter.spawn(area, real.data, real.rng)
		if encounter.enemies.size() == 2 and encounter.enemies[0].def.id == encounter.enemies[1].def.id:
			encounter.enemies[0].hp = 1
			assert_eq(encounter.enemies[1].hp, 20, "separate hp")
			found = true
			break
	assert_true(found)


# --- parry (F-75), dual wield, hp ------------------------------------------------------------------------------

func _count_enemy_hits(session: GameSession) -> Dictionary:
	var result: Dictionary = {"hits": 0, "blocked": 0}
	for h: Array in _hits:
		if int(h[0]) >= 0 and bool(h[2]):
			result["hits"] += 1
			if bool(h[4]):
				result["blocked"] += 1
	return result


func test_block_chance() -> void:
	# F-75: with a shield each enemy hit tries block_chance (limit 50); without one no roll.
	_session.equipment.equip(TestFactory.give_piece(_session, SHIELD))
	_boost(_session, [Modifier.make(&"block_chance", 45.0), Modifier.make(&"max_hp_flat", 100000.0)])
	assert_eq(_session.combat.player_stats().block_chance, 45.0)
	_boost(_session, [Modifier.make(&"block_chance", 95.0), Modifier.make(&"max_hp_flat", 100000.0)])
	assert_eq(_session.combat.player_stats().block_chance, 50.0, "T8 + 40 = 55 -> limit 50")
	_record_hits(_session)
	_session.combat.start(AREA)
	for i: int in 9000:
		_session.combat.advance(1000)
	var counts: Dictionary = _count_enemy_hits(_session)
	assert_gt(int(counts["hits"]), 500, "enough samples")
	assert_between(float(counts["blocked"]) / float(counts["hits"]), 0.43, 0.57)
	for h: Array in _hits:
		if bool(h[4]):
			assert_eq(h[3], 0, "a parried hit does 0 damage")

	var plain: GameSession = _new_session(99)
	_boost(plain, [Modifier.make(&"block_chance", 40.0), Modifier.make(&"max_hp_flat", 100000.0)])
	assert_eq(plain.combat.player_stats().block_chance, 0.0, "no shield, no roll")
	_record_hits(plain)
	plain.combat.start(AREA)
	for i: int in 300:
		plain.combat.advance(1000)
	assert_eq(int(_count_enemy_hits(plain)["blocked"]), 0)


func test_a_parried_hit_does_not_trigger_field_rations() -> void:
	_session.equipment.equip(TestFactory.give_piece(_session, SHIELD))
	TestFactory.give(_session, RATION, 20)
	_session.equipment.set_food(RATION)
	_boost(_session, [Modifier.make(&"block_chance", 50.0), Modifier.make(&"auto_eat_tier", 3.0),
			Modifier.make(&"max_hp_flat", 100.0)])
	_record_hits(_session)
	_session.combat.start(AREA)
	for i: int in 400:
		_session.combat.advance(1000)
		if _session.combat.state() == CombatEngine.STATE_IDLE:
			break
	assert_eq(_session.combat.food_eaten(), 20 - _session.bank.get_count(RATION), "pieces counted exactly")


func test_dual_wield_alternates_hands() -> void:
	_session.equipment.equip(TestFactory.give_piece(_session, BLADE))
	_session.equipment.equip(TestFactory.give_piece(_session, BLADE), &"offhand")
	_boost(_session, [Modifier.make(&"max_hp_flat", 100000.0)])
	_session.combat.start(AREA)
	assert_eq(_session.combat.get_state()["hand"], 0)
	_session.combat.advance(int(_session.combat.get_state()["player_timer_ms"]))
	assert_eq(_session.combat.get_state()["hand"], 1)
	_session.combat.advance(int(_session.combat.get_state()["player_timer_ms"]))
	assert_eq(_session.combat.get_state()["hand"], 0)


func test_hp_never_exceeds_a_lowered_maximum() -> void:
	_boost(_session, [Modifier.make(&"max_hp_flat", 40.0)])
	_session.combat.start(AREA)
	assert_eq(_session.combat.get_state()["player_hp"], 100)
	_boost(_session, [])
	assert_eq(_session.combat.get_state()["player_hp"], 60)
	assert_eq(_session.combat.get_state()["player_max_hp"], 60)


# --- food, death -----------------------------------------------------------------------------------------------

func _hurt(session: GameSession, hp: int) -> void:
	var saved: Dictionary = session.combat.to_save()
	saved["player_hp"] = hp
	session.combat.from_save(saved)
	session.rebuild_modifiers()


func test_manual_eat() -> void:
	assert_eq(_session.combat.eat().reason, Reasons.NOT_RUNNING)
	TestFactory.give(_session, RATION, 3)
	_session.equipment.set_food(RATION)
	_session.combat.start(AREA)
	assert_true(_session.combat.eat().ok, "full hp: nothing eaten but not an error")
	assert_eq(_session.combat.food_eaten(), 0)
	_hurt(_session, 10)
	assert_true(_session.combat.eat().ok)
	assert_eq(_session.combat.get_state()["player_hp"], 30, "F-29: ration heals 20")
	assert_eq(_session.combat.food_eaten(), 1)
	assert_eq(_session.bank.get_count(RATION), 2)
	_session.equipment.set_food(&"")
	assert_eq(_session.combat.eat().reason, Reasons.NO_FOOD)


func test_death_loses_only_the_bag() -> void:
	TestFactory.give(_session, &"test_log", 5)
	_session.wallet.add_gold(50)
	_session.combat.start(AREA)
	_session.combat.loot.add(&"test_twig", 3)
	_hurt(_session, 1)
	watch_signals(_session.events)
	var guard: int = 0
	while _session.combat.deaths() == 0 and guard < 2000:
		_session.combat.advance(1000)
		guard += 1
	assert_eq(_session.combat.deaths(), 1)
	assert_signal_emitted(_session.events, "player_died")
	assert_signal_emitted_with_parameters(_session.events, "combat_stopped", [Reasons.PLAYER_DIED])
	assert_signal_emitted_with_parameters(_session.events, "loot_lost", [&"test_twig", 3])
	assert_eq(_session.combat.state(), CombatEngine.STATE_IDLE)
	assert_eq(_session.combat.get_state()["player_hp"], 60, "hp back to the maximum")
	assert_true(_session.combat.loot.items().is_empty())
	assert_eq(_session.bank.get_count(&"test_log"), 5, "the bank is untouched")
	assert_gte(_session.wallet.get_gold(), 50, "gold is not lost")
	assert_true(_session.combat.stop_reasons_log().has(Reasons.PLAYER_DIED))


# --- equivalence and save --------------------------------------------------------------------------------------

func _equal_runs(seed_value: int, total_ms: int, step_a: int, step_b: int) -> void:
	var a: GameSession = _new_session(seed_value)
	var b: GameSession = _new_session(seed_value)
	for s: GameSession in [a, b]:
		_boost(s, [Modifier.make(&"power_bonus", 40.0), Modifier.make(&"max_hp_flat", 30.0)])
		s.combat.start(AREA)
	for i: int in total_ms / step_a:
		a.combat.advance(step_a)
	for i: int in total_ms / step_b:
		b.combat.advance(step_b)
	assert_eq(a.combat.to_save(), b.combat.to_save(), "seed %d: combat state" % seed_value)
	assert_eq(a.rng.to_save(), b.rng.to_save(), "seed %d: rng" % seed_value)
	assert_eq(a.wallet.get_gold(), b.wallet.get_gold())
	assert_eq(a.character.get_xp(), b.character.get_xp())


func test_advance_one_second_equals_ten_hundreds() -> void:
	for seed_value: int in [11, 12, 13, 14]:
		_equal_runs(seed_value, 600000, 1000, 100)
	_equal_runs(15, 300000, 100000, 700)


func test_session_advance_drives_the_combat() -> void:
	_session.combat.start(AREA)
	var before: int = int(_session.combat.get_state()["player_timer_ms"])
	_session.advance(100)
	assert_eq(int(_session.combat.get_state()["player_timer_ms"]), before - 100)


func test_save_roundtrip_continues_identically() -> void:
	_session.combat.start(AREA)
	_session.combat.loot.add(&"test_twig", 2)
	_session.advance(31000)
	var saved: Dictionary = _session.to_save(1000)
	var json_text: String = JSON.stringify(saved)
	var copy: GameSession = autofree(TestFactory.session(5))
	assert_true(copy.from_save(JSON.parse_string(json_text) as Dictionary).ok)
	assert_eq(copy.combat.to_save(), _session.combat.to_save())
	_session.advance(60000)
	copy.advance(60000)
	assert_eq(copy.combat.to_save(), _session.combat.to_save(), "same state after going on")
	assert_eq(copy.wallet.get_gold(), _session.wallet.get_gold())


func test_from_save_tolerates_unknown_ids() -> void:
	_session.combat.start(AREA)
	_session.combat.loot.add(&"test_twig", 2)
	var saved: Dictionary = _session.combat.to_save()
	saved["kills"] = {"test_monster_a": 4, "ghost": 9}
	saved["deaths"] = 2
	var bad_area: Dictionary = saved.duplicate(true)
	bad_area["area"] = "ghost_area"
	_session.combat.from_save(bad_area)
	assert_eq(_session.combat.state(), CombatEngine.STATE_IDLE)
	assert_eq(_session.combat.kills(MONSTER_A), 4, "counters kept, unknown monster dropped")
	assert_eq(_session.combat.kills(&"ghost"), 0)
	assert_eq(_session.combat.deaths(), 2)
	assert_eq(_session.combat.loot.items().size(), 1, "the bag is kept")
	var bad_monster: Dictionary = saved.duplicate(true)
	(bad_monster["enemies"] as Array)[0]["monster"] = "ghost"
	_session.combat.from_save(bad_monster)
	assert_eq(_session.combat.state(), CombatEngine.STATE_IDLE)


func test_new_game_resets_everything() -> void:
	_session.combat.start(AREA)
	_session.combat.loot.add(&"test_twig", 2)
	_session.combat.new_game()
	assert_eq(_session.combat.state(), CombatEngine.STATE_IDLE)
	assert_true(_session.combat.loot.items().is_empty())
	assert_eq(_session.combat.deaths(), 0)
	assert_eq(_session.combat.get_state()["player_hp"], 60)


func test_snapshot_reads_the_counters() -> void:
	_hero(_session)
	_fight_until_kills(_session, 2)
	var snapshot: SessionSnapshot = SessionSnapshot.take(_session)
	assert_eq(snapshot.kills, _session.combat.total_kills())
	assert_eq(snapshot.deaths, 0)


func _ids(list: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for id: Variant in list:
		result.append(StringName(str(id)))
	return result


# --- idle save normalization (M6-02, 05 §5.10) ------------------------------------------------------------------

func _assert_idle_roundtrip(session: GameSession, label: String) -> void:
	var saved: Dictionary = session.combat.to_save()
	assert_eq(saved["state"], "idle", label)
	assert_eq(saved["area"], "", "%s: area empty" % label)
	for key: String in ["player_hp", "player_timer_ms", "hand", "between_ms"]:
		assert_eq(saved[key], 0, "%s: %s written as 0" % [label, key])
	assert_eq(saved["enemies"], [])
	var copy: GameSession = autofree(TestFactory.session(5))
	copy.combat.from_save(JSON.parse_string(JSON.stringify(saved)) as Dictionary)
	assert_eq(copy.combat.to_save(), saved, "%s: save -> load -> save identical" % label)
	assert_eq(copy.combat.area_id(), &"")


func test_idle_save_is_normalized_after_stop() -> void:
	_session.combat.start(AREA)
	_session.combat.loot.add(&"test_twig", 2)
	_session.combat.advance(1000)
	_session.combat.stop()
	_assert_idle_roundtrip(_session, "after stop")
	assert_eq(_session.combat.to_save()["loot"]["stacks"].size(), 1, "the bag is kept")


func test_idle_save_is_normalized_after_death() -> void:
	_session.combat.start(AREA)
	_hurt(_session, 1)
	var guard: int = 0
	while _session.combat.deaths() == 0 and guard < 2000:
		_session.combat.advance(1000)
		guard += 1
	assert_eq(_session.combat.deaths(), 1)
	_assert_idle_roundtrip(_session, "after death")


func test_new_game_save_is_normalized() -> void:
	_assert_idle_roundtrip(_session, "new game")


func _kill_xp(monster_id: StringName) -> int:
	return floori(float(_session.data.monster(monster_id).xp) * float(_session.data.balance_value("combat.kill_xp_mult")) + 1e-9)
