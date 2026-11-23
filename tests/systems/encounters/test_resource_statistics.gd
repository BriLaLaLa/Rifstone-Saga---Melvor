extends GutTest
## F-200, the real roll: with a fixed seed, 10,000 nodes of the Minatore in zone 3 (dry_uplands) at level 45 come out Rame / Ferro / Ferro scuro /
## Ferro nero within 2 points of 5 / 25 / 55 / 15 %. Tables of F-201 (`zone_tables.gd`).

const ZoneTables := preload("res://tests/systems/encounters/zone_tables.gd")
const NODES: int = 10000


func test_ten_thousand_nodes_follow_the_table() -> void:
	var s: GameSession = autofree(TestFactory.session_no_kit(2026, ZoneTables.data()))
	var counts: Dictionary = {}
	for _i: int in NODES:
		var action: ActionDef = EncounterCycle.pick_resource(s, &"dry_uplands", &"quarrying", 45, false)
		counts[action.id] = int(counts.get(action.id, 0)) + 1
	var expected: Dictionary = {&"quarry_emberbronze": 5.0, &"quarry_ashlead": 25.0, &"quarry_stormzinc": 55.0, &"quarry_duskcobalt": 15.0}
	for id: StringName in expected:
		assert_almost_eq(float(counts.get(id, 0)) * 100.0 / NODES, float(expected[id]), 2.0, str(id))
	assert_eq(counts.size(), 4)
