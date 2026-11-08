class_name TestFactory
extends RefCounted
## Builds data and sessions for unit tests (docs/05_INTERFACES.md §8). Never touches real slots or the Game autoload.
##
## GameData is immutable after loading, so the fixture and real data are loaded once per test run and shared.
## Every session returned by `session` must be freed by the test (`autofree()` or `session.free()`).

const FIXTURE_CONTENT_ROOT: String = "res://tests/fixtures/data"
const CONFIG_ROOT: String = "res://data/config"
const REAL_CONTENT_ROOT: String = "res://data"
const ROOMY_SLOTS: int = 2000
const PreRun := preload("res://tests/helpers/gut_pre_run.gd")

static var _fixture_data: GameData = null
static var _real_data: GameData = null
static var _deposit_data: Dictionary[String, GameData] = {}


## Fixture content (res://tests/fixtures/data) with the real configuration (res://data/config).
static func fixture_data() -> GameData:
	if _fixture_data == null:
		_fixture_data = _load(FIXTURE_CONTENT_ROOT)
	return _fixture_data


## The game's real data (res://data).
static func real_data() -> GameData:
	if _real_data == null:
		_real_data = _load(REAL_CONTENT_ROOT)
	return _real_data


## New session on its own GameEvents (not the autoload), with new_game() done. data = null uses the fixtures.
## M10: a new game gives the starting kit (food, pieces, unique tools, Field Rations I). On the legacy fixtures the kit is
## emptied after new_game (see `clear_kit`) so that older tests see an empty game; `keep_kit` = true leaves it (the
## kit tests); a session on other data (the M10 fixtures, the real data) always keeps it.
## Legacy fixture data = the content of res://tests/fixtures/data, also when loaded with a modified copy of the config.
static func session(seed_value: int = 1234, data: GameData = null, keep_kit: bool = false) -> GameSession:
	var game_data: GameData = data if data != null else fixture_data()
	var events: GameEvents = GameEvents.new()
	var result: GameSession = GameSession.new(game_data, events, seed_value)
	# Child of the session, so freeing the session frees its events too.
	result.add_child(events)
	result.new_game()
	if is_legacy_fixture(game_data) and not keep_kit:
		clear_kit(result)
	return result


## Like `session`, but always without the starting kit (also on the real data): for flow tests that predate the kit and
## do not test it. The kit itself is covered by test_starting_kit.gd and test_m10_flow.gd.
static func session_no_kit(seed_value: int = 1234, data: GameData = null) -> GameSession:
	var result: GameSession = session(seed_value, data, true)
	clear_kit(result)
	return result


## True for the content of res://tests/fixtures/data (it has the test items and the real `start.food`).
static func is_legacy_fixture(data: GameData) -> bool:
	return data.has_item(&"test_twig") and data.balance_value("start.food") == "seared_brookfin"


## Empties the starting kit of a new game: no kit food in the bank, an empty Armory, nothing worn, no food chosen,
## no purchase made. Gold and the other systems stay as new_game left them.
static func clear_kit(session: GameSession) -> void:
	var food: StringName = StringName(str(session.data.balance_value("start.food")))
	if session.bank.get_count(food) > 0:
		session.bank.remove(food, session.bank.get_count(food))
	session.armory.from_save({"items": []})
	session.equipment.from_save({})
	session.shop.from_save({"purchases": {}})
	session.rebuild_modifiers()


## Adds items through bank.add and asserts it succeeds.
static func give(session: GameSession, item_id: StringName, qty: int) -> void:
	assert(session != null, "TestFactory.give needs a session")
	var result: CommandResult = session.bank.add(item_id, qty)
	if not result.ok:
		push_error("TestFactory.give(%s, %d) failed: %s" % [item_id, qty, result.reason])
	assert(result.ok, "TestFactory.give failed")


## Raises a skill to `level` through skills.add_xp with the missing xp_for_level (emits xp_gained/level_up).
## Call it before adding skill_xp_pct modifiers and only upwards: it asserts the level is exactly reached.
static func set_level(session: GameSession, skill_id: StringName, level: int) -> void:
	assert(session != null, "TestFactory.set_level needs a session")
	var missing: int = session.data.xp_table().xp_for_level(level) - session.skills.get_xp(skill_id)
	if missing > 0:
		session.skills.add_xp(skill_id, missing)
	var reached: int = session.skills.get_level(skill_id)
	if reached != level:
		push_error("TestFactory.set_level(%s, %d): level is %d" % [skill_id, level, reached])
	assert(reached == level, "TestFactory.set_level(%s, %d) did not reach the level" % [skill_id, level])


static func _load(content_root: String) -> GameData:
	var data: GameData = GameData.load_from_dirs(content_root, CONFIG_ROOT)
	assert(data.is_valid(), "test data in %s is not valid: %s" % [content_root, "\n".join(data.errors)])
	return data


## Raises the character to `level` through character.add_xp with the missing xp (emits character_* signals).
## Call it before adding skill_xp_pct modifiers and only upwards: it asserts the level is exactly reached.
static func set_character_level(session: GameSession, level: int) -> void:
	assert(session != null, "TestFactory.set_character_level needs a session")
	var missing: int = session.data.character_xp_table().xp_for_level(level) - session.character.get_xp()
	if missing > 0:
		session.character.add_xp(missing)
	var reached: int = session.character.get_level()
	if reached != level:
		push_error("TestFactory.set_character_level(%d): level is %d" % [level, reached])
	assert(reached == level, "TestFactory.set_character_level did not reach the level")


## Creates a piece in the Armory through armory.create and asserts it worked; returns its uid.
static func give_piece(
	session: GameSession, base_id: StringName, rarity: StringName = &"common", ilvl: int = 1
) -> int:
	assert(session != null, "TestFactory.give_piece needs a session")
	var uid: int = session.armory.create(base_id, rarity, ilvl)
	if uid <= 0:
		push_error("TestFactory.give_piece(%s) failed: no uid" % base_id)
	assert(uid > 0, "TestFactory.give_piece failed")
	return uid


## GameData of `content_root` with a copy of the real configuration where `deposit.base_slots` is `base_slots` (M12: the
## capacity no longer comes from a stat, so tests that need a roomy or a tiny Deposit load other data). The copy is
## written under user:// only while loading and removed at once; results are cached per (root, base_slots).
static func data_with_deposit(content_root: String, base_slots: int) -> GameData:
	var key: String = "%s#%d" % [content_root, base_slots]
	if _deposit_data.has(key):
		return _deposit_data[key]
	var dir: String = PreRun.test_dir("factory_deposit_%d" % base_slots)
	DirAccess.make_dir_recursive_absolute(dir)
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_ROOT.path_join("balance.json")))
	(balance["deposit"] as Dictionary)["base_slots"] = base_slots
	_write(dir.path_join("balance.json"), JSON.stringify(balance))
	_write(dir.path_join("stats.json"), FileAccess.get_file_as_string(CONFIG_ROOT.path_join("stats.json")))
	var data: GameData = GameData.load_from_dirs(content_root, dir)
	assert(data.is_valid(), "data with %d deposit slots is not valid: %s" % [base_slots, "\n".join(data.errors)])
	DirAccess.remove_absolute(dir.path_join("balance.json"))
	DirAccess.remove_absolute(dir.path_join("stats.json"))
	DirAccess.remove_absolute(dir)
	_deposit_data[key] = data
	return data


## A Deposit big enough for any test that fills it on purpose (`ROOMY_SLOTS` base slots).
static func roomy_data(content_root: String = FIXTURE_CONTENT_ROOT) -> GameData:
	return data_with_deposit(content_root, ROOMY_SLOTS)


static func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## Gives the Deposit room for ROOMY_SLOTS more boxes (a negative occupant), for tests that keep every drop. Once per
## session. Returns the one-element array holding the extra room: set it to [0] to take the room away.
static func make_roomy(session: GameSession) -> Array[int]:
	var room: Array[int] = [ROOMY_SLOTS]
	session.deposit.register_occupant(&"test:roomy", func() -> int: return -room[0])
	return room
