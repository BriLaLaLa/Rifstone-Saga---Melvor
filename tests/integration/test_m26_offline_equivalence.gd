extends GutTest
## M26-11: colours and skill-ups (F-166..F-168), schemes and reagents (F-170/F-171) and Auction House sales keep the offline run on the same
## engine as the game (Q109): 12 h in one block = ticks of 100 ms = blocks of 60 s = 6 h + save/load + 6 h, whole state identical,
## `frac` of the professions included. Real data, no combat: the queue works on its own.

const SEED: int = 2611
const HOUR_MS: int = 3_600_000
const TICK_MS: int = 100


## Forging and hearthcraft at level 44: the plate of level 30 (40/50/60) and the dish of level 30 are yellow, their ingredients too.
func _session() -> GameSession:
	var s: GameSession = autofree(TestFactory.session_no_kit(SEED, TestFactory.real_data()))
	s.disciplines.new_game()
	TestFactory.set_character_level(s, 55)
	TestFactory.make_roomy(s)
	s.wallet.add_gold(200_000_000)
	for id: StringName in [&"forging", &"hearthcraft"]:
		TestFactory.learn_discipline(s, id)
	TestFactory.set_level(s, &"forging", 44)
	TestFactory.set_level(s, &"hearthcraft", 44)
	# Purchases: schemes and reagents (F-170, F-171), then a sale at the Auction House.
	_ok(s.shop.buy(&"buy_recipe_forge_duskcobalt_plate"))
	_ok(s.shop.buy(&"buy_recipe_cook_dusk_eel"))
	_ok(s.disciplines.learn_recipe(&"recipe_forge_duskcobalt_plate"))
	_ok(s.disciplines.learn_recipe(&"recipe_cook_dusk_eel"))
	_ok(s.shop.buy_many(&"buy_reagent_forging_2", 6000))
	_ok(s.shop.buy_many(&"buy_reagent_hearthcraft_2", 5000))
	TestFactory.give(s, &"duskcobalt_ingot", 12000)
	TestFactory.give(s, &"duskcobalt_ore", 40000)
	TestFactory.give(s, &"dusk_eel", 5000)
	_build_auction(s)
	TestFactory.give(s, &"ashlead_plate", 50)
	_ok(s.auction.sell(&"ashlead_plate", 50))
	_ok(s.actions.enqueue(&"forging", &"forge_duskcobalt_plate", 5000, false))
	_ok(s.actions.enqueue(&"hearthcraft", &"cook_dusk_eel", 4000, false))
	_ok(s.actions.enqueue(&"forging", &"smelt_duskcobalt", 1, true))
	return s


func _ok(r: CommandResult) -> void:
	assert_true(r.ok, "command failed: %s" % [r.reason])


func _state(s: GameSession) -> Dictionary:
	var d: Dictionary = s.to_save(0)
	d.erase("play_time_ms")
	return d


func _assert_same(a: GameSession, b: GameSession, what: String) -> void:
	var left: Dictionary = _state(a)
	var right: Dictionary = _state(b)
	var modules_a: Dictionary = left["modules"]
	var modules_b: Dictionary = right["modules"]
	for module: Variant in modules_a:
		assert_eq(modules_b.get(module), modules_a[module], "%s: module %s" % [what, module])
	assert_eq(right["rng"], left["rng"], "%s: the rng" % what)


func test_twelve_hours_with_colours_queue_and_purchases_are_the_same_in_a_block_ticks_and_blocks() -> void:
	var one: GameSession = _session()
	var ticks: GameSession = _session()
	var blocks: GameSession = _session()
	var twelve: int = 12 * HOUR_MS
	var xp_before: int = one.skills.get_xp(&"forging")
	one.advance(twelve)
	for _i: int in twelve / TICK_MS:
		ticks.advance(TICK_MS)
	for _i: int in twelve / 60_000:
		blocks.advance(60_000)
	assert_gt(one.skills.get_xp(&"forging"), xp_before, "the yellow queue gives xp")
	assert_gt(one.skills.get_xp(&"hearthcraft"), 0, "the dishes give xp")
	assert_gt(one.professions.frac(&"forging") + one.professions.frac(&"hearthcraft"), -1, "the fraction is readable")
	_assert_same(one, ticks, "12 h block vs ticks")
	_assert_same(one, blocks, "12 h block vs blocks")


func test_six_hours_save_and_load_six_hours_equals_twelve_straight() -> void:
	var straight: GameSession = _session()
	var half: GameSession = _session()
	straight.advance(12 * HOUR_MS)
	half.advance(6 * HOUR_MS)
	var loaded: GameSession = autofree(TestFactory.session_no_kit(SEED + 1, TestFactory.real_data()))
	assert_true(loaded.from_save(SaveCodec.decode(SaveCodec.encode(half.to_save(0)))).ok)
	_assert_same(half, loaded, "right after the load")
	loaded.advance(6 * HOUR_MS)
	_assert_same(straight, loaded, "straight vs save-reload")


func _build_auction(s: GameSession) -> void:
	var cost: Dictionary = s.village.next_cost(&"auction_house")
	for row: Dictionary in cost["items"] as Array:
		TestFactory.give(s, row["item"] as StringName, int(row["qty"]))
	_ok(s.village.upgrade(&"auction_house"))
