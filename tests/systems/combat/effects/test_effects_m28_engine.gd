extends GutTest
## The twelve types of F-192 as `EffectSet` builds them from data (`create_typed`) and as the engine uses them: a few real fights.

const TYPES: Dictionary = {
	"stack_damage": {"gain": "kill", "pct": 5, "max": 5, "lose": "damaged"},
	"stack_haste": {"gain": "hit", "pct": 3, "max": 8, "lose": "encounter"},
	"focus_combo": {"pct": 6, "max": 5},
	"riposte": {"on": "block", "mult": 0.8},
	"damage_trade": {"dealt_pct": 25, "taken_pct": 20},
	"apply_on_hit": {"every": 3, "condition": "bleed", "pct": 40, "ms": 4000},
	"status_damage_mult": {"condition": "bleed", "pct": 20},
	"kill_cooldown_cut": {"ms": 1500},
	"after_ability_mult": {"mult": 1.5},
	"ward_on": {"on": "kill", "pct": 8, "ms": 6000},
	"ability_mult": {"kinds": ["strike"], "pct": 25},
	"lone_target_mult": {"pct": 25},
}
const STATE_TYPES: Array[String] = ["stack_damage", "stack_haste", "focus_combo", "apply_on_hit", "after_ability_mult"]

var _s: GameSession


func after_each() -> void:
	EffectKit.cleanup()


func _fight(effects: Array, enemies: Array, player_timer_ms: int = 100000, max_hp_extra: int = 100000) -> void:
	_s = autofree(TestFactory.session(1))
	_s.modifiers.set_source(&"test:sturdy", [Modifier.make(&"max_hp_flat", float(max_hp_extra))] as Array[Modifier])
	_s.rng = ConditionKit.ScriptRng.new()
	EffectKit.equip_trait(_s, &"t_fx", effects)
	ConditionKit.begin(_s, enemies, player_timer_ms, 60 + max_hp_extra)


func test_create_typed_builds_every_type_with_its_state_flag() -> void:
	for type: String in TYPES:
		var fx: TraitEffect = EffectSet.create_typed(&"t", StringName(type), TYPES[type])
		assert_not_null(fx, type)
		assert_eq(fx.has_state(), STATE_TYPES.has(type), type)
		assert_eq(fx.trait_id, &"t")


func test_riposte_on_block_strikes_the_source_back_and_not_on_a_hit() -> void:
	_fight([{"type": "riposte", "params": {"on": "block", "mult": 0.8}}], [EffectKit.enemy(ConditionKit.MONSTER_B, 60, 100000)])
	(_s.rng as ConditionKit.ScriptRng).ints = [30]
	_s.combat._incoming(0, {"hit": true, "blocked": false, "damage": 0})
	assert_eq(_s.combat._encounter.enemies[0].hp, 60, "no block, no counter")
	_s.combat._incoming(0, {"hit": true, "blocked": true, "damage": 0})
	assert_lt(_s.combat._encounter.enemies[0].hp, 60, "the counter-attack took hp")


func test_riposte_on_evade() -> void:
	_fight([{"type": "riposte", "params": {"on": "evade", "mult": 1.0}}], [EffectKit.enemy(ConditionKit.MONSTER_B, 60, 100000)])
	(_s.rng as ConditionKit.ScriptRng).ints = [30]
	_s.combat._incoming(0, {"hit": false, "blocked": false, "damage": 0})
	assert_lt(_s.combat._encounter.enemies[0].hp, 60)


func test_ward_on_kill_grants_the_ward() -> void:
	_fight([{"type": "ward_on", "params": {"on": "kill", "pct": 8, "ms": 6000}}], [EffectKit.enemy(ConditionKit.MONSTER_A, 3, 100000)], 0)
	(_s.rng as ConditionKit.ScriptRng).ints = [9]
	_s.combat.advance(0)
	var max_hp: int = _s.combat.player_stats().max_hp
	assert_eq(_s.combat._ward.to_save(), {"amount": int(floor(max_hp * 8.0 / 100.0)), "ms": 6000})


func test_damage_trade_raises_the_damage_taken() -> void:
	_fight([{"type": "damage_trade", "params": {"dealt_pct": 25, "taken_pct": 20}}], [EffectKit.enemy(ConditionKit.MONSTER_B, 60, 100000)])
	assert_eq(_s.combat._incoming_damage(0, 25), 30)


func test_stack_haste_shortens_the_next_timer_and_the_stacks_are_saved() -> void:
	_fight([{"type": "stack_haste", "params": {"gain": "kill", "pct": 3, "max": 8, "lose": "encounter"}}],
			[EffectKit.enemy(ConditionKit.MONSTER_B, 60, 100000)], 0)
	var interval: int = _s.combat.player_stats().attack_interval_ms
	_s.combat._fx.effects()[0].from_save({"stacks": 4})
	(_s.rng as ConditionKit.ScriptRng).ints = [1]
	_s.combat.advance(0)
	var expected: int = maxi(int(_s.data.balance_value("combat.min_attack_interval_ms")), int(floor(interval * 0.88 + CombatMath.EPSILON)))
	assert_eq(_s.combat._player_timer_ms, expected)
	assert_eq(_s.combat._fx.to_save(), {"t_fx": {"stacks": 4}}, "the state goes to combat.effects under the trait id")


func test_stack_damage_after_a_kill_is_in_the_save_and_comes_back() -> void:
	_fight([{"type": "stack_damage", "params": {"gain": "kill", "pct": 5, "max": 5, "lose": "damaged"}}],
			[EffectKit.enemy(ConditionKit.MONSTER_A, 3, 100000), EffectKit.enemy(ConditionKit.MONSTER_B, 60, 100000)], 0)
	(_s.rng as ConditionKit.ScriptRng).ints = [9]
	_s.combat.advance(0)
	var saved: Dictionary = _s.combat.to_save()
	assert_eq(saved["effects"], {"t_fx": {"stacks": 1}})
	_s.combat.from_save(saved)
	assert_eq(_s.combat.to_save()["effects"], {"t_fx": {"stacks": 1}})
