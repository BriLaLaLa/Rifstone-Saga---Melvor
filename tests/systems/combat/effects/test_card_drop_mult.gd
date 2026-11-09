extends GutTest
## F-120 `card_drop_mult` (hook `on_kill`): the probability of the Fracture Cards dropped by monsters and Monoliths (F-113) x
## `mult`, at most 100%. The sinks apply it to the Card bases; the fight sets it at every kill.

var _s: GameSession = null


func test_the_effect_multiplies_the_context() -> void:
	var ctx := EffectContext.new()
	CardDropMult.new(&"equipment:neck", {"mult": 2.0}).on_kill(ctx)
	assert_eq(ctx.card_mult, 2.0)
	assert_eq(ctx.triggered, [&"equipment:neck"] as Array[StringName])
	CardDropMult.new(&"t", {"mult": 1.5}).on_kill(ctx)
	assert_eq(ctx.card_mult, 3.0)


func test_the_sink_scales_only_the_cards_and_caps_at_100() -> void:
	var data: GameData = LegendaryKit.session(1).data
	var card_base: ItemDef = data.map_base(1)
	var sink := LootSink.new()
	assert_eq(sink.drop_chance(card_base, 30.0), 30.0)
	sink.card_mult = 2.0
	assert_eq(sink.drop_chance(card_base, 30.0), 60.0)
	assert_eq(sink.drop_chance(card_base, 70.0), 100.0)
	assert_eq(sink.drop_chance(data.item(&"test_log"), 30.0), 30.0, "an ordinary item keeps its chance")


func test_engine_a_kill_sets_the_multiplier_of_the_loot_bag() -> void:
	for seed_value: int in range(5, 40):
		_s = autofree(LegendaryKit.session(seed_value))
		LegendaryKit.hero(_s)
		LegendaryKit.wear(_s, &"fx_leg_cards")
		_s.combat.from_save(EffectKit.fight([EffectKit.enemy("test_monster_a", 20, 999999)], 100))
		_s.combat.advance(100)
		if _s.combat.kills(&"test_monster_a") == 1:
			assert_eq(_s.combat.loot.card_mult, 2.0)
			return
	fail_test("no seed killed at the first attack")


func test_engine_without_the_legendary_the_multiplier_is_one() -> void:
	for seed_value: int in range(5, 40):
		_s = autofree(LegendaryKit.session(seed_value))
		LegendaryKit.hero(_s)
		_s.combat.from_save(EffectKit.fight([EffectKit.enemy("test_monster_a", 20, 999999)], 100))
		_s.combat.advance(100)
		if _s.combat.kills(&"test_monster_a") == 1:
			assert_eq(_s.combat.loot.card_mult, 1.0)
			return
	fail_test("no seed killed at the first attack")
