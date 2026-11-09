extends GutTest
## Integration, acceptance of M10 (docs/07_TASKS.md M10-01..M10-07): new game with the starting kit, combat drop ->
## blueprint -> craft (also saved half way and offline) -> piece -> worn -> combat; the chosen affix from Forging level 50;
## the three unique tools refined +0..+9 (always succeeding, with the level requirements); F-95 dismantling; no word
## "Bank" in the visible texts. Real data, fixed seeds, public APIs only (docs/05_INTERFACES.md 5.8b, 5.17).

const SEED: int = 1010
const AREA: StringName = &"redrock_plains"
const SWORD: StringName = &"mw_sword_1"  # M14-05: the blueprint crafts a Masterwork
const BLUEPRINT: StringName = &"bp_mw_sword_1"
const PLATE: StringName = &"emberbronze_plate"
const SHARD: StringName = &"rift_shard"
const FORGING: StringName = &"forging"
const HERO: StringName = &"test:hero"
const NOW_MS: int = 1793600000000
# F-94: the nine steps (docs/02_FORMULAS.md).
const MIN_LEVELS: Array[int] = [1, 10, 20, 25, 35, 50, 65, 80, 90]
const GRADES: Array[int] = [1, 2, 3, 3, 4, 5, 6, 7, 8]
const PLATES: Array[int] = [2, 2, 3, 3, 4, 4, 5, 5, 6]
const HANDLES: Array[int] = [1, 1, 1, 1, 2, 2, 2, 2, 3]
const GOLD: Array[int] = [100, 250, 600, 1200, 2500, 5000, 10000, 20000, 40000]
# tool slot -> [skill, extra stat, total at +5, total at +9]
const TOOLS: Dictionary[StringName, Array] = {
	&"tool_forestry": [&"forestry", &"double_item_chance", 2.0, 5.0],
	&"tool_quarrying": [&"quarrying", &"double_item_chance", 2.0, 5.0],
	&"tool_angling": [&"angling", &"rift_shard_chance", 10.0, 25.0],
}

var _session: GameSession = null
var _extra: Array[GameSession] = []


func before_each() -> void:
	_session = autofree(TestFactory.session(SEED, TestFactory.real_data()))


func after_each() -> void:
	for session: GameSession in _extra:
		session.free()
	_extra.clear()


# --- new game ---------------------------------------------------------------------------------------------------

func test_a_new_game_has_the_kit_the_field_rations_and_the_combat_hint() -> void:
	var s: GameSession = _session
	assert_eq(s.armory.instances().size(), 6, "three pieces and the three unique tools")
	assert_eq(s.equipment.setup(), &"sword_shield", "the kit sword and shield are worn")
	assert_eq(s.armory.used(), 1, "only the spare greatsword takes a place")
	for slot: StringName in TOOLS:
		var uid: int = s.armory.tool_uid(slot)
		assert_gt(uid, 0, "%s has its unique tool" % slot)
		assert_eq(s.armory.get_instance(uid).upgrade, 0)
		assert_true(s.armory.is_worn(uid))
	assert_eq(s.shop.purchase_count(&"auto_eat_1"), 1, "Razioni da campo I owned from the start")
	assert_eq(s.data.shop_entry(&"auto_eat_1").name, "Razioni da campo I")
	assert_eq(s.equipment.get_food(), StringName(str(s.data.balance_value("start.food"))), "the kit food is chosen")
	assert_gt(s.bank.get_count(s.equipment.get_food()), 0)
	s.events.session_started.emit(1, true)
	assert_true(s.hints.pending().has(&"first_action"))
	assert_true(s.data.hint(&"first_action").text.contains("Combattimento"), "the first hint points to combat (B4)")


func test_unique_tools_cannot_be_sold_dismantled_locked_or_taken_off() -> void:
	var gold: int = _session.wallet.get_gold()
	for slot: StringName in TOOLS:
		var uid: int = _session.armory.tool_uid(slot)
		assert_eq(_session.equipment.unequip(slot).reason, Reasons.ITEM_UNIQUE)
		assert_eq(_session.shop.sell_instance(uid).reason, Reasons.ITEM_UNIQUE)
		assert_eq(_session.armory.salvage(uid).reason, Reasons.ITEM_UNIQUE)
		assert_eq(_session.armory.get_instance(uid).base_id, StringName("unique_" + String(TOOLS[slot][0]).replace("forestry", "hatchet").replace("quarrying", "pick").replace("angling", "rod")))
	assert_eq(_session.wallet.get_gold(), gold)
	assert_eq(_session.armory.instances().size(), 6)


# --- unique tools +0..+9 ----------------------------------------------------------------------------------------

func test_each_unique_tool_refines_from_zero_to_nine_always_succeeding() -> void:
	for slot: StringName in TOOLS:
		_refine_to_nine(slot)


func _refine_to_nine(slot: StringName) -> void:
	var skill: StringName = TOOLS[slot][0]
	var extra_stat: StringName = TOOLS[slot][1]
	var uid: int = _session.armory.tool_uid(slot)
	var plate_items: Array = _session.data.balance_value("tool_upgrade.plate_items") as Array
	var handle_items: Array = _session.data.balance_value("tool_upgrade.handle_items") as Array
	var ctx: ModifierContext = ModifierContext.for_skill(skill)
	assert_eq(_session.modifiers.total(&"skill_interval_pct", ctx), -5.0, "%s +0: -5%%" % slot)
	for target: int in range(1, 10):
		var step: Dictionary = _session.armory.tool_next_step(uid)
		assert_eq(int(step["target"]), target)
		assert_eq(int(step["min_level"]), MIN_LEVELS[target - 1], "%s min level to +%d" % [slot, target])
		assert_eq(int(step["grade"]), GRADES[target - 1])
		var plates: ItemQty = step["plates"]
		var handles: ItemQty = step["handles"]
		assert_eq([plates.item_id, plates.qty], [StringName(str(plate_items[GRADES[target - 1] - 1])), PLATES[target - 1]])
		assert_eq([handles.item_id, handles.qty], [StringName(str(handle_items[GRADES[target - 1] - 1])), HANDLES[target - 1]])
		assert_eq(int(step["gold"]), GOLD[target - 1])
		# refusals in order: level, gold, items
		if MIN_LEVELS[target - 1] > 1 and _session.skills.get_level(skill) < MIN_LEVELS[target - 1]:
			_session.wallet.add_gold(GOLD[target - 1])
			TestFactory.give(_session, plates.item_id, plates.qty)
			TestFactory.give(_session, handles.item_id, handles.qty)
			assert_eq(_session.armory.upgrade_tool(uid).reason, Reasons.LEVEL_TOO_LOW, "+%d needs %s %d" % [target, skill, MIN_LEVELS[target - 1]])
			TestFactory.set_level(_session, skill, MIN_LEVELS[target - 1])
		else:
			_session.wallet.add_gold(GOLD[target - 1])
			TestFactory.give(_session, plates.item_id, plates.qty)
			TestFactory.give(_session, handles.item_id, handles.qty)
		var gold: int = _session.wallet.get_gold()
		var rng_before: Dictionary = _session.rng.to_save()
		var result: CommandResult = _session.armory.upgrade_tool(uid)
		assert_true(result.ok, "%s +%d: %s" % [slot, target, result.reason])
		assert_eq(_session.rng.to_save(), rng_before, "no roll: the refinement always succeeds")
		assert_eq(_session.armory.get_instance(uid).upgrade, target)
		assert_eq(_session.wallet.get_gold(), gold - GOLD[target - 1])
		assert_eq(_session.bank.get_count(plates.item_id), 0, "the plates were spent")
		assert_eq(_session.bank.get_count(handles.item_id), 0, "the handles were spent")
		assert_eq(_session.modifiers.total(&"skill_interval_pct", ctx), -float(5 + 2 * target), "%s +%d" % [slot, target])
		if target == 5:
			assert_eq(_session.modifiers.total(extra_stat, ctx), float(TOOLS[slot][2]), "%s extra at +5" % slot)
		if target == 9:
			assert_eq(_session.modifiers.total(extra_stat, ctx), float(TOOLS[slot][3]), "%s extra at +9" % slot)
	assert_eq(_session.armory.upgrade_tool(uid).reason, Reasons.UPGRADE_MAX)
	assert_true(_session.armory.tool_next_step(uid).is_empty(), "no step after +9")
	assert_eq(_session.armory.get_instance(uid).upgrade, 9, "never lowered")


func test_a_piece_is_not_a_tool_and_the_refinement_needs_gold_and_items() -> void:
	var sword: int = _session.armory.instances()[0].uid
	assert_eq(_session.armory.upgrade_tool(sword).reason, Reasons.NOT_A_TOOL)
	assert_eq(_session.armory.upgrade_tool(9999).reason, Reasons.UNKNOWN_ID)
	var hatchet: int = _session.armory.tool_uid(&"tool_forestry")
	assert_eq(_session.armory.upgrade_tool(hatchet).reason, Reasons.NOT_ENOUGH_GOLD)
	_session.wallet.add_gold(100)
	assert_eq(_session.armory.upgrade_tool(hatchet).reason, Reasons.NOT_ENOUGH_ITEMS)
	assert_eq(_session.armory.get_instance(hatchet).upgrade, 0)


# --- combat drop -> blueprint -> piece -> worn -> combat --------------------------------------------------------

func test_drop_blueprint_then_craft_wear_and_fight_with_the_new_piece() -> void:
	var data: GameData = GameData.load_from_dirs(TestFactory.REAL_CONTENT_ROOT, TestFactory.CONFIG_ROOT)
	for monster_id: StringName in data.area(AREA).monster_ids:
		var entry := DropEntry.new()
		entry.item_id = BLUEPRINT
		entry.chance_pct = 100.0
		entry.qty_min = 1
		entry.qty_max = 1
		data.monster(monster_id).drops = [entry] as Array[DropEntry]
	var s: GameSession = autofree(TestFactory.session_no_kit(SEED, data))
	s.modifiers.set_source(HERO, [Modifier.make(&"power_bonus", 5000.0), Modifier.make(&"max_hp_flat", 100000.0)])
	var kills: Array[int] = [0]
	s.events.monster_killed.connect(func(_i: int, _m: StringName) -> void: kills[0] += 1)
	assert_true(s.combat.start(AREA).ok)
	var guard: int = 0
	while kills[0] < 3 and guard < 20000:
		s.advance(500)
		guard += 1
	s.combat.stop()
	assert_eq(s.armory.instances().size(), 0, "a blueprint is never a piece")
	assert_true(s.combat.loot.collect_all().ok)
	var dropped: int = s.bank.get_count(BLUEPRINT)
	assert_gte(dropped, 3, "one blueprint per kill (certain in this copy), none lost")
	# the unarmed fight, then the craft of the piece
	assert_true(s.combat.start(AREA).ok)
	var unarmed: int = s.combat.player_stats().max_hit
	s.combat.stop()
	var blueprint: ItemDef = data.item(BLUEPRINT)
	for input: ItemQty in BlueprintCraft.inputs(blueprint):
		TestFactory.give(s, input.item_id, input.qty)
	var bank_before: int = s.bank.get_count(BLUEPRINT)
	assert_true(s.actions.start_blueprint(BLUEPRINT).ok)
	assert_eq(s.bank.get_count(BLUEPRINT), bank_before - 1, "exactly one blueprint is consumed")
	var done: Array[int] = []
	s.events.blueprint_crafted.connect(func(_id: StringName, uid: int) -> void: done.append(uid))
	s.advance(int(s.actions.blueprint_state()["duration_ms"]))
	assert_eq(done.size(), 1, "blueprint_crafted once")
	var piece: ItemInstance = s.armory.get_instance(done[0])
	assert_eq(piece.base_id, SWORD)
	assert_ne(piece.rarity, &"common")
	assert_true(s.equipment.equip(piece.uid).ok)
	assert_true(s.combat.start(AREA).ok)
	assert_gt(s.combat.player_stats().max_hit, unarmed, "the worn sword raises the damage in combat")


# --- chosen affix (F-92) ----------------------------------------------------------------------------------------

func test_the_chosen_affix_needs_forging_level_50_and_comes_first() -> void:
	var s: GameSession = autofree(TestFactory.session_no_kit(SEED, TestFactory.real_data()))
	var blueprint: ItemDef = s.data.item(BLUEPRINT)
	var candidates: Array[AffixDef] = ItemRoller.chosen_affix_candidates(s.data.item(SWORD), 1, s.data)
	assert_gt(candidates.size(), 0, "a sword has candidate affixes")
	var chosen: StringName = candidates[0].id
	TestFactory.give(s, BLUEPRINT, 1)
	for input: ItemQty in BlueprintCraft.inputs(blueprint):
		TestFactory.give(s, input.item_id, input.qty)
	TestFactory.set_level(s, FORGING, 49)
	assert_eq(s.actions.start_blueprint(BLUEPRINT, chosen).reason, Reasons.INVALID_CHOICE, "level 49: refused")
	assert_eq(s.bank.get_count(BLUEPRINT), 1, "and nothing consumed")
	TestFactory.set_level(s, FORGING, 50)
	assert_true(s.actions.start_blueprint(BLUEPRINT, chosen).ok, "level 50: accepted")
	s.advance(int(s.actions.blueprint_state()["duration_ms"]))
	var piece: ItemInstance = s.armory.instances()[0]
	assert_eq(piece.affixes[0].affix_id, chosen, "the chosen affix is the first")


# --- save and offline -------------------------------------------------------------------------------------------

func test_a_craft_saved_half_way_resumes_and_finishes() -> void:
	var s: GameSession = autofree(TestFactory.session_no_kit(SEED, TestFactory.real_data()))
	TestFactory.give(s, BLUEPRINT, 1)
	for input: ItemQty in BlueprintCraft.inputs(s.data.item(BLUEPRINT)):
		TestFactory.give(s, input.item_id, input.qty)
	assert_true(s.actions.start_blueprint(BLUEPRINT).ok)
	var duration: int = int(s.actions.blueprint_state()["duration_ms"])
	s.advance(duration / 2)
	var saved: Dictionary = s.to_save(NOW_MS)
	var copy: GameSession = TestFactory.session_no_kit(SEED + 1, s.data)
	_extra.append(copy)
	assert_true(copy.from_save(SaveCodec.decode(SaveCodec.encode(saved))).ok)
	var state: Dictionary = copy.actions.blueprint_state()
	assert_eq(state["blueprint"], BLUEPRINT)
	assert_eq(int(state["elapsed_ms"]), duration / 2)
	assert_eq(copy.armory.instances().size(), 0, "not yet")
	copy.advance(duration - duration / 2)
	assert_eq(copy.armory.instances().size(), 1, "finished after the rest of the time")
	assert_eq(copy.bank.get_count(BLUEPRINT), 0)


func test_a_craft_finishes_offline() -> void:
	var s: GameSession = autofree(TestFactory.session_no_kit(SEED, TestFactory.real_data()))
	TestFactory.give(s, BLUEPRINT, 1)
	for input: ItemQty in BlueprintCraft.inputs(s.data.item(BLUEPRINT)):
		TestFactory.give(s, input.item_id, input.qty)
	assert_true(s.actions.start_blueprint(BLUEPRINT).ok)
	var duration: int = int(s.actions.blueprint_state()["duration_ms"])
	await OfflineSimulator.new().run(s, duration + 60000, false, false)
	assert_eq(s.armory.instances().size(), 1, "the offline time made the piece")
	assert_false(s.actions.is_running())
	assert_gt(s.skills.get_xp(FORGING), 0)


# --- dismantling (F-95) -----------------------------------------------------------------------------------------

func test_dismantling_a_crafted_piece_returns_plates_and_shards_and_nothing_else() -> void:
	var s: GameSession = autofree(TestFactory.session_no_kit(SEED, TestFactory.real_data()))
	TestFactory.give(s, BLUEPRINT, 1)
	for input: ItemQty in BlueprintCraft.inputs(s.data.item(BLUEPRINT)):
		TestFactory.give(s, input.item_id, input.qty)
	assert_true(s.actions.start_blueprint(BLUEPRINT).ok)
	s.advance(int(s.actions.blueprint_state()["duration_ms"]))
	var piece: ItemInstance = s.armory.instances()[0]
	var shards: int = 3  # Masterwork: shards_by_rarity.masterwork
	assert_true(s.armory.salvage(piece.uid).ok)
	assert_false(s.armory.has(piece.uid), "gone for good")
	assert_eq(s.bank.get_count(PLATE), 7, "floor(18 x 0.4) plates: the cost of a Masterwork blueprint is x3")
	assert_eq(s.bank.get_count(&"redbirch_grip"), 2, "floor(6 x 0.4) grips")
	assert_eq(s.bank.get_count(&"boar_tusk"), 0, "the rare component is never returned")
	assert_eq(s.bank.get_count(SHARD), shards, "shards by rarity")


# --- texts ------------------------------------------------------------------------------------------------------

func test_no_visible_text_says_bank() -> void:
	var hits: Array[String] = []
	var quoted: RegEx = RegEx.create_from_string("\"[^\"\\n]*\\bBank\\b[^\"\\n]*\"")
	for path: String in _files("res://ui", ["gd", "tscn"]):
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			if not line.strip_edges().begins_with("#") and quoted.search(line) != null:
				hits.append("%s: %s" % [path, line.strip_edges()])
	var json_text: RegEx = RegEx.create_from_string("\"(name|description|title|text)\"\\s*:\\s*\"[^\"]*\\bBank\\b")
	for path: String in _files("res://data", ["json"]):
		if json_text.search(FileAccess.get_file_as_string(path)) != null:
			hits.append(path)
	assert_eq(hits, [] as Array[String], "the visible word is Deposito")


func _files(root: String, extensions: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for dir: String in DirAccess.get_directories_at(root):
		out.append_array(_files(root.path_join(dir), extensions))
	for file: String in DirAccess.get_files_at(root):
		if extensions.has(file.get_extension()):
			out.append(root.path_join(file))
	return out
