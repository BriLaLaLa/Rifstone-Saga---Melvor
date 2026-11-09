extends GutTest
## F-110 (grade scale, examples of docs/02_FORMULAS.md) and the pure helpers of F-111 (`FractureScaler`).

var _data: GameData = null
var _none: Array[Dictionary] = []


func before_all() -> void:
	_data = TestFactory.real_data()


func _scaled(id: StringName, grade: int, effects: Array[Dictionary] = []) -> ScaledMonsterDef:
	return FractureScaler.scale_monster(_data.monster(id), grade, effects, _data) as ScaledMonsterDef


func _effect(risk_type: StringName, risk: float, reward_type: StringName = &"xp_pct", reward: float = 0.0) -> Dictionary:
	return {"mod": &"t", "risk_type": risk_type, "risk": risk, "reward_type": reward_type, "reward": reward}


func test_crack_golem_at_grade_3() -> void:
	var golem: ScaledMonsterDef = _scaled(&"crack_golem", 3)
	assert_eq(golem.attack_level, 46)
	assert_eq(golem.power_level, 46)
	assert_eq(golem.defence_level, 46)
	var row: FractureGradeDef = _data.fracture_grade(3)
	assert_eq(golem.hp, int(round(float(_data.monster(&"crack_golem").hp) * row.hp_mult)), "hp x the hp_mult of the row")
	assert_eq(golem.damage_mult, 1.16)
	assert_eq(golem.xp, int(round(float(_data.monster(&"crack_golem").xp) * row.reward_mult)))
	assert_eq(golem.id, &"crack_golem", "the id of the data")


func test_golem_damage_is_floor_of_1_16_on_min_and_max() -> void:
	var base: CombatantStats = CombatantStats.for_monster(_data.monster(&"crack_golem"), _data)
	var scaled: CombatantStats = CombatantStats.for_monster(_scaled(&"crack_golem", 3), _data)
	# the levels grow too (F-110): compare with the stats of the monster at the scaled levels, unscaled damage
	var plain := ScaledMonsterDef.copy_of(_data.monster(&"crack_golem"))
	plain.attack_level = 46
	plain.power_level = 46
	plain.defence_level = 46
	var at_46: CombatantStats = CombatantStats.for_monster(plain, _data)
	assert_eq(scaled.max_hit, maxi(1, floori(at_46.max_hit * 1.16 + 1e-9)))
	assert_eq(scaled.min_hit, maxi(1, floori(at_46.min_hit * 1.16 + 1e-9)))
	assert_gt(scaled.max_hit, base.max_hit)


func test_vein_witch_level_63_and_wraith_unchanged_at_grade_4() -> void:
	assert_eq(_scaled(&"vein_witch", 3).attack_level, 63)
	var wraith: ScaledMonsterDef = _scaled(&"shard_wraith", 4)
	assert_eq(wraith.attack_level, 65)
	assert_eq(wraith.hp, int(round(float(_data.monster(&"shard_wraith").hp) * _data.fracture_grade(4).hp_mult)))
	assert_eq(wraith.damage_mult, 1.0)


func test_levels_are_capped_at_99() -> void:
	var wraith: ScaledMonsterDef = _scaled(&"riftborn_colossus", 10)
	assert_lte(wraith.attack_level, 99)
	assert_eq(wraith.attack_level, mini(99, _data.monster(&"riftborn_colossus").attack_level + 7))


func test_the_data_monster_does_not_change() -> void:
	var before: int = _data.monster(&"crack_golem").hp
	_scaled(&"crack_golem", 10)
	assert_eq(_data.monster(&"crack_golem").hp, before)
	assert_eq(_data.monster(&"crack_golem").attack_level, 38)


func test_a_boss_takes_only_the_risks() -> void:
	var boss: BossDef = BossDef.new()
	boss.id = &"b"
	boss.hp = 1000
	boss.xp = 500
	boss.gold_min = 10
	boss.gold_max = 20
	boss.attack_level = 50
	boss.power_level = 50
	boss.defence_level = 50
	boss.style = &"blade"
	boss.attack_interval_ms = 3000
	var plain: ScaledMonsterDef = FractureScaler.scale_monster(boss, 3, _none, _data) as ScaledMonsterDef
	assert_true(plain.is_boss)
	assert_eq(plain.hp, 1000)
	assert_eq(plain.xp, 500, "reward_mult does not apply to the boss (F-115)")
	assert_eq(plain.attack_level, 50, "no level bonus")
	var risky: Array[Dictionary] = [_effect(&"monster_hp_pct", 20.0)]
	assert_eq((FractureScaler.scale_monster(boss, 3, risky, _data) as ScaledMonsterDef).hp, 1200)


func test_total_sums_risk_and_reward_of_a_type() -> void:
	var effects: Array[Dictionary] = [_effect(&"pack_bonus", 2.0, &"xp_pct", 20.0), _effect(&"pulse", 3.0, &"xp_pct", 10.0)]
	assert_eq(FractureScaler.total(effects, &"pack_bonus"), 2.0)
	assert_eq(FractureScaler.total(effects, &"xp_pct"), 30.0)
	assert_eq(FractureScaler.total(effects, &"nothing"), 0.0)


func test_pack_size_is_capped_at_the_maximum() -> void:
	var effects: Array[Dictionary] = [_effect(&"pack_bonus", 2.0)]
	assert_eq(FractureScaler.pack_size(2, effects, _data), 4)
	assert_eq(FractureScaler.pack_size(5, effects, _data), int(_data.balance_value("combat.max_pack_size")))
	assert_eq(FractureScaler.pack_size(3, _none, _data), 3)
