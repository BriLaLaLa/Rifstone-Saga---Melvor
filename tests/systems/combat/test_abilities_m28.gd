extends GutTest
## M28-04, F-191 of docs/02_FORMULAS_M28.md (and the examples of F-190 that concern an ability): the new parameters of the
## abilities (`hits`, `target`, `execute`, `apply`, `drain_pct`) and the kind `ward`. Runner-level cases use stats built by hand,
## engine-level cases a fight on the fixture data with a scripted random source (`ConditionKit`).


## Like `ConditionKit.ScriptRng`, but the draws of `randf` can fail: `misses` is read once per `randf`, true = the roll fails.
class MissRng extends ConditionKit.ScriptRng:
	var misses: Array[bool] = []

	func randf() -> float:
		calls += 1
		return 1.0 if (not misses.is_empty() and misses.pop_front()) else 0.0


var _s: GameSession
var _added: Array[AbilityDef] = []


func after_each() -> void:
	if _s != null and _s.character != null:
		for def: AbilityDef in _added:
			_s.character.class_def().abilities.erase(def)
	_added.clear()


func _make(kind: String, params: Dictionary, cooldown: int = 1000) -> AbilityDef:
	var def: AbilityDef = AbilityDef.from_dict({"id": "t_ability", "name": "Prova", "description": "Prova.", "unlock_level": 1,
		"setups": [], "kind": kind, "cooldown_ms": cooldown, "params": params})
	assert_not_null(def, "valid test ability")
	_s.character.class_def().abilities.append(def)
	_added.append(def)
	assert_true(_s.loadout.set_ability(0, &"t_ability").ok)
	return def


# An engine fight with the ability in slot 0 (cooldown 1 s) and a scripted random source.
func _fight(enemies: Array, kind: String, params: Dictionary, max_hp_extra: int = 100000) -> MissRng:
	_s = autofree(ConditionKit.base(max_hp_extra))
	var rng := MissRng.new()
	_s.rng = rng
	_make(kind, params)
	ConditionKit.begin(_s, enemies, 100000, 60 + max_hp_extra)
	return rng


# A runner on a session with the ability, ready to be used.
func _runner(kind: String, params: Dictionary) -> AbilityRunner:
	_s = autofree(TestFactory.session(41))
	TestFactory.set_character_level(_s, 30)
	_make(kind, params, 3000)
	var runner := AbilityRunner.new(_s)
	runner.tick(3000)
	return runner


func _enemy_with(max_hp: int, hp: int, dr: float) -> Encounter.Enemy:
	var enemy := Encounter.Enemy.new(_s.data.monster(&"test_monster_a"), _s.data)
	enemy.stats = _stats(&"blade", 1, 1, dr)
	enemy.stats.max_hp = max_hp
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


func _hits(s: GameSession, rows: Array) -> void:
	s.events.combat_hit.connect(func(a: int, t: int, h: bool, d: int, _b: bool) -> void: rows.append([a, t, h, d]))


# --- F-191 hits -------------------------------------------------------------------------------------------------------

func test_hits_example_rain_of_cuts_leaves_the_fifth_roll_unused() -> void:
	var rng: MissRng = _fight([EffectKit.enemy(ConditionKit.MONSTER_A, 20, 100000)], "strike", {"power_mult": 0.5, "hits": 5})
	rng.ints = [20, 14, 30, 8]
	rng.misses = [false, true, false, false, false]
	var rows: Array = []
	_hits(_s, rows)
	var used: Array = []
	_s.events.ability_used.connect(func(id: StringName, targets: Array[int]) -> void: used.append([id, targets]))
	_s.combat.advance(1000)
	assert_eq(rows, [[CombatState.PLAYER, 0, true, 10], [CombatState.PLAYER, 0, false, 0], [CombatState.PLAYER, 0, true, 7],
			[CombatState.PLAYER, 0, true, 15]], "4 events, the miss included, the 5th discarded")
	assert_eq(used, [[&"t_ability", [0] as Array[int]]], "a target appears once")


func test_hits_rolls_all_before_applying() -> void:
	var runner: AbilityRunner = _runner("strike", {"power_mult": 1.0, "hits": 3})
	var encounter := Encounter.new()
	encounter.enemies.append(_enemy_with(100, 100, 0.0))
	var use: AbilityRunner.Use = runner.take_due(encounter, 170, _stats(&"blade", 5, 5, 0.0), Encounter.RULE_FIRST)
	assert_eq(use.targets, [0, 0, 0] as Array[int])
	assert_eq(use.attacks.size(), 3)
	assert_eq(encounter.enemies[0].hp, 100, "the runner changes no hp")


func test_a_strike_without_hits_has_one_roll() -> void:
	var runner: AbilityRunner = _runner("strike", {"power_mult": 1.0})
	var encounter := Encounter.new()
	encounter.enemies.append(_enemy_with(100, 100, 0.0))
	assert_eq(runner.take_due(encounter, 170, _stats(&"blade", 5, 5, 0.0), Encounter.RULE_FIRST).targets, [0] as Array[int])


# --- F-191 target ----------------------------------------------------------------------------------------------------

func test_target_overrides_the_rule_of_the_traits() -> void:
	var runner: AbilityRunner = _runner("strike", {"power_mult": 1.0, "target": "lowest_hp"})
	var encounter := Encounter.new()
	encounter.enemies.append(_enemy_with(100, 90, 0.0))
	encounter.enemies.append(_enemy_with(100, 20, 0.0))
	var use: AbilityRunner.Use = runner.take_due(encounter, 170, _stats(&"blade", 5, 5, 0.0), Encounter.RULE_HIGHEST_HP)
	assert_eq(use.targets, [1] as Array[int])


func test_without_target_the_rule_of_the_traits_is_used() -> void:
	var runner: AbilityRunner = _runner("strike", {"power_mult": 1.0})
	var encounter := Encounter.new()
	encounter.enemies.append(_enemy_with(100, 90, 0.0))
	encounter.enemies.append(_enemy_with(100, 20, 0.0))
	var use: AbilityRunner.Use = runner.take_due(encounter, 170, _stats(&"blade", 5, 5, 0.0), Encounter.RULE_LOWEST_HP)
	assert_eq(use.targets, [1] as Array[int])


# --- F-190 / F-191 execute -------------------------------------------------------------------------------------------

func test_execute_example_25_of_100_hp_is_117_and_31_is_46() -> void:
	var runner: AbilityRunner = _runner("strike", {"power_mult": 1.3, "execute": {"hp_pct": 30, "mult": 2.5}})
	var encounter := Encounter.new()
	encounter.enemies.append(_enemy_with(100, 25, 10.0))
	var me: CombatantStats = _stats(&"blade", 40, 40, 0.0)
	assert_eq(runner.take_due(encounter, 170, me, Encounter.RULE_FIRST).attacks[0]["damage"], 117, "floor(52 x 2.5) = 130, DR 10")
	runner.tick(3000)
	encounter.enemies[0].hp = 31
	assert_eq(runner.take_due(encounter, 170, me, Encounter.RULE_FIRST).attacks[0]["damage"], 46, "above the threshold: 52, DR 10")
	runner.tick(3000)
	encounter.enemies[0].hp = 30
	assert_eq(runner.take_due(encounter, 170, me, Encounter.RULE_FIRST).attacks[0]["damage"], 117, "30 of 100 is at the threshold")


func test_execute_multiplies_the_factor_of_the_effects_in_one_floor() -> void:
	var runner: AbilityRunner = _runner("strike", {"power_mult": 1.0, "execute": {"hp_pct": 50, "mult": 2.0}})
	var encounter := Encounter.new()
	encounter.enemies.append(_enemy_with(100, 10, 0.0))
	var factor: Callable = func(_def: AbilityDef, _i: int) -> float: return 1.25
	var use: AbilityRunner.Use = runner.take_due(encounter, 170, _stats(&"blade", 7, 7, 0.0), Encounter.RULE_FIRST, factor)
	assert_eq(use.attacks[0]["damage"], 17, "floor(7 x 1.25 x 2.0) = floor(17.5)")


# --- F-191 apply -----------------------------------------------------------------------------------------------------

func test_apply_example_crossed_cuts_leave_two_bleeds_that_add_up() -> void:
	var rng: MissRng = _fight([EffectKit.enemy(ConditionKit.MONSTER_B, 60, 100000)], "strike", {"power_mult": 0.5, "hits": 3,
			"apply": [{"condition": "bleed", "pct": 30, "ms": 4000}]})
	rng.ints = [20, 24]
	rng.misses = [false, true, false]
	_s.combat.advance(1000)
	var cond: EnemyConditions = ConditionKit.cond(_s, 0)
	assert_eq([cond.bleed_left, cond.bleed_ticks], [6, 4], "3 + 3 over 4 ticks, the miss leaves nothing")
	var ticks: Array[int] = []
	_s.events.combat_condition_damage.connect(func(_t: int, d: int, _c: StringName) -> void: ticks.append(d))
	_s.combat.advance(4000)
	assert_eq(ticks, [2, 2, 1, 1] as Array[int])


func test_apply_is_not_used_on_a_target_that_died() -> void:
	var rng: MissRng = _fight([EffectKit.enemy(ConditionKit.MONSTER_A, 5, 100000)], "strike", {"power_mult": 1.0, "hits": 2,
			"apply": [{"condition": "weaken", "pct": 25, "ms": 4000}]})
	rng.ints = [10, 10]
	var rows: Array = []
	_hits(_s, rows)
	_s.combat.advance(1000)
	assert_eq(rows.size(), 1, "the second hit is lost with no event")


# --- F-191 drain_pct -------------------------------------------------------------------------------------------------

func test_drain_example_54_damage_at_30_pct_cures_16() -> void:
	var runner: AbilityRunner = _runner("strike", {"power_mult": 1.8, "drain_pct": 30})
	var encounter := Encounter.new()
	encounter.enemies.append(_enemy_with(500, 500, 0.0))
	var use: AbilityRunner.Use = runner.take_due(encounter, 100, _stats(&"blade", 30, 30, 0.0), Encounter.RULE_FIRST)
	assert_eq(use.attacks[0]["damage"], 54)
	assert_eq(use.attacks[0]["drain"], 16, "floor(54 x 30%) = floor(16.2)")


func test_drain_in_the_engine_cures_after_the_hit_and_stops_at_the_maximum() -> void:
	var rng: MissRng = _fight([EffectKit.enemy(ConditionKit.MONSTER_B, 60, 100000)], "strike", {"power_mult": 1.0, "drain_pct": 50}, 0)
	_s.combat._set_hp(10)
	rng.ints = [20]
	_s.combat.advance(1000)
	assert_eq(_s.combat.get_state()["player_hp"], 20, "10 + floor(20 x 50%)")
	assert_eq(_s.combat.get_state()["player_hp"] <= _s.combat.player_stats().max_hp, true)


func test_a_missed_hit_has_no_drain_and_no_conditions() -> void:
	var rng: MissRng = _fight([EffectKit.enemy(ConditionKit.MONSTER_B, 60, 100000)], "strike", {"power_mult": 1.0, "drain_pct": 50,
			"apply": [{"condition": "expose", "pct": 20, "ms": 4000}]}, 0)
	_s.combat._set_hp(10)
	rng.misses = [true]
	_s.combat.advance(1000)
	assert_eq(_s.combat.get_state()["player_hp"], 10)
	assert_false(ConditionKit.cond(_s, 0).has(ConditionApply.EXPOSE))


# --- F-191 ward ------------------------------------------------------------------------------------------------------

func test_ward_example_high_guard_is_used_only_if_it_gives_more() -> void:
	var runner: AbilityRunner = _runner("ward", {"ward_pct": 15, "duration_ms": 6000})
	var encounter := Encounter.new()
	encounter.enemies.append(_enemy_with(100, 100, 0.0))
	var me: CombatantStats = _stats(&"blade", 5, 5, 0.0)
	me.max_hp = 400
	assert_eq(runner.next_ms(400, 400, 70), AbilityRunner.NO_TIMER, "60 <= 70: not usable, no zero timer")
	assert_null(runner.take_due(encounter, 400, me, Encounter.RULE_FIRST, Callable(), 70))
	assert_eq(runner.next_ms(400, 400, 20), 0)
	var use: AbilityRunner.Use = runner.take_due(encounter, 400, me, Encounter.RULE_FIRST, Callable(), 20)
	assert_eq([use.ward, use.ward_ms, use.kind], [60, 6000, AbilityDef.KIND_WARD])
	assert_true(use.attacks.is_empty() and use.targets.is_empty())
	assert_eq(use.heal, 0)


func test_ward_amount_takes_the_factor_of_the_effects() -> void:
	var runner: AbilityRunner = _runner("ward", {"ward_pct": 15, "duration_ms": 6000})
	var encounter := Encounter.new()
	encounter.enemies.append(_enemy_with(100, 100, 0.0))
	var me: CombatantStats = _stats(&"blade", 5, 5, 0.0)
	me.max_hp = 400
	var factor: Callable = func(_def: AbilityDef, i: int) -> float: return 1.25 if i < 0 else 1.0
	assert_eq(runner.take_due(encounter, 400, me, Encounter.RULE_FIRST, factor, 0).ward, 75, "floor(400 x 15% x 1.25)")


func test_ward_in_the_engine_grants_the_ward_and_waits_while_it_lasts() -> void:
	_fight([EffectKit.enemy(ConditionKit.MONSTER_B, 60, 100000)], "ward", {"ward_pct": 10, "duration_ms": 6000})
	var max_hp: int = _s.combat.player_stats().max_hp
	var expected: int = int(floor(max_hp * 10.0 / 100.0))
	_s.combat.advance(1000)
	assert_eq([_s.combat._ward.amount, _s.combat._ward.ms], [expected, 6000])
	_s.combat.advance(1000)
	assert_eq(_s.combat._ward.amount, expected, "the cooldown is not over: nothing new")


# --- cut_cooldowns, equivalence --------------------------------------------------------------------------------------

func test_a_new_strike_gives_the_same_result_in_one_step_or_ten() -> void:
	var results: Array = []
	for step: int in [1000, 100]:
		var rng: MissRng = _fight([EffectKit.enemy(ConditionKit.MONSTER_B, 60, 100000)], "strike", {"power_mult": 1.0, "hits": 2,
				"apply": [{"condition": "bleed", "pct": 50, "ms": 4000}], "drain_pct": 20}, 0)
		_s.combat._set_hp(10)
		rng.ints = [8, 9]
		for i: int in 1000 / step:
			_s.combat.advance(step)
		var cond: EnemyConditions = ConditionKit.cond(_s, 0)
		results.append([_s.combat.get_state()["player_hp"], cond.bleed_left, cond.bleed_ticks])
		after_each()
	assert_eq(results[0], results[1])
