extends GutTest
## F-200: the resource of a node, rolled at the start with the weights of the zone (docs/02_FORMULAS_M35B.md). The tables are the ones
## of F-201 (`zone_tables.gd`). Zone 1 = redrock_plains, zone 3 = dry_uplands, zone 10 = rift_heart; Minatore (quarrying) steps
## Rame 1, Ferro 10, Ferro scuro 20, Ferro nero 30, Argento runico 45, Ossidiana 60, Astrite 75, Riftite 90. A fake generator records the calls.

const ZoneTables := preload("res://tests/systems/encounters/zone_tables.gd")
const Q: StringName = &"quarrying"
const Z1: StringName = &"redrock_plains"
const Z3: StringName = &"dry_uplands"
const Z10: StringName = &"rift_heart"
const COPPER: StringName = &"quarry_emberbronze"
const IRON: StringName = &"quarry_ashlead"
const DARK_IRON: StringName = &"quarry_stormzinc"
const BLACK_IRON: StringName = &"quarry_duskcobalt"
const OBSIDIAN: StringName = &"quarry_palecinnabar"
const ASTRITE: StringName = &"quarry_emberheart"


## Records the calls in order (`log`: "pick" / "roll"), the weights of every pick, and answers the scripted index.
class FakeRng extends RngService:
	var log: Array[String] = []
	var weights_seen: Array = []
	var answer: int = 0

	func _init() -> void:
		super(1)

	func pick_weighted(weights: Array[int]) -> int:
		log.append("pick")
		weights_seen.append(weights.duplicate())
		return answer

	func roll_pct(_chance_pct: float) -> bool:
		log.append("roll")
		return false


func _session(level: int = 1) -> GameSession:
	var s: GameSession = autofree(TestFactory.session_no_kit(55, ZoneTables.data()))
	s.disciplines._grades.clear()
	TestFactory.learn_discipline(s, Q)
	if level > 1:
		TestFactory.set_level(s, Q, level)
	s.rng = FakeRng.new()
	return s


func _fake(s: GameSession) -> FakeRng:
	return s.rng as FakeRng


func _pick(s: GameSession, area: StringName, level: int, answer: int, skipped: bool = false) -> ActionDef:
	_fake(s).answer = answer
	return EncounterCycle.pick_resource(s, area, Q, level, skipped)


func test_zone_3_at_level_45_rolls_over_all_four_weights() -> void:
	var s: GameSession = _session()
	var action: ActionDef = _pick(s, Z3, 45, 2)
	assert_eq(action.id, DARK_IRON)
	assert_eq(_fake(s).weights_seen, [[5, 25, 55, 15]])
	assert_eq(EncounterCycle.color(s.data, 45, action.level)["id"], &"green", "d 25")


func test_zone_3_at_level_25_drops_the_not_workable_entry() -> void:
	var s: GameSession = _session()
	var action: ActionDef = _pick(s, Z3, 25, 1)
	assert_eq(action.id, IRON)
	assert_eq(_fake(s).weights_seen, [[5, 25, 55]], "the weights are not recomputed: pick_weighted renormalizes")
	assert_eq(EncounterCycle.color(s.data, 25, action.level)["id"], &"yellow", "d 15")


func test_one_eligible_entry_is_taken_without_a_roll() -> void:
	var s: GameSession = _session()
	assert_eq(_pick(s, Z3, 5, 0).id, COPPER)
	assert_eq(_pick(s, Z10, 62, 0).id, OBSIDIAN, "only Ossidiana of zone 10 is workable at 62")
	assert_eq(_fake(s).log, [])


func test_a_skipped_node_takes_the_heaviest_eligible_entry_without_a_roll() -> void:
	var s: GameSession = _session()
	assert_eq(_pick(s, Z3, 25, 1, true).id, DARK_IRON)
	assert_eq(_pick(s, Z3, 45, 1, true).id, DARK_IRON)
	assert_eq(_fake(s).log, [])


func test_no_eligible_entry_gives_the_fallback_without_a_roll() -> void:
	var s: GameSession = _session()
	assert_eq(_pick(s, Z10, 1, 0).id, COPPER, "zone 10 at level 1: nothing workable, the best step <= 1")
	assert_eq(_pick(s, Z10, 1, 0, true).id, COPPER, "also when skipped")
	assert_eq(_pick(s, Z10, 50, 0).id, EncounterCycle.fallback_action(s.data, Q, 50).id, "level 50: Argento runico (45) is not in the zone")
	assert_eq(_fake(s).log, [])


func test_zone_10_at_level_80_rolls_between_obsidian_and_astrite() -> void:
	var s: GameSession = _session()
	assert_eq(_pick(s, Z10, 80, 1).id, ASTRITE)
	assert_eq(_fake(s).weights_seen, [[6, 29]])


func test_zone_1_at_level_10_copper_or_iron_both_orange() -> void:
	var s: GameSession = _session()
	var copper: ActionDef = _pick(s, Z1, 10, 0)
	assert_eq(copper.id, COPPER)
	assert_eq(EncounterCycle.color(s.data, 10, copper.level)["id"], &"orange", "d 9")
	var iron: ActionDef = _pick(s, Z1, 10, 1)
	assert_eq(iron.id, IRON)
	assert_eq(EncounterCycle.color(s.data, 10, iron.level)["id"], &"orange", "d 0")
	assert_eq(_fake(s).weights_seen, [[79, 21], [79, 21]])


func test_the_cap_of_the_zone_no_longer_limits_the_resource() -> void:
	var s: GameSession = _session()
	assert_eq(s.data.area_nodes(Z1).max_level, 10)
	assert_eq(_pick(s, Z1, 10, 1).level, 10, "Ferro, level 10, at the cap")
	assert_eq(_pick(s, Z3, 45, 3).id, BLACK_IRON, "index 3 of the four workable entries")


# --- the position of the generator in NodeWork.begin ---------------------------------------------------------------------------------

func _begin(s: GameSession, area: StringName) -> NodeWork:
	((s.data.get("_balance") as Dictionary)["encounters"] as Dictionary)["rich_chance_pct"] = 10  # so the rich roll consumes the generator
	return NodeWork.begin(s, area, Q)


func test_begin_rolls_the_resource_then_the_rich_node() -> void:
	var s: GameSession = _session(45)
	var work: NodeWork = _begin(s, Z3)
	assert_eq(_fake(s).log, ["pick", "roll"])
	assert_eq(work.action_id, COPPER, "the scripted answer is index 0")


func test_begin_with_one_eligible_entry_only_rolls_the_rich_node() -> void:
	var s: GameSession = _session(5)
	var work: NodeWork = _begin(s, Z3)
	assert_eq(_fake(s).log, ["roll"])
	assert_eq(work.action_id, COPPER)


func test_begin_of_a_skipped_node_does_not_touch_the_generator() -> void:
	var s: GameSession = _session(45)
	s.disciplines._grades.clear()  # not learned: skipped
	var work: NodeWork = _begin(s, Z3)
	assert_true(work.skipped)
	assert_eq(work.skip_reason, Reasons.NOT_LEARNED)
	assert_eq(_fake(s).log, [])
	assert_eq(work.action_id, DARK_IRON, "the one that would have been worked: the heaviest eligible")


func test_the_resource_is_saved_with_the_node_and_not_rolled_again_on_load() -> void:
	var s: GameSession = _session(45)
	s.rng = RngService.new(77)  # the real generator: the node rolls its resource for real
	TestFactory.set_character_level(s, 30)
	s.modifiers.set_source(&"test:hero", [Modifier.make(&"power_bonus", 100000.0), Modifier.make(&"max_hp_flat", 100000.0), Modifier.make(&"armor", 100000.0)])
	assert_true(s.combat.start(Z3).ok)
	var node: Dictionary = {}
	for _i: int in 3000:
		s.advance(1000)
		node = s.combat.get_state().get("node", {})
		if not node.is_empty():
			break
	assert_false(node.is_empty(), "a node started")
	var saved: Dictionary = SaveCodec.decode(SaveCodec.encode(s.to_save(0)))
	var loaded: GameSession = autofree(TestFactory.session_no_kit(56, ZoneTables.data()))
	loaded.rng = FakeRng.new()
	assert_true(loaded.from_save(saved).ok)
	var loaded_node: Dictionary = loaded.combat.get_state()["node"]
	assert_eq(loaded_node["action"], node["action"], "the same resource")
	assert_eq(loaded_node["ne"], node["ne"])
	assert_eq(_fake(loaded).log, [], "no roll at the load")
