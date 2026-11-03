extends GutTest
## Integration, reform flow (M4): forge a sword, a shield and a greatsword with different mastery -> Armory instances
## with rarity and affixes -> equip in the three setups -> save and load identical (slot, uid, affixes); full Armory
## during crafting; F-83 rarity grows with mastery and with `item_rarity_pct`.
##
## Real data, fixed seeds, only public APIs. The full-Armory case uses a copy of the real config with
## `armory.base_slots` = 2 written under PreRun.test_dir() (not a save slot) and removed afterwards.

const SEED: int = 31337
const OTHER_SEED: int = 99
const NOW_MS: int = 1793603600000
const SKILL: StringName = &"forging"
const FORGE_SWORD: StringName = &"forge_emberbronze_sword"
const FORGE_GREAT: StringName = &"forge_emberbronze_greatsword"
const FORGE_SHIELD: StringName = &"forge_emberbronze_shield"
const SWORD: StringName = &"emberbronze_sword"
const GREATSWORD: StringName = &"emberbronze_greatsword"
const SHIELD: StringName = &"emberbronze_shield"
const INGOT: StringName = &"emberbronze_ingot"
const GRIP: StringName = &"redbirch_grip"
const SHIELDCORE: StringName = &"redbirch_shieldcore"
const RARITIES: Array[StringName] = [&"common", &"magic", &"rare"]
const CONTENT_ROOT: String = "res://data"
const CONFIG_ROOT: String = "res://data/config"
const RARITY_STAT: StringName = &"item_rarity_pct"
const RARITY_SOURCE: StringName = &"test:rarity"
const SAMPLE_CYCLES: int = 60
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


func test_forging_three_pieces_with_different_mastery_creates_instances() -> void:
	_stock(5)
	var levels: Dictionary = {FORGE_SWORD: 1, FORGE_GREAT: 40, FORGE_SHIELD: 99}
	_set_mastery(levels)
	for action_id: StringName in levels:
		assert_eq(_session.mastery.get_mastery_level(action_id), levels[action_id], "mastery of %s" % action_id)
	var ingots: int = _session.bank.get_count(INGOT)
	_forge(FORGE_SWORD)
	_forge(FORGE_GREAT)
	_forge(FORGE_SHIELD)
	var pieces: Array[ItemInstance] = _session.armory.instances()
	assert_eq(pieces.size(), 3, "one instance per cycle")
	assert_eq(_bases(pieces), [SWORD, GREATSWORD, SHIELD] as Array[StringName], "insertion order")
	assert_eq([pieces[0].uid, pieces[1].uid, pieces[2].uid], [1, 2, 3], "uids from 1")
	for piece: ItemInstance in pieces:
		assert_true(RARITIES.has(piece.rarity), "%s rarity %s" % [piece.base_id, piece.rarity])
		assert_eq(piece.ilvl, _session.data.action(FORGE_SWORD).level, "ilvl = recipe level")
		assert_eq(piece.upgrade, 0)
		assert_false(piece.locked)
		_assert_affix_rules(piece)
	assert_eq(_session.bank.get_count(INGOT), ingots - 3 - 5 - 4, "ingots of the three recipes consumed")
	for base: StringName in [SWORD, GREATSWORD, SHIELD]:
		assert_eq(_session.bank.get_count(base), 0, "a piece is never banked")
	assert_eq(_stops.size(), 3, "each lane was stopped by the test")


func test_pieces_equip_in_the_three_setups() -> void:
	var pieces: Dictionary = _forge_all()
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
	var pieces: Dictionary = _forge_all()
	assert_true(_session.equipment.equip(pieces[SWORD]).ok)
	assert_true(_session.equipment.equip(pieces[SHIELD]).ok)
	assert_true(_session.armory.set_locked(pieces[GREATSWORD], true).ok)
	_session.slot = 2
	_session.player_name = "Forgiatore"
	var text: String = SaveCodec.encode(_session.to_save(NOW_MS))
	var copy: GameSession = TestFactory.session(OTHER_SEED, _session.data)
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


func test_full_armory_stops_the_forge_without_consuming_anything() -> void:
	_session.free()
	_session = _new_session(_data_with_armory_slots(2))
	_stock(3)
	_forge(FORGE_SWORD)
	_forge(FORGE_SWORD)
	assert_eq(_session.armory.used(), 2)
	assert_false(_session.armory.can_add(1), "the Armory is full")
	var ingots: int = _session.bank.get_count(INGOT)
	var grips: int = _session.bank.get_count(GRIP)
	var xp: int = _session.skills.get_xp(SKILL)
	var mastery_xp: int = _session.mastery.get_mastery_xp(FORGE_SWORD)
	_stops.clear()
	assert_true(_session.actions.start(SKILL, FORGE_SWORD).ok, "a full Armory does not forbid starting")
	_session.advance(_session.data.action(FORGE_SWORD).interval_ms)
	assert_eq(_stops, [Reasons.ARMORY_FULL] as Array[StringName], "the lane stops with armory_full")
	assert_false(_session.actions.is_running())
	assert_eq(_session.armory.used(), 2)
	assert_eq(_session.armory.instances().size(), 2, "no instance created")
	assert_eq(_session.bank.get_count(INGOT), ingots, "nothing consumed")
	assert_eq(_session.bank.get_count(GRIP), grips)
	assert_eq(_session.skills.get_xp(SKILL), xp, "the cycle did not count")
	assert_eq(_session.mastery.get_mastery_xp(FORGE_SWORD), mastery_xp)
	var first: ItemInstance = _session.armory.instances()[0]
	assert_true(_session.armory.remove(first.uid).ok)
	_forge(FORGE_SWORD)
	assert_eq(_session.armory.used(), 2, "freeing one place lets the forge continue")


func test_rarity_grows_with_mastery() -> void:
	var low: int = _count_non_common(1, 0.0)
	var high: int = _count_non_common(99, 0.0)
	assert_gt(high, low, "mastery 99 gives more magic/rare pieces than mastery 1 (F-83, fixed seed)")
	assert_gt(high, SAMPLE_CYCLES / 4, "about half of the pieces are not common at mastery 99")


func test_item_rarity_pct_raises_the_rarity_through_the_modifiers() -> void:
	var base: int = _count_non_common(1, 0.0)
	var boosted: int = _count_non_common(1, 500.0)
	assert_gt(boosted, base, "item_rarity_pct +500 gives more magic/rare pieces (F-83)")


func test_item_rarity_pct_is_read_with_the_context_of_the_action() -> void:
	# F-83 says "global"; ArtisanResolver reads the stat with the context of the action, so a modifier scoped to
	# the skill of the action applies and one scoped to another skill does not. Documents the current behaviour.
	var ctx: ModifierContext = ModifierContext.for_action(SKILL, FORGE_SWORD)
	_session.modifiers.set_source(RARITY_SOURCE, [Modifier.make(RARITY_STAT, 100.0)] as Array[Modifier])
	assert_eq(_session.modifiers.total(RARITY_STAT, ctx), 100.0, "global modifier reaches the forge")
	var other: Array[Modifier] = [Modifier.make(RARITY_STAT, 100.0, Modifier.SCOPE_SKILL, &"forestry")]
	_session.modifiers.set_source(RARITY_SOURCE, other)
	assert_eq(_session.modifiers.total(RARITY_STAT, ctx), 0.0, "a modifier scoped to forestry does not")


# --- helpers ----------------------------------------------------------------------------------------------------

func _new_session(data: GameData) -> GameSession:
	var session: GameSession = TestFactory.session(SEED, data)
	session.events.action_stopped.connect(_on_action_stopped)
	return session


# Ingots, grips and shield cores for `multiplier` cycles of each of the three recipes.
func _stock(multiplier: int) -> void:
	TestFactory.give(_session, INGOT, 12 * multiplier)
	TestFactory.give(_session, GRIP, 2 * multiplier)
	TestFactory.give(_session, SHIELDCORE, multiplier)


# One cycle of the action: start, advance exactly its interval, stop.
func _forge(action_id: StringName) -> void:
	var interval: int = _session.data.action(action_id).interval_ms
	assert_true(_session.actions.start(SKILL, action_id).ok, "start %s" % action_id)
	_session.advance(interval)
	_session.actions.stop()


# Forges a sword, a greatsword and a shield; returns {base: uid}.
func _forge_all() -> Dictionary:
	_stock(2)
	_set_mastery({FORGE_SWORD: 1, FORGE_GREAT: 40, FORGE_SHIELD: 99})
	_forge(FORGE_SWORD)
	_forge(FORGE_GREAT)
	_forge(FORGE_SHIELD)
	var out: Dictionary = {}
	for piece: ItemInstance in _session.armory.instances():
		out[piece.base_id] = piece.uid
	assert_eq(out.size(), 3, "three different pieces")
	return out


# Sets the mastery xp of each action to the xp of the given mastery level.
func _set_mastery(level_by_action: Dictionary) -> void:
	var actions: Dictionary = {}
	for action_id: Variant in level_by_action:
		actions[str(action_id)] = _session.data.mastery_table().xp_for_level(int(level_by_action[action_id]))
	_session.mastery.from_save({str(SKILL): {"pool": 0, "actions": actions, "nodes": []}})
	_session.rebuild_modifiers()


func _bases(pieces: Array[ItemInstance]) -> Array[StringName]:
	var out: Array[StringName] = []
	for piece: ItemInstance in pieces:
		out.append(piece.base_id)
	return out


func _assert_affix_rules(piece: ItemInstance) -> void:
	var count: int = piece.affixes.size()
	match piece.rarity:
		&"common":
			assert_eq(count, 0, "%s common has no affixes" % piece.base_id)
		&"magic":
			assert_between(count, 1, 2, "%s magic has 1-2 affixes" % piece.base_id)
		&"rare":
			assert_gte(count, 2, "%s rare has at least 2 affixes" % piece.base_id)
	var seen: Array[StringName] = []
	for roll: AffixRoll in piece.affixes:
		assert_false(seen.has(roll.affix_id), "no repeated affix")
		seen.append(roll.affix_id)
		assert_not_null(_session.data.affix(roll.affix_id), "known affix")
		assert_gte(roll.tier, 1, "tier from 1")


# Forges SAMPLE_CYCLES swords from the given starting mastery level with a fresh session and a fixed seed; returns
# how many are not common. The Armory is emptied after each cycle.
func _count_non_common(mastery_level: int, rarity_pct: float) -> int:
	_session.free()
	_session = _new_session(TestFactory.real_data())
	TestFactory.give(_session, INGOT, 3 * SAMPLE_CYCLES)
	TestFactory.give(_session, GRIP, SAMPLE_CYCLES)
	_set_mastery({FORGE_SWORD: mastery_level})
	if rarity_pct > 0.0:
		_session.modifiers.set_source(RARITY_SOURCE, [Modifier.make(RARITY_STAT, rarity_pct)] as Array[Modifier])
	var non_common: int = 0
	for _i: int in SAMPLE_CYCLES:
		_forge(FORGE_SWORD)
		for piece: ItemInstance in _session.armory.instances():
			if piece.rarity != &"common":
				non_common += 1
			assert_true(_session.armory.remove(piece.uid).ok)
	return non_common


# Real content with a config copy where the Armory has `slots` base slots.
func _data_with_armory_slots(slots: int) -> GameData:
	DirAccess.make_dir_recursive_absolute(_tmp_config)
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_ROOT.path_join("balance.json")))
	(balance["armory"] as Dictionary)["base_slots"] = slots
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
