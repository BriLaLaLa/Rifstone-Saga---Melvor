extends RefCounted
## Not a test (GUT only runs `test_*.gd`): the real game data plus the `auction_house` building of docs/04_DATA_SCHEMA.md §28
## (in data/village/buildings.json since M23-03; `building()` builds a copy of it for the validator tests).

const BUILDING_ID: StringName = &"auction_house"
const SPEC: Dictionary = {
	"id": "auction_house", "name": "Casa d'Aste", "description": "Banchi dove i prezzi salgono e scendono con le vendite.",
	"icon": "coins", "order": 8, "buildable": true, "map_pos": [0.86, 0.49], "page": "auction", "unlocks_auction": true,
	"cost_spec": {"wood": [{"component": "shieldcore", "weight": 0.25}, {"component": "handle", "weight": 0.25}],
		"plate": 0.5, "food": 0, "gold_weight": 1.0},
}

## The real data (the building is in data/village/buildings.json since M23-03).
static func data() -> GameData:
	return TestFactory.real_data()


## The building as a raw dictionary, with its generated levels.
static func building(real: GameData) -> Dictionary:
	var params: Dictionary = real.balance_value("village") as Dictionary
	var result: Dictionary = SPEC.duplicate(true)
	var levels: Array = []
	for level: int in range(1, int(params["max_level"]) + 1):
		levels.append(DataValidatorVillage.levels_for(SPEC, params, level))
	result["levels"] = levels
	return result


## A new session on `data()` with the Auction House at `level` and a plain Deposit.
static func session(level: int, seed_value: int = 1234) -> GameSession:
	var result: GameSession = TestFactory.session_no_kit(seed_value, data())
	result.village.from_save({"levels": {String(BUILDING_ID): level}})
	return result

