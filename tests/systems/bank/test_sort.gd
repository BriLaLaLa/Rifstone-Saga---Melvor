extends GutTest
## Bank.sort (M14-06, docs/05_INTERFACES.md §5.24): category, then sort_order, then id; `sort_stacks` is the same command.

var _session: GameSession


func before_each() -> void:
	_session = TestFactory.session(1234, TestFactory.real_data())
	for item_id: StringName in [&"rift_shard", &"redbirch_log", &"seared_brookfin", &"rift_dust"]:
		if _session.data.has_item(item_id):
			TestFactory.give(_session, item_id, 3)


func after_each() -> void:
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func _ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for stack: Dictionary in _session.bank.stacks():
		result.append(stack["item"])
	return result


func test_sort_puts_stacks_in_category_sort_order_and_id_order() -> void:
	_session.bank.sort()
	var ids: Array[StringName] = _ids()
	for index: int in range(1, ids.size()):
		var a: ItemDef = _session.data.item(ids[index - 1])
		var b: ItemDef = _session.data.item(ids[index])
		var cat_a: int = Bank.SORT_CATEGORIES.find(a.category)
		var cat_b: int = Bank.SORT_CATEGORIES.find(b.category)
		var ordered: bool = cat_a < cat_b or (cat_a == cat_b and (a.sort_order < b.sort_order \
				or (a.sort_order == b.sort_order and String(a.id) <= String(b.id))))
		assert_true(ordered, "%s before %s" % [a.id, b.id])


func test_sort_stacks_is_the_same_command() -> void:
	_session.bank.sort()
	var first: Array[StringName] = _ids()
	_session.bank.move_stack(first[first.size() - 1], 0)
	_session.bank.sort_stacks()
	assert_eq(_ids(), first)


func test_sort_keeps_the_counts_and_emits_for_the_moved_stacks() -> void:
	var counts: Dictionary = {}
	for stack: Dictionary in _session.bank.stacks():
		counts[stack["item"]] = stack["count"]
	_session.bank.move_stack(_ids()[0], _ids().size() - 1)
	watch_signals(_session.events)
	_session.bank.sort()
	assert_signal_emitted(_session.events, "bank_changed")
	for stack: Dictionary in _session.bank.stacks():
		assert_eq(stack["count"], counts[stack["item"]])
