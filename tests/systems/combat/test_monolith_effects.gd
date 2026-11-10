extends GutTest
## F-120 and the Rift Monolith (F-87): `monolith_loot_mult` doubles the stacks of the loot, the legendaries of the Monolith go
## straight to the Armory (never through the loot bag, never filtered), the equivalence of the steps with the effects.
## Content: tests/helpers/m14_data.gd (`test_stone`: 60 hp, 2-4 shards, 2 test_log at 100%; legendaries fx_leg_rod and
## fx_leg_pick at 100%; `test_loot_stone` gives fx_leg_monolith and fx_leg_cards).

const AREA: StringName = &"test_stone_area"
const STONE: StringName = &"test_stone"

var _s: GameSession = null


func _stone_save(stone_hp: int = 60, player_hp: int = 100060, player_timer_ms: int = 0) -> Dictionary:
	return {"state": "riftstone", "area": String(AREA), "player_hp": player_hp, "player_timer_ms": player_timer_ms,
		"hand": 0, "between_ms": 0, "loot": [], "kills": {}, "deaths": 0, "food_eaten": 0,
		"enemies": [{"monster": String(STONE), "hp": stone_hp, "timer_ms": 3000}],
		"stone": {"since": 0, "pending": false}}


func _kill_the_stone(s: GameSession) -> void:
	s.combat.from_save(_stone_save())
	var guard: int = 0
	while s.combat.state() == CombatEngine.STATE_RIFTSTONE and guard < 200:
		s.combat.advance(100)
		guard += 1
	assert_eq(s.combat.state(), CombatEngine.STATE_BETWEEN, "the stone is dead")


func _loot(s: GameSession) -> Dictionary[StringName, int]:
	var bag: Dictionary[StringName, int] = {}
	for entry: Dictionary in s.combat.loot.items():
		bag[entry["item"]] = entry["qty"]
	return bag


func _hero_session(seed_value: int) -> GameSession:
	var s: GameSession = autofree(LegendaryKit.session(seed_value))
	LegendaryKit.hero(s)
	return s


func test_the_ring_doubles_the_stacks_of_the_loot() -> void:
	var plain: GameSession = _hero_session(5)
	_kill_the_stone(plain)
	var ring: GameSession = _hero_session(5)
	LegendaryKit.wear(ring, &"fx_leg_monolith")
	_kill_the_stone(ring)
	assert_eq(_loot(plain)[&"test_log"], 2)
	assert_eq(_loot(ring)[&"test_log"], 4, "x2")
	assert_eq(_loot(ring)[&"rift_shard"], 2 * _loot(plain)[&"rift_shard"], "the shards too")


func test_the_monolith_gives_its_legendaries_directly_to_the_armory() -> void:
	_s = _hero_session(5)
	_kill_the_stone(_s)
	_s.combat.loot.collect_all()
	var bases: Array[StringName] = []
	for inst: ItemInstance in _s.armory.instances():
		bases.append(inst.base_id)
		assert_eq(inst.rarity, &"legendary")
		assert_true(inst.affixes.is_empty())
	assert_eq(bases, [&"fx_leg_rod", &"fx_leg_pick"] as Array[StringName], "both, in the order of the data")
	assert_false(_loot(_s).has(&"fx_leg_rod"), "never through the loot bag")


func test_the_legendaries_of_the_stone_are_not_multiplied_by_the_ring() -> void:
	_s = _hero_session(5)
	LegendaryKit.wear(_s, &"fx_leg_monolith")
	_kill_the_stone(_s)
	_s.combat.loot.collect_all()
	var count: int = 0
	for inst: ItemInstance in _s.armory.instances():
		if inst.base_id == &"fx_leg_rod":
			count += 1
	assert_eq(count, 1)


func test_with_a_full_deposit_the_legendary_of_the_monolith_is_lost_with_a_notification() -> void:
	_s = _hero_session(5)
	var fill: Array[int] = [0]
	_s.deposit.register_occupant(&"test:fill", func() -> int: return fill[0])
	fill[0] = _s.deposit.free_slots()
	watch_signals(_s.events)
	_kill_the_stone(_s)
	_s.combat.loot.collect_all()
	assert_signal_emitted_with_parameters(_s.events, "armory_rejected", [&"fx_leg_rod", 1], 0)
	assert_signal_emitted_with_parameters(_s.events, "armory_rejected", [&"fx_leg_pick", 1], 1)
	assert_signal_not_emitted(_s.events, "item_salvaged")
	assert_eq(_s.armory.instances().size(), 0)


func test_one_big_step_equals_many_small_steps_with_the_ring() -> void:
	var big: GameSession = _equivalence_session()
	var small: GameSession = _equivalence_session()
	big.advance(30000)
	big.combat.loot.collect_all()
	for i: int in 300:
		small.advance(100)
	small.combat.loot.collect_all()
	var bases: Array[StringName] = []
	for inst: ItemInstance in big.armory.instances():
		bases.append(inst.base_id)
	assert_true(bases.has(&"fx_leg_rod"), "the stone died and dropped its legendary")
	assert_eq(SaveCodec.encode(small.to_save(0)), SaveCodec.encode(big.to_save(0)))


func _equivalence_session() -> GameSession:
	var s: GameSession = _hero_session(21)
	LegendaryKit.wear(s, &"fx_leg_monolith")
	TestFactory.make_roomy(s)
	s.combat.from_save(_stone_save(60, 100060, 100))
	return s
