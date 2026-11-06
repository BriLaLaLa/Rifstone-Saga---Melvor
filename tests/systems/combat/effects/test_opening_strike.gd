extends GutTest
## F-81 `opening_strike`: the base-attack timer goes to 0 at the start of an encounter (2400 -> 0).

var _session: GameSession


func before_each() -> void:
	_session = autofree(TestFactory.session(21))


func after_each() -> void:
	EffectKit.cleanup()


func test_timer_goes_to_zero() -> void:
	var ctx := EffectContext.new()
	ctx.player_timer_ms = 2400
	OpeningStrike.new(&"t", {}).on_encounter_start(ctx)
	assert_eq(ctx.player_timer_ms, 0)
	assert_eq(ctx.triggered, [&"t"] as Array[StringName])


func test_engine_first_attack_is_immediate() -> void:
	EffectKit.equip_trait(_session, &"t_open", [{"type": "opening_strike", "params": {}}])
	var attackers: Array[int] = []
	_session.events.combat_hit.connect(func(a: int, _t: int, _h: bool, _d: int, _b: bool) -> void: attackers.append(a))
	assert_true(_session.combat.start(&"test_area").ok)
	assert_eq(_session.combat.get_state()["player_timer_ms"], 0)
	_session.combat.advance(0)
	assert_eq(attackers, [CombatEngine.PLAYER] as Array[int], "attacks at t=0, before any enemy")
	assert_eq(_session.combat.get_state()["player_timer_ms"], 2400)
