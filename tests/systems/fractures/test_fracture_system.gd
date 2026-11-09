extends GutTest
## FractureSystem (docs/05_INTERFACES.md §5.23): open and its refusals, state, abandon, save of the Fracture and of the
## waiting bag, tolerance of a bad save, new game. The fights are in test_fracture_flow.gd.

var _s: GameSession = null


func before_each() -> void:
	_s = autofree(FractureUtil.session(5))


func test_open_refusals_in_order() -> void:
	assert_eq(_s.fractures.open(999).reason, Reasons.UNKNOWN_ID)
	var first: int = FractureUtil.card(_s, 1)
	var second: int = FractureUtil.card(_s, 2)
	assert_true(_s.fractures.open(first).ok)
	assert_eq(_s.fractures.open(second).reason, Reasons.FRACTURE_ACTIVE)
	assert_eq(_s.fractures.open(999).reason, Reasons.UNKNOWN_ID, "unknown_id comes first")
	assert_true(_s.cards.has(second), "a refused open spends nothing")
	assert_false(_s.cards.has(first), "the opened Card is gone")


func test_open_emits_the_grade_and_consumes_the_card() -> void:
	watch_signals(_s.events)
	var uid: int = FractureUtil.card(_s, 3)
	assert_true(_s.fractures.open(uid).ok)
	assert_signal_emitted_with_parameters(_s.events, "fracture_opened", [3])
	assert_signal_emitted_with_parameters(_s.events, "card_changed", [uid, &"removed"])
	assert_true(_s.fractures.is_active())
	assert_eq(_s.fractures.run().grade, 3)
	assert_eq(_s.fractures.run().card.uid, uid)


func test_state_for_the_ui() -> void:
	assert_eq(_s.fractures.state(), {})
	assert_null(_s.fractures.run())
	var uid: int = FractureUtil.card(_s, 2, [["sturdy", 3]])
	_s.fractures.open(uid)
	var state: Dictionary = _s.fractures.state()
	assert_eq(state["grade"], 2)
	assert_eq(state["group"], 1)
	assert_eq(state["groups"], 3)
	assert_false(state["boss"])
	assert_eq((state["card"] as MapCard).mods.size(), 1)
	assert_eq(state["bag"], {"stacks": 0, "pieces": 0, "cards": 0})
	(state["card"] as MapCard).mods.clear()
	assert_eq(_s.fractures.state()["card"].mods.size(), 1, "the state is a copy")


func test_abandon_without_a_fracture() -> void:
	assert_eq(_s.fractures.abandon().reason, Reasons.NO_FRACTURE)
	assert_eq(_s.fractures.collect().reason, Reasons.NO_FRACTURE)


func test_recommended_level_comes_from_the_grade_table() -> void:
	assert_eq(_s.fractures.recommended_level(1), 45)
	assert_eq(_s.fractures.recommended_level(10), 99)


func test_save_and_load_a_fracture_in_progress() -> void:
	TestFactory.set_character_level(_s, 90)  # strong through saved state: a test modifier would not survive the load
	_s.fractures.open(FractureUtil.card(_s, 2, [["assault", 4]]))
	_s.fractures.run().bag.add_stack(&"test_log", 4)
	_s.advance(5000)
	var saved: Dictionary = _s.to_save(1)
	var loaded: GameSession = autofree(FractureUtil.session(5))
	assert_true(loaded.from_save(saved).ok)
	assert_true(loaded.fractures.is_active())
	assert_eq(loaded.fractures.to_save(), _s.fractures.to_save())
	assert_eq(loaded.combat.to_save(), _s.combat.to_save())
	assert_true(loaded.combat.in_fracture())
	assert_true(loaded.modifiers.has_source(StringName("fracture:%d" % _s.fractures.run().card.uid)), "the rewards come back")


func test_the_pending_bag_is_saved() -> void:
	var bag := FractureBag.new()
	bag.add_stack(&"test_log", 3)
	var card := MapCard.new()
	card.base_id = &"fracture_card_1"
	card.grade = 1
	card.mods.append(MapModRoll.make(&"sturdy", 2))
	bag.add_card(card)
	_s.fractures.from_save({"run": {}, "pending": bag.to_save()})
	assert_true(_s.fractures.has_pending())
	var pending: Dictionary = _s.fractures.pending()
	assert_eq(pending["cards"], 1)
	assert_eq(_s.fractures.to_save()["pending"], bag.to_save())
	assert_eq(_s.fractures.open(FractureUtil.card(_s, 1)).reason, Reasons.FRACTURE_BAG_PENDING)


func test_a_bad_save_is_tolerated() -> void:
	_s.fractures.from_save({"run": {"card": {"uid": 1, "base": "nope", "rarity": "common", "mods": []}}, "pending": 3})
	assert_false(_s.fractures.is_active())
	assert_false(_s.fractures.has_pending())
	_s.fractures.from_save({"run": {"card": FractureUtil.card_dict(1), "group": 9, "groups_cleared": 0}})
	assert_false(_s.fractures.is_active(), "group beyond the total")
	_s.fractures.from_save({"run": {"card": FractureUtil.card_dict(1), "group": 1, "groups_cleared": 2}})
	assert_false(_s.fractures.is_active(), "more groups cleared than drawn")
	_s.fractures.from_save({})
	assert_false(_s.fractures.is_active())


func test_a_saved_run_with_an_idle_combat_is_dropped() -> void:
	_s.fractures.open(FractureUtil.card(_s, 1))
	var saved: Dictionary = _s.to_save(1)
	((saved["modules"] as Dictionary)["combat"] as Dictionary)["state"] = "idle"
	var loaded: GameSession = autofree(FractureUtil.session(5))
	assert_true(loaded.from_save(saved).ok)
	assert_false(loaded.fractures.is_active(), "no fight to run on: the Fracture is over")
	assert_false(loaded.combat.is_active())


func test_a_saved_fight_without_a_run_is_idle() -> void:
	_s.fractures.open(FractureUtil.card(_s, 1))
	var saved: Dictionary = _s.to_save(1)
	((saved["modules"] as Dictionary)["fractures"] as Dictionary)["run"] = {}
	var loaded: GameSession = autofree(FractureUtil.session(5))
	assert_true(loaded.from_save(saved).ok)
	assert_false(loaded.combat.is_active())
	assert_false(loaded.combat.in_fracture())


func test_new_game_empties_everything() -> void:
	_s.fractures.open(FractureUtil.card(_s, 1))
	_s.new_game()
	assert_false(_s.fractures.is_active())
	assert_false(_s.combat.in_fracture())
	assert_false(_s.fractures.has_pending())
	assert_eq(_s.fractures.to_save(), {"run": {}, "pending": {}})
