extends GutTest
## The `upgrade` (F-86) and `salvage` (F-88) sections of balance.json against the tables of 02_FORMULAS.md §5.
## The rules about their shape are tests of the validator (tests/core/data/test_data_validator_loot.gd).

const BALANCE_PATH: String = "res://data/config/balance.json"
const SUCCESS: Array[int] = [95, 90, 85, 75, 65, 55, 45, 35, 25]
const GOLD: Array[int] = [50, 100, 200, 400, 800, 1600, 3200, 6400, 12800]
const INGOTS: Array[int] = [1, 1, 2, 2, 3, 3, 4, 4, 5]
const SHARDS: Array[int] = [0, 0, 0, 0, 0, 5, 10, 15, 20]
const INGOT_ITEMS: Array[String] = ["emberbronze_ingot", "ashlead_ingot", "stormzinc_ingot", "duskcobalt_ingot",
	"glimmerite_ingot", "palecinnabar_ingot", "emberheart_ingot", "riftite_ingot"]

var _balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BALANCE_PATH))


func test_upgrade_table() -> void:
	var upgrade: Dictionary = _balance["upgrade"]
	var levels: Array = upgrade["levels"]
	assert_eq(levels.size(), 9, "+0 -> +9")
	for n: int in levels.size():
		var row: Dictionary = levels[n]
		assert_eq(row.size(), 4, "row %d has only the four fields" % n)
		assert_eq(int(row["success_pct"]), SUCCESS[n])
		assert_eq(int(row["gold_per_grade"]), GOLD[n])
		assert_eq(int(row["ingots"]), INGOTS[n])
		assert_eq(int(row["shards"]), SHARDS[n])


func test_upgrade_scalars() -> void:
	var upgrade: Dictionary = _balance["upgrade"]
	assert_eq(int(upgrade["downgrade_from"]), 4)
	assert_eq(int(upgrade["mod_pct_per_level"]), 10)
	assert_eq(upgrade["ingot_items"], INGOT_ITEMS)
	assert_false(str(upgrade["seal_item"]).is_empty())
	assert_eq(upgrade.size(), 5, "no other key")


func test_salvage_values() -> void:
	var salvage: Dictionary = _balance["salvage"]
	assert_eq(float(salvage["ingot_ratio"]), 0.4)
	var shards: Dictionary = salvage["shards_by_rarity"]
	assert_eq([int(shards["common"]), int(shards["magic"]), int(shards["rare"])], [0, 1, 3])
	assert_eq(salvage.size(), 2, "no other key")
