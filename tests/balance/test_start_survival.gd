extends GutTest
## Survival of the starting kit (M17-04b, docs/M16_M18.md V4): with the sword and shield of balance.json `start`, no armour, the
## starting food and rations, a hero of level 1, 5, 10 and 60 does not die in the Redrock Plains and eats at most 800 pieces
## per hour (the bands are wider than the 600 aimed at by tools/gen_areas.gd: one hour is a noisy sample).

const Sim := preload("res://tools/sim_survival.gd")
const SimCombat := preload("res://tools/sim_combat.gd")

var _data: GameData = null


func before_all() -> void:
	_data = TestFactory.real_data()


func test_plains_do_not_kill_the_starting_kit() -> void:
	var area: Object = _data.area(&"redrock_plains")
	for level: int in [1, 5, 10, 60]:
		var r: Dictionary = Sim.measure(SimCombat, _data, area, level, "start", {"seed": 4321, "hours": "2"})
		assert_eq(float(r["deaths"]), 0.0, "deaths per hour at level %d" % level)
		assert_lt(float(r["food"]), 800.0, "food per hour at level %d" % level)
		assert_gt(float(r["kills"]), 60.0, "kills per hour at level %d" % level)
