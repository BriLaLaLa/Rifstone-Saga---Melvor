extends GutTest
## M24-07, integration on the real data and a real `GameSession`: the flow of docs/01_GDD_M24.md §35 seen from the outside, with the
## real engine. Learns 2 + 2 disciplines from the Trainers, fights with nodes worked and skipped, a production queue in parallel,
## the next grade, unlearning, save and reload, the Fracture and the Dungeon opened during a node. The equivalences of the
## offline run (one block = ticks = blocks) are in `test_m24_offline_equivalence.gd`. Public APIs only (05_INTERFACES_M24.md).

const AREA: StringName = &"redrock_plains"
const SEED: int = 2407
const FORESTRY: StringName = &"forestry"
const ANGLING: StringName = &"angling"
const QUARRYING: StringName = &"quarrying"
const HERBALISM: StringName = &"herbalism"
const FORGING: StringName = &"forging"
const HEARTH: StringName = &"hearthcraft"
const WOODWRIGHT: StringName = &"woodwright"
const SMELT: StringName = &"smelt_emberbronze"
const ORE: StringName = &"emberbronze_ore"
const INGOT: StringName = &"emberbronze_ingot"
const TICKET: StringName = &"dungeon_ticket_monkey_den"
const DEN: StringName = &"monkey_den"
const NOW_MS: int = 1793603600000
const STEP_MS: int = 500
const LIMIT_MS: int = 4 * 3_600_000


## A new game on the real data with nothing learned (the factory learns the first disciplines: they are forgotten here), a hero that
## does not die and room in the Deposit.
func _session(seed_value: int = SEED) -> GameSession:
	var s: GameSession = autofree(TestFactory.session_no_kit(seed_value, TestFactory.real_data()))
	s.disciplines.new_game()
	TestFactory.set_character_level(s, 55)
	TestFactory.make_roomy(s)
	_boost(s)
	s.wallet.add_gold(200000)
	return s


func _boost(s: GameSession) -> void:
	s.modifiers.set_source(&"test:hero", [Modifier.make(&"power_bonus", 100000.0), Modifier.make(&"max_hp_flat", 100000.0),
			Modifier.make(&"armor", 100000.0), Modifier.make(&"evasion_bonus", 80000.0)])


func _learn(s: GameSession, ids: Array[StringName]) -> void:
	for id: StringName in ids:
		assert_true(s.disciplines.learn(id).ok, "learn %s" % id)


## Advances in STEP_MS steps until `done` is true, within LIMIT_MS; returns whether it happened.
func _until(s: GameSession, done: Callable) -> bool:
	var spent: int = 0
	while spent < LIMIT_MS:
		if done.call():
			return true
		s.advance(STEP_MS)
		spent += STEP_MS
	return done.call()


## What the Deposit holds, item to count, without the Dungeon tickets (spent at the entry).
func _goods(s: GameSession) -> Dictionary:
	var goods: Dictionary = {}
	for stack: Dictionary in s.bank.to_save().get("stacks", []):
		if stack["item"] != String(TICKET):
			goods[stack["item"]] = int(goods.get(stack["item"], 0)) + int(stack["count"])
	return goods


func _in_worked_node(s: GameSession) -> bool:
	return s.combat.state() == CombatEngine.STATE_NODE and not bool(s.combat.get_state()["node"]["skipped"])


func test_two_and_two_disciplines_are_learned_from_the_trainers_and_the_third_is_refused() -> void:
	var s: GameSession = _session()
	assert_eq(s.disciplines.learned(&"gathering").size(), 0)
	_learn(s, [FORESTRY, ANGLING, FORGING, HEARTH])
	assert_eq(s.disciplines.learned(&"gathering"), [FORESTRY, ANGLING] as Array[StringName])
	assert_eq(s.disciplines.learned(&"artisan").size(), 2)
	assert_eq(s.disciplines.free_slots(&"gathering"), 0)
	assert_eq(s.disciplines.learn(QUARRYING).reason, Reasons.DISCIPLINE_SLOTS_FULL)
	assert_eq(s.disciplines.free_slots(&"artisan"), 1, "M32: the Cucina does not take an artisan slot, so one is still free")
	assert_eq(s.disciplines.learn(FORESTRY).reason, Reasons.ALREADY_LEARNED)
	assert_eq(s.disciplines.grade(FORESTRY), 1)
	assert_eq(s.disciplines.grade(QUARRYING), 0)
	assert_eq(s.skills.add_xp(QUARRYING, 500), 0, "a discipline that is not learned gains nothing")
	assert_eq(s.skills.get_xp(QUARRYING), 0)


func test_the_fights_work_the_learned_nodes_and_skip_the_others() -> void:
	var s: GameSession = _session()
	_learn(s, [FORESTRY, ANGLING])
	var skipped: Array[StringName] = []
	var worked_units: Dictionary[StringName, int] = {}
	s.events.node_finished.connect(func(skill: StringName, _a: StringName, units: int, reason: StringName) -> void:
		if reason == &"not_learned":
			skipped.append(skill)
			assert_eq(units, 0, "a skipped node gives nothing")
		else:
			worked_units[skill] = worked_units.get(skill, 0) + units)
	assert_true(s.combat.start(AREA).ok)
	var xp_before: int = s.skills.get_xp(FORESTRY)
	assert_true(_until(s, func() -> bool: return int(s.combat.node_counts()["worked"]) >= 3 and int(s.combat.node_counts()["skipped"]) >= 2))
	assert_true(skipped.has(QUARRYING) or skipped.has(HERBALISM), "only the disciplines not learned are skipped")
	assert_false(skipped.has(FORESTRY) or skipped.has(ANGLING))
	assert_gt(worked_units.size(), 0)
	for skill: StringName in worked_units:
		# M25 (F-162): a node gives at least `node_units` x `yield_min_pct` / 100 units (the yield falls with the gap to the difficulty)
		var least: int = int(s.data.balance_value("encounters.node_units")) * int(s.data.balance_value("encounters.yield_min_pct")) / 100
		assert_gte(worked_units[skill], least, "the least a node gives (%s)" % skill)
		assert_gt(s.skills.get_xp(skill), 0)
	assert_eq(s.skills.get_xp(QUARRYING), 0)
	assert_eq(s.skills.get_xp(HERBALISM), 0)
	assert_gte(s.skills.get_xp(FORESTRY), xp_before)
	assert_gt(s.combat.total_kills().size(), 0, "the fights go on between the nodes")
	assert_false(s.combat.is_active() and s.combat.state() == CombatEngine.STATE_IDLE)


func test_the_production_queue_runs_in_parallel_with_the_fights() -> void:
	var s: GameSession = _session()
	_learn(s, [FORESTRY, ANGLING, FORGING])
	TestFactory.give(s, ORE, 4000)
	assert_true(s.actions.enqueue(FORGING, SMELT, 100).ok)
	assert_true(s.combat.start(AREA).ok)
	var seen: Dictionary = {"kills": 0, "nodes": 0}  # lambdas capture numbers by value: a dictionary is shared
	s.events.monster_killed.connect(func(_i: int, _id: StringName) -> void: seen["kills"] += 1)
	s.events.node_finished.connect(func(_s: StringName, _a: StringName, _u: int, _r: StringName) -> void: seen["nodes"] += 1)
	var forging_xp: int = s.skills.get_xp(FORGING)
	assert_true(_until(s, func() -> bool:
		return int(seen["kills"]) >= 5 and int(seen["nodes"]) >= 2 and s.bank.get_count(INGOT) >= 10))
	assert_true(s.combat.is_active(), "the queue does not stop the combat")
	assert_gt(s.skills.get_xp(FORGING), forging_xp)
	assert_lt(s.bank.get_count(ORE), 4000, "the ore is consumed while the fights go on")


func test_the_next_grade_needs_the_skill_level_the_character_level_and_the_gold() -> void:
	var s: GameSession = _session()
	_learn(s, [FORESTRY])
	var cap_before: int = s.disciplines.level_cap(FORESTRY)
	var xp_max_before: int = s.disciplines.xp_max(FORESTRY)
	assert_eq(s.disciplines.train(FORESTRY).reason, Reasons.LEVEL_TOO_LOW, "level 1 is far from the cap of the first grade")
	TestFactory.set_level(s, FORESTRY, 14)
	assert_eq(s.disciplines.train(FORESTRY).reason, Reasons.LEVEL_TOO_LOW, "one level short of cap - margin")
	TestFactory.set_level(s, FORESTRY, 15)
	var gold: int = s.wallet.get_gold()
	var cost: int = s.disciplines.next_grade_cost(FORESTRY)
	assert_gt(cost, 0)
	assert_true(s.disciplines.train(FORESTRY).ok)
	assert_eq(s.disciplines.grade(FORESTRY), 2)
	assert_eq(s.wallet.get_gold(), gold - cost)
	assert_gt(s.disciplines.level_cap(FORESTRY), cap_before)
	assert_gt(s.disciplines.xp_max(FORESTRY), xp_max_before)
	var poor: GameSession = _session()
	_learn(poor, [FORESTRY])
	TestFactory.set_level(poor, FORESTRY, 15)
	poor.wallet.spend(poor.wallet.get_gold())
	assert_eq(poor.disciplines.train(FORESTRY).reason, Reasons.NOT_ENOUGH_GOLD)
	assert_eq(poor.disciplines.grade(FORESTRY), 1, "nothing changes when the gold is missing")


func test_the_xp_stops_at_the_cap_of_the_grade() -> void:
	var s: GameSession = _session()
	_learn(s, [FORESTRY])
	var lost: Array[int] = []
	s.events.xp_capped.connect(func(skill: StringName, amount: int) -> void:
		if skill == FORESTRY:
			lost.append(amount))
	s.skills.add_xp(FORESTRY, s.disciplines.xp_max(FORESTRY) + 1000)
	assert_eq(s.skills.get_xp(FORESTRY), s.disciplines.xp_max(FORESTRY))
	assert_eq(s.skills.get_level(FORESTRY), s.disciplines.level_cap(FORESTRY))
	assert_false(lost.is_empty(), "the xp over the cap is announced as lost")


func test_unlearning_resets_the_discipline_drops_its_jobs_and_frees_the_place() -> void:
	var s: GameSession = _session()
	_learn(s, [FORGING, HEARTH])
	TestFactory.give(s, ORE, 500)
	assert_true(s.actions.enqueue(FORGING, SMELT, 50).ok)
	s.advance(20_000)
	assert_gt(s.skills.get_xp(FORGING), 0)
	assert_gt(s.mastery.get_mastery_xp(SMELT), 0)
	var cost: int = s.disciplines.unlearn_cost(FORGING)
	assert_gt(cost, 0)
	var gold: int = s.wallet.get_gold()
	var poor: GameSession = _session()
	_learn(poor, [FORGING])
	poor.wallet.spend(poor.wallet.get_gold())
	assert_eq(poor.disciplines.unlearn(FORGING).reason, Reasons.NOT_ENOUGH_GOLD)
	assert_eq(poor.disciplines.grade(FORGING), 1)
	assert_true(s.disciplines.unlearn(FORGING).ok)
	assert_eq(s.wallet.get_gold(), gold - cost)
	assert_eq(s.skills.get_xp(FORGING), 0)
	assert_eq(s.mastery.get_mastery_xp(SMELT), 0)
	assert_eq(s.mastery.get_pool(FORGING), 0)
	assert_eq(s.disciplines.grade(FORGING), 0)
	assert_eq(s.actions.jobs().size(), 0, "the jobs of the discipline leave the queue")
	assert_false(s.actions.is_running())
	assert_eq(s.disciplines.free_slots(&"artisan"), 2, "M32: the Cucina learned by the factory takes no place")
	assert_true(s.disciplines.learn(WOODWRIGHT).ok, "the place is free for another discipline")


func test_a_discipline_cannot_be_unlearned_while_its_node_is_worked() -> void:
	var s: GameSession = _session()
	_learn(s, [FORESTRY, ANGLING])
	assert_true(s.combat.start(AREA).ok)
	assert_true(_until(s, func() -> bool: return _in_worked_node(s)))
	var busy: StringName = s.combat.node_skill()
	assert_ne(busy, &"")
	assert_eq(s.disciplines.unlearn(busy).reason, Reasons.DISCIPLINE_BUSY)
	assert_gt(s.disciplines.grade(busy), 0)


func test_a_saved_session_continues_identical_with_the_queue_and_the_nodes() -> void:
	var a: GameSession = _session()
	_learn(a, [FORESTRY, ANGLING, FORGING])
	TestFactory.give(a, ORE, 4000)
	assert_true(a.actions.enqueue(FORGING, SMELT, 300).ok)
	assert_true(a.combat.start(AREA).ok)
	for _i: int in 7 * 60 * 2 + 5:  # 7 minutes and a bit, inside some state of the cycle
		a.advance(STEP_MS)
	var b: GameSession = autofree(TestFactory.session_no_kit(1, TestFactory.real_data()))
	assert_true(b.from_save(SaveCodec.decode(SaveCodec.encode(a.to_save(NOW_MS))) as Dictionary).ok)
	_boost(b)  # the load rebuilds the modifier sources: the boost of the test goes back
	b.combat.from_save(a.combat.to_save())
	TestFactory.make_roomy(b)
	assert_eq(b.combat.to_save(), a.combat.to_save())
	assert_eq(b.disciplines.to_save(), a.disciplines.to_save())
	assert_eq(b.actions.to_save(), a.actions.to_save())
	for _i: int in 20 * 60 * 2:
		a.advance(STEP_MS)
		b.advance(STEP_MS)
	assert_eq(b.combat.to_save(), a.combat.to_save())
	assert_eq(b.actions.to_save(), a.actions.to_save())
	assert_eq(b.bank.to_save(), a.bank.to_save())
	assert_eq(b.skills.to_save(), a.skills.to_save())
	assert_eq(b.mastery.to_save(), a.mastery.to_save())
	assert_eq(b.rng.to_save(), a.rng.to_save())


func test_a_fracture_opened_during_a_worked_node_loses_the_node_without_products() -> void:
	var s: GameSession = _session()
	_learn(s, [FORESTRY, ANGLING])
	assert_true(s.combat.start(AREA).ok)
	assert_true(_until(s, func() -> bool: return _in_worked_node(s)))
	var bank: Dictionary = _goods(s)
	var xp: Dictionary = s.skills.to_save()
	var uid: int = FractureUtil.card(s, 1)
	assert_true(s.fractures.open(uid).ok)
	assert_true(s.combat.in_fracture())
	assert_eq(s.combat.node_skill(), &"")
	assert_eq(s.skills.to_save(), xp, "the node is lost: no xp")
	assert_eq(_goods(s), bank, "the node is lost: no units")


func test_a_dungeon_opened_during_a_node_or_a_journey_loses_it_without_products() -> void:
	var s: GameSession = _session()
	_learn(s, [FORESTRY, ANGLING])
	s.bank.add(TICKET, 2)
	assert_true(s.combat.start(AREA).ok)
	assert_true(_until(s, func() -> bool: return s.combat.state() == CombatEngine.STATE_TRAVEL))
	var xp: Dictionary = s.skills.to_save()
	assert_true(s.dungeon.open(DEN).ok, "a dungeon opens during a journey")
	assert_true(s.combat.in_dungeon())
	assert_eq(s.skills.to_save(), xp)
	assert_true(s.dungeon.flee().ok)
	assert_eq(s.combat.area_id(), AREA, "back to the area after the flight")
	assert_true(_until(s, func() -> bool: return _in_worked_node(s)))
	xp = s.skills.to_save()
	var stacks: Dictionary = _goods(s)
	assert_true(s.dungeon.open(DEN).ok, "a dungeon opens during a worked node")
	assert_eq(s.combat.node_skill(), &"")
	assert_eq(s.skills.to_save(), xp, "the node is lost: no xp")
	assert_eq(_goods(s), stacks, "the node is lost: no units")
	assert_true(s.dungeon.flee().ok)
