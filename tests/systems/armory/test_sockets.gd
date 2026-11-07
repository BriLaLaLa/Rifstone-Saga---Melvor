extends GutTest
## F-89 sockets: pure rules (Sockets) and the Armory commands (socket_stone, clear_socket), modifiers of the stones,
## worn pieces, save. The real config has no `sockets` section yet, so the tests use a copy of it that adds the one of
## docs/02_FORMULAS.md (fixture content: test_stone, test_stone_b, test_blade).

const STONE: StringName = &"test_stone"
const STONE_B: StringName = &"test_stone_b"
const BLADE: StringName = &"test_blade"
const CONFIG_ROOT: String = "res://data/config"
const PreRun := preload("res://tests/helpers/gut_pre_run.gd")

var _tmp_config: String = PreRun.test_dir("test_sockets").path_join("config")
var _data: GameData = null


func before_all() -> void:
	DirAccess.make_dir_recursive_absolute(_tmp_config)
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_ROOT.path_join("balance.json")))
	balance["sockets"] = {"by_rarity": {"common": 0, "magic": 1, "rare": 2}, "bonus_at_upgrade": 7}
	_write(_tmp_config.path_join("balance.json"), JSON.stringify(balance))
	_write(_tmp_config.path_join("stats.json"), FileAccess.get_file_as_string(CONFIG_ROOT.path_join("stats.json")))
	_data = GameData.load_from_dirs(TestFactory.FIXTURE_CONTENT_ROOT, _tmp_config)
	assert_true(_data.is_valid(), str(_data.errors))


func after_all() -> void:
	for file: String in ["balance.json", "stats.json"]:
		DirAccess.remove_absolute(_tmp_config.path_join(file))
	DirAccess.remove_absolute(_tmp_config)
	DirAccess.remove_absolute(_tmp_config.get_base_dir())


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _session() -> GameSession:
	return autofree(TestFactory.session(7, _data))


func _piece(s: GameSession, rarity: StringName, upgrade: int = 0) -> int:
	var uid: int = TestFactory.give_piece(s, BLADE, rarity)
	_set_upgrade(s, uid, upgrade)
	return uid


# Test shortcut: sets the refinement through the save format (the real path needs materials and luck).
func _set_upgrade(s: GameSession, uid: int, upgrade: int) -> void:
	var saved: Dictionary = s.armory.to_save()
	for entry: Dictionary in saved["items"]:
		if int(entry["uid"]) == uid:
			entry["upgrade"] = upgrade
	s.armory.from_save(saved)


func test_f89_examples() -> void:
	assert_eq(Sockets.count(&"rare", 7, _data), 3, "rare +7")
	assert_eq(Sockets.count(&"common", 9, _data), 1, "common +9")
	assert_eq(Sockets.count(&"magic", 6, _data), 1, "magic +6")


func test_f89_table() -> void:
	assert_eq(Sockets.count(&"common", 0, _data), 0)
	assert_eq(Sockets.count(&"magic", 7, _data), 2)
	assert_eq(Sockets.count(&"rare", 6, _data), 2)


func test_armory_socket_count_follows_rarity_and_upgrade() -> void:
	var s: GameSession = _session()
	var uid: int = _piece(s, &"rare", 7)
	assert_eq(s.armory.socket_count(uid), 3)
	assert_eq(s.armory.socket_count(999), 0)


func test_socket_stone_consumes_it_and_emits() -> void:
	var s: GameSession = _session()
	var uid: int = _piece(s, &"rare")
	TestFactory.give(s, STONE, 2)
	watch_signals(s.events)
	assert_true(s.armory.socket_stone(uid, STONE).ok)
	assert_eq(s.bank.get_count(STONE), 1)
	assert_eq(s.armory.get_instance(uid).sockets, [STONE] as Array[StringName])
	assert_signal_emitted_with_parameters(s.events, "armory_changed", [uid, Armory.CHANGE_UPDATED])


func test_socket_stone_refusals_change_nothing() -> void:
	var s: GameSession = _session()
	var common: int = _piece(s, &"common")
	var magic: int = _piece(s, &"magic")
	TestFactory.give(s, STONE, 1)
	assert_eq(s.armory.socket_stone(999, STONE).reason, Reasons.UNKNOWN_ID)
	assert_eq(s.armory.socket_stone(magic, &"rift_shard").reason, Reasons.NOT_EQUIPPABLE)
	assert_eq(s.armory.socket_stone(common, STONE).reason, Reasons.SOCKET_LOCKED)
	assert_eq(s.armory.socket_stone(magic, STONE_B).reason, Reasons.NOT_ENOUGH_ITEMS)
	assert_true(s.armory.socket_stone(magic, STONE).ok)
	TestFactory.give(s, STONE, 1)
	assert_eq(s.armory.socket_stone(magic, STONE).reason, Reasons.SOCKET_OCCUPIED)
	assert_eq(s.bank.get_count(STONE), 1)


func test_clear_socket_destroys_the_stone() -> void:
	var s: GameSession = _session()
	var uid: int = _piece(s, &"rare")
	TestFactory.give(s, STONE, 1)
	TestFactory.give(s, STONE_B, 1)
	s.armory.socket_stone(uid, STONE)
	s.armory.socket_stone(uid, STONE_B)
	assert_eq(s.armory.clear_socket(uid, 2).reason, Reasons.SLOT_EMPTY)
	assert_eq(s.armory.clear_socket(999, 0).reason, Reasons.UNKNOWN_ID)
	assert_true(s.armory.clear_socket(uid, 0).ok)
	assert_eq(s.armory.get_instance(uid).sockets, [STONE_B] as Array[StringName])
	assert_eq(s.bank.get_count(STONE), 0, "destroyed, not returned")


func test_stone_modifiers_are_in_the_instance_modifiers() -> void:
	var s: GameSession = _session()
	var uid: int = _piece(s, &"magic")
	var before: int = s.armory.instance_modifiers(uid).size()
	TestFactory.give(s, STONE, 1)
	s.armory.socket_stone(uid, STONE)
	var mods: Array[Modifier] = s.armory.instance_modifiers(uid)
	assert_eq(mods.size(), before + 1)
	assert_eq(mods[mods.size() - 1].stat, &"power_bonus")
	assert_eq(mods[mods.size() - 1].value, 5.0)


func test_worn_piece_updates_its_source_when_sockets_change() -> void:
	var s: GameSession = _session()
	var uid: int = _piece(s, &"magic")
	assert_true(s.equipment.equip(uid).ok)
	var base: float = s.modifiers.total(&"power_bonus")
	TestFactory.give(s, STONE, 1)
	s.armory.socket_stone(uid, STONE)
	assert_eq(s.modifiers.total(&"power_bonus"), base + 5.0)
	s.armory.clear_socket(uid, 0)
	assert_eq(s.modifiers.total(&"power_bonus"), base)


func test_stone_beyond_the_sockets_is_inactive() -> void:
	var s: GameSession = _session()
	var uid: int = _piece(s, &"magic", 7)
	TestFactory.give(s, STONE, 2)
	s.armory.socket_stone(uid, STONE)
	s.armory.socket_stone(uid, STONE)
	var with_two: int = s.armory.instance_modifiers(uid).size()
	_set_upgrade(s, uid, 6)
	assert_eq(s.armory.socket_count(uid), 1)
	assert_eq(s.armory.instance_modifiers(uid).size(), with_two - 1, "only the first stone counts")
	assert_eq(s.armory.get_instance(uid).sockets.size(), 2, "the stones stay in the piece")


func test_save_round_trip_and_bad_stones_are_dropped() -> void:
	var s: GameSession = _session()
	var uid: int = _piece(s, &"rare")
	TestFactory.give(s, STONE, 1)
	s.armory.socket_stone(uid, STONE)
	var saved: Dictionary = s.armory.to_save()
	assert_eq(((saved["items"] as Array)[0] as Dictionary)["sockets"], ["test_stone"])
	((saved["items"] as Array)[0] as Dictionary)["sockets"] = ["test_stone", "rift_shard", "nope"]
	var other: GameSession = _session()
	other.armory.from_save(saved)
	assert_eq(other.armory.get_instance(uid).sockets, [STONE] as Array[StringName])
