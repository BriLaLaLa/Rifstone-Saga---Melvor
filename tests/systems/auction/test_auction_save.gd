extends GutTest
## Save of the Auction House (docs/05_INTERFACES.md §5.30, §6): `modules.auction`, the round trip, the tolerant load, the additive key.

const AuctionTestData := preload("res://tests/systems/auction/auction_test_data.gd")
const LOG: StringName = &"redbirch_log"
const GRIP: StringName = &"redbirch_grip"
const PLATE: StringName = &"riftite_plate"

var _s: GameSession
var _house: AuctionHouse


func before_each() -> void:
	_s = AuctionTestData.session(8)
	add_child_autofree(_s)
	_house = _s.auction


func _loaded(d: Dictionary) -> AuctionHouse:
	_house.from_save(d)
	return _house


func _items(d: Dictionary) -> Dictionary:
	return d["items"] as Dictionary


func test_a_new_market_saves_only_the_header() -> void:
	var d: Dictionary = _house.to_save()
	assert_eq(d["seed"], 1235)
	assert_eq(d["block"], 0)
	assert_eq(d["pending_ms"], 0)
	assert_eq(_items(d), {}, "everything at rest: nothing to save")


func test_only_items_away_from_rest_are_saved_with_the_keys_that_differ() -> void:
	TestFactory.give(_s, LOG, 100)
	_house.sell(LOG, 100)
	_s.wallet.add_gold(100000)
	_house.buy(PLATE, 3)
	_house.buy(GRIP, 1)
	var items: Dictionary = _items(_house.to_save())
	assert_eq(items["redbirch_log"], {"sat": 25000})
	assert_eq(items["riftite_plate"], {"stock": 7})
	assert_eq(items["redbirch_grip"], {"stock": 499})
	assert_eq(items.size(), 3)
	_house.advance(12 * 3600000)
	assert_eq(_items(_house.to_save()), {}, "after 12 hours everything is back at rest and leaves the save")


func test_round_trip_through_json_gives_the_same_prices_and_stock() -> void:
	TestFactory.give(_s, LOG, 500)
	TestFactory.give(_s, GRIP, 50)
	_house.sell(LOG, 500)
	_house.sell(GRIP, 40)
	_s.wallet.add_gold(100000)
	_house.buy(PLATE, 4)
	_house.advance(7 * 300000 + 1234)
	var file: Dictionary = JSON.parse_string(JSON.stringify(_s.to_save(1000))) as Dictionary
	assert_true((file["modules"] as Dictionary).has("auction"))
	var other: GameSession = AuctionTestData.session(8, 777)
	add_child_autofree(other)
	assert_true(other.from_save(file).ok)
	for id: StringName in _house.listed_items():
		assert_eq(other.auction.sell_quote(id, 17), _house.sell_quote(id, 17), "%s sell" % id)
		assert_eq(other.auction.buy_quote(id, 3), _house.buy_quote(id, 3), "%s buy" % id)
		assert_eq(other.auction.stock(id), _house.stock(id), "%s stock" % id)
		assert_eq(other.auction.trend(id), _house.trend(id), "%s trend" % id)
	assert_eq(other.auction.to_save(), _house.to_save())
	other.advance(300000)
	_s.advance(300000)
	assert_eq(other.auction.to_save(), _s.to_save(2000)["modules"]["auction"], "the same clock afterwards")


func test_the_seed_is_kept_across_a_load_and_does_not_follow_the_new_generator() -> void:
	var saved: Dictionary = _house.to_save()
	var other: GameSession = AuctionTestData.session(8, 99999)
	add_child_autofree(other)
	other.auction.from_save(JSON.parse_string(JSON.stringify(saved)) as Dictionary)
	assert_eq(other.auction.to_save()["seed"], 1235)


func test_a_missing_key_is_a_new_market() -> void:
	var file: Dictionary = _s.to_save(1000)
	(file["modules"] as Dictionary).erase("auction")
	var other: GameSession = AuctionTestData.session(8, 55)
	add_child_autofree(other)
	other.auction.advance(900000)
	assert_true(other.from_save(file).ok)
	assert_eq(other.auction.to_save()["block"], 0, "the market starts again")
	assert_eq(other.auction.to_save()["seed"], 1235, "taken from the restored generator of the file (seed 1234)")
	assert_eq(_items(other.auction.to_save()), {})


func test_a_bad_seed_becomes_a_new_one() -> void:
	for bad: Variant in [null, "abc", -4, 0, 1.5, [1]]:
		var d: Dictionary = {"seed": bad, "block": 3, "pending_ms": 10, "items": {}}
		var saved: Dictionary = _loaded(d).to_save()
		assert_eq(saved["seed"], 1235, "bad seed %s" % str(bad))
		assert_eq(saved["block"], 3)
	assert_eq(_loaded({"seed": 9, "block": 0, "pending_ms": 0, "items": {}}).to_save()["seed"], 9)
	assert_eq(_loaded({"seed": 12345.0, "block": 0, "pending_ms": 0, "items": {}}).to_save()["seed"], 12345, "JSON numbers are floats")


func test_a_bad_block_or_pending_is_zero() -> void:
	for bad: Variant in [null, "x", -1, 2.5]:
		var saved: Dictionary = _loaded({"seed": 5, "block": bad, "pending_ms": bad, "items": {}}).to_save()
		assert_eq(saved["block"], 0, "bad block %s" % str(bad))
		assert_eq(saved["pending_ms"], 0)
	assert_eq(_loaded({"seed": 5, "block": 4, "pending_ms": 300000, "items": {}}).to_save()["pending_ms"], 0, "pending must be below block_ms")
	assert_eq(_loaded({"seed": 5, "block": 4, "pending_ms": 299999, "items": {}}).to_save()["pending_ms"], 299999)


func test_items_that_is_not_an_object_leaves_everything_at_rest() -> void:
	_house.advance(0)
	for bad: Variant in [null, [1, 2], "x", 3]:
		assert_eq(_items(_loaded({"seed": 5, "block": 1, "pending_ms": 0, "items": bad}).to_save()), {})


func test_unknown_or_unlisted_items_are_dropped_and_values_corrected() -> void:
	var cap: int = _s.data.auction_params().cap_ppm
	var d: Dictionary = {"seed": 5, "block": 0, "pending_ms": 0, "items": {
		"test_unknown": {"sat": 100},
		"coins": {"sat": 100},
		"redbirch_log": {"sat": 10.0 * cap, "stock": 3},
		"ashpine_log": {"sat": -5},
		"thornalder_log": {"sat": "x"},
		"riftite_plate": {"stock": 99, "sat": 250.0},
		"redbirch_grip": {"stock": -2},
		"ashpine_grip": {"stock": "many"},
		"emberbronze_plate": "nonsense",
		"duskelm_grip": {"stock": 4.5},
	}}
	var items: Dictionary = _items(_loaded(d).to_save())
	assert_false(items.has("test_unknown"))
	assert_false(items.has("coins"))
	assert_eq(items["redbirch_log"], {"sat": cap}, "above the cap -> the cap; stock on a sell-only item ignored")
	assert_false(items.has("ashpine_log"), "a negative saturation is 0: at rest")
	assert_false(items.has("thornalder_log"))
	assert_eq(items["riftite_plate"], {"sat": 250}, "stock above the maximum -> full: nothing saved")
	assert_eq(items["redbirch_grip"], {"stock": 0})
	assert_false(items.has("ashpine_grip"), "a non-integer stock -> full")
	assert_false(items.has("emberbronze_plate"))
	assert_false(items.has("duskelm_grip"))
	assert_eq(_house.stock(&"riftite_plate"), 10)
	assert_eq(_house.stock(&"redbirch_grip"), 0)
