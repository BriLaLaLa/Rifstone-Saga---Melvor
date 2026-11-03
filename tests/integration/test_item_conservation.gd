extends GutTest
## Integration (Lesson "single source of truth"): items are only created by completed cycles and live in one place.
## Sum of the products of every `action_completed.outputs` (rift_shard included) = final bank - initial bank
## (the initial bank is `start.items` of balance.json); the bank_changed deltas tell the same story.
##
## Randomness (F-06 double, F-07 shard) comes from fixed seeds; a test-only modifier source raises the chances so
## that both rolls actually happen. The bank-full case uses a copy of the real config with `bank.base_slots` = 1,
## written under PreRun.test_dir() (not a save slot) and removed afterwards.

const SEED: int = 424242
const SKILL: StringName = &"forestry"
const T1_ACTION: StringName = &"cut_redbirch"
const T2_ACTION: StringName = &"cut_ashpine"
const T2_LEVEL: int = 10
const SHARD: StringName = &"rift_shard"
const TICK_MS: int = 100
const RUN_MS: int = 600000
const HALF_RUN_MS: int = 300000
const IDLE_MS: int = 60000
const BOOST_SOURCE: StringName = &"test:conservation"
const DOUBLE_CHANCE: float = 35.0
const SHARD_CHANCE: float = 25.0
const SMELT_ACTION: StringName = &"smelt_emberbronze"
const ORE_STACK: int = 40
const SOLD_QTY: int = 7
const PRESERVE_CHANCE: float = 60.0
const BLADE: StringName = &"emberbronze_sword"
const BLADE_2: StringName = &"ashlead_sword"
const BOW: StringName = &"emberbronze_greatsword"
const SHIELD: StringName = &"emberbronze_shield"
const FILLER: StringName = &"redbirch_log"
const CONTENT_ROOT: String = "res://data"
const CONFIG_ROOT: String = "res://data/config"
const PreRun := preload("res://tests/helpers/gut_pre_run.gd")

var _tmp_config: String = PreRun.test_dir("test_item_conservation")
var _session: GameSession = null
var _produced: Dictionary[StringName, int] = {}
var _deltas: Dictionary[StringName, int] = {}
var _cycles: int = 0
var _doubles: int = 0
var _stops: Array[StringName] = []


func before_each() -> void:
	_produced.clear()
	_deltas.clear()
	_cycles = 0
	_doubles = 0
	_stops.clear()


func after_each() -> void:
	if _session != null:
		_session.free()
	_session = null


func after_all() -> void:
	if not DirAccess.dir_exists_absolute(_tmp_config):
		return
	for file_name: String in DirAccess.get_files_at(_tmp_config):
		DirAccess.remove_absolute(_tmp_config.path_join(file_name))
	DirAccess.remove_absolute(_tmp_config)


func test_initial_bank_is_start_items() -> void:
	_session = _watched_session(TestFactory.real_data())
	var expected: Dictionary[StringName, int] = {}
	for entry: Variant in _session.data.balance_value("start.items") as Array:
		var d: Dictionary = entry
		var id := StringName(str(d["item"]))
		expected[id] = expected.get(id, 0) + int(d["qty"])
	assert_eq(_bank_counts(_session), expected)


func test_default_chances_products_equal_bank_gain() -> void:
	_session = _watched_session(TestFactory.real_data())
	var start: Dictionary[StringName, int] = _bank_counts(_session)
	_session.actions.start(SKILL, T1_ACTION)
	_advance_in_ticks(_session, RUN_MS)
	assert_eq(_cycles, 200, "600 000 / 3000 (F-03)")
	_assert_conserved(start)


func test_boosted_double_and_shard_products_equal_bank_gain() -> void:
	_session = _watched_session(TestFactory.real_data())
	_boost(_session)
	var start: Dictionary[StringName, int] = _bank_counts(_session)
	_session.actions.start(SKILL, T1_ACTION)
	_advance_in_ticks(_session, RUN_MS)
	assert_gt(_doubles, 0, "doubles happened (F-06)")
	assert_gt(_produced.get(SHARD, 0), 0, "shards happened (F-07)")
	assert_eq(_produced[&"redbirch_log"], _cycles + _doubles, "1 log per cycle, 2 when doubled")
	_assert_conserved(start)


func test_switching_actions_keeps_conservation() -> void:
	_session = _watched_session(TestFactory.real_data())
	_boost(_session)
	var start: Dictionary[StringName, int] = _bank_counts(_session)
	_session.actions.start(SKILL, T1_ACTION)
	_advance_in_ticks(_session, HALF_RUN_MS)
	TestFactory.set_level(_session, SKILL, T2_LEVEL)
	assert_true(_session.actions.start(SKILL, T2_ACTION).ok)
	_advance_in_ticks(_session, HALF_RUN_MS)
	_session.actions.stop()
	_advance_in_ticks(_session, IDLE_MS)
	assert_gt(_produced.get(&"ashpine_log", 0), 0)
	_assert_conserved(start)


func test_bank_full_cycle_adds_nothing() -> void:
	_session = _watched_session(_data_with_slots(1))
	assert_eq(_session.bank.capacity(), 1, "bank.base_slots = 1")
	# A shard needs a second slot: the first cycle that rolls one does not count and stops the lane.
	var mods: Array[Modifier] = [Modifier.make(&"rift_shard_chance", SHARD_CHANCE)]
	_session.modifiers.set_source(BOOST_SOURCE, mods)
	var start: Dictionary[StringName, int] = _bank_counts(_session)
	_session.actions.start(SKILL, T1_ACTION)
	_advance_in_ticks(_session, RUN_MS)
	assert_eq(_stops, [Reasons.BANK_FULL] as Array[StringName], "stopped by the full bank")
	assert_false(_session.actions.is_running())
	assert_eq(_produced.get(SHARD, 0), 0, "the rejected shard is in no outputs")
	assert_eq(_session.bank.get_count(SHARD), 0, "and not in the bank")
	assert_gt(_cycles, 0)
	assert_eq(_session.skills.get_xp(SKILL), _cycles * 10, "XP only for counted cycles (10 per T1 cycle)")
	_assert_conserved(start)


func test_items_are_in_one_place_only() -> void:
	_session = _watched_session(TestFactory.real_data())
	_boost(_session)
	_session.actions.start(SKILL, T1_ACTION)
	_advance_in_ticks(_session, RUN_MS)
	var seen: Dictionary[StringName, bool] = {}
	var stacks: Array = _session.to_save(0)["modules"]["bank"]["stacks"]
	for entry: Dictionary in stacks:
		var id := StringName(str(entry["item"]))
		assert_false(seen.has(id), "%s appears in a single stack" % id)
		seen[id] = true
		assert_eq(int(entry["count"]), _session.bank.get_count(id), "the save is the bank")
	assert_eq(stacks.size(), _session.bank.used())


func test_crafting_products_and_consumed_equal_bank_change() -> void:
	_session = _watched_session(TestFactory.real_data())
	var smelt: ActionDef = _session.data.action(SMELT_ACTION)
	var ore: StringName = smelt.inputs[0].item_id
	var ingot: StringName = smelt.outputs[0].item_id
	TestFactory.give(_session, ore, ORE_STACK)
	_deltas.clear()
	var mods: Array[Modifier] = [
		Modifier.make(&"preservation_chance", PRESERVE_CHANCE),
		Modifier.make(&"double_item_chance", DOUBLE_CHANCE),
	]
	_session.modifiers.set_source(BOOST_SOURCE, mods)
	var start: Dictionary[StringName, int] = _bank_counts(_session)
	assert_true(_session.actions.start(smelt.skill_id, smelt.id).ok)
	_advance_in_ticks(_session, RUN_MS)
	assert_gt(_cycles, 0)
	assert_gt(_doubles, 0, "doubles happened")
	var consumed: int = start[ore] - _session.bank.get_count(ore)
	assert_eq(consumed % smelt.inputs[0].qty, 0, "ingredients leave in whole recipes")
	assert_lt(consumed, _cycles * smelt.inputs[0].qty, "some cycles were preserved (F-08)")
	assert_eq(_session.bank.get_count(ingot), _produced[ingot], "products = ingots in the bank")
	assert_eq(_deltas.get(ore, 0), -consumed, "bank_changed tells the same story for the ingredient")
	assert_eq(_deltas.get(ingot, 0), _produced[ingot], "and for the product")
	assert_false(_produced.has(SHARD), "no shard from crafting (GDD 5)")


func test_selling_conserves_items_and_gold() -> void:
	_session = _watched_session(TestFactory.real_data())
	var ore: StringName = _session.data.action(SMELT_ACTION).inputs[0].item_id
	TestFactory.give(_session, ore, ORE_STACK)
	_deltas.clear()
	var gold: int = _session.wallet.get_gold()
	assert_false(_session.shop.sell(ore, ORE_STACK + 1).ok, "more than owned is refused")
	assert_eq(_session.bank.get_count(ore), ORE_STACK, "refusal changes nothing")
	var value: int = _session.shop.sell_value(ore, SOLD_QTY)
	assert_true(_session.shop.sell(ore, SOLD_QTY).ok)
	assert_eq(_session.bank.get_count(ore), ORE_STACK - SOLD_QTY)
	assert_eq(_session.wallet.get_gold(), gold + value, "gold = sell_value (F-18)")
	assert_eq(_deltas.get(ore, 0), -SOLD_QTY, "bank_changed delta of the sale")
	_session.bank.set_locked(ore, true)
	assert_eq(_session.shop.sell(ore, 1).reason, Reasons.ITEM_LOCKED)
	assert_eq(_session.bank.get_count(ore), ORE_STACK - SOLD_QTY, "a locked stack is untouched")


func test_selling_ingredients_mid_cycle_stops_without_xp_or_products() -> void:
	_session = _watched_session(TestFactory.real_data())
	var smelt: ActionDef = _session.data.action(SMELT_ACTION)
	var ore: StringName = smelt.inputs[0].item_id
	TestFactory.give(_session, ore, smelt.inputs[0].qty)
	assert_true(_session.actions.start(smelt.skill_id, smelt.id).ok)
	@warning_ignore("integer_division")
	_session.advance(smelt.interval_ms / 2)
	assert_true(_session.shop.sell(ore, smelt.inputs[0].qty).ok)
	_advance_in_ticks(_session, smelt.interval_ms)
	assert_eq(_stops, [Reasons.MISSING_INPUTS] as Array[StringName])
	assert_eq(_cycles, 0)
	assert_eq(_session.skills.get_xp(smelt.skill_id), 0, "no XP")
	assert_eq(_session.bank.used(), 0, "the bank is empty: nothing appeared")


func test_equipping_moves_one_unit_and_each_item_exists_once() -> void:
	pending("M4-06: requisiti character, uid e assetti")
	return
	_session = _watched_session(TestFactory.real_data())
	var all: Array[StringName] = [BLADE, BOW, SHIELD]
	for id: StringName in all:
		TestFactory.give(_session, id, 1)
	assert_true(_session.equipment.equip(SHIELD).ok)
	_assert_once(all)
	assert_true(_session.equipment.equip(BOW).ok, "two-handed weapon")
	assert_eq(_session.equipment.get_item(&"offhand"), &"", "the shield went back")
	assert_eq(_session.bank.get_count(SHIELD), 1)
	_assert_once(all)
	assert_true(_session.equipment.equip(SHIELD).ok, "offhand with a two-handed weapon")
	assert_eq(_session.equipment.get_item(&"weapon"), &"", "the bow went back")
	assert_eq(_session.bank.get_count(BOW), 1)
	_assert_once(all)
	assert_true(_session.equipment.equip(BLADE).ok)
	assert_true(_session.equipment.unequip(&"weapon").ok)
	assert_eq(_session.bank.get_count(BLADE), 1)
	_assert_once(all)
	var saved: Dictionary = _session.to_save(0)["modules"]
	assert_eq((saved["equipment"]["slots"] as Dictionary).size(), 1, "only the shield is worn in the save")


func test_equip_with_full_bank_is_refused_unless_the_worn_unit_was_the_last() -> void:
	pending("M4-06: requisiti character, uid e assetti")
	return
	_session = _watched_session(_data_with_slots(2))
	assert_eq(_session.bank.capacity(), 2)
	TestFactory.give(_session, BLADE, 1)
	assert_true(_session.equipment.equip(BLADE).ok)
	var better: ItemDef = _session.data.item(BLADE_2)
	for skill: StringName in better.equip.requirements:
		TestFactory.set_level(_session, skill, better.equip.requirements[skill])
	TestFactory.give(_session, BLADE_2, 2)
	TestFactory.give(_session, FILLER, 1)
	assert_eq(_session.bank.used(), 2, "bank full")
	var ids: Array[StringName] = [BLADE, BLADE_2, FILLER]
	var before: Dictionary = _world(_session, ids)
	var refused: CommandResult = _session.equipment.equip(BLADE_2)
	assert_eq(refused.reason, Reasons.BANK_FULL, "no room for the replaced piece")
	assert_eq(_world(_session, ids), before, "nothing changed")
	_session.bank.remove(BLADE_2, 1)
	assert_true(_session.equipment.equip(BLADE_2).ok, "its stack was the last unit: its slot is free for the old piece")
	assert_eq(_session.bank.get_count(BLADE), 1)


func test_last_batch_of_ingredients_with_full_bank_frees_its_own_slot() -> void:
	_session = _watched_session(_data_with_slots(2))
	var smelt: ActionDef = _session.data.action(SMELT_ACTION)
	var ore: StringName = smelt.inputs[0].item_id
	var ingot: StringName = smelt.outputs[0].item_id
	TestFactory.give(_session, ore, smelt.inputs[0].qty)
	TestFactory.give(_session, FILLER, 1)
	assert_eq(_session.bank.used(), _session.bank.capacity(), "bank full")
	assert_true(_session.actions.start(smelt.skill_id, smelt.id).ok)
	_session.advance(smelt.interval_ms)
	assert_eq(_cycles, 1, "the ingot takes the slot of the consumed ore (05 5.8)")
	assert_eq(_session.bank.get_count(ore), 0)
	assert_eq(_session.bank.get_count(ingot), smelt.outputs[0].qty)
	assert_eq(_session.bank.used(), 2)
	_session.actions.stop()
	# One ore more than a recipe: the stack survives, the new item has no slot: the cycle does not count.
	_session.free()
	_cycles = 0
	_stops.clear()
	_session = _watched_session(_data_with_slots(2))
	TestFactory.give(_session, ore, smelt.inputs[0].qty + 1)
	TestFactory.give(_session, FILLER, 1)
	var ids: Array[StringName] = [ore, ingot, FILLER]
	var before: Dictionary = _world(_session, ids)
	assert_true(_session.actions.start(smelt.skill_id, smelt.id).ok)
	_session.advance(smelt.interval_ms)
	assert_eq(_cycles, 0)
	assert_eq(_stops, [Reasons.BANK_FULL] as Array[StringName])
	assert_eq(_world(_session, ids), before, "nothing consumed, nothing produced")


func test_save_with_two_handed_weapon_and_offhand_keeps_the_invariants() -> void:
	_session = _watched_session(TestFactory.real_data())
	var saved: Dictionary = _session.to_save(0)
	var slots: Dictionary = (saved["modules"] as Dictionary)["equipment"]["slots"]
	slots["weapon"] = String(BOW)
	slots["offhand"] = String(SHIELD)
	var loaded: GameSession = TestFactory.session(SEED, _session.data)
	assert_true(loaded.from_save(saved).ok, "the edited save loads")
	assert_eq(loaded.equipment.get_item(&"weapon"), BOW, "the two-handed weapon is kept")
	assert_eq(loaded.equipment.get_item(&"offhand"), &"", "the offhand is dropped")
	assert_eq(loaded.bank.get_count(SHIELD), _session.bank.get_count(SHIELD), "the bank is untouched")
	loaded.free()


func _assert_once(ids: Array[StringName]) -> void:
	for id: StringName in ids:
		var worn: int = 0
		for slot: StringName in Equipment.SLOTS:
			if _session.equipment.get_item(slot) == id:
				worn += 1
		assert_eq(_session.bank.get_count(id) + worn, 1, "%s exists exactly once" % id)


# Bank counts of the given items plus every worn slot and the used boxes, comparable with assert_eq.
func _world(session: GameSession, ids: Array[StringName]) -> Dictionary:
	var out: Dictionary = {}
	for id: StringName in ids:
		out[id] = session.bank.get_count(id)
	for slot: StringName in Equipment.SLOTS:
		out["slot:" + String(slot)] = session.equipment.get_item(slot)
	out["used"] = session.bank.used()
	return out


func _assert_conserved(start: Dictionary[StringName, int]) -> void:
	var gain: Dictionary[StringName, int] = {}
	var final: Dictionary[StringName, int] = _bank_counts(_session)
	for id: StringName in final:
		var diff: int = final[id] - start.get(id, 0)
		if diff != 0:
			gain[id] = diff
	for id: StringName in start:
		if not final.has(id):
			gain[id] = -start[id]
	assert_eq(gain, _produced, "bank gain = sum of action_completed outputs")
	assert_eq(_deltas, _produced, "bank_changed deltas = sum of outputs")


func _watched_session(data: GameData) -> GameSession:
	var session: GameSession = TestFactory.session(SEED, data)
	session.events.action_completed.connect(_on_action_completed)
	session.events.bank_changed.connect(_on_bank_changed)
	session.events.action_stopped.connect(_on_action_stopped)
	return session


func _boost(session: GameSession) -> void:
	var mods: Array[Modifier] = [
		Modifier.make(&"double_item_chance", DOUBLE_CHANCE),
		Modifier.make(&"rift_shard_chance", SHARD_CHANCE),
	]
	session.modifiers.set_source(BOOST_SOURCE, mods)


func _bank_counts(session: GameSession) -> Dictionary[StringName, int]:
	var counts: Dictionary[StringName, int] = {}
	for stack: Dictionary in session.bank.stacks():
		counts[stack["item"]] = int(stack["count"])
	return counts


# Real content with a config copy where the bank has `slots` base slots.
func _data_with_slots(slots: int) -> GameData:
	DirAccess.make_dir_recursive_absolute(_tmp_config)
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_ROOT.path_join("balance.json")))
	(balance["bank"] as Dictionary)["base_slots"] = slots
	_write(_tmp_config.path_join("balance.json"), JSON.stringify(balance))
	_write(_tmp_config.path_join("stats.json"), FileAccess.get_file_as_string(CONFIG_ROOT.path_join("stats.json")))
	var data: GameData = GameData.load_from_dirs(CONTENT_ROOT, _tmp_config)
	assert_true(data.is_valid(), "%d-slot data valid: %s" % [slots, ", ".join(data.errors)])
	return data


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _advance_in_ticks(session: GameSession, ms: int) -> void:
	@warning_ignore("integer_division")
	var ticks: int = ms / TICK_MS
	for i: int in ticks:
		session.advance(TICK_MS)


func _on_action_completed(_lane: StringName, _skill_id: StringName, action_id: StringName,
		outputs: Dictionary) -> void:
	_cycles += 1
	var action: ActionDef = _session.data.action(action_id)
	for output: ItemQty in action.outputs:
		if int(outputs.get(output.item_id, 0)) > output.qty:
			_doubles += 1
			break
	for key: Variant in outputs:
		var id := StringName(str(key))
		_produced[id] = _produced.get(id, 0) + int(outputs[key])


func _on_bank_changed(item_id: StringName, _new_count: int, delta: int) -> void:
	if delta != 0:
		_deltas[item_id] = _deltas.get(item_id, 0) + delta


func _on_action_stopped(_lane: StringName, _skill_id: StringName, reason: StringName) -> void:
	_stops.append(reason)
