extends GutTest
## Disciplines (M24-03, docs/05_INTERFACES_M24.md §5.31): F-158 costs and requirements, F-159 unlearn cost, F-160 limits, the order of the
## refusals, atomic commands, unlearn effects, Recipes, tolerant loading and the invariant "xp > 0 implies learned".

const FORESTRY: StringName = &"forestry"
const QUARRYING: StringName = &"quarrying"
const ANGLING: StringName = &"angling"
const FORGING: StringName = &"forging"
const RIFTBINDING: StringName = &"riftbinding"

var _s: GameSession = null
var _d: Disciplines = null


func before_each() -> void:
	_s = autofree(TestFactory.session_no_kit(1, TestFactory.real_data()))
	_d = _s.disciplines
	_d.new_game()


func test_new_game_has_nothing_learned() -> void:
	assert_eq(_d.learned(&"gathering"), [] as Array[StringName])
	assert_eq(_d.free_slots(&"gathering"), 2)
	assert_false(_d.is_learned(FORESTRY))
	assert_false(_d.is_learned(RIFTBINDING), "the Incisore is a discipline since M25-11")
	assert_false(_d.is_learned(&"nope"))
	assert_eq(_d.grade(FORESTRY), 0)
	assert_eq(_d.category_of(FORESTRY), &"gathering")
	assert_eq(_d.category_of(RIFTBINDING), &"artisan")
	assert_eq(_d.to_save(), {"learned": {}, "recipes": [], "extra": [], "focus": {}})


## F-158: gold 0, 250, 1.250, 6.250, 31.250 (spent in total 39.000 up to grade 5).
func test_f158_gold_of_the_grades() -> void:
	var golds: Array[int] = []
	for g: int in range(1, 6):
		golds.append(TrainerGradeDef.gold(_s.data, g))
	assert_eq(golds, [0, 25000, 125000, 625000, 3125000] as Array[int])
	assert_eq(_d.next_grade_cost(FORESTRY), 0, "grade 0: the cost of grade 1")


func test_learn_gives_grade_1_and_signals() -> void:
	watch_signals(_s.events)
	assert_true(_d.learn(FORESTRY).ok)
	assert_eq(_d.grade(FORESTRY), 1)
	assert_eq(_d.level_cap(FORESTRY), 20)
	assert_signal_emitted_with_parameters(_s.events, "discipline_changed", [FORESTRY, 1])
	assert_eq(_d.next_grade_cost(FORESTRY), 25000)
	assert_eq(_d.learn(FORESTRY).reason, Reasons.ALREADY_LEARNED)


func test_learn_refusals_in_order_and_nothing_changes() -> void:
	assert_eq(_d.learn(&"nope").reason, Reasons.UNKNOWN_ID)
	assert_true(_d.learn(FORESTRY).ok)
	assert_true(_d.learn(QUARRYING).ok)
	watch_signals(_s.events)
	assert_eq(_d.learn(ANGLING).reason, Reasons.DISCIPLINE_SLOTS_FULL)
	assert_eq(_d.free_slots(&"gathering"), 0)
	assert_eq(_d.learned(&"gathering"), [FORESTRY, QUARRYING] as Array[StringName])
	assert_signal_not_emitted(_s.events, "discipline_changed")
	assert_true(_d.learn(FORGING).ok, "another category has its own places")


## F-158 example: grade 2 needs the discipline at 15 (cap 20 - 5), the character at 15, 250 gold; the order of the refusals.
func test_train_refusals_in_order_then_grade_2() -> void:
	assert_eq(_d.train(FORESTRY).reason, Reasons.NOT_LEARNED)
	assert_eq(_d.train(&"nope").reason, Reasons.UNKNOWN_ID)
	_d.learn(FORESTRY)
	TestFactory.set_level(_s, FORESTRY, 14)
	assert_eq(_d.train(FORESTRY).reason, Reasons.LEVEL_TOO_LOW, "14 < 15, before the character and the gold")
	TestFactory.set_level(_s, FORESTRY, 15)
	assert_eq(_d.train(FORESTRY).reason, Reasons.REQUIREMENT_NOT_MET, "character level 1 < 15, before the gold")
	TestFactory.set_character_level(_s, 15)
	assert_eq(_d.train(FORESTRY).reason, Reasons.NOT_ENOUGH_GOLD)
	var gold: int = _s.wallet.get_gold()
	_s.wallet.add_gold(25000 - gold + 1)
	watch_signals(_s.events)
	assert_true(_d.train(FORESTRY).ok)
	assert_eq(_d.grade(FORESTRY), 2)
	assert_eq(_s.wallet.get_gold(), 1)
	assert_eq(_d.level_cap(FORESTRY), 40)
	assert_signal_emitted_with_parameters(_s.events, "discipline_changed", [FORESTRY, 2])


func test_max_grade() -> void:
	TestFactory.learn_discipline(_s, FORESTRY, 5)
	assert_eq(_d.train(FORESTRY).reason, Reasons.MAX_GRADE)
	assert_eq(_d.next_grade_cost(FORESTRY), -1)
	assert_eq(_d.level_cap(FORESTRY), 99)


func test_learn_needs_the_gold_of_grade_1_which_is_free_at_the_start() -> void:
	assert_eq(_s.wallet.get_gold(), int(_s.data.balance_value("start.gold")))
	var gold: int = _s.wallet.get_gold()
	_d.learn(FORESTRY)
	assert_eq(_s.wallet.get_gold(), gold, "learn_gold is 0")


## F-159: 100, 125, 750, 3.875, 19.500.
func test_f159_unlearn_cost() -> void:
	var costs: Array[int] = []
	for g: int in range(1, 6):
		TestFactory.learn_discipline(_s, FORESTRY, g)
		costs.append(_d.unlearn_cost(FORESTRY))
	assert_eq(costs, [10000, 12500, 75000, 387500, 1950000] as Array[int])
	assert_eq(_d.unlearn_cost(QUARRYING), 0)


func test_unlearn_refusals_and_atomicity() -> void:
	assert_eq(_d.unlearn(FORESTRY).reason, Reasons.NOT_LEARNED)
	_d.learn(FORESTRY)
	_s.wallet.spend(_s.wallet.get_gold())
	_s.skills.add_xp(FORESTRY, 500)
	watch_signals(_s.events)
	assert_eq(_d.unlearn(FORESTRY).reason, Reasons.NOT_ENOUGH_GOLD)
	assert_eq(_d.grade(FORESTRY), 1)
	assert_eq(_s.skills.get_xp(FORESTRY), 500, "nothing changed")
	assert_signal_not_emitted(_s.events, "discipline_changed")


func test_unlearn_resets_xp_mastery_nodes_and_jobs() -> void:
	TestFactory.learn_discipline(_s, FORGING, 2)
	TestFactory.learn_discipline(_s, FORESTRY, 1)
	_s.wallet.add_gold(100000)
	_s.skills.add_xp(FORESTRY, 3000)
	var action: ActionDef = _s.data.mastery_actions_for_skill(FORESTRY)[0]
	_s.mastery.add_for_action(action, 5)
	assert_gt(_s.mastery.get_pool(FORESTRY), 0)
	TestFactory.give(_s, &"emberbronze_ore", 20)
	_s.actions.enqueue(FORGING, &"smelt_emberbronze", 3)
	var gold: int = _s.wallet.get_gold()
	watch_signals(_s.events)
	assert_true(_d.unlearn(FORESTRY).ok)
	assert_eq(_s.wallet.get_gold(), gold - 10000)
	assert_eq(_d.grade(FORESTRY), 0)
	assert_eq(_s.skills.get_xp(FORESTRY), 0)
	assert_eq(_s.mastery.get_mastery_xp(action.id), 0)
	assert_eq(_s.mastery.get_pool(FORESTRY), 0)
	assert_signal_emitted_with_parameters(_s.events, "skill_reset", [FORESTRY])
	assert_signal_emitted_with_parameters(_s.events, "discipline_changed", [FORESTRY, 0])
	assert_signal_not_emitted(_s.events, "level_up")
	assert_true(_s.actions.is_running(), "the jobs of other disciplines stay")
	assert_true(_d.unlearn(FORGING).ok)
	assert_false(_s.actions.is_running(), "the jobs of the discipline are dropped")


func test_unlearn_gives_back_the_started_blueprint_materials() -> void:
	TestFactory.learn_discipline(_s, FORGING, 1)
	var bp: ItemDef = null
	for item: ItemDef in _s.data.items():
		if item.is_blueprint() and BlueprintCraft.required_level(item, _s.data) <= 1:
			bp = item
			break
	if bp == null:
		pending("no blueprint of level 1 in the data")
		return
	for entry: ItemQty in BlueprintCraft.inputs(bp):
		TestFactory.give(_s, entry.item_id, entry.qty)
	TestFactory.give(_s, bp.id, 1)
	_s.wallet.add_gold(50000)
	assert_true(_s.actions.enqueue_blueprint(bp.id).ok)
	assert_eq(_s.bank.get_count(bp.id), 0, "the head consumed the blueprint")
	assert_true(_d.unlearn(FORGING).ok)
	assert_eq(_s.bank.get_count(bp.id), 1, "given back")


## discipline_busy needs a node in progress: M24-04 tests it with the real node cycle (node_skill is a stub returning &"" here).
func test_no_node_in_progress_does_not_block_unlearning() -> void:
	_d.learn(FORESTRY)
	_s.wallet.add_gold(50000)
	assert_eq(_s.combat.node_skill(), &"")
	assert_true(_d.can_unlearn(FORESTRY).ok)


func test_slots_free_up_after_unlearning() -> void:
	_d.learn(FORESTRY)
	_d.learn(QUARRYING)
	_s.wallet.add_gold(10000)
	_d.unlearn(FORESTRY)
	assert_true(_d.learn(ANGLING).ok)




func test_save_round_trip() -> void:
	_d.learn(FORESTRY)
	_d.learn(FORGING)
	TestFactory.learn_discipline(_s, FORGING, 3)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(_d.to_save()))
	assert_eq(_d.to_save(), {"learned": {"forestry": 1, "forging": 3}, "recipes": [], "extra": [], "focus": {}})
	var other: GameSession = autofree(TestFactory.session_no_kit(2, TestFactory.real_data()))
	other.disciplines.from_save(saved)
	assert_eq(other.disciplines.to_save(), _d.to_save())


func test_from_save_is_tolerant() -> void:
	_d.from_save({"learned": {"forestry": 2, "riftbinding": 1, "nope": 1, "quarrying": 9, "angling": 3, "forging": "x", "woodwright": 1.0}})
	assert_eq(_d.grade(FORESTRY), 2)
	assert_eq(_d.grade(QUARRYING), 0, "grade out of 1..n")
	assert_eq(_d.grade(ANGLING), 3, "the second gathering place")
	assert_false(_d.learned(&"gathering").has(QUARRYING))
	assert_eq(_d.grade(FORGING), 0)
	assert_eq(_d.grade(&"woodwright"), 1)
	_d.from_save({"learned": {"forestry": 1, "quarrying": 1, "angling": 1}})
	assert_eq(_d.learned(&"gathering"), [FORESTRY, QUARRYING] as Array[StringName], "the first by order stay")
	_d.from_save({"learned": "oops", "recipes": 5})
	assert_eq(_d.to_save(), {"learned": {}, "recipes": [], "extra": [], "focus": {}})


func test_from_save_resets_a_discipline_with_xp_that_is_not_learned() -> void:
	TestFactory.learn_discipline(_s, ANGLING, 1)
	_s.skills.add_xp(ANGLING, 400)
	assert_gt(_s.skills.get_xp(ANGLING), 0)
	_d.from_save({"learned": {"forestry": 1}})
	assert_eq(_s.skills.get_xp(ANGLING), 0, "xp > 0 implies learned")


func test_a_session_save_round_trip_resets_nothing_learned() -> void:
	_d.learn(FORESTRY)
	_s.skills.add_xp(FORESTRY, 300)
	var text: String = SaveCodec.encode(_s.to_save(1))
	var other: GameSession = autofree(TestFactory.session_no_kit(3, TestFactory.real_data()))
	assert_true(other.from_save(SaveCodec.decode(text)).ok)
	assert_eq(other.skills.get_xp(FORESTRY), _s.skills.get_xp(FORESTRY))
	assert_eq(other.disciplines.grade(FORESTRY), 1)


# --- Recipes (fixture: recipe_secret teaches craft_secret of test_craft_b) -----------------------------------------------

func test_recipes() -> void:
	var s: GameSession = autofree(TestFactory.session())
	var d: Disciplines = s.disciplines
	assert_true(d.knows_recipe(&"craft_plank"), "an action without `discover` is always known")
	assert_false(d.knows_recipe(&"craft_secret"))
	assert_false(d.knows_recipe(&"nope"))
	assert_eq(d.learn_recipe(&"nope").reason, Reasons.UNKNOWN_ID)
	assert_eq(d.learn_recipe(&"test_twig").reason, Reasons.NOT_A_RECIPE)
	assert_eq(d.learn_recipe(&"recipe_secret").reason, Reasons.NOT_ENOUGH_ITEMS)
	TestFactory.give(s, &"recipe_secret", 2)
	watch_signals(s.events)
	assert_true(d.learn_recipe(&"recipe_secret").ok)
	assert_true(d.knows_recipe(&"craft_secret"))
	assert_eq(s.bank.get_count(&"recipe_secret"), 1)
	assert_eq(d.known_recipes(), [&"craft_secret"] as Array[StringName])
	assert_signal_emitted_with_parameters(s.events, "recipe_learned", [&"craft_secret"])
	assert_eq(d.learn_recipe(&"recipe_secret").reason, Reasons.RECIPE_KNOWN)
	assert_eq(s.bank.get_count(&"recipe_secret"), 1, "nothing consumed by a refusal")
	var saved: Dictionary = d.to_save()
	assert_eq(saved["recipes"], ["craft_secret"])
	d.from_save({"learned": {}, "recipes": ["craft_secret", "craft_plank", "nope", "craft_secret"]})
	assert_eq(d.known_recipes(), [&"craft_secret"] as Array[StringName], "unknown, undiscoverable and repeated ones dropped")

