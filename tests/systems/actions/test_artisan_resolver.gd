extends GutTest
## ArtisanResolver: input check, consumption, preservation (F-08), double product (F-06), bank room, no rift shard.
##
## Fixture: craft_plank (test_craft, 2000 ms, 8 xp, mastery) = 2 test_log -> 1 test_plank. A bank-full case uses a
## copy of res://data/config under user:// with `bank.base_slots` 1 and one test_log at start.

const FIXTURE_ROOT: String = "res://tests/fixtures/data"
const CONFIG_ROOT: String = "res://data/config"
const PreRun := preload("res://tests/helpers/gut_pre_run.gd")
const SKILL: StringName = &"test_craft"
const PLANK: StringName = &"craft_plank"
const LOG_ITEM: StringName = &"test_log"
const PLANK_ITEM: StringName = &"test_plank"
const PRESERVATION: StringName = &"preservation_chance"
const DOUBLE: StringName = &"double_item_chance"
const CYCLES: int = 10000
const BLADE: StringName = &"test_blade"
const RARITY: StringName = &"item_rarity_pct"

var _tmp_config: String = PreRun.test_dir("test_artisan_resolver").path_join("config")
var _small_data: GameData = null
var _session: GameSession = null


func before_all() -> void:
	DirAccess.make_dir_recursive_absolute(_tmp_config)
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_ROOT.path_join("balance.json")))
	(balance["bank"] as Dictionary)["base_slots"] = 1
	(balance["start"] as Dictionary)["items"] = [{"item": String(LOG_ITEM), "qty": 1}]
	_write(_tmp_config.path_join("balance.json"), JSON.stringify(balance))
	_write(_tmp_config.path_join("stats.json"), FileAccess.get_file_as_string(CONFIG_ROOT.path_join("stats.json")))
	_small_data = GameData.load_from_dirs(FIXTURE_ROOT, _tmp_config)


func after_all() -> void:
	for file: String in ["balance.json", "stats.json"]:
		DirAccess.remove_absolute(_tmp_config.path_join(file))
	DirAccess.remove_absolute(_tmp_config)
	DirAccess.remove_absolute(_tmp_config.get_base_dir())


func before_each() -> void:
	_session = autofree(TestFactory.session())


func test_can_start_needs_every_input() -> void:
	assert_eq(ArtisanResolver.can_start(_session, _action()).reason, Reasons.MISSING_INPUTS)
	TestFactory.give(_session, LOG_ITEM, 1)
	assert_false(ArtisanResolver.can_start(_session, _action()).ok)
	TestFactory.give(_session, LOG_ITEM, 1)
	assert_true(ArtisanResolver.can_start(_session, _action()).ok)


func test_resolve_consumes_inputs_and_gives_products_xp_and_mastery() -> void:
	TestFactory.give(_session, LOG_ITEM, 3)
	watch_signals(_session.events)
	var outcome: ActionOutcome = ArtisanResolver.resolve(_session, _action())
	assert_true(outcome.ok)
	assert_eq(outcome.consumed, {LOG_ITEM: 2} as Dictionary[StringName, int])
	assert_eq(outcome.outputs, {PLANK_ITEM: 1} as Dictionary[StringName, int])
	assert_false(outcome.shard)
	assert_eq(outcome.xp, 8)
	assert_eq(outcome.mastery_xp, 2)
	assert_eq(_session.bank.get_count(LOG_ITEM), 1)
	assert_eq(_session.bank.get_count(PLANK_ITEM), 1)
	assert_eq(_session.skills.get_xp(SKILL), 8)
	assert_signal_emitted_with_parameters(_session.events, "xp_gained", [SKILL, 8])


func test_resolve_without_inputs_fails_and_changes_nothing() -> void:
	TestFactory.give(_session, LOG_ITEM, 1)
	watch_signals(_session.events)
	var outcome: ActionOutcome = ArtisanResolver.resolve(_session, _action())
	assert_false(outcome.ok)
	assert_eq(outcome.reason, Reasons.MISSING_INPUTS)
	assert_eq(_session.bank.get_count(LOG_ITEM), 1)
	assert_eq(_session.skills.get_xp(SKILL), 0)
	assert_signal_not_emitted(_session.events, "xp_gained")


## Stat effect (stats.json), F-08: chance 0 always consumes.
func test_preservation_0_always_consumes() -> void:
	TestFactory.give(_session, LOG_ITEM, 200)
	for i: int in 100:
		assert_true(ArtisanResolver.resolve(_session, _action()).ok)
	assert_eq(_session.bank.get_count(LOG_ITEM), 0)


## F-08: a total of 95 is limited to 80; over 10,000 cycles (fixed seed) about 80% do not consume (+-2%).
func test_preservation_cap() -> void:
	_set_mods([Modifier.make(PRESERVATION, 95.0)])
	TestFactory.give(_session, LOG_ITEM, 2)
	var preserved: int = 0
	for i: int in CYCLES:
		var outcome: ActionOutcome = ArtisanResolver.resolve(_session, _action())
		assert_true(outcome.ok)
		if outcome.consumed.is_empty():
			preserved += 1
		else:
			TestFactory.give(_session, LOG_ITEM, 2)
	assert_almost_eq(float(preserved) / CYCLES, 0.8, 0.02)


## F-08 scope: a chance of another skill does not apply, so every cycle consumes.
func test_preservation_applies_to_the_action_context() -> void:
	_set_mods([Modifier.make(PRESERVATION, 100.0, &"skill", &"forestry")])
	TestFactory.give(_session, LOG_ITEM, 200)
	for i: int in 100:
		ArtisanResolver.resolve(_session, _action())
	assert_eq(_session.bank.get_count(LOG_ITEM), 0)


## The same seed replayed outside the resolver (preservation roll first, then the double roll, which consumes
## nothing at chance 0) predicts which cycles keep the inputs; they still give products and xp.
func test_preserved_cycle_keeps_the_inputs() -> void:
	_set_mods([Modifier.make(PRESERVATION, 80.0)])
	var replica: RngService = RngService.new(1234)
	var kept: int = 0
	for i: int in 200:
		var preserve: bool = replica.roll_pct(80.0)
		TestFactory.give(_session, LOG_ITEM, 2)
		var before: int = _session.bank.get_count(LOG_ITEM)
		var outcome: ActionOutcome = ArtisanResolver.resolve(_session, _action())
		assert_true(outcome.ok)
		assert_eq(outcome.consumed.is_empty(), preserve)
		assert_eq(_session.bank.get_count(LOG_ITEM), before if preserve else before - 2)
		assert_eq(outcome.xp, 8)
		kept += 1 if preserve else 0
	assert_gt(kept, 0)
	assert_lt(kept, 200)


## F-06: chance 100 doubles the product; chance 0 never does.
func test_double_item_chance() -> void:
	TestFactory.give(_session, LOG_ITEM, 20)
	for i: int in 5:
		assert_eq(ArtisanResolver.resolve(_session, _action()).outputs[PLANK_ITEM], 1)
	_set_mods([Modifier.make(DOUBLE, 100.0)])
	for i: int in 5:
		assert_eq(ArtisanResolver.resolve(_session, _action()).outputs[PLANK_ITEM], 2)
	assert_eq(_session.bank.get_count(PLANK_ITEM), 15)


## 01_GDD §5: no rift shard even with the stat at 100.
func test_no_rift_shard() -> void:
	_set_mods([Modifier.make(&"rift_shard_chance", 100.0)])
	TestFactory.give(_session, LOG_ITEM, 20)
	for i: int in 10:
		var outcome: ActionOutcome = ArtisanResolver.resolve(_session, _action())
		assert_false(outcome.shard)
		assert_false(outcome.outputs.has(&"rift_shard"))
	assert_eq(_session.bank.get_count(&"rift_shard"), 0)


## No room for the product (the logs remain): nothing changes, no xp, `bank_full`.
func test_bank_full_consumes_nothing() -> void:
	var session: GameSession = autofree(TestFactory.session(1234, _small_data))
	TestFactory.give(session, LOG_ITEM, 2)
	watch_signals(session.events)
	var outcome: ActionOutcome = ArtisanResolver.resolve(session, _action())
	assert_false(outcome.ok)
	assert_eq(outcome.reason, Reasons.BANK_FULL)
	assert_eq(session.bank.get_count(LOG_ITEM), 3)
	assert_eq(session.bank.get_count(PLANK_ITEM), 0)
	assert_eq(session.skills.get_xp(SKILL), 0)
	assert_eq(session.mastery.get_mastery_xp(PLANK), 0)
	assert_signal_not_emitted(session.events, "bank_changed")


## Consuming the last logs frees their slot, which the product takes.
func test_freed_slot_takes_the_product() -> void:
	var session: GameSession = autofree(TestFactory.session(1234, _small_data))
	TestFactory.give(session, LOG_ITEM, 1)
	var outcome: ActionOutcome = ArtisanResolver.resolve(session, _action())
	assert_true(outcome.ok)
	assert_eq(session.bank.get_count(LOG_ITEM), 0)
	assert_eq(session.bank.get_count(PLANK_ITEM), 1)


## Equipment/tool products become Armory instances; the recipe level is their ilvl; nothing goes to the bank.
func test_piece_product_becomes_an_instance() -> void:
	TestFactory.give(_session, LOG_ITEM, 1)
	var outcome: ActionOutcome = ArtisanResolver.resolve(_session, _piece_action())
	assert_true(outcome.ok)
	assert_eq(outcome.outputs, {BLADE: 1})
	assert_eq(_session.bank.get_count(BLADE), 0)
	var all: Array[ItemInstance] = _session.armory.instances()
	assert_eq(all.size(), 1)
	assert_eq(all[0].base_id, BLADE)
	assert_eq(all[0].ilvl, 7)


## F-06: a doubled piece product gives two separate instances.
func test_double_product_gives_two_instances() -> void:
	_set_mods([Modifier.make(DOUBLE, 100.0)])
	TestFactory.give(_session, LOG_ITEM, 1)
	assert_true(ArtisanResolver.resolve(_session, _piece_action()).ok)
	assert_eq(_session.armory.instances().size(), 2)
	assert_ne(_session.armory.instances()[0].uid, _session.armory.instances()[1].uid)


## No Armory room: cycle not counted, nothing consumed, no xp, `armory_full`.
func test_armory_full_consumes_nothing() -> void:
	_fill_armory(_session)
	TestFactory.give(_session, LOG_ITEM, 1)
	var logs: int = _session.bank.get_count(LOG_ITEM)
	var held: int = _session.armory.instances().size()
	var outcome: ActionOutcome = ArtisanResolver.resolve(_session, _piece_action())
	assert_false(outcome.ok)
	assert_eq(outcome.reason, Reasons.ARMORY_FULL)
	assert_eq(_session.bank.get_count(LOG_ITEM), logs)
	assert_eq(_session.armory.instances().size(), held)
	assert_eq(_session.skills.get_xp(SKILL), 0)


## A doubled product needs room for both instances.
func test_double_needs_room_for_both() -> void:
	_set_mods([Modifier.make(DOUBLE, 100.0)])
	_fill_armory(_session)
	var uid: int = _session.armory.instances()[0].uid
	assert_true(_session.armory.remove(uid).ok)
	TestFactory.give(_session, LOG_ITEM, 1)
	var outcome: ActionOutcome = ArtisanResolver.resolve(_session, _piece_action())
	assert_eq(outcome.reason, Reasons.ARMORY_FULL)
	assert_eq(_session.bank.get_count(LOG_ITEM), 1)


## F-83: item_rarity_pct multiplies the chances, so more pieces come out rare (fixed seed, 200 cycles each).
func test_item_rarity_pct_gives_more_rare_pieces() -> void:
	var plain: int = _count_rare(0.0)
	_session.free()
	_session = autofree(TestFactory.session())
	var boosted: int = _count_rare(1000.0)
	assert_gt(boosted, plain)


func _count_rare(rarity_pct: float) -> int:
	_set_mods([Modifier.make(RARITY, rarity_pct)])
	var rare: int = 0
	for i: int in 200:
		TestFactory.give(_session, LOG_ITEM, 1)
		assert_true(ArtisanResolver.resolve(_session, _piece_action()).ok)
		var inst: ItemInstance = _session.armory.instances()[0]
		rare += 1 if inst.rarity == &"rare" else 0
		assert_true(_session.armory.remove(inst.uid).ok)
	return rare



## 05_INTERFACES 5.8: rolls in the order preservation, double, then rarity and affixes of each instance.
func test_roll_order_with_a_fixed_seed() -> void:
	var replica: RngService = RngService.new(1234)
	var chances: Vector2 = ItemRoller.craft_chances(0, 0.0, _session.data)
	for i: int in 30:
		replica.roll_pct(0.0)
		replica.roll_pct(0.0)
		var rarity: StringName = ItemRoller.roll_rarity(chances, replica)
		var expected: ItemInstance = ItemRoller.create(_session.data.item(BLADE), rarity, 7, _session.data, replica)
		TestFactory.give(_session, LOG_ITEM, 1)
		assert_true(ArtisanResolver.resolve(_session, _piece_action()).ok)
		var got: ItemInstance = _session.armory.instances()[i]
		assert_eq(got.rarity, expected.rarity)
		assert_eq(got.affixes.size(), expected.affixes.size())


func _piece_action(qty: int = 1) -> ActionDef:
	var action := ActionDef.new()
	action.id = &"craft_blade"
	action.skill_id = SKILL
	action.level = 7
	action.interval_ms = 2000
	action.xp = 8
	action.mastery = true
	action.inputs = [_qty(LOG_ITEM, 1)]
	action.outputs = [_qty(BLADE, qty)]
	return action


func _qty(item_id: StringName, qty: int) -> ItemQty:
	var entry := ItemQty.new()
	entry.item_id = item_id
	entry.qty = qty
	return entry


func _fill_armory(session: GameSession) -> void:
	while session.armory.can_add(1):
		TestFactory.give_piece(session, BLADE)


func _action() -> ActionDef:
	return _session.data.action(PLANK)


func _set_mods(mods: Array[Modifier]) -> void:
	_session.modifiers.set_source(&"test", mods)


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
