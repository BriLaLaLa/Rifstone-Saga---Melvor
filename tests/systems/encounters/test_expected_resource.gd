extends GutTest
## F-203: the expected xp percentage of a node (docs/02_FORMULAS_M35B.md), as `tools/sim_encounters.gd` measures it: zone 4 (cracked_mines) at
## level 40 = 38.2%, zone 1 at level 10 = 100%. Tables of F-201 (`zone_tables.gd`).

const ZoneTables := preload("res://tests/systems/encounters/zone_tables.gd")
const SIM: GDScript = preload("res://tools/sim_encounters.gd")
const CYCLE: GDScript = preload("res://systems/encounters/encounter_cycle.gd")
const Q: StringName = &"quarrying"


func test_zone_4_at_level_40_is_38_2_percent() -> void:
	var data: GameData = ZoneTables.data()
	assert_almost_eq(float(SIM.expected_xp_pct(CYCLE, data, &"cracked_mines", Q, 40)), 38.2, 0.05)
	# the same sum by hand: weights [5, 25, 55] over 85, grey 0% / green 20% / yellow 50%
	var by_hand: float = 0.0
	for row: Dictionary in EncounterCycle.resource_odds(data, &"cracked_mines", Q, 40):
		if row["workable"]:
			by_hand += float(row["pct_effective"]) / 100.0 * float(EncounterCycle.color(data, 40, (row["action"] as ActionDef).level)["xp_pct"])
	assert_almost_eq(by_hand, 38.2, 0.05)


func test_zone_1_at_level_10_is_100_percent() -> void:
	assert_almost_eq(float(SIM.expected_xp_pct(CYCLE, ZoneTables.data(), &"redrock_plains", Q, 10)), 100.0, 0.001)


func test_nothing_workable_uses_the_fallback_color() -> void:
	assert_almost_eq(float(SIM.expected_xp_pct(CYCLE, ZoneTables.data(), &"rift_heart", Q, 1)), 100.0, 0.001, "Rame at level 1, orange")
