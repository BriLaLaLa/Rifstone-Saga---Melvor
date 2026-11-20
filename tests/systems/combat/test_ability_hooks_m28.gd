extends GutTest
## The hooks of an ability use (docs/05_INTERFACES_M28.md §5.10b-c, F-190, F-191, F-193): the `M` of an ability hit and the factor of
## the amount of a heal come from the effects, `on_ability` follows the use, `ability_used` has no repeated targets. Test abilities
## and fake effects only.

var _s: GameSession
var _added: Array[AbilityDef] = []


func after_each() -> void:
	for def: AbilityDef in _added:
		_s.character.class_def().abilities.erase(def)
	_added.clear()


# A session in a fight (`enemies`), with a test ability in slot 0 and a fake effect installed after it (a loadout change drops it).
func _fight(enemies: Array, kind: String, params: Dictionary, max_hp_extra: int = 100000) -> ConditionKit.Fake:
	_s = autofree(ConditionKit.base(max_hp_extra))
	var def: AbilityDef = AbilityDef.from_dict({"id": "t_ability", "name": "Prova", "description": "Prova.", "unlock_level": 1,
		"setups": [], "kind": kind, "cooldown_ms": 1000, "params": params})
	_s.character.class_def().abilities.append(def)
	_added.append(def)
	assert_true(_s.loadout.set_ability(0, &"t_ability").ok)
	ConditionKit.begin(_s, enemies, 100000, 60 + max_hp_extra)
	return ConditionKit.install(_s, ConditionKit.Fake.new())


func test_a_strike_takes_its_factor_from_the_effects() -> void:
	var fake: ConditionKit.Fake = _fight([EffectKit.enemy(ConditionKit.MONSTER_A, 20, 100000)], "strike", {"power_mult": 1.0})
	fake.hit = 2.0
	(_s.rng as ConditionKit.ScriptRng).ints = [4]
	var damages: Array[int] = []
	_s.events.combat_hit.connect(func(_a: int, _t: int, _h: bool, d: int, _b: bool) -> void: damages.append(d))
	_s.combat.advance(1000)
	assert_eq(damages, [8], "floor(4 x 1.0) x 2.0")
	assert_eq(fake.hooks("hit_mult")[0]["kind"], EffectContext.HIT_ABILITY)
	assert_eq(fake.hooks("hit_mult")[0]["ability_kind"], AbilityDef.KIND_STRIKE)
	assert_eq(fake.hooks("on_hit")[0]["kind"], EffectContext.HIT_ABILITY)
	assert_false(fake.hooks("on_hit")[0]["base"])


func test_on_ability_comes_after_the_hits_with_the_kind() -> void:
	var fake: ConditionKit.Fake = _fight([EffectKit.enemy(ConditionKit.MONSTER_A, 20, 100000)], "strike", {"power_mult": 1.0})
	(_s.rng as ConditionKit.ScriptRng).ints = [4]
	_s.combat.advance(1000)
	var order: Array = fake.seen.map(func(e: Dictionary) -> String: return e["hook"])
	assert_true(order.find("on_hit") < order.find("on_ability"), "the hit hooks, then on_ability")
	assert_eq(fake.hooks("on_ability")[0]["ability_kind"], AbilityDef.KIND_STRIKE)


func test_a_heal_takes_the_factor_of_the_amount_from_the_effects() -> void:
	var fake: ConditionKit.Fake = _fight([EffectKit.enemy(ConditionKit.MONSTER_B, 60, 100000)], "heal", {"heal_pct": 50}, 0)
	fake.amount = 1.5
	_s.combat._set_hp(10)
	_s.combat.advance(1000)
	assert_eq(_s.combat.get_state()["player_hp"], 55, "10 + floor(60 x 50% x 1.5) = 10 + 45")
	assert_eq(fake.hooks("amount_mult")[0]["ability_kind"], AbilityDef.KIND_HEAL)
	assert_eq(fake.hooks("on_ability")[0]["ability_kind"], AbilityDef.KIND_HEAL)


func test_a_heal_without_effects_is_the_plain_one() -> void:
	_fight([EffectKit.enemy(ConditionKit.MONSTER_B, 60, 100000)], "heal", {"heal_pct": 50}, 0)
	_s.combat._set_hp(10)
	_s.combat.advance(1000)
	assert_eq(_s.combat.get_state()["player_hp"], 40)


func test_a_cleave_reports_each_target_once() -> void:
	_fight([EffectKit.enemy(ConditionKit.MONSTER_A, 20, 100000), EffectKit.enemy(ConditionKit.MONSTER_B, 60, 100000)], "cleave",
			{"power_mult": 1.0, "targets": 0})
	var uses: Array = []
	_s.events.ability_used.connect(func(id: StringName, targets: Array[int]) -> void: uses.append([id, targets]))
	_s.combat.advance(1000)
	assert_eq(uses, [[&"t_ability", [0, 1] as Array[int]]])


func test_a_kill_cuts_the_cooldown_of_the_running_abilities() -> void:
	var fake: ConditionKit.Fake = _fight([EffectKit.enemy(ConditionKit.MONSTER_A, 20, 100000), EffectKit.enemy(ConditionKit.MONSTER_B, 60, 100000)],
			"strike", {"power_mult": 1.0})
	fake.cut_ms = 600
	(_s.rng as ConditionKit.ScriptRng).ints = [25]
	_s.combat.advance(1000)  # the strike kills enemy 0 (25 damage) and starts its cooldown again: 1000 - 600 left
	assert_eq(_s.combat._abilities.timers_save()["t_ability"], 400)
