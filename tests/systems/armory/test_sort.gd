extends GutTest
## Armory.sort (M14-06, docs/05_INTERFACES.md §5.24): slot, grade descending, rarity descending, uid. Real data.

var _session: GameSession


func before_each() -> void:
	_session = TestFactory.session(1234, TestFactory.real_data())


func after_each() -> void:
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func _key(inst: ItemInstance) -> Array:
	var equip: EquipInfo = _session.data.item(inst.base_id).equip
	return [Equipment.SLOTS.find(equip.slot), equip.grade, Rarities.ORDER.find(inst.rarity), inst.uid]


func _make_mess() -> void:
	TestFactory.give_piece(_session, &"emberbronze_sword", &"common")
	TestFactory.give_piece(_session, &"emberbronze_helm", &"rare")
	TestFactory.give_piece(_session, &"mw_sword_1", &"masterwork")
	TestFactory.give_piece(_session, &"emberbronze_sword", &"rare")
	TestFactory.give_piece(_session, &"ashlead_sword", &"magic")
	TestFactory.give_piece(_session, &"emberbronze_helm", &"common")


func test_sort_orders_by_slot_then_grade_then_rarity_then_uid() -> void:
	_make_mess()
	_session.armory.sort()
	var list: Array[ItemInstance] = _session.armory.instances()
	assert_gte(list.size(), 6)
	for index: int in range(1, list.size()):
		var a: Array = _key(list[index - 1])
		var b: Array = _key(list[index])
		var ordered: bool = a[0] < b[0] \
				or (a[0] == b[0] and (a[1] > b[1] \
				or (a[1] == b[1] and (a[2] > b[2] or (a[2] == b[2] and a[3] < b[3])))))
		assert_true(ordered, "%s before %s" % [a, b])


func test_sort_changes_nothing_but_the_order() -> void:
	_make_mess()
	var before: Dictionary = {}
	for inst: ItemInstance in _session.armory.instances():
		before[inst.uid] = inst.base_id
	var used: int = _session.armory.used()
	_session.armory.sort()
	assert_eq(_session.armory.used(), used)
	assert_eq(_session.armory.instances().size(), before.size())
	for inst: ItemInstance in _session.armory.instances():
		assert_eq(before[inst.uid], inst.base_id)


func test_sort_emits_a_signal_for_the_pieces_that_moved_and_none_when_sorted() -> void:
	_make_mess()
	var moved: Array[int] = []
	_session.events.armory_changed.connect(func(uid: int, _change: StringName) -> void: moved.append(uid))
	_session.armory.sort()
	assert_gt(moved.size(), 0)
	moved.clear()
	_session.armory.sort()
	assert_eq(moved.size(), 0)


func test_sorting_survives_the_save() -> void:
	_make_mess()
	_session.armory.sort()
	var saved: Dictionary = _session.armory.to_save()
	var uids: Array[int] = []
	for inst: ItemInstance in _session.armory.instances():
		uids.append(inst.uid)
	_session.armory.from_save(saved)
	var again: Array[int] = []
	for inst: ItemInstance in _session.armory.instances():
		again.append(inst.uid)
	assert_eq(again, uids)
