extends GutTest
## F-202: `EncounterCycle.resource_odds` (nominal and effective chance, workable) and `GameData.zones_of_action` (docs/02_FORMULAS_M35B.md),
## on the tables of F-201 (`zone_tables.gd`). Zone 3 = dry_uplands: Rame 5, Ferro 25, Ferro scuro 55, Ferro nero 15.

const ZoneTables := preload("res://tests/systems/encounters/zone_tables.gd")
const Q: StringName = &"quarrying"
const Z3: StringName = &"dry_uplands"

var _data: GameData


func before_each() -> void:
	_data = ZoneTables.data()


func _row(rows: Array[Dictionary], action: StringName) -> Dictionary:
	for row: Dictionary in rows:
		if (row["action"] as ActionDef).id == action:
			return row
	return {}


func _eff(rows: Array[Dictionary]) -> Array:
	return rows.map(func(r: Dictionary) -> float: return r["pct_effective"])


func test_zone_3_at_level_25() -> void:
	var rows: Array[Dictionary] = EncounterCycle.resource_odds(_data, Z3, Q, 25)
	assert_eq(rows.size(), 4)
	assert_eq(rows.map(func(r: Dictionary) -> int: return r["pct_nominal"]), [5, 25, 55, 15])
	assert_almost_eq(float(_row(rows, &"quarry_emberbronze")["pct_effective"]), 5.9, 0.05)
	assert_almost_eq(float(_row(rows, &"quarry_ashlead")["pct_effective"]), 29.4, 0.05)
	assert_almost_eq(float(_row(rows, &"quarry_stormzinc")["pct_effective"]), 64.7, 0.05)
	assert_eq(float(_row(rows, &"quarry_duskcobalt")["pct_effective"]), 0.0)
	assert_eq(rows.map(func(r: Dictionary) -> bool: return r["workable"]), [true, true, true, false])


func test_zone_3_at_level_45_is_the_nominal_table() -> void:
	assert_eq(_eff(EncounterCycle.resource_odds(_data, Z3, Q, 45)), [5.0, 25.0, 55.0, 15.0])


func test_zone_3_at_level_5_is_all_copper() -> void:
	assert_eq(_eff(EncounterCycle.resource_odds(_data, Z3, Q, 5)), [100.0, 0.0, 0.0, 0.0])


func test_nothing_workable_gives_zero_everywhere_and_an_unknown_zone_is_empty() -> void:
	assert_eq(_eff(EncounterCycle.resource_odds(_data, &"rift_heart", Q, 1)), [0.0, 0.0, 0.0])
	assert_eq(EncounterCycle.resource_odds(_data, &"no_such_area", Q, 1).size(), 0)


func test_zones_of_action_are_ordered_by_percentage_then_by_zone_order() -> void:
	assert_eq(_data.zones_of_action(&"quarry_ashlead"), [{"area": &"whisper_wood", "pct": 58}, {"area": &"dry_uplands", "pct": 25},
			{"area": &"redrock_plains", "pct": 21}, {"area": &"cracked_mines", "pct": 5}] as Array[Dictionary])
	assert_eq(_data.zones_of_action(&"quarry_emberbronze"), [{"area": &"redrock_plains", "pct": 79}, {"area": &"whisper_wood", "pct": 26},
			{"area": &"dry_uplands", "pct": 5}] as Array[Dictionary])
	assert_eq(_data.zones_of_action(&"quarry_riftite"), [{"area": &"rift_heart", "pct": 65}, {"area": &"black_glass_desert", "pct": 15},
			{"area": &"sunken_citadel", "pct": 15}] as Array[Dictionary], "a tie: the zone of lower order first")
	assert_eq(_data.zones_of_action(&"no_such_action").size(), 0)
