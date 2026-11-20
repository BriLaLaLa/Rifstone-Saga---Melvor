extends GutTest
## F-192 `kill_cooldown_cut` (`ms`): at every kill each active cooldown is cut by the sum of the `ms` of the effects, never under 0.
## Example: 1500 -> 4000 and 800 become 2500 and 0 (the durations of the buffs do not change).


func after_each() -> void:
	EffectKit.cleanup()


func test_the_effect_adds_its_ms_and_the_sum_over_effects() -> void:
	var ctx := EffectContext.new()
	KillCooldownCut.new(&"a", {"ms": 1500}).on_kill(ctx)
	assert_eq(ctx.cooldown_cut_ms, 1500)
	KillCooldownCut.new(&"b", {"ms": 700}).on_kill(ctx)
	assert_eq(ctx.cooldown_cut_ms, 2200)
	assert_eq(ctx.triggered, [&"a", &"b"] as Array[StringName])


func test_engine_example_4000_becomes_2500_and_800_becomes_0() -> void:
	for start: Array in [[4000, 2500], [800, 0]]:
		var s: GameSession = autofree(TestFactory.session(1))
		s.rng = ConditionKit.ScriptRng.new()
		EffectKit.equip_trait(s, &"t_cut", [{"type": "kill_cooldown_cut", "params": {"ms": 1500}}])
		assert_true(s.loadout.set_ability(0, &"test_strike").ok)
		var save: Dictionary = EffectKit.fight([EffectKit.enemy(ConditionKit.MONSTER_A, 3, 100000)], 0)
		save["abilities"] = {"test_strike": start[0]}
		s.combat.from_save(save)
		(s.rng as ConditionKit.ScriptRng).ints = [9]
		s.combat.advance(0)  # the base attack kills the 3 hp enemy
		assert_eq(s.combat._abilities.timers_save().get("test_strike"), start[1], "from %d" % start[0])
