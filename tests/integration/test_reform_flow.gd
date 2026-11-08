extends GutTest
## Integration, reform flow (M4, reworked for M10): blueprint -> craft -> Armory instance (at least magic, with affixes)
## -> equip in the three setups -> save and load identical (slot, uid, affixes); full Armory during crafting; F-91 rarity
## grows with the Forging level and with `item_rarity_pct`.
##
## Real data, fixed seeds, only public APIs (docs/05_INTERFACES.md 5.8b). The full-Armory case uses a copy of the real
## config with `armory.base_slots` = 2 written under PreRun.test_dir() (not a save slot) and removed afterwards.

const SEED: int = 31337
const OTHER_SEED: int = 99
const NOW_MS: int = 1793603600000
const SKILL: StringName = &"forging"
const SWORD: StringName = &"emberbronze_sword"
const GREATSWORD: StringName = &"emberbronze_greatsword"
const SHIELD: StringName = &"emberbronze_shield"
const RARITIES: Array[StringName] = [&"magic", &"rare"]
const CONTENT_ROOT: String = "res://data"
const CONFIG_ROOT: String = "res://data/config"
const RARITY_STAT: StringName = &"item_rarity_pct"
const RARITY_SOURCE: StringName = &"test:rarity"
const SAMPLE_CYCLES: int = 80
const PreRun := preload("res://tests/helpers/gut_pre_run.gd")

var _tmp_config: String = PreRun.test_dir("test_reform_flow")
var _session: GameSession = null
var _extra: Array[GameSession] = []
var _stops: Array[StringName] = []


func before_each() -> void:
	_stops.clear()
	_session = _new_session(TestFactory.real_data())


func after_each() -> void:
	_session.free()
	for extra: GameSession in _extra:
		extra.free()
	_extra.clear()


func after_all() -> void:
	if not DirAccess.dir_exists_absolute(_tmp_config):
		return
	for file_name: String in DirAccess.get_files_at(_tmp_config):
		DirAccess.remove_absolute(_tmp_config.path_join(file_name))
	DirAccess.remove_absolute(_tmp_config)


func test_three_blueprints_create_three_pieces_of_at_least_magic_rarity() -> void:
	for base: StringName in [SWORD, GREATSWORD, SHIELD]:
		_stock(base)
		_craft(base)
	var pieces: Array[ItemInstance] = _session.armory.instances()
	assert_eq(pieces.size(), 3, "one instance per blueprint")
	assert_eq(_bases(pieces), [SWORD, GREATSWORD, SHIELD] as Array[StringName], "insertion order")
	assert_eq([pieces[0].uid, pieces[1].uid, pieces[2].uid], [1, 2, 3], "uids from 1")
	for piece: ItemInstance in pieces:
		assert_true(RARITIES.has(piece.rarity), "%s rarity %s: never common (F-91)" % [piece.base_id, piece.rarity])
		assert_eq(piece.ilvl, 1, "ilvl = level of the grade (grade 1)")
		assert_eq(piece.upgrade, 0)
		assert_false(piece.locked)
		_assert_affix_rules(piece)
	for base: StringName in [SWORD, GREATSWORD, SHIELD]:
		assert_eq(_session.bank.get_count(base), 0, "a piece is never banked")
		assert_eq(_session.bank.get_count(_bp(base)), 0, "the blueprint is consumed")
	assert_eq(_session.bank.used(), 0, "the materials and the rare components were all consumed")
	assert_eq(_stops, [Reasons.BLUEPRINT_DONE, Reasons.BLUEPRINT_DONE, Reasons.BLUEPRINT_DONE] as Array[StringName])
	assert_gt(_session.skills.get_xp(SKILL), 0, "Forging XP earned")


func test_pieces_equip_in_the_three_setups() -> void:
	var pieces: Dictionary = _craft_all()
	assert_true(_session.equipment.equip(pieces[SWORD]).ok)
	assert_eq(_session.equipment.setup(), &"sword")
	assert_true(_session.equipment.equip(pieces[SHIELD]).ok)
	assert_eq(_session.equipment.setup(), &"sword_shield")
	assert_true(_session.equipment.equip(pieces[GREATSWORD]).ok)
	assert_eq(_session.equipment.setup(), &"greatsword")
	assert_eq(_session.equipment.get_uid(&"offhand"), 0, "the shield went back to the Armory")
	assert_false(_session.armory.is_worn(pieces[SHIELD]))
	assert_false(_session.armory.is_worn(pieces[SWORD]))
	assert_true(_session.armory.is_worn(pieces[GREATSWORD]))
	assert_true(_session.modifiers.has_source(&"equipment:weapon"))
	assert_false(_session.modifiers.has_source(&"equipment:offhand"))


func test_save_and_load_are_identical_with_worn_pieces() -> void:
	var pieces: Dictionary = _craft_all()
	assert_true(_session.equipment.equip(pieces[SWORD]).ok)
	assert_true(_session.equipment.equip(pieces[SHIELD]).ok)
	assert_true(_session.armory.set_locked(pieces[GREATSWORD], true).ok)
	_session.slot = 2
	_session.player_name = "Forgiatore"
	var text: String = SaveCodec.encode(_session.to_save(NOW_MS))
	var copy: GameSession = TestFactory.session_no_kit(OTHER_SEED, _session.data)
	_extra.append(copy)
	assert_true(copy.from_save(SaveCodec.decode(text)).ok)
	assert_eq(SaveCodec.encode(copy.to_save(NOW_MS)), text, "byte for byte")
	assert_eq(copy.slot, 2)
	assert_eq(copy.player_name, "Forgiatore")
	var original: Array[ItemInstance] = _session.armory.instances()
	var loaded: Array[ItemInstance] = copy.armory.instances()
	assert_eq(loaded.size(), original.size())
	for index: int in mini(original.size(), loaded.size()):
		assert_eq(loaded[index].to_dict(), original[index].to_dict(), "uid %d: base, rarity, affixes" % original[index].uid)
		assert_eq(copy.armory.is_worn(loaded[index].uid), _session.armory.is_worn(original[index].uid), "worn flag")
	assert_eq(copy.equipment.get_uid(&"weapon"), pieces[SWORD])
	assert_eq(copy.equipment.get_uid(&"offhand"), pieces[SHIELD])
	assert_eq(copy.equipment.setup(), &"sword_shield")
	assert_true(copy.armory.get_instance(pieces[GREATSWORD]).locked, "the lock is kept")
	assert_eq(copy.armory.used(), _session.armory.used())
	for stat: StringName in copy.data.stats.ids():
		assert_eq(copy.modifiers.total(stat), _session.modifiers.total(stat), "%s rebuilt from the worn pieces" % stat)
	assert_eq(copy.armory.create(SWORD, &"common", 1), 4, "next_uid saved: uids are never reused")


func test_full_armory_refuses_the_start_and_waits_at_the_end_without_losing_anything() -> void:
	_session.free()
	_session = _new_session(TestFactory.real_data())
	var room: Array[int] = TestFactory.make_roomy(_session)
	for i: int in 3:
		_stock(SWORD)
	_craft(SWORD)
	_craft(SWORD)
	assert_eq(_session.armory.used(), 2)
	_seal(room, 0)
	assert_false(_session.armory.can_add(1), "the Armory is full")
	var before: Dictionary = _world()
	var refused: CommandResult = _session.actions.start_blueprint(_bp(SWORD))
	assert_eq(refused.reason, Reasons.ARMORY_FULL, "a full Armory refuses the start")
	assert_eq(_world(), before, "nothing consumed by a refused start")
	# one place frees up, the craft starts, the place is taken again before the end: the work waits
	var first: ItemInstance = _session.armory.instances()[0]
	assert_true(_session.armory.remove(first.uid).ok)
	assert_true(_session.actions.start_blueprint(_bp(SWORD)).ok)
	var duration: int = int(_session.actions.blueprint_state()["duration_ms"])
	_seal(room, 1)  # the craft consumed materials: exactly one box is free again
	var filler: int = _session.armory.create(SWORD, &"common", 1)
	assert_gt(filler, 0, "the free place was taken meanwhile")
	_session.advance(duration)
	assert_true(bool(_session.actions.blueprint_state().get("waiting", false)), "the finished work waits for a place")
	assert_true(_session.actions.is_running())
	assert_eq(_session.armory.used(), 2)
	_session.advance(duration)
	assert_true(bool(_session.actions.blueprint_state().get("waiting", false)), "and keeps waiting")
	assert_true(_session.armory.remove(filler).ok)
	_session.advance(100)
	assert_eq(_session.armory.used(), 2, "the piece entered as soon as a place was free")
	assert_false(_session.actions.is_running())
	assert_eq(_stops.back(), Reasons.BLUEPRINT_DONE)


func test_stop_returns_blueprint_and_materials() -> void:
	_stock(SWORD)
	var before: Dictionary = _world()
	assert_true(_session.actions.start_blueprint(_bp(SWORD)).ok)
	assert_ne(_world(), before, "blueprint and materials left the bank at the start")
	_session.advance(60000)
	_session.actions.stop()
	assert_eq(_world(), before, "stop gives everything back")
	assert_eq(_session.armory.instances().size(), 0)


func test_rarity_grows_with_the_forging_level() -> void:
	var low: int = _count_rare(1, 0.0)
	var high: int = _count_rare(99, 0.0)
	assert_gt(high, low, "Forging 99 gives more rare pieces than level 1 (F-91, fixed seed)")
	assert_gt(high, SAMPLE_CYCLES / 3, "p_rare 59.5% at level 99")


func test_item_rarity_pct_raises_the_rarity_through_the_modifiers() -> void:
	var base: int = _count_rare(1, 0.0)
	var boosted: int = _count_rare(1, 500.0)
	assert_gt(boosted, base, "item_rarity_pct +500 gives more rare pieces (F-91)")
	assert_eq(boosted, SAMPLE_CYCLES, "p_rare is clamped to 100: all rare")


func test_item_rarity_pct_is_read_with_the_context_of_the_action() -> void:
	# A modifier scoped to the skill of the action applies, one scoped to another skill does not.
	var ctx: ModifierContext = ModifierContext.for_action(SKILL, &"blueprint_craft")
	_session.modifiers.set_source(RARITY_SOURCE, [Modifier.make(RARITY_STAT, 100.0)] as Array[Modifier])
	assert_eq(_session.modifiers.total(RARITY_STAT, ctx), 100.0, "global modifier reaches the forge")
	var other: Array[Modifier] = [Modifier.make(RARITY_STAT, 100.0, Modifier.SCOPE_SKILL, &"forestry")]
	_session.modifiers.set_source(RARITY_SOURCE, other)
	assert_eq(_session.modifiers.total(RARITY_STAT, ctx), 0.0, "a modifier scoped to forestry does not")


# --- helpers ----------------------------------------------------------------------------------------------------

func _new_session(data: GameData) -> GameSession:
	var session: GameSession = TestFactory.session_no_kit(SEED, data)
	session.events.action_stopped.connect(_on_action_stopped)
	return session


func _bp(base: StringName) -> StringName:
	return StringName("bp_" + String(base))


# One blueprint of `base` and everything its craft needs (plates, handles, rare component).
func _stock(base: StringName) -> void:
	var blueprint: ItemDef = _session.data.item(_bp(base))
	TestFactory.give(_session, blueprint.id, 1)
	for input: ItemQty in BlueprintCraft.inputs(blueprint):
		TestFactory.give(_session, input.item_id, input.qty)


# Starts the blueprint of `base` and lets it finish (the lane stops by itself with blueprint_done).
func _craft(base: StringName) -> void:
	var result: CommandResult = _session.actions.start_blueprint(_bp(base))
	assert_true(result.ok, "start %s: %s" % [base, result.reason])
	_session.advance(int(_session.actions.blueprint_state()["duration_ms"]))


# Crafts a sword, a greatsword and a shield; returns {base: uid}.
func _craft_all() -> Dictionary:
	for base: StringName in [SWORD, GREATSWORD, SHIELD]:
		_stock(base)
		_craft(base)
	var out: Dictionary = {}
	for piece: ItemInstance in _session.armory.instances():
		out[piece.base_id] = piece.uid
	assert_eq(out.size(), 3, "three different pieces")
	return out


func _world() -> Dictionary:
	var out: Dictionary = {"pieces": _session.armory.instances().size()}
	for stack: Dictionary in _session.bank.stacks():
		out[stack["item"]] = stack["count"]
	return out


func _bases(pieces: Array[ItemInstance]) -> Array[StringName]:
	var out: Array[StringName] = []
	for piece: ItemInstance in pieces:
		out.append(piece.base_id)
	return out


func _assert_affix_rules(piece: ItemInstance) -> void:
	var count: int = piece.affixes.size()
	match piece.rarity:
		&"magic":
			assert_between(count, 1, 2, "%s magic has 1-2 affixes" % piece.base_id)
		&"rare":
			assert_between(count, 3, 4, "%s rare has 3-4 affixes" % piece.base_id)
	var seen: Array[StringName] = []
	for roll: AffixRoll in piece.affixes:
		assert_false(seen.has(roll.affix_id), "no repeated affix")
		seen.append(roll.affix_id)
		assert_not_null(_session.data.affix(roll.affix_id), "known affix")
		assert_gte(roll.tier, 1, "tier from 1")


# Crafts SAMPLE_CYCLES swords at the given Forging level with a fresh session and a fixed seed; returns how many are
# rare. The Armory is emptied after each cycle.
func _count_rare(forging_level: int, rarity_pct: float) -> int:
	_session.free()
	_session = _new_session(TestFactory.real_data())
	TestFactory.set_level(_session, SKILL, forging_level)
	if rarity_pct > 0.0:
		_session.modifiers.set_source(RARITY_SOURCE, [Modifier.make(RARITY_STAT, rarity_pct)] as Array[Modifier])
	var rare: int = 0
	for _i: int in SAMPLE_CYCLES:
		_stock(SWORD)
		_craft(SWORD)
		for piece: ItemInstance in _session.armory.instances():
			if piece.rarity == &"rare":
				rare += 1
			assert_true(_session.armory.remove(piece.uid).ok)
	return rare


# Real content with a config copy where the Armory has `slots` base slots.
func _data_with_armory_slots(slots: int) -> GameData:
	DirAccess.make_dir_recursive_absolute(_tmp_config)
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_ROOT.path_join("balance.json")))
	(balance["deposit"] as Dictionary)["base_slots"] = slots
	_write(_tmp_config.path_join("balance.json"), JSON.stringify(balance))
	_write(_tmp_config.path_join("stats.json"), FileAccess.get_file_as_string(CONFIG_ROOT.path_join("stats.json")))
	var data: GameData = GameData.load_from_dirs(CONTENT_ROOT, _tmp_config)
	assert_true(data.is_valid(), "%d-slot data valid: %s" % [slots, ", ".join(data.errors)])
	return data


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _on_action_stopped(_lane: StringName, _skill_id: StringName, reason: StringName) -> void:
	_stops.append(reason)


# Sets the extra room so that exactly `free` boxes of the shared Deposit are free.
func _seal(room: Array[int], free: int) -> void:
	room[0] = 0
	room[0] = _session.deposit.used() - _session.deposit.capacity() + free
