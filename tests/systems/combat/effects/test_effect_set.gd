extends GutTest
## EffectSet and the engine hooks together: unknown types, counters kept across rebuilds and in the save, several
## traits at once, and the equivalence of advance(1000) with ten advance(100) with the effects active.

var _session: GameSession


func before_each() -> void:
	_session = autofree(TestFactory.session(31))
	TestFactory.set_character_level(_session, 25)


func after_each() -> void:
	EffectKit.cleanup()


func _setup_traits(session: GameSession) -> void:
	EffectKit.equip_trait(session, &"t_cleave", [{"type": "every_nth_attack_all", "params": {"n": 2}}], 0)
	EffectKit.equip_trait(session, &"t_cut", [{"type": "on_kill_timer_cut", "params": {"pct": 50}}], 1)
	EffectKit.equip_trait(session, &"t_reflect", [{"type": "reflect_pct", "params": {"pct": 30}}], 2)
	EffectKit.sturdy(session)


func test_create_unknown_type_is_null() -> void:
	var def := TraitEffectDef.new()
	def.type = &"made_up"
	assert_null(EffectSet.create(&"t", def))
	assert_push_error(1)


func test_every_registered_type_builds() -> void:
	var types: Array[StringName] = [&"every_nth_attack_all", &"on_kill_timer_cut", &"low_hp_damage_mult", &"stat_trade",
		&"target_rule", &"reflect_pct", &"leech_pct", &"opening_strike"]
	for type: StringName in types:
		var def := TraitEffectDef.new()
		def.type = type
		assert_not_null(EffectSet.create(&"t", def), String(type))


func test_counter_survives_a_rebuild_and_the_save() -> void:
	EffectKit.equip_trait(_session, &"t_cleave", [{"type": "every_nth_attack_all", "params": {"n": 5}}])
	EffectKit.sturdy(_session)
	_session.combat.from_save(EffectKit.fight([EffectKit.enemy("test_monster_b", 60, 2400)], 100))
	_session.combat.advance(100)
	_session.combat.advance(2400)
	assert_eq(_session.combat.to_save()["effects"], {"t_cleave": {"count": 2}})
	_session.events.traits_changed.emit()
	assert_eq(_session.combat.to_save()["effects"], {"t_cleave": {"count": 2}}, "kept when the loadout is rebuilt")
	var copy: GameSession = autofree(TestFactory.session(31))
	TestFactory.set_character_level(copy, 25)
	EffectKit.equip_trait(copy, &"t_cleave", [{"type": "every_nth_attack_all", "params": {"n": 5}}])
	copy.combat.from_save(JSON.parse_string(JSON.stringify(_session.combat.to_save())) as Dictionary)
	assert_eq(copy.combat.to_save()["effects"], {"t_cleave": {"count": 2}})


func test_counter_restarts_with_a_new_combat() -> void:
	EffectKit.equip_trait(_session, &"t_cleave", [{"type": "every_nth_attack_all", "params": {"n": 5}}])
	EffectKit.sturdy(_session)
	_session.combat.from_save(EffectKit.fight([EffectKit.enemy("test_monster_b", 60, 2400)], 100))
	_session.combat.advance(100)
	_session.combat.stop()
	assert_eq(_session.combat.to_save()["effects"], {}, "idle: no effect state")
	assert_true(_session.combat.start(&"test_area").ok)
	assert_eq(_session.combat.to_save()["effects"], {})


func test_malformed_effects_in_the_save_are_dropped() -> void:
	EffectKit.equip_trait(_session, &"t_cleave", [{"type": "every_nth_attack_all", "params": {"n": 5}}])
	var saved: Dictionary = EffectKit.fight([EffectKit.enemy("test_monster_b", 60, 2400)], 100)
	saved["effects"] = {"t_cleave": "oops", "ghost": {"count": 3}}
	_session.combat.from_save(saved)
	assert_eq(_session.combat.to_save()["effects"], {}, "no state for a bad entry or an inactive trait")
	saved["effects"] = 7
	_session.combat.from_save(saved)
	assert_eq(_session.combat.state(), CombatEngine.STATE_ENCOUNTER)


func _run(session: GameSession, steps: int, step_ms: int) -> Dictionary:
	_setup_traits(session)
	session.combat.from_save(EffectKit.fight([EffectKit.enemy("test_monster_b", 60, 2400),
		EffectKit.enemy("test_monster_a", 20, 2800)], 2400))
	for i: int in steps:
		session.combat.advance(step_ms)
	return session.combat.to_save()


func test_one_step_equals_ten_steps_with_effects() -> void:
	var coarse: Dictionary = _run(_session, 60, 1000)
	var other: GameSession = autofree(TestFactory.session(31))
	TestFactory.set_character_level(other, 25)
	var fine: Dictionary = _run(other, 600, 100)
	assert_eq(fine, coarse)
	assert_eq(other.rng.randf() == _session.rng.randf(), true, "same random sequence consumed")
