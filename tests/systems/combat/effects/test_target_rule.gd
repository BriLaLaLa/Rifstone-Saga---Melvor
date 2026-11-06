extends GutTest
## F-81 `target_rule` (F-76 rules) and the choose_target hook; two traits with a rule: the lowest slot wins.

var _session: GameSession


func before_each() -> void:
	_session = autofree(TestFactory.session(11))
	TestFactory.set_character_level(_session, 10)


func after_each() -> void:
	EffectKit.cleanup()


func _rule(rule: String) -> Array:
	return [{"type": "target_rule", "params": {"rule": rule}}]


func _fight() -> void:
	_session.combat.from_save(EffectKit.fight([EffectKit.enemy("test_monster_b", 60, 2400),
		EffectKit.enemy("test_monster_a", 20, 2800)]))


func test_effect_reports_its_rule() -> void:
	assert_eq(TargetRuleEffect.new(&"t", {"rule": "lowest_hp"}).target_rule(), &"lowest_hp")
	assert_eq(TraitEffect.new().target_rule(), &"", "other effects ask for nothing")


func test_default_is_first() -> void:
	_fight()
	assert_eq(_session.combat.get_state()["target"], 0)


func test_lowest_slot_wins_with_two_rules() -> void:
	EffectKit.equip_trait(_session, &"t_low", _rule("lowest_hp"))
	EffectKit.equip_trait(_session, &"t_high", _rule("highest_hp"), 1)
	_fight()
	assert_eq(_session.combat.get_state()["target"], 1, "hp [60, 20]: slot 0 asks for the weaker one")
	_session.combat.stop()
	_session.loadout.set_trait(0, &"")
	_fight()
	assert_eq(_session.combat.get_state()["target"], 0, "only highest_hp left: the 60-hp enemy")


func test_the_attack_goes_to_the_chosen_target() -> void:
	EffectKit.equip_trait(_session, &"t_low", _rule("lowest_hp"))
	EffectKit.sturdy(_session)
	_fight()
	var targets: Array[int] = []
	_session.events.combat_hit.connect(func(a: int, t: int, _h: bool, _d: int, _b: bool) -> void:
		if a == CombatEngine.PLAYER:
			targets.append(t))
	_session.combat.advance(2400)
	assert_eq(targets, [1] as Array[int])
