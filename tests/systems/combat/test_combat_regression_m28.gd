extends GutTest
## M28-03 non-regression (docs/02_FORMULAS_M28.md, docs/05_INTERFACES_M28.md §5.10b): with the content of M27 (`loadout=auto`) the
## engine gives the same events, hp and random generator state as before the conditions were wired in. The numbers were recorded
## from `main` (1568b0e) before the engine was touched: 2 h of fight, fixed seed, three assemblies, a quiet case in each of two areas
## and two cases with weak gear and little food (deaths, the loot bag lost).
## M28-06: the four cases that reach level 30 (mines, weak gear sword_shield) were re-recorded: the new traits and abilities, appended
## after the old ones, fill the slots that stayed empty (verified: with the M27 rift_blade.json the old numbers come back).

const Rig := preload("res://tests/systems/combat/combat_regression_rig.gd")
const SEED: int = 1234
const HOURS: float = 2.0

var _data: GameData = null


func before_all() -> void:
	_data = TestFactory.real_data()


func _check(area: StringName, setup: StringName, offset: int, grade_minus: int, expected: Dictionary, food: int = 1000000) -> void:
	var got: Dictionary = Rig.run(_data, area, setup, offset, HOURS, SEED, grade_minus, food)
	assert_eq(got, expected, "%s / %s / %d / %d" % [area, setup, offset, grade_minus])


func test_sword_shield_plains() -> void:
	_check(&"redrock_plains", &"sword_shield", -3, 0,
			{"deaths": 0, "events": 12768, "food": 387, "hash": 2038849273073428160, "kills": 529, "rng": 1163697843})


func test_greatsword_plains() -> void:
	_check(&"redrock_plains", &"greatsword", -3, 0,
			{"deaths": 0, "events": 10485, "food": 375, "hash": 8313901566582730724, "kills": 385, "rng": 1217041523})


func test_dual_plains() -> void:
	_check(&"redrock_plains", &"dual", -3, 0,
			{"deaths": 0, "events": 12894, "food": 381, "hash": 9215568773177735570, "kills": 487, "rng": 763040687})


func test_sword_shield_mines() -> void:
	_check(&"cracked_mines", &"sword_shield", -4, 0,
			{"deaths": 0, "events": 26509, "food": 401, "hash": 8907143056429198199, "kills": 925, "rng": 3401925336})


func test_greatsword_mines() -> void:
	_check(&"cracked_mines", &"greatsword", -4, 0,
			{"deaths": 0, "events": 28920, "food": 589, "hash": 9202982194096669069, "kills": 1250, "rng": 1993799300})


func test_dual_mines() -> void:
	_check(&"cracked_mines", &"dual", -4, 0,
			{"deaths": 0, "events": 34965, "food": 705, "hash": 5534287392357155274, "kills": 895, "rng": 1087087418})


func test_weak_gear_sword_shield() -> void:
	_check(&"cracked_mines", &"sword_shield", -4, 4,
			{"deaths": 160, "events": 14961, "food": 30, "hash": 3882544513423752090, "kills": 337, "rng": 659808001}, 30)


func test_weak_gear_dual() -> void:
	_check(&"whisper_wood", &"dual", -4, 3,
			{"deaths": 180, "events": 16345, "food": 50, "hash": 6620158104904999490, "kills": 346, "rng": 1132470544}, 30)
