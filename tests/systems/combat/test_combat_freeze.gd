extends GutTest
## M31 (docs/M31_RITOCCHI_TUTORIAL.md §3.1): the frozen engine, `wound_to_pct`, `force_node` flags, on the real data.

const AREA: StringName = &"redrock_plains"
const SEED: int = 777


func _session() -> GameSession:
	var s: GameSession = autofree(TestFactory.session(SEED, TestFactory.real_data()))
	assert_true(s.combat.start(AREA).ok)
	s.advance(5000)
	return s


func test_frozen_advance_consumes_nothing_and_rolls_nothing() -> void:
	var s: GameSession = _session()
	s.combat.set_frozen(true)
	assert_true(s.combat.is_frozen())
	var combat_before: String = JSON.stringify(s.combat.to_save())
	var rng_before: String = JSON.stringify(s.rng.to_save())
	var time_before: int = s.play_time_ms
	s.advance(60000)
	assert_eq(JSON.stringify(s.combat.to_save()), combat_before)
	assert_eq(JSON.stringify(s.rng.to_save()), rng_before)
	assert_eq(s.play_time_ms, time_before + 60000, "play time goes on")
	s.combat.set_frozen(false)
	s.advance(60000)
	assert_ne(JSON.stringify(s.combat.to_save()), combat_before, "the fight goes on")


func test_frozen_is_not_saved_and_new_game_clears_it() -> void:
	var s: GameSession = _session()
	s.combat.set_frozen(true)
	s.combat.set_force_node(true)
	assert_false(JSON.stringify(s.combat.to_save()).contains("frozen"))
	var twin: GameSession = autofree(TestFactory.session(SEED, TestFactory.real_data()))
	assert_true(twin.from_save(s.to_save(0)).ok)
	assert_false(twin.combat.is_frozen())
	assert_false(twin.combat.is_force_node())
	s.combat.new_game()
	assert_false(s.combat.is_frozen())
	assert_false(s.combat.is_force_node())


func test_wound_to_pct() -> void:
	var s: GameSession = _session()
	var max_hp: int = s.combat.player_stats().max_hp
	s.combat.wound_to_pct(30)
	assert_eq(s.combat.get_state()["player_hp"], (max_hp * 30 + 99) / 100)
	var low: int = int(s.combat.get_state()["player_hp"])
	s.combat.wound_to_pct(90)
	assert_eq(s.combat.get_state()["player_hp"], low, "never heals")
	s.combat.wound_to_pct(1)
	assert_gte(int(s.combat.get_state()["player_hp"]), 1, "never under 1")


func test_wound_to_pct_does_nothing_while_idle() -> void:
	var s: GameSession = autofree(TestFactory.session(SEED, TestFactory.real_data()))
	var before: Dictionary = s.combat.to_save()
	s.combat.wound_to_pct(30)
	assert_eq(s.combat.to_save(), before)
