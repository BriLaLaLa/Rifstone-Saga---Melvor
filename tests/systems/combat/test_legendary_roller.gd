extends GutTest
## F-120 sources of the legendaries (docs/05_INTERFACES.md §5.24): `LegendaryRoller` (one `roll_pct` per legendary of a source,
## in the order of the data), the delivery of a boss legendary with the bag of the Fracture (lost with it on a defeat) and a full
## Deposit (`armory_rejected`, the piece is lost, never salvaged). Content: tests/helpers/m14_data.gd, every chance is 100.

const M14Data := preload("res://tests/helpers/m14_data.gd")

var _s: GameSession = null
var _saved_chances: Dictionary[StringName, float] = {}


func after_each() -> void:
	for id: StringName in _saved_chances:
		M14Data.data().item(id).equip.legendary.chance_pct = _saved_chances[id]
	_saved_chances.clear()


# The data is shared by the whole run: a chance changed by a test is put back in after_each.
func _set_chance(id: StringName, pct: float) -> void:
	var info: LegendaryInfo = M14Data.data().item(id).equip.legendary
	_saved_chances[id] = info.chance_pct
	info.chance_pct = pct


func test_chance_100_gives_every_legendary_of_the_source_in_order() -> void:
	var data: GameData = M14Data.data()
	var rolled: Array[StringName] = LegendaryRoller.roll(&"boss", &"boss_grade_2", data, RngService.new(3))
	assert_eq(rolled, [&"fx_leg_pierce", &"fx_leg_cap", &"fx_leg_convert"] as Array[StringName])
	assert_eq(LegendaryRoller.roll(&"monolith", &"test_stone_area", data, RngService.new(3)),
			[&"fx_leg_rod", &"fx_leg_pick"] as Array[StringName])


func test_a_source_without_legendaries_draws_nothing() -> void:
	var data: GameData = M14Data.data()
	var rng := RngService.new(4)
	assert_true(LegendaryRoller.roll(&"boss", &"boss_grade_9", data, rng).is_empty())
	assert_true(LegendaryRoller.roll(&"monolith", &"nobody", data, rng).is_empty())
	assert_eq(rng.randf(), RngService.new(4).randf(), "no draw")


func test_one_roll_pct_per_legendary_in_order() -> void:
	var data: GameData = M14Data.data()
	for id: StringName in [&"fx_leg_pierce", &"fx_leg_cap", &"fx_leg_convert"]:
		_set_chance(id, 40.0)
	var rng := RngService.new(21)
	var replica := RngService.new(21)
	var expected: Array[StringName] = []
	for id: StringName in [&"fx_leg_pierce", &"fx_leg_cap", &"fx_leg_convert"]:
		if replica.roll_pct(40.0):
			expected.append(id)
	assert_eq(LegendaryRoller.roll(&"boss", &"boss_grade_2", data, rng), expected)
	assert_eq(rng.randf(), replica.randf(), "exactly three draws")


func test_chance_0_gives_nothing() -> void:
	_set_chance(&"fx_leg_killheal", 0.0)
	_set_chance(&"fx_leg_blockheal", 0.0)
	assert_true(LegendaryRoller.roll(&"boss", &"boss_grade_1", M14Data.data(), RngService.new(5)).is_empty())


func test_the_pieces_are_legendary_without_affixes_at_the_level_of_their_grade() -> void:
	var data: GameData = M14Data.data()
	var pieces: Array[ItemInstance] = LegendaryRoller.drops(&"boss", &"boss_grade_2", data, RngService.new(5))
	assert_eq(pieces.size(), 3)
	for piece: ItemInstance in pieces:
		assert_eq(piece.rarity, &"legendary")
		assert_true(piece.affixes.is_empty(), "a legendary has no affixes")
		assert_eq(piece.uid, 0)
		assert_eq(piece.ilvl, data.grade_level(data.item(piece.base_id).equip.grade))


# --- the Fracture --------------------------------------------------------------------------------------------------

func _fracture_session(seed_value: int = 77) -> GameSession:
	var s: GameSession = autofree(TestFactory.session(seed_value, M14Data.data_with_groups(3)))
	TestFactory.make_roomy(s)
	FractureUtil.hero(s)
	return s


func _owned_bases(s: GameSession) -> Array[StringName]:
	var bases: Array[StringName] = []
	for inst: ItemInstance in s.armory.instances():
		bases.append(inst.base_id)
	return bases


func test_the_boss_victory_delivers_its_legendaries_with_the_bag() -> void:
	_s = _fracture_session()
	var finished: Array = []
	_s.events.fracture_finished.connect(func(o: StringName, g: int, n: int, c: int, p: int) -> void: finished.append([o, g, n, c, p]))
	assert_true(_s.fractures.open(FractureUtil.card(_s, 1)).ok)
	FractureUtil.run_until(_s, func() -> bool: return not _s.combat.in_fracture())
	assert_eq(finished.size(), 1)
	assert_eq(finished[0][0], &"won")
	assert_eq(finished[0][4], 3, "the guaranteed piece of the boss and its two legendaries")
	var owned: Array[StringName] = _owned_bases(_s)
	assert_true(owned.has(&"fx_leg_blockheal") and owned.has(&"fx_leg_killheal"), "delivered to the Armory: %s" % [owned])
	for inst: ItemInstance in _s.armory.instances():
		if inst.base_id == &"fx_leg_killheal":
			assert_eq(inst.rarity, &"legendary")
			assert_true(inst.affixes.is_empty())


func test_a_legendary_in_the_bag_is_lost_with_a_defeat() -> void:
	_s = _fracture_session(8)
	assert_true(_s.fractures.open(FractureUtil.card(_s, 1)).ok)
	var base: ItemDef = _s.data.item(&"fx_leg_killheal")
	_s.fractures.run().bag.add_piece(ItemRoller.create(base, &"legendary", 5, _s.data, _s.rng))
	_s.events.fracture_finished.emit(&"died", 1, 0, 0, 1)
	assert_false(_owned_bases(_s).has(&"fx_leg_killheal"), "nothing is delivered on a defeat")
	assert_false(_s.fractures.has_pending())


func test_the_boss_does_not_roll_legendaries_before_it_is_killed() -> void:
	_s = _fracture_session(9)
	assert_true(_s.fractures.open(FractureUtil.card(_s, 1)).ok)
	assert_false(_s.fractures.run().bag.pieces().any(func(p: ItemInstance) -> bool: return p.rarity == &"legendary"))


# --- a full Deposit ------------------------------------------------------------------------------------------------

func test_a_legendary_dropped_with_a_full_deposit_is_lost_with_a_notification() -> void:
	_s = autofree(LegendaryKit.session(3))
	var fill: Array[int] = [0]
	_s.deposit.register_occupant(&"test:fill", func() -> int: return fill[0])
	fill[0] = _s.deposit.free_slots()
	assert_false(_s.armory.can_add(1))
	watch_signals(_s.events)
	var piece: ItemInstance = ItemRoller.create(_s.data.item(&"fx_leg_cap"), &"legendary", 5, _s.data, _s.rng)
	assert_eq(_s.armory.add_drop(piece), 0)
	assert_signal_emitted_with_parameters(_s.events, "armory_rejected", [&"fx_leg_cap", 1])
	assert_signal_not_emitted(_s.events, "item_salvaged")
	assert_eq(_s.armory.instances().size(), 0)


func test_the_filter_never_salvages_a_legendary() -> void:
	_s = autofree(LegendaryKit.session(3))
	assert_true(_s.armory.set_filter(&"head", &"rare", 15).ok)
	var piece: ItemInstance = ItemRoller.create(_s.data.item(&"fx_leg_cap"), &"legendary", 5, _s.data, _s.rng)
	assert_false(_s.armory.is_filtered(piece))
	assert_gt(_s.armory.add_drop(piece), 0, "kept")
	var plain: ItemInstance = ItemRoller.create(_s.data.item(&"test_helm"), &"common", 1, _s.data, _s.rng)
	assert_true(_s.armory.is_filtered(plain), "the same rule salvages a common helm")
