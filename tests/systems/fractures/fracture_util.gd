class_name FractureUtil
extends RefCounted
## Helpers of the Fracture tests (M13-02). The fixtures share the real `balance.json` (`fracture.groups` = 16), so the tests
## with three groups load the fixture content with a modified copy of the configuration (written under user:// only while
## loading, then removed) and cache it.

const PreRun := preload("res://tests/helpers/gut_pre_run.gd")
const SOURCE: StringName = &"test:hero"

static var _cache: Dictionary[String, GameData] = {}


## Fixture content with `fracture.groups` = `groups`.
static func data(groups: int = 3) -> GameData:
	return data_with(groups, {})


## Like `data`, with `overrides` merged into the `fracture` section of the balance (e.g. `{"card_drop": {...}}`).
static func data_with(groups: int, overrides: Dictionary) -> GameData:
	var key: String = "%d:%s" % [groups, JSON.stringify(overrides)]
	if _cache.has(key):
		return _cache[key]
	var dir: String = PreRun.test_dir("fracture_groups_%d" % groups)
	DirAccess.make_dir_recursive_absolute(dir)
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/config/balance.json"))
	(balance["fracture"] as Dictionary)["groups"] = groups
	(balance["fracture"] as Dictionary).merge(overrides, true)
	_write(dir.path_join("balance.json"), JSON.stringify(balance))
	_write(dir.path_join("stats.json"), FileAccess.get_file_as_string("res://data/config/stats.json"))
	var loaded: GameData = GameData.load_from_dirs(TestFactory.FIXTURE_CONTENT_ROOT, dir)
	assert(loaded.is_valid(), "fracture test data is not valid: %s" % "\n".join(loaded.errors))
	DirAccess.remove_absolute(dir.path_join("balance.json"))
	DirAccess.remove_absolute(dir.path_join("stats.json"))
	DirAccess.remove_absolute(dir)
	_cache[key] = loaded
	return loaded


## A session on `data(groups)`, with room for many boxes in the Deposit. The caller frees it (`autofree`).
static func session(seed_value: int = 1234, groups: int = 3, overrides: Dictionary = {}) -> GameSession:
	var result: GameSession = TestFactory.session(seed_value, data_with(groups, overrides))
	TestFactory.make_roomy(result)
	return result


## A player that kills fast and survives: for the flow tests.
static func hero(s: GameSession) -> void:
	s.modifiers.set_source(SOURCE, [Modifier.make(&"power_bonus", 5000.0), Modifier.make(&"max_hp_flat", 100000.0)])


## A very weak player (cannot kill, dies easily): for the defeat tests.
static func weakling(s: GameSession) -> void:
	s.modifiers.set_source(SOURCE, [Modifier.make(&"power_bonus", -1000.0), Modifier.make(&"max_hp_flat", -30.0)])


## A Card of `grade` and `rarity` with the modifiers `[[mod_id, step], ...]` in the CardStore. Returns its uid.
static func card(s: GameSession, grade: int, mods: Array = [], rarity: StringName = &"magic") -> int:
	var made := MapCard.new()
	made.base_id = StringName("fracture_card_%d" % grade)
	made.grade = grade
	made.rarity = rarity
	for pair: Array in mods:
		made.mods.append(MapModRoll.make(StringName(pair[0]), int(pair[1])))
	return s.cards.add(made)


## The save form of a valid Card without modifiers.
static func card_dict(grade: int) -> Dictionary:
	return {"uid": 1, "base": "fracture_card_%d" % grade, "rarity": "common", "mods": [], "locked": false}


## Runs `advance` in steps of `step_ms` until `done` returns true or `limit_ms` passed. Returns the time spent.
static func run_until(s: GameSession, done: Callable, step_ms: int = 100, limit_ms: int = 3_600_000) -> int:
	var spent: int = 0
	while spent < limit_ms and not done.call():
		s.advance(step_ms)
		spent += step_ms
	return spent


static func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
