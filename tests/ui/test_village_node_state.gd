extends GutTest
## VillageNodeState.of (M21-03): table of the states of docs/01_GDD.md §32.

const MAX: int = 8


func test_state_table() -> void:
	var rows: Array = [
		[0, false, &"ok", &"placeholder"],
		[0, true, &"level_too_low", &"locked"],
		[0, true, &"not_enough_gold", &"unbuilt"],
		[0, true, &"not_enough_items", &"unbuilt"],
		[0, true, &"ok", &"ready"],
		[3, true, &"ok", &"ready"],
		[3, true, &"not_enough_gold", &"built"],
		[3, true, &"level_too_low", &"built"],
		[MAX, true, &"max_level", &"maxed"],
		[MAX, true, &"ok", &"maxed"],
	]
	for row: Array in rows:
		assert_eq(VillageNodeState.of(row[0], MAX, row[1], row[2]), row[3], "row %s" % [row])
