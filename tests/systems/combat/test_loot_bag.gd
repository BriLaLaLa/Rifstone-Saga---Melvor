extends GutTest
## LootBag: F-33 capacity, auto loot, collect all, loss on death, save. Real data (many item types).

const A: StringName = &"boar_tusk"
const B: StringName = &"redrock_flint"

var _session: GameSession = null
var _bag: LootBag = null


func before_each() -> void:
	_session = autofree(TestFactory.session(1234, TestFactory.real_data()))
	_bag = LootBag.new(_session)
	watch_signals(_session.events)


func _other_items(count: int) -> Array[StringName]:
	var result: Array[StringName] = []
	for def: ItemDef in _session.data.items():
		if result.size() < count and def.equip == null and def.id != A and def.id != B:
			result.append(def.id)
	return result


func _fill_bank() -> void:
	for def: ItemDef in _session.data.items():
		if def.id != A and def.id != B and _session.bank.can_add(def.id):
			_session.bank.add(def.id, 1)


func test_capacity_uses_loot_bag_slots() -> void:
	assert_eq(_bag.capacity(), 12)
	_session.modifiers.set_source(&"test:bag", [Modifier.make(&"loot_bag_slots", 8.0)] as Array[Modifier])
	assert_eq(_bag.capacity(), 20, "F-33: 12 + 8")


func test_add_stacks_by_type() -> void:
	assert_true(_bag.add(A, 2))
	assert_true(_bag.add(A, 3))
	assert_true(_bag.add(B, 1))
	assert_eq(_bag.items(), [{"item": A, "qty": 5}, {"item": B, "qty": 1}] as Array[Dictionary])
	assert_eq(_bag.used(), 2)
	assert_signal_emitted_with_parameters(_session.events, "loot_bag_changed", [2, 12])


func test_full_bag_loses_new_types_but_stacks_existing() -> void:
	for id: StringName in _other_items(12):
		assert_true(_bag.add(id, 1))
	assert_eq(_bag.used(), 12)
	assert_false(_bag.add(A, 4), "a thirteenth type is lost")
	assert_signal_emitted_with_parameters(_session.events, "loot_lost", [A, 4])
	assert_eq(_bag.used(), 12)
	assert_true(_bag.add(_other_items(1)[0], 5), "an existing type still stacks")


func test_auto_loot_to_bank() -> void:
	_session.modifiers.set_source(&"test:auto", [Modifier.make(&"auto_loot", 1.0)] as Array[Modifier])
	assert_true(_bag.add(A, 2))
	assert_eq(_session.bank.get_count(A), 2)
	assert_eq(_bag.used(), 0)


func test_auto_loot_with_full_bank_goes_to_the_bag() -> void:
	_fill_bank()
	_session.modifiers.set_source(&"test:auto", [Modifier.make(&"auto_loot", 1.0)] as Array[Modifier])
	assert_true(_bag.add(A, 2))
	assert_eq(_session.bank.get_count(A), 0)
	assert_eq(_bag.items(), [{"item": A, "qty": 2}] as Array[Dictionary])


func test_collect_all() -> void:
	_bag.add(A, 2)
	_bag.add(B, 3)
	assert_true(_bag.collect_all().ok)
	assert_eq([_session.bank.get_count(A), _session.bank.get_count(B)], [2, 3])
	assert_eq(_bag.used(), 0)


func test_collect_all_keeps_what_does_not_fit() -> void:
	TestFactory.give(_session, A, 1)
	_fill_bank()
	_bag.add(A, 2)
	_bag.add(B, 3)
	var result: CommandResult = _bag.collect_all()
	assert_false(result.ok)
	assert_eq(result.reason, Reasons.BANK_FULL)
	assert_eq(_session.bank.get_count(A), 3, "an existing stack still accepts")
	assert_eq(_bag.items(), [{"item": B, "qty": 3}] as Array[Dictionary])


func test_lose_all_on_death() -> void:
	_bag.add(A, 2)
	_bag.add(B, 3)
	_bag.lose_all()
	assert_eq(_bag.used(), 0)
	assert_eq(get_signal_parameters(_session.events, "loot_lost", 0), [A, 2])
	assert_eq(get_signal_parameters(_session.events, "loot_lost", 1), [B, 3])
	assert_eq(_session.bank.get_count(A), 0, "the bank is untouched")


func test_save_round_trip() -> void:
	_bag.add(A, 2)
	_bag.add(B, 3)
	var copy := LootBag.new(_session)
	copy.from_save(JSON.parse_string(JSON.stringify(_bag.to_save())))
	assert_eq(copy.items(), _bag.items())


func test_from_save_is_tolerant() -> void:
	var copy := LootBag.new(_session)
	copy.from_save([{"item": "boar_tusk", "qty": 2.0}, {"item": "nope", "qty": 1}, {"item": "boar_tusk", "qty": 1},
		{"item": "redrock_flint", "qty": -1}, "junk", {"qty": 3}])
	assert_eq(copy.items(), [{"item": A, "qty": 3}] as Array[Dictionary])
