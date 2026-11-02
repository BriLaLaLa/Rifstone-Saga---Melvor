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
static func session(seed_value: int = 1234, data: GameData = null) -> GameSession:
	var game_data: GameData = data if data != null else fixture_data()
	var events: GameEvents = GameEvents.new()
	var result: GameSession = GameSession.new(game_data, events, seed_value)
	# Child of the session, so freeing the session frees its events too.
	result.add_child(events)
	result.new_game()
	return result


## Adds items through bank.add and asserts it succeeds. Needs Bank (M1-07).
static func give(session: GameSession, item_id: StringName, qty: int) -> void:
	assert(session != null, "TestFactory.give needs a session")
	push_error("TestFactory.give(%s, %d): Bank does not exist yet (M1-07)" % [item_id, qty])
	assert(false, "TestFactory.give needs Bank (M1-07)")


## Sets a skill level through skills.add_xp with xp_for_level. Needs SkillsSystem (M1-08).
static func set_level(session: GameSession, skill_id: StringName, level: int) -> void:
	assert(session != null, "TestFactory.set_level needs a session")
	push_error("TestFactory.set_level(%s, %d): SkillsSystem does not exist yet (M1-08)" % [skill_id, level])
	assert(false, "TestFactory.set_level needs SkillsSystem (M1-08)")


static func _load(content_root: String) -> GameData:
	var data: GameData = GameData.load_from_dirs(content_root, CONFIG_ROOT)
	assert(data.is_valid(), "test data in %s is not valid: %s" % [content_root, "\n".join(data.errors)])
	return data
