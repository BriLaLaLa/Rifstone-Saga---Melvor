extends GutTest
## M6-03: active abilities (F-79 cooldown, F-80 effect), the `ability_used` event, `get_state()["abilities"]`, the save
## of timers and buffs, and the equivalence of advance(1000) with ten advance(100).

const HUGE: int = 1000000  # a timer that never expires during a test

var _session: GameSession
var _added: Array[AbilityDef] = []
var _uses: Array = []  # [clock_ms, ability id, targets]
var _clock: int = 0


func before_each() -> void:
	_session = autofree(TestFactory.session(41))
	TestFactory.set_character_level(_session, 30)
	_uses.clear()
	_clock = 0
	_session.events.ability_used.connect(func(id: StringName, targets: Array[int]) -> void:
		_uses.append([_clock, id, targets]))


func after_each() -> void:
	var class_def: ClassDef = _session.character.class_def()
	for def: AbilityDef in _added:
		class_def.abilities.erase(def)
	_added.clear()
	EffectKit.cleanup()


# Puts a test ability in the fixture class and equips it in `slot` (removed in after_each).
func _equip(id: String, kind: String, cooldown: int, params: Dictionary, slot: int = 0, setups: Array = []) -> void:
	var def: AbilityDef = AbilityDef.from_dict({"id": id, "name": "Prova", "description": "Prova.", "unlock_level": 1,
		"setups": setups, "kind": kind, "cooldown_ms": cooldown, "params": params})
	assert(def != null, "invalid test ability")
	_session.character.class_def().abilities.append(def)
	_added.append(def)
	var result: CommandResult = _session.loadout.set_ability(slot, StringName(id))
	assert(result.ok, "set_ability failed: %s" % result.reason)


func _fight(enemies: Array, hp: int = 100060) -> Dictionary:
	return EffectKit.fight(enemies, HUGE, hp)


func _quiet_enemy(monster: String = "test_monster_b") -> Dictionary:
	return EffectKit.enemy(monster, 60 if monster == "test_monster_b" else 20, HUGE)


func _run(ms: int, step: int = 1000) -> void:
	for i: int in ms / step:
		_clock += step
		_session.combat.advance(step)


# --- F-80 ---------------------------------------------------------------------------------------------------------

func _enemy_with(stats: CombatantStats, hp: int) -> Encounter.Enemy:
	var enemy := Encounter.Enemy.new(_session.data.monster(&"test_monster_a"), _session.data)
	enemy.stats = stats
	enemy.hp = hp
	return enemy


func _stats(style: StringName, min_hit: int, max_hit: int, dr: float) -> CombatantStats:
	var stats := CombatantStats.new()
	stats.style = style
	stats.accuracy = 1000000
	stats.evasion = 1
	stats.min_hit = min_hit
	stats.max_hit = max_hit
	stats.damage_reduction = dr
	stats.max_hp = 170
	return stats


func test_strike_example_roll_30_power_2_dr_10_is_54() -> void:
	_equip("t_strike", "strike", 8000, {"power_mult": 2.0})
	var runner := AbilityRunner.new(_session)
	var encounter := Encounter.new()
	encounter.enemies.append(_enemy_with(_stats(&"blade", 1, 1, 10.0), 100))
	var me: CombatantStats = _stats(&"blade", 30, 30, 0.0)
	assert_null(runner.take_due(encounter, 170, me, Encounter.RULE_FIRST), "cooldown starts full")
	runner.tick(8000)
	var use: AbilityRunner.Use = runner.take_due(encounter, 170, me, Encounter.RULE_FIRST)
	assert_not_null(use)
	assert_eq(use.targets, [0] as Array[int])
	assert_true(use.attacks[0]["hit"])
	assert_eq(use.attacks[0]["damage"], 54)
	assert_null(runner.take_due(encounter, 170, me, Encounter.RULE_FIRST), "the cooldown restarted")


func test_strike_uses_the_target_rule() -> void:
	_equip("t_strike", "strike", 3000, {"power_mult": 1.0})
	var runner := AbilityRunner.new(_session)
	var encounter := Encounter.new()
	encounter.enemies.append(_enemy_with(_stats(&"blade", 1, 1, 0.0), 30))
	encounter.enemies.append(_enemy_with(_stats(&"blade", 1, 1, 0.0), 12))
	runner.tick(3000)
	var use: AbilityRunner.Use = runner.take_due(encounter, 170, _stats(&"blade", 5, 5, 0.0), Encounter.RULE_LOWEST_HP)
	assert_eq(use.targets, [1] as Array[int])


func test_cleave_targets_all_or_the_first_n_alive() -> void:
	_equip("t_cleave", "cleave", 3000, {"power_mult": 1.0, "targets": 2})
	var runner := AbilityRunner.new(_session)
	var encounter := Encounter.new()
	for hp: int in [10, 0, 10, 10]:
		encounter.enemies.append(_enemy_with(_stats(&"blade", 1, 1, 0.0), hp))
	runner.tick(3000)
	var me: CombatantStats = _stats(&"blade", 5, 5, 0.0)
	assert_eq(runner.take_due(encounter, 170, me, Encounter.RULE_FIRST).targets, [0, 2] as Array[int])
	_session.loadout.set_ability(0, &"")
	_equip("t_all", "cleave", 3000, {"power_mult": 1.0, "targets": 0})
	var all := AbilityRunner.new(_session)
	all.tick(3000)
	assert_eq(all.take_due(encounter, 170, me, Encounter.RULE_FIRST).targets, [0, 2, 3] as Array[int])


func test_heal_example_20_pct_of_170_from_100_is_134() -> void:
	_equip("t_mend", "heal", 3000, {"heal_pct": 20})
	var runner := AbilityRunner.new(_session)
	var encounter := Encounter.new()
	encounter.enemies.append(_enemy_with(_stats(&"blade", 1, 1, 0.0), 10))
	var me: CombatantStats = _stats(&"blade", 5, 5, 0.0)
	runner.tick(3000)
	assert_eq(runner.next_ms(170, 170), AbilityRunner.NO_TIMER, "full hp: nothing to heal")
	assert_eq(runner.next_ms(100, 170), 0)
	var use: AbilityRunner.Use = runner.take_due(encounter, 100, me, Encounter.RULE_FIRST)
	assert_eq(mini(170, 100 + use.heal), 134)
	assert_true(use.targets.is_empty())


func test_engine_heal_restores_the_percentage_and_stops_at_the_maximum() -> void:
	_equip("t_mend", "heal", 3000, {"heal_pct": 20})
	EffectKit.sturdy(_session)
	var max_hp: int = _session.combat.player_stats().max_hp
	_session.combat.from_save(_fight([_quiet_enemy()], 100))
	_run(3000)
	assert_eq(_session.combat.get_state()["player_hp"], 100 + int(floor(max_hp * 20.0 / 100.0)))
	assert_eq(_uses, [[3000, &"t_mend", [] as Array[int]]])
	_session.combat.from_save(_fight([_quiet_enemy()], max_hp - 5))
	_run(3000)
	assert_eq(_session.combat.get_state()["player_hp"], max_hp)


func test_engine_heal_waits_for_missing_hp_then_fires() -> void:
	_equip("t_mend", "heal", 3000, {"heal_pct": 20})
	var max_hp: int = _session.combat.player_stats().max_hp
	_session.combat.from_save(_fight([_quiet_enemy()], max_hp))
	_run(7000)
	assert_true(_uses.is_empty(), "full hp: not used")
	assert_eq(_session.combat.get_state()["abilities"][0]["timer_ms"], 0, "ready and waiting")
	EffectKit.sturdy(_session)  # the maximum grows: hp is now below it
	_run(1, 1)
	assert_eq(_uses.size(), 1, "used the moment it became useful")


# --- buffs -------------------------------------------------------------------------------------------------------

func _equip_guard(duration: int = 6000, cooldown: int = 8000) -> void:
	_equip("t_guard", "buff", cooldown, {"modifiers": [{"stat": "armor", "value": 5}],
		"duration_ms": duration})
	EffectKit.sturdy(_session)


func test_buff_used_at_8000_lasts_6000_ms() -> void:
	_equip_guard()
	_session.combat.from_save(_fight([_quiet_enemy()]))
	_run(7999, 1)
	assert_true(_session.combat.get_state()["buffs"].is_empty())
	_run(1, 1)
	assert_eq(_session.combat.get_state()["buffs"], {&"t_guard": 6000})
	assert_true(_session.modifiers.has_source(&"ability:t_guard"))
	assert_eq(_session.modifiers.total(&"armor"), 5.0)
	_run(5999, 1)
	assert_eq(_session.combat.get_state()["buffs"], {&"t_guard": 1}, "active until 14000")
	_run(1, 1)
	assert_true(_session.combat.get_state()["buffs"].is_empty())
	assert_false(_session.modifiers.has_source(&"ability:t_guard"))
	assert_eq(_session.modifiers.total(&"armor"), 0.0)


func test_buff_is_used_again_only_after_it_ended() -> void:
	_equip_guard(20000, 8000)
	_session.combat.from_save(_fight([_quiet_enemy()]))
	_run(40000)
	assert_eq(_uses.size(), 2)
	assert_eq(_uses[0][0], 8000)
	assert_eq(_uses[1][0], 28000, "ready at 16000 but the buff runs until 28000")


func test_buff_does_not_survive_stop_or_death() -> void:
	_equip_guard(20000, 3000)
	_session.combat.from_save(_fight([_quiet_enemy()]))
	_run(3000)
	assert_true(_session.modifiers.has_source(&"ability:t_guard"))
	_session.combat.stop()
	assert_false(_session.modifiers.has_source(&"ability:t_guard"))
	assert_true(_session.combat.get_state()["buffs"].is_empty())
	assert_true(_session.combat.to_save()["buffs"].is_empty())


# --- cooldowns ---------------------------------------------------------------------------------------------------

func test_cooldown_8000_with_an_enemy_always_present_uses_at_8000_16000_24000() -> void:
	_equip("t_strike", "strike", 8000, {"power_mult": 0.1})
	_session.combat.from_save(_fight([_quiet_enemy()]))
	_run(25000)
	var times: Array = []
	for use: Array in _uses:
		times.append(use[0])
	assert_eq(times, [8000, 16000, 24000])


func test_timers_run_between_encounters() -> void:
	_equip("t_strike", "strike", 8000, {"power_mult": 1.0})
	var saved: Dictionary = {"state": "between", "area": "test_area", "player_hp": 50, "player_timer_ms": 1000,
		"hand": 0, "between_ms": 3000, "enemies": [], "abilities": {"t_strike": 5000}, "buffs": {}, "loot": [],
		"kills": {}, "deaths": 0, "food_eaten": 0}
	_session.combat.from_save(saved)
	_session.combat.advance(2000)
	assert_eq(_session.combat.get_state()["abilities"][0]["timer_ms"], 3000)
	assert_true(_uses.is_empty(), "no target between encounters")


func test_ready_ability_fires_when_the_next_encounter_starts() -> void:
	_equip("t_strike", "strike", 8000, {"power_mult": 1.0})
	EffectKit.sturdy(_session)
	var saved: Dictionary = {"state": "between", "area": "test_area", "player_hp": 1000, "player_timer_ms": HUGE,
		"hand": 0, "between_ms": 1000, "enemies": [], "abilities": {"t_strike": 0}, "buffs": {}, "loot": [],
		"kills": {}, "deaths": 0, "food_eaten": 0}
	_session.combat.from_save(saved)
	_session.combat.advance(1000)
	assert_eq(_session.combat.state(), CombatEngine.STATE_ENCOUNTER)
	assert_eq(_uses.size(), 1, "used the instant the pack appeared")


func test_disabled_ability_keeps_its_timer_frozen() -> void:
	_equip("t_frozen", "strike", 8000, {"power_mult": 1.0}, 0, ["no_such_setup"])
	_session.combat.from_save(_fight([_quiet_enemy()]))
	_run(20000)
	assert_true(_uses.is_empty())
	assert_eq(_session.combat.get_state()["abilities"], [
		{"id": &"t_frozen", "timer_ms": 8000, "cooldown_ms": 8000, "enabled": false}] as Array[Dictionary])


func test_state_lists_equipped_abilities_with_the_time_left() -> void:
	_equip("t_strike", "strike", 8000, {"power_mult": 0.1}, 0)
	_equip("t_mend", "heal", 12000, {"heal_pct": 20}, 1)
	assert_eq(_session.combat.get_state()["abilities"].size(), 2, "idle: listed with full cooldowns")
	assert_eq(_session.combat.get_state()["abilities"][1]["timer_ms"], 12000)
	_session.combat.from_save(_fight([_quiet_enemy()]))
	_run(3000)
	var first: Dictionary = _session.combat.get_state()["abilities"][0]
	assert_eq([first["id"], first["timer_ms"], first["cooldown_ms"], first["enabled"]], [&"t_strike", 5000, 8000, true])


# --- effects together --------------------------------------------------------------------------------------------

func _surehit() -> void:
	_session.modifiers.set_source(&"test:surehit", [Modifier.make(&"accuracy_bonus", 1000000.0)] as Array[Modifier])


func test_leech_heals_from_ability_hits() -> void:
	EffectKit.equip_trait(_session, &"t_leech", [{"type": "leech_pct", "params": {"pct": 100}}])
	_equip("t_strike", "strike", 3000, {"power_mult": 1.0})
	EffectKit.sturdy(_session)
	_surehit()
	var dealt: Array[int] = []
	_session.events.combat_hit.connect(func(a: int, _t: int, _h: bool, d: int, _b: bool) -> void:
		if a == CombatEngine.PLAYER:
			dealt.append(d))
	_session.combat.from_save(_fight([EffectKit.enemy("test_monster_b", 60, HUGE)], 50))
	_run(3000)
	assert_eq(dealt.size(), 1)
	assert_gt(dealt[0], 0)
	assert_eq(_session.combat.get_state()["player_hp"], 50 + dealt[0])


func test_ability_that_kills_the_last_enemy_ends_the_encounter() -> void:
	_equip("t_strike", "strike", 3000, {"power_mult": 10.0})
	_equip("t_cleave", "cleave", 3000, {"power_mult": 10.0, "targets": 0}, 1)
	EffectKit.sturdy(_session)
	_surehit()
	_session.combat.from_save(_fight([EffectKit.enemy("test_monster_a", 1, HUGE)]))
	_run(3000)
	assert_eq(_session.combat.state(), CombatEngine.STATE_BETWEEN)
	assert_eq(_uses.size(), 1, "the second ability had no target left")
	assert_eq(_session.combat.kills(&"test_monster_a"), 1)


# --- save --------------------------------------------------------------------------------------------------------

func test_save_keeps_timers_and_buffs_and_the_roundtrip_is_identical() -> void:
	_equip_guard(20000, 3000)
	_equip("t_strike", "strike", 8000, {"power_mult": 0.1}, 1)
	_session.combat.from_save(_fight([_quiet_enemy()]))
	_run(4000)
	var saved: Dictionary = _session.combat.to_save()
	assert_eq(saved["abilities"], {"t_guard": 2000, "t_strike": 4000})
	assert_eq(saved["buffs"], {"t_guard": 19000})
	var copy: GameSession = autofree(TestFactory.session(41))
	TestFactory.set_character_level(copy, 30)
	copy.loadout.set_ability(0, &"t_guard")
	copy.loadout.set_ability(1, &"t_strike")
	EffectKit.sturdy(copy)
	copy.combat.from_save(JSON.parse_string(JSON.stringify(saved)) as Dictionary)
	assert_eq(copy.combat.to_save(), saved)
	assert_true(copy.modifiers.has_source(&"ability:t_guard"), "the buff modifiers are registered again")


func test_full_session_save_load_rebuilds_the_buff_modifiers() -> void:
	_equip_guard(20000, 3000)
	_session.combat.from_save(_fight([_quiet_enemy()]))
	_run(3000)
	var data: Dictionary = JSON.parse_string(JSON.stringify(_session.to_save(0))) as Dictionary
	_session.modifiers.clear_all()
	assert_true(_session.from_save(data).ok)
	assert_true(_session.modifiers.has_source(&"ability:t_guard"))
	assert_eq(_session.modifiers.total(&"armor"), 5.0)


func test_idle_engine_saves_no_ability_state() -> void:
	_equip("t_strike", "strike", 3000, {"power_mult": 1.0})
	_session.combat.from_save(_fight([_quiet_enemy()]))
	_run(2000)
	_session.combat.stop()
	var saved: Dictionary = _session.combat.to_save()
	assert_eq(saved["abilities"], {})
	assert_eq(saved["buffs"], {})
	_session.combat.from_save(saved)
	assert_eq(_session.combat.to_save(), saved)


func test_malformed_ability_state_in_the_save_is_dropped_or_clamped() -> void:
	_equip("t_strike", "strike", 8000, {"power_mult": 1.0})
	_equip_guard(6000, 8000)
	var saved: Dictionary = _fight([_quiet_enemy()])
	saved["abilities"] = {"t_strike": 99999, "ghost": 5, "t_guard": "oops"}
	saved["buffs"] = {"t_guard": 99999, "t_strike": 100, "ghost": 7}
	_session.combat.from_save(saved)
	var out: Dictionary = _session.combat.to_save()
	assert_eq(out["abilities"], {"t_strike": 8000}, "clamped to the cooldown; bad entries dropped")
	assert_eq(out["buffs"], {"t_guard": 6000}, "clamped to the duration; only buffs")
	saved["abilities"] = 7
	saved["buffs"] = []
	_session.combat.from_save(saved)
	assert_eq(_session.combat.state(), CombatEngine.STATE_ENCOUNTER)
	assert_eq(_session.combat.to_save()["abilities"], {})


# --- determinism -------------------------------------------------------------------------------------------------

func _scenario(session: GameSession, steps: int, step_ms: int) -> Dictionary:
	TestFactory.set_character_level(session, 30)
	for i: int in _added.size():
		session.loadout.set_ability(i, _added[i].id)
	EffectKit.sturdy(session)
	session.combat.from_save(EffectKit.fight([EffectKit.enemy("test_monster_b", 60, 2400),
		EffectKit.enemy("test_monster_a", 20, 2800)], 2400, 40))
	for i: int in steps:
		session.combat.advance(step_ms)
	var out: Dictionary = session.combat.to_save()
	return out


func test_one_step_equals_ten_steps_with_abilities() -> void:
	_equip("t_strike", "strike", 3000, {"power_mult": 2.0}, 0)
	_equip("t_mend", "heal", 5000, {"heal_pct": 20}, 1)
	_equip("t_guard", "buff", 4000, {"modifiers": [{"stat": "armor", "value": 5}],
		"duration_ms": 2500}, 2)
	var coarse: Dictionary = _scenario(_session, 60, 1000)
	var other: GameSession = autofree(TestFactory.session(41))
	var fine: Dictionary = _scenario(other, 600, 100)
	assert_eq(fine, coarse)
	assert_eq(other.rng.randf() == _session.rng.randf(), true, "same random sequence consumed")
