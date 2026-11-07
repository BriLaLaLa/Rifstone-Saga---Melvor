class_name TestFactory
extends RefCounted
## Builds data and sessions for unit tests (docs/05_INTERFACES.md §8). Never touches real slots or the Game autoload.
##
## GameData is immutable after loading, so the fixture and real data are loaded once per test run and shared.
## Every session returned by `session` must be freed by the test (`autofree()` or `session.free()`).

const FIXTURE_CONTENT_ROOT: String = "res://tests/fixtures/data"
const CONFIG_ROOT: String = "res://data/config"
const REAL_CONTENT_ROOT: String = "res://data"

static var _fixture_data: GameData = null
static var _real_data: GameData = null


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
