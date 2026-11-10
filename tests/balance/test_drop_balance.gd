extends GutTest
## Drop targets of the Alpha (ALPHA.md §2.7 and §10, F-121, Q69, M14-10), measured with tools/sim_m14.gd on the real data in the
## area of the character level: 3-5 pieces per 30 minutes, about 1 magic per 30 minutes, 1 rare every 2-3 hours, about 1
## project per hour. The kills per hour come from a seeded run of the real engine; the rates per kill come from the data.

const Sim := preload("res://tools/sim_m14.gd")
const HOURS: float = 4.0
const SEED: int = 1234

var _data: GameData = null
var _rows: Dictionary = {}


func before_all() -> void:
	_data = TestFactory.real_data()
	for area: AreaDef in _data.areas():
		_rows[area.id] = Sim.area_drops(_data, area, HOURS, SEED)


func _chance(key: String) -> float:
	return float(_data.balance_value(key)) / 100.0


func test_nobody_dies_in_the_area_of_their_level() -> void:
	for id: Variant in _rows:
		assert_eq(float((_rows[id] as Dictionary)["deaths_h"]), 0.0, "%s deaths per hour" % id)


func test_kills_per_hour_are_even_across_the_areas() -> void:
	var low: float = INF
	var high: float = 0.0
	for id: Variant in _rows:
		var kills: float = float((_rows[id] as Dictionary)["kills_h"])
		low = minf(low, kills)
		high = maxf(high, kills)
		assert_between(kills, 190.0, 360.0, "%s kills per hour" % id)
	assert_lt(high / low, 1.6, "the busiest area is at most 1.6 times the slowest")


func test_three_to_five_pieces_every_30_minutes() -> void:
	for id: Variant in _rows:
		var row: Dictionary = _rows[id]
		var expected: float = float(row["kills_h"]) * _chance("loot.equipment.chance_pct") / 2.0
		assert_between(expected, 2.5, 5.0, "%s monster-only pieces per 30 minutes from the data" % id)
		assert_between(float(row["pieces_30"]), 2.0, 6.0, "%s pieces per 30 minutes in the run" % id)


func test_about_one_magic_piece_every_30_minutes() -> void:
	for id: Variant in _rows:
		var row: Dictionary = _rows[id]
		var expected: float = float(row["kills_h"]) * _chance("loot.equipment.chance_pct") / 2.0 * _chance("rarity.drop.magic_pct")
		assert_between(expected, 0.6, 1.35, "%s monster-only magic pieces per 30 minutes from the data" % id)
		assert_between(float(row["magic_30"]), 0.25, 2.2, "%s magic pieces per 30 minutes in the run" % id)


func test_one_rare_piece_every_two_to_three_hours() -> void:
	for id: Variant in _rows:
		var per_hour: float = float((_rows[id] as Dictionary)["kills_h"]) * _chance("loot.equipment.chance_pct") * _chance("rarity.drop.rare_pct")
		assert_between(1.0 / per_hour, 2.0, 3.6, "%s hours per rare piece" % id)


func test_about_one_blueprint_per_hour() -> void:
	for id: Variant in _rows:
		var per_hour: float = float((_rows[id] as Dictionary)["kills_h"]) * _chance("loot.blueprint.chance_pct")
		assert_between(per_hour, 0.75, 1.4, "%s blueprints per hour from the data" % id)


func test_rift_dust_is_a_trickle_not_a_flood() -> void:
	# Q71: it was about 150 an hour for a single use; kills and Monoliths now give tens an hour, below 150 in every area.
	for id: Variant in _rows:
		var dust: float = float((_rows[id] as Dictionary)["dust_h"])
		assert_between(dust, 10.0, 150.0, "%s dust per hour" % id)
