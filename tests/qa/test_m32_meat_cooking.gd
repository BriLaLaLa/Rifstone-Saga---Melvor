extends GutTest
## M32-05: meat as food on a real session (real data, a real new game, fixed seeds): the Cucina is learnable with both artisan slots full,
## a meat recipe cooks raw meat from the Deposit, the starter quest `campfire_meal` completes, claims and pays; every meat has a source
## in the monsters of its area. docs/M32_CIBO.md. The balance numbers (meat against consumption) are tools/sim_meat.gd, not tests.

const Play := preload("res://tests/integration/test_tutorial_playthrough.gd")
const RAW: Array[StringName] = [&"plains_haunch", &"wood_venison", &"upland_game", &"gallery_game", &"marsh_fowl", &"scorpion_pulp",
	&"hound_cut", &"serpent_fillet", &"coral_tentacle", &"leech_pulp"]

var _s: GameSession = null


func after_each() -> void:
	if is_instance_valid(_s):
		_s.free()
	_s = null


func _open(seed_value: int = 3201) -> void:
	_s = Play.new_game_session(seed_value)
	_s.tutorial.from_save({"completed": true, "step": "", "visited": []})


func _fill_artisan_slots() -> void:
	assert_true(_s.disciplines.learn(&"forging").ok, "Fucina")
	assert_true(_s.disciplines.learn(&"woodwright").ok, "Falegnameria")
	assert_eq(_s.disciplines.free_slots(&"artisan"), 0, "both artisan slots are full")


func test_cooking_is_learnable_with_both_artisan_slots_full() -> void:
	_open()
	_fill_artisan_slots()
	assert_true(_s.disciplines.can_learn(&"hearthcraft").ok)
	assert_true(_s.disciplines.learn(&"hearthcraft").ok)
	assert_true(_s.disciplines.is_learned(&"hearthcraft"))
	assert_true(_s.disciplines.is_free_slot(&"hearthcraft"))
	assert_eq(_s.disciplines.free_slots(&"artisan"), 0, "the Cucina does not take a slot")
	assert_false(_s.disciplines.can_learn(&"smithing_unknown").ok, "an unknown id still fails")


func test_meat_recipe_cooks_raw_meat_from_the_deposit() -> void:
	_open()
	_fill_artisan_slots()
	assert_true(_s.disciplines.learn(&"hearthcraft").ok)
	TestFactory.give(_s, &"plains_haunch", 5)
	assert_false(_s.disciplines.knows_recipe(&"cook_plains_haunch") and _s.data.action(&"cook_plains_haunch").discover, "no scheme needed")
	assert_true(_s.actions.enqueue(&"hearthcraft", &"cook_plains_haunch", 3).ok, "a meat recipe needs no discovery")
	var guard: int = 0
	while _s.actions.is_running() and guard < 400:
		_s.advance(500)
		guard += 1
	assert_eq(_s.bank.get_count(&"cooked_plains_haunch"), 3)
	assert_eq(_s.bank.get_count(&"plains_haunch"), 2, "one raw meat per cooking")
	assert_gt(_s.data.item(&"cooked_plains_haunch").food_heal, 0)


func test_every_meat_is_cooked_by_a_recipe_without_discover_and_dropped_by_an_animal() -> void:
	_open()
	for meat: StringName in RAW:
		var cooks: Array[ActionDef] = []
		for def: ActionDef in _s.data.actions_for_skill(&"hearthcraft"):
			if str(def.id).begins_with("cook_") and def.inputs.any(func(i: ItemQty) -> bool: return i.item_id == meat):
				cooks.append(def)
		assert_eq(cooks.size(), 1, "%s: one recipe" % meat)
		if cooks.size() == 1:
			assert_false(cooks[0].discover, "%s: no scheme" % meat)
		var sources: int = 0
		for monster: MonsterDef in _monsters():
			if monster.drops.any(func(d: DropEntry) -> bool: return d.item_id == meat):
				sources += 1
		assert_gt(sources, 0, "%s: dropped by at least one monster" % meat)
	_s.free()
	_s = null


func test_campfire_meal_quest_completes_claims_and_pays() -> void:
	_open()
	_fill_artisan_slots()
	var st: StarterQuests = _s.tutorial.starter
	assert_false(st.is_complete(&"campfire_meal"))
	assert_true(_s.disciplines.learn(&"hearthcraft").ok)
	TestFactory.give(_s, &"plains_haunch", 1)
	assert_true(_s.actions.enqueue(&"hearthcraft", &"cook_plains_haunch", 1).ok)
	var guard: int = 0
	while _s.actions.is_running() and guard < 100:
		_s.advance(500)
		guard += 1
	assert_true(st.is_complete(&"campfire_meal"))
	var before: int = _s.bank.get_count(&"cooked_plains_haunch")
	assert_true(st.claim(&"campfire_meal").ok)
	for message: Dictionary in _s.mail.messages():
		assert_true(_s.mail.collect(int(message["id"])).ok)
	assert_eq(_s.bank.get_count(&"cooked_plains_haunch") - before, 10, "the reward is ten cooked haunches")


func test_the_first_kills_in_area_one_drop_meat_across_seeds() -> void:
	# The meat of area 1 must fall within a reasonable number of kills: 35% x 1-2 from the boar, so 40 kills miss with chance ~ 1e-8.
	for seed_value: int in [3211, 3212, 3213]:
		_open(seed_value)
		_s.combat.start(&"redrock_plains")
		var guard: int = 0
		while _s.combat.loot.items().filter(func(e: Dictionary) -> bool: return e["item"] == &"plains_haunch").is_empty() \
				and _s.bank.get_count(&"plains_haunch") == 0 and guard < 20000:
			_s.advance(500)
			guard += 1
		assert_lt(guard, 20000, "seed %d: a haunch fell" % seed_value)
		_s.free()
		_s = null


func _monsters() -> Array[MonsterDef]:
	var out: Array[MonsterDef] = []
	for area: AreaDef in _s.data.areas():
		for id: StringName in area.monster_ids:
			var m: MonsterDef = _s.data.monster(id)
			if not out.has(m):
				out.append(m)
	return out
