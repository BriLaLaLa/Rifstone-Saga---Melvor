extends GutTest
## Integration (Lesson "single source of truth"), pieces: equipping moves one Armory piece and each piece exists once,
## whether worn or not. The bank flows are in test_item_conservation.gd. The full-Armory case uses a copy of the real
## config with `armory.base_slots` = 4 written under PreRun.test_dir() (not a save slot) and removed afterwards.

const SEED: int = 424242
const SWORD: StringName = &"emberbronze_sword"
const GREATSWORD: StringName = &"emberbronze_greatsword"
const SHIELD: StringName = &"emberbronze_shield"
const CONTENT_ROOT: String = "res://data"
const CONFIG_ROOT: String = "res://data/config"
const PreRun := preload("res://tests/helpers/gut_pre_run.gd")

var _tmp_config: String = PreRun.test_dir("test_item_conservation_equipment")
var _session: GameSession = null


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


func test_equipping_moves_one_piece_and_each_piece_exists_once() -> void:
	_session = TestFactory.session_no_kit(SEED, TestFactory.real_data())
	var sword: int = TestFactory.give_piece(_session, SWORD)
	var great: int = TestFactory.give_piece(_session, GREATSWORD)
	var shield: int = TestFactory.give_piece(_session, SHIELD)
	var all: Array[int] = [sword, great, shield]
	assert_true(_session.equipment.equip(shield).ok)
	_assert_once(all)
	assert_true(_session.equipment.equip(great).ok, "two-handed weapon")
	assert_eq(_session.equipment.get_uid(&"offhand"), 0, "the shield went back")
	assert_false(_session.armory.is_worn(shield))
	_assert_once(all)
	assert_true(_session.equipment.equip(shield).ok, "offhand with a two-handed weapon")
	assert_eq(_session.equipment.get_uid(&"weapon"), 0, "the greatsword went back")
	assert_false(_session.armory.is_worn(great))
	_assert_once(all)
	assert_true(_session.equipment.equip(sword).ok)
	assert_true(_session.equipment.unequip(&"weapon").ok)
	assert_false(_session.armory.is_worn(sword))
	_assert_once(all)
	var saved: Dictionary = _session.to_save(0)["modules"]
	assert_eq((saved["equipment"]["slots"] as Dictionary).size(), 1, "only the shield is worn in the save")
	assert_eq(_session.bank.used(), 0, "the bank was never involved")


func test_equip_with_full_armory_is_refused_when_pieces_return_without_room() -> void:
	_session = TestFactory.session_no_kit(SEED, _data_with_armory_slots(4))
	assert_eq(_session.armory.capacity(), 4)
	var sword: int = TestFactory.give_piece(_session, SWORD)
	var shield: int = TestFactory.give_piece(_session, SHIELD)
	assert_true(_session.equipment.equip(sword).ok)
	assert_true(_session.equipment.equip(shield).ok)
	var great: int = TestFactory.give_piece(_session, GREATSWORD)
	var filler: int = TestFactory.give_piece(_session, SWORD)
	TestFactory.give_piece(_session, SWORD)
	TestFactory.give_piece(_session, SWORD)
	assert_eq(_session.armory.used(), 4, "Armory full")
	var before: Dictionary = _pieces_world(_session)
	assert_eq(_session.equipment.equip(great).reason, Reasons.ARMORY_FULL, "two pieces would return, one place is taken")
	assert_eq(_pieces_world(_session), before, "nothing changed")
	assert_true(_session.armory.remove(filler).ok)
	assert_true(_session.equipment.equip(great).ok, "room for the piece that returns beyond the one worn")
	assert_true(_session.armory.used() <= _session.armory.capacity())


func test_save_with_two_handed_weapon_and_offhand_keeps_the_invariants() -> void:
	_session = TestFactory.session_no_kit(SEED, TestFactory.real_data())
	var great: int = TestFactory.give_piece(_session, GREATSWORD)
	var shield: int = TestFactory.give_piece(_session, SHIELD)
	var saved: Dictionary = _session.to_save(0)
	var slots: Dictionary = (saved["modules"] as Dictionary)["equipment"]["slots"]
	slots["weapon"] = great
	slots["offhand"] = shield
	var loaded: GameSession = TestFactory.session_no_kit(SEED, _session.data)
	assert_true(loaded.from_save(saved).ok, "the edited save loads")
	assert_eq(loaded.equipment.get_item(&"weapon"), GREATSWORD, "the two-handed weapon is kept")
	assert_eq(loaded.equipment.get_uid(&"offhand"), 0, "the offhand is dropped")
	assert_true(loaded.armory.has(shield), "the shield is still in the Armory")
	assert_false(loaded.armory.is_worn(shield), "and is not worn")
	loaded.free()


func _assert_once(uids: Array[int]) -> void:
	for uid: int in uids:
		var worn: int = 0
		for slot: StringName in Equipment.SLOTS:
			if _session.equipment.get_uid(slot) == uid:
				worn += 1
		assert_true(_session.armory.has(uid), "%d is in the Armory" % uid)
		assert_eq(worn, 1 if _session.armory.is_worn(uid) else 0, "%d worn in one slot iff flagged worn" % uid)


# Bank counts of the given items plus every worn slot and the used boxes, comparable with assert_eq.
# Worn uids per slot, the Armory pieces and its used places.
func _pieces_world(session: GameSession) -> Dictionary:
	var out: Dictionary = {}
	for slot: StringName in Equipment.SLOTS:
		out["slot:" + String(slot)] = session.equipment.get_uid(slot)
	out["count"] = session.armory.instances().size()
	out["used"] = session.armory.used()
	return out



# Real content with a config copy where the Armory has `armory_slots` base slots.
func _data_with_armory_slots(armory_slots: int) -> GameData:
	DirAccess.make_dir_recursive_absolute(_tmp_config)
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_ROOT.path_join("balance.json")))
	(balance["armory"] as Dictionary)["base_slots"] = armory_slots
	_write(_tmp_config.path_join("balance.json"), JSON.stringify(balance))
	_write(_tmp_config.path_join("stats.json"), FileAccess.get_file_as_string(CONFIG_ROOT.path_join("stats.json")))
	var data: GameData = GameData.load_from_dirs(CONTENT_ROOT, _tmp_config)
	assert_true(data.is_valid(), "%d-slot data valid: %s" % [armory_slots, ", ".join(data.errors)])
	return data


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
