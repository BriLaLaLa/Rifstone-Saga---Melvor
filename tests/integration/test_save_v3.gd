extends GutTest
## Integration, save format v3 (M10): a v1 or v2 save is refused and left alone; slots A and B are independent also for the
## Armory, the worn pieces and the character; the tolerant load of the Armory/character/equipment modules; the header
## total_level includes the character level.
##
## Slot tests use a private instance of game.gd on the real data like test_slot_isolation.gd. SaveService.base_dir is
## PreRun.save_dir() (gut_pre_run.gd), emptied before and after each test; GameClock.time_source is fixed and restored.

const GameScript := preload("res://core/autoload/game.gd")
const PreRun := preload("res://tests/helpers/gut_pre_run.gd")
const NOW_MS: int = 1793600000000
const SLOT_A: int = 1
const SLOT_B: int = 2
const SWORD: StringName = &"emberbronze_sword"
const SHIELD: StringName = &"emberbronze_shield"
const GREATSWORD: StringName = &"emberbronze_greatsword"
const CHARACTER_XP: int = 5000

var _test_dir: String = PreRun.save_dir()
var _game: GameScript
var _saved_time_source: Callable
var _extra: Array[GameSession] = []


func before_each() -> void:
	_clear_dir(_test_dir)
	_saved_time_source = GameClock.time_source
	GameClock.time_source = func() -> int: return NOW_MS
	_game = GameScript.new()
	add_child_autofree(_game)


func after_each() -> void:
	_game.end_session(false)
	GameClock.set_paused(true)
	GameClock.time_source = _saved_time_source
	for session: GameSession in _extra:
		session.free()
	_extra.clear()
	_clear_dir(_test_dir)


# --- version ----------------------------------------------------------------------------------------------------

func test_format_version_is_3() -> void:
	assert_eq(SaveMigrator.CURRENT_VERSION, 3)
	assert_eq(int(_session().to_save(NOW_MS)["format_version"]), 3)


func test_v1_file_is_refused_and_left_untouched() -> void:
	_write_raw_v1()
	var before: String = _slot_text(SLOT_A)
	var result: CommandResult = await _game.continue_game(SLOT_A)
	assert_false(result.ok)
	assert_eq(result.reason, Reasons.VERSION_UNSUPPORTED)
	assert_null(_game.session, "no session")
	assert_eq(_game.state, &"menu")
	assert_eq(_slot_text(SLOT_A), before, "the v1 file is not rewritten")
	assert_eq(SaveService.read_slot_info(SLOT_A).state, &"unsupported", "the menu shows it as unsupported")


func test_session_refuses_a_v1_dictionary_without_changing_state() -> void:
	var session: GameSession = _session()
	session.wallet.add_gold(77)
	var gold: int = session.wallet.get_gold()
	var result: CommandResult = session.from_save(_v1_save())
	assert_false(result.ok)
	assert_eq(result.reason, Reasons.VERSION_UNSUPPORTED)
	assert_eq(session.wallet.get_gold(), gold, "nothing changed")


func test_new_game_over_a_v1_slot_writes_v3() -> void:
	_write_raw_v1()
	assert_true(_game.new_game(SLOT_A, "Nuova").ok, "a new game overwrites the old slot")
	_game.end_session(true)
	assert_eq(int(SaveCodec.decode(_slot_text(SLOT_A))["format_version"]), 3)
	assert_true((await _game.continue_game(SLOT_A)).ok)


# --- two slots, Armory and character ----------------------------------------------------------------------------

func test_slots_are_independent_for_armory_character_and_worn_pieces() -> void:
	assert_true(_game.new_game(SLOT_A, "Alfa").ok)
	var a: GameSession = _game.session
	var sword: int = TestFactory.give_piece(a, SWORD, &"rare", 1)
	var shield: int = TestFactory.give_piece(a, SHIELD, &"magic", 1)
	TestFactory.give_piece(a, GREATSWORD)
	assert_true(a.equipment.equip(sword).ok)
	assert_true(a.equipment.equip(shield).ok)
	assert_true(a.armory.set_locked(3, true).ok)
	a.character.add_xp(CHARACTER_XP)
	var a_xp: int = a.character.get_xp()
	var a_level: int = a.character.get_level()
	assert_gt(a_level, 1, "slot A character leveled up")
	var a_total: int = a.total_level()
	_game.end_session(true)
	var a_text: String = _slot_text(SLOT_A)
	assert_true(_game.new_game(SLOT_B, "Beta").ok)
	var b: GameSession = _game.session
	assert_eq(b.armory.instances().size(), 0, "B has no pieces of A")
	assert_eq(b.armory.used(), 0)
	assert_eq(b.equipment.get_uid(&"weapon"), 0)
	assert_eq(b.equipment.setup(), Equipment.UNARMED)
	assert_eq(b.character.get_xp(), 0)
	assert_eq(b.character.get_level(), 1)
	var b_piece: int = TestFactory.give_piece(b, SWORD, &"common", 1)
	assert_eq(b_piece, 1, "uids restart from 1 in a new slot")
	b.character.add_xp(10)
	_game.end_session(true)
	assert_eq(_slot_text(SLOT_A), a_text, "slot A byte for byte")
	assert_true((await _game.continue_game(SLOT_A)).ok)
	var again: GameSession = _game.session
	assert_eq(again.armory.instances().size(), 3, "A keeps its three pieces")
	assert_eq(again.equipment.get_uid(&"weapon"), sword)
	assert_eq(again.equipment.get_uid(&"offhand"), shield)
	assert_eq(again.equipment.setup(), &"sword_shield")
	assert_true(again.armory.get_instance(3).locked)
	assert_eq(again.armory.get_instance(sword).rarity, &"rare")
	assert_eq(again.character.get_xp(), a_xp)
	assert_eq(again.character.get_level(), a_level)
	assert_eq(again.total_level(), a_total)
	_game.end_session(true)
	assert_true((await _game.continue_game(SLOT_B)).ok)
	assert_eq(_game.session.armory.instances().size(), 1, "B keeps only its piece")
	assert_eq(_game.session.armory.instances()[0].base_id, SWORD)
	assert_eq(_game.session.character.get_xp(), 10)
	assert_eq(_game.session.equipment.get_uid(&"weapon"), 0)


func test_slot_list_shows_the_total_level_with_the_character() -> void:
	assert_true(_game.new_game(SLOT_A, "Alfa").ok)
	_game.session.character.add_xp(CHARACTER_XP)
	var skills_total: int = _game.session.skills.total_level()
	var expected: int = _game.session.total_level()
	_game.end_session(true)
	var info: SlotInfo = SaveService.read_slot_info(SLOT_A)
	assert_eq(info.total_level, expected)
	assert_eq(int(SaveCodec.decode(_slot_text(SLOT_A))["total_level"]), expected, "header total_level")
	assert_gt(expected, skills_total, "the character level is counted")


func test_deleting_one_slot_keeps_the_pieces_of_the_other() -> void:
	assert_true(_game.new_game(SLOT_A, "Alfa").ok)
	TestFactory.give_piece(_game.session, SWORD, &"magic", 1)
	_game.end_session(true)
	assert_true(_game.new_game(SLOT_B, "Beta").ok)
	TestFactory.give_piece(_game.session, SHIELD, &"rare", 1)
	_game.end_session(true)
	var b_text: String = _slot_text(SLOT_B)
	assert_true(_game.delete_slot(SLOT_A).ok)
	assert_eq(_slot_text(SLOT_B), b_text)
	assert_true((await _game.continue_game(SLOT_B)).ok)
	assert_eq(_game.session.armory.instances()[0].base_id, SHIELD)


# --- tolerant load ----------------------------------------------------------------------------------------------

func test_missing_armory_character_and_equipment_modules_start_as_a_new_game() -> void:
	var source: GameSession = _session()
	TestFactory.give_piece(source, SWORD)
	source.character.add_xp(CHARACTER_XP)
	var saved: Dictionary = source.to_save(NOW_MS)
	for module: String in ["armory", "character", "equipment"]:
		(saved["modules"] as Dictionary).erase(module)
	var loaded: GameSession = _session(55)
	assert_true(loaded.from_save(saved).ok)
	assert_eq(loaded.armory.instances().size(), 0)
	assert_eq(loaded.character.get_xp(), 0)
	assert_eq(loaded.character.class_id(), StringName(loaded.data.balance_value("character.start_class")))
	assert_eq(loaded.equipment.get_uid(&"weapon"), 0)


func test_invalid_armory_entries_are_discarded_and_next_uid_is_repaired() -> void:
	var source: GameSession = _session()
	var good: int = TestFactory.give_piece(source, SWORD, &"common", 3)
	var saved: Dictionary = source.to_save(NOW_MS)
	var armory: Dictionary = (saved["modules"] as Dictionary)["armory"]
	var items: Array = []
	items.append_array(armory["items"] as Array)
	armory["items"] = items
	var good_entry: Dictionary = (items[0] as Dictionary).duplicate(true)
	var unknown: Dictionary = good_entry.duplicate(true)
	unknown["uid"] = 5
	unknown["base"] = "ghost_blade"
	var not_a_piece: Dictionary = good_entry.duplicate(true)
	not_a_piece["uid"] = 6
	not_a_piece["base"] = "redbirch_log"
	var duplicate: Dictionary = good_entry.duplicate(true)
	duplicate["base"] = "emberbronze_shield"
	items.append_array([unknown, not_a_piece, duplicate, "garbage", 12])
	armory["next_uid"] = 1
	var loaded: GameSession = _session(56)
	assert_true(loaded.from_save(saved).ok)
	var pieces: Array[ItemInstance] = loaded.armory.instances()
	assert_eq(pieces.size(), 1, "only the valid piece survives")
	assert_eq(pieces[0].uid, good)
	assert_eq(pieces[0].base_id, SWORD)
	assert_eq(pieces[0].ilvl, 3)
	assert_eq(loaded.armory.create(SWORD, &"common", 1), good + 1, "next_uid raised above the highest uid")


func test_equipment_pointing_to_a_missing_or_shared_uid_is_dropped() -> void:
	var source: GameSession = _session()
	var sword: int = TestFactory.give_piece(source, SWORD)
	assert_true(source.equipment.equip(sword).ok)
	var saved: Dictionary = source.to_save(NOW_MS)
	var slots: Dictionary = (saved["modules"] as Dictionary)["equipment"]["slots"]
	slots["offhand"] = 999
	slots["ring"] = sword
	slots["ghost_slot"] = 1
	var loaded: GameSession = _session(57)
	assert_true(loaded.from_save(saved).ok)
	assert_eq(loaded.equipment.get_uid(&"weapon"), sword)
	assert_eq(loaded.equipment.get_uid(&"offhand"), 0, "uid absent from the Armory")
	assert_eq(loaded.equipment.get_uid(&"ring"), 0, "uid already worn elsewhere")
	assert_true(loaded.armory.is_worn(sword))
	assert_eq(loaded.armory.used(), 0, "the worn piece does not use a place")


func test_the_worn_flag_is_not_saved_in_the_armory() -> void:
	var source: GameSession = _session()
	var sword: int = TestFactory.give_piece(source, SWORD)
	assert_true(source.equipment.equip(sword).ok)
	var items: Array = (source.to_save(NOW_MS)["modules"] as Dictionary)["armory"]["items"]
	assert_eq(items.size(), 1)
	assert_false((items[0] as Dictionary).has("worn"), "worn is derived from the equipment module")
	assert_false((items[0] as Dictionary).has("equipped"))


# --- helpers ----------------------------------------------------------------------------------------------------

# A session on the real data, tracked and freed after the test.
func _session(seed_value: int = 4242) -> GameSession:
	var session: GameSession = TestFactory.session(seed_value, TestFactory.real_data())
	_extra.append(session)
	return session


# Header and modules of a v1 save (stance in equipment, bank items in the slots, no armory/character).
func _v1_save() -> Dictionary:
	return {
		"format_version": 1,
		"game_version": "0.1.0",
		"slot": SLOT_A,
		"player_name": "Vecchio",
		"created_at_unix_ms": NOW_MS,
		"saved_at_unix_ms": NOW_MS,
		"play_time_ms": 1000,
		"total_level": 12,
		"rng": {"seed": 1, "state": "1"},
		"modules": {
			"wallet": {"gold": 500},
			"equipment": {"slots": {"weapon": "emberbronze_sword"}, "stance": "balanced", "food": ""},
		},
	}


func _slot_text(slot: int) -> String:
	return FileAccess.get_file_as_string(SaveService.slot_path(slot))


func _clear_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub_dir: String in DirAccess.get_directories_at(path):
		_clear_dir(path.path_join(sub_dir))
		DirAccess.remove_absolute(path.path_join(sub_dir))
	for file_name: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))




# Writes a v1 slot file by hand (the store would stamp the current version).
func _write_raw_v1() -> void:
	DirAccess.make_dir_recursive_absolute(_test_dir)
	var file: FileAccess = FileAccess.open(SaveService.slot_path(SLOT_A), FileAccess.WRITE)
	file.store_string(SaveCodec.encode(_v1_save()))
	file.close()


# A v2 save (the format before the loot reform) is refused as well, and left untouched.
func test_v2_file_is_refused_and_left_untouched() -> void:
	DirAccess.make_dir_recursive_absolute(_test_dir)
	var v2: Dictionary = _v1_save()
	v2["format_version"] = 2
	var file: FileAccess = FileAccess.open(SaveService.slot_path(SLOT_A), FileAccess.WRITE)
	file.store_string(SaveCodec.encode(v2))
	file.close()
	var before: String = _slot_text(SLOT_A)
	var result: CommandResult = await _game.continue_game(SLOT_A)
	assert_false(result.ok)
	assert_eq(result.reason, Reasons.VERSION_UNSUPPORTED)
	assert_eq(_slot_text(SLOT_A), before, "the v2 file is not rewritten")
	assert_eq(SaveService.read_slot_info(SLOT_A).state, &"unsupported")
	assert_eq(_session().from_save(v2).reason, Reasons.VERSION_UNSUPPORTED)
