extends GutTest
## M28-03 non-regression (docs/02_FORMULAS_M28.md, docs/05_INTERFACES_M28.md §5.10b): with the content of M27 (`loadout=auto`) the
## M32-05: the new meat drops roll on the shared RNG: the eight numbers were re-recorded (the combat rules did not change).
## engine gives the same events, hp and random generator state as before the conditions were wired in. The numbers were recorded
## from `main` (1568b0e) before the engine was touched: 2 h of fight, fixed seed, three assemblies, a quiet case in each of two areas
## and two cases with weak gear and little food (deaths, the loot bag lost).
## M29-01: three cases re-recorded (cracked_mines sword_shield/greatsword, whisper_wood dual): the Cards that drop now roll their modifiers with the new pool and the 3-6 range, which changes the draws on the shared generator.
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
			{"deaths": 0, "events": 14681, "food": 525, "hash": 5422507137686393826, "kills": 482, "rng": 1524697678})


func test_greatsword_plains() -> void:
	_check(&"redrock_plains", &"greatsword", -3, 0,
			{"deaths": 0, "events": 9355, "food": 294, "hash": 5245565990442101452, "kills": 338, "rng": 2150712148})


func test_dual_plains() -> void:
	_check(&"redrock_plains", &"dual", -3, 0,
			{"deaths": 0, "events": 13019, "food": 373, "hash": 466955768779039067, "kills": 483, "rng": 567842782})


func test_sword_shield_mines() -> void:
	_check(&"cracked_mines", &"sword_shield", -4, 0,
			{"deaths": 0, "events": 25126, "food": 354, "hash": 5138722031695424454, "kills": 945, "rng": 2127339254})


func test_greatsword_mines() -> void:
	_check(&"cracked_mines", &"greatsword", -4, 0,
			{"deaths": 0, "events": 27966, "food": 559, "hash": 2838294413621131168, "kills": 1248, "rng": 4057641873})


func test_dual_mines() -> void:
	_check(&"cracked_mines", &"dual", -4, 0,
			{"deaths": 0, "events": 36290, "food": 742, "hash": 5971097916550848884, "kills": 881, "rng": 3156943746})


func test_weak_gear_sword_shield() -> void:
	_check(&"cracked_mines", &"sword_shield", -4, 4,
			{"deaths": 157, "events": 15377, "food": 30, "hash": 6185219295258474572, "kills": 387, "rng": 3191412544}, 30)


func test_weak_gear_dual() -> void:
	_check(&"whisper_wood", &"dual", -4, 3,
			{"deaths": 188, "events": 16495, "food": 50, "hash": 8800156141418015176, "kills": 335, "rng": 467379930}, 20)  # M31: the start kit gives 30 rations instead of 20: 20 + 30 = the 50 pieces of food of the expected numbers
