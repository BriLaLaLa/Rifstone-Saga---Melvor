extends GutTest
## F-81 `every_nth_attack_all` (n 3 -> attacks 3, 6, 9), its counter in the save, and the hook in the engine.

var _session: GameSession
var _hits: Array[Array] = []


func before_each() -> void:
	_session = autofree(TestFactory.session(77))
	_hits = []
	_session.events.combat_hit.connect(func(a: int, t: int, h: bool, d: int, b: bool) -> void: _hits.append([a, t, h, d, b]))


func after_each() -> void:
	EffectKit.cleanup()


func _effect(n: int) -> EveryNthAttackAll:
	return EveryNthAttackAll.new(&"t", {"n": n})


func test_every_third_attack_hits_all() -> void:
	var effect: EveryNthAttackAll = _effect(3)
	var fired: Array[int] = []
	for attack: int in range(1, 10):
		var ctx := EffectContext.new()
		effect.on_before_attack(ctx)
		if ctx.attack_all:
			fired.append(attack)
			assert_eq(ctx.triggered, [&"t"] as Array[StringName])
	assert_eq(fired, [3, 6, 9] as Array[int])


func test_counter_is_saved_and_restored() -> void:
	var effect: EveryNthAttackAll = _effect(3)
	assert_eq(effect.to_save(), {}, "nothing to save at zero")
	effect.on_before_attack(EffectContext.new())
	effect.on_before_attack(EffectContext.new())
	assert_eq(effect.to_save(), {"count": 2})
	var copy: EveryNthAttackAll = _effect(3)
	copy.from_save(effect.to_save())
	var ctx := EffectContext.new()
	copy.on_before_attack(ctx)
	assert_true(ctx.attack_all, "the restored counter goes on from 2")
	copy.from_save({"count": 99})
	assert_eq(copy.to_save(), {"count": 2}, "limited to n - 1")


func _two_enemies(timer_ms: int) -> Dictionary:
	return EffectKit.fight([EffectKit.enemy("test_monster_b", 60, timer_ms), EffectKit.enemy("test_monster_b", 60, timer_ms)], 100)


func test_engine_third_attack_hits_every_enemy() -> void:
	EffectKit.equip_trait(_session, &"t_cleave", [{"type": "every_nth_attack_all", "params": {"n": 3}}])
	EffectKit.sturdy(_session)
	_session.combat.from_save(EffectKit.fight([EffectKit.enemy("test_monster_b", 60, 2400),
		EffectKit.enemy("test_monster_b", 60, 2400)], 100))
	watch_signals(_session.events)
	var player_hits_per_attack: Array[int] = []
	for i: int in 3:
		_hits.clear()
		_session.combat.advance(2400 if i > 0 else 100)
		var mine: int = 0
		for h: Array in _hits:
			if int(h[0]) == CombatEngine.PLAYER:
				mine += 1
		player_hits_per_attack.append(mine)
	assert_eq(player_hits_per_attack, [1, 1, 2] as Array[int], "attacks 1 and 2 one target, attack 3 both")
	assert_signal_emitted_with_parameters(_session.events, "trait_triggered", [&"t_cleave"])
	assert_eq(_session.combat.to_save()["effects"], {}, "counter back at zero after the third attack")
	_session.combat.advance(2400)
	assert_eq(_session.combat.to_save()["effects"], {"t_cleave": {"count": 1}}, "saved in combat.effects")
