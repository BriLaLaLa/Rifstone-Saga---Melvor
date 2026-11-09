extends GutTest
## Armour and Barrier (F-117, F-118, M14-10): at levels 1, 50 and 90 the main defensive stat of the worn set (Armour for Plate,
## Barrier for Tessuto runico) reduces the damage of a monster of the same level by 15-55%, never reaching the cap; the
## other materials sit lower and the opposite stat of a pure set stays at 0.

const Sim := preload("res://tools/sim_m14.gd")

var _data: GameData = null


func before_all() -> void:
	_data = TestFactory.real_data()


func test_plate_armour_between_15_and_55_percent() -> void:
	for level: int in [1, 50, 90]:
		var r: Dictionary = Sim.armor_reduction(_data, level, &"plate")
		assert_between(float(r["armor_pct"]), 15.0, 55.0, "plate armour %% at level %d" % level)
		assert_eq(float(r["barrier_pct"]), 0.0, "plate has no Barrier at level %d" % level)


func test_cloth_barrier_between_15_and_55_percent() -> void:
	for level: int in [1, 50, 90]:
		var r: Dictionary = Sim.armor_reduction(_data, level, &"cloth")
		assert_between(float(r["barrier_pct"]), 15.0, 55.0, "cloth barrier %% at level %d" % level)
		assert_lt(float(r["armor_pct"]), float(r["barrier_pct"]), "cloth favours the Barrier at level %d" % level)


func test_leather_sits_between_the_two() -> void:
	for level: int in [1, 50, 90]:
		var leather: Dictionary = Sim.armor_reduction(_data, level, &"leather")
		var plate: Dictionary = Sim.armor_reduction(_data, level, &"plate")
		assert_lt(float(leather["armor_pct"]), float(plate["armor_pct"]), "leather armour below plate at level %d" % level)
		assert_gt(float(leather["barrier_pct"]), 0.0, "leather has some Barrier at level %d" % level)


func test_no_set_reaches_the_cap() -> void:
	var cap: float = float(_data.balance_value("combat.armor.cap_pct"))
	for level: int in [1, 50, 90]:
		for material: StringName in [&"plate", &"leather", &"cloth"]:
			var r: Dictionary = Sim.armor_reduction(_data, level, material)
			assert_lt(maxf(float(r["armor_pct"]), float(r["barrier_pct"])), cap, "%s at level %d" % [material, level])
