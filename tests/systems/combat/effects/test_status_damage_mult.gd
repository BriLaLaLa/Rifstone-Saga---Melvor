extends GutTest
## F-192 `status_damage_mult` (`condition`, `pct`): factor `1 + pct/100` in `M` (B, A, C) if the target has the condition (`stagger` = the
## window "staggered"). Example: against a bleeding enemy, 20 -> x1.2.


func _ctx(cond: EnemyConditions, kind: StringName = EffectContext.HIT_BASE) -> EffectContext:
	var ctx := EffectContext.new()
	ctx.target_conditions = cond
	ctx.hit_kind = kind
	return ctx


func test_example_against_a_bleeding_enemy() -> void:
	var cond := EnemyConditions.new()
	cond.bleed_left = 8
	cond.bleed_ticks = 2
	var fx := StatusDamageMult.new(&"t", {"condition": "bleed", "pct": 20.0})
	assert_eq(fx.hit_mult(_ctx(cond)), 1.2)
	assert_eq(fx.hit_mult(_ctx(EnemyConditions.new())), 1.0, "not bleeding")


func test_each_condition_reads_its_own_state() -> void:
	var cond := EnemyConditions.new()
	cond.weaken_ms = 100
	cond.expose_ms = 100
	cond.stagger_ms = 100
	for name: String in ["weaken", "expose", "stagger"]:
		var fx := StatusDamageMult.new(&"t", {"condition": name, "pct": 10.0})
		assert_eq(fx.hit_mult(_ctx(cond)), 1.1, name)
		assert_eq(fx.hit_mult(_ctx(EnemyConditions.new())), 1.0, name)
	assert_eq(StatusDamageMult.new(&"t", {"condition": "bleed", "pct": 10.0}).hit_mult(_ctx(cond)), 1.0)


func test_the_immunity_after_a_stagger_is_not_the_window() -> void:
	var cond := EnemyConditions.new()
	cond.immune_ms = 3000
	assert_eq(StatusDamageMult.new(&"t", {"condition": "stagger", "pct": 10.0}).hit_mult(_ctx(cond)), 1.0)


func test_b_a_and_c_but_not_the_extra_hit_and_no_target_is_neutral() -> void:
	var cond := EnemyConditions.new()
	cond.bleed_left = 4
	cond.bleed_ticks = 1
	var fx := StatusDamageMult.new(&"t", {"condition": "bleed", "pct": 20.0})
	for kind: StringName in [EffectContext.HIT_BASE, EffectContext.HIT_ABILITY, EffectContext.HIT_COUNTER]:
		assert_eq(fx.hit_mult(_ctx(cond, kind)), 1.2, String(kind))
	assert_eq(fx.hit_mult(_ctx(cond, EffectContext.HIT_EXTRA)), 1.0)
	assert_eq(fx.hit_mult(EffectContext.new()), 1.0)
