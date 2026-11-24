extends GutTest
## AuctionHouse (docs/05_INTERFACES.md §5.30): the reasons of can_sell and can_buy in order, atomic commands, signals and their order,
## the link with the Wallet and the Deposit, the clock and the seed that takes no roll.

const AuctionTestData := preload("res://tests/systems/auction/auction_test_data.gd")
const LOG: StringName = &"redbirch_log"
const GRIP: StringName = &"redbirch_grip"
const PLATE: StringName = &"riftite_plate"
const FIRST_PLATE: StringName = &"emberbronze_plate"

var _s: GameSession
var _house: AuctionHouse
var _seen: Array = []


func before_each() -> void:
	_seen = []
	_s = AuctionTestData.session(8)
	add_child_autofree(_s)
	_house = _s.auction
	_s.events.bank_changed.connect(func(id: StringName, count: int, delta: int) -> void: _seen.append(["bank", id, count, delta]))
	_s.events.gold_changed.connect(func(gold: int, delta: int) -> void: _seen.append(["gold", gold, delta]))
	_s.events.auction_sold.connect(func(id: StringName, qty: int, gold: int) -> void: _seen.append(["sold", id, qty, gold]))
	_s.events.auction_bought.connect(func(id: StringName, qty: int, gold: int) -> void: _seen.append(["bought", id, qty, gold]))
	_s.events.auction_updated.connect(func(blocks: int) -> void: _seen.append(["updated", blocks]))
	_s.events.item_sold.connect(func(_id: StringName, _qty: int, _gold: int) -> void: _seen.append(["item_sold"]))


func test_level_and_listing() -> void:
	assert_eq(_s.data.auction_building(), &"auction_house")
	assert_eq(_house.level(), 8)
	assert_true(_house.is_open())
	assert_eq(_house.listed_items().size(), 130)
	assert_eq(_house.buyable_items().size(), 58)
	assert_eq(_house.listed_items()[0], LOG, "file order")
	assert_eq(_house.buy_level(PLATE), 8)


func test_not_built_and_without_the_building_in_the_data() -> void:
	var closed: GameSession = AuctionTestData.session(0)
	add_child_autofree(closed)
	assert_eq(closed.auction.level(), 0)
	assert_false(closed.auction.is_open())
	TestFactory.give(closed, LOG, 5)
	assert_eq(closed.auction.can_sell(LOG, 5).reason, Reasons.REQUIREMENT_NOT_MET)
	var plain: GameSession = TestFactory.session_no_kit(1, TestFactory.real_data())
	add_child_autofree(plain)
	assert_eq(plain.data.auction_building(), &"auction_house")
	assert_eq(TestFactory.fixture_data().auction_building(), &"", "the minimal fixtures have no Auction House")
	assert_eq(plain.auction.level(), 0)
	assert_eq(plain.auction.can_buy(GRIP, 1).reason, Reasons.REQUIREMENT_NOT_MET)


func test_can_sell_reasons_in_order() -> void:
	assert_eq(_house.can_sell(&"test_unknown", 0).reason, Reasons.INVALID_AMOUNT)
	assert_eq(_house.can_sell(LOG, -3).reason, Reasons.INVALID_AMOUNT)
	assert_eq(_house.can_sell(&"test_unknown", 1).reason, Reasons.UNKNOWN_ID)
	var stone: StringName = _first_of_category(&"stone")
	assert_eq(_house.can_sell(stone, 1).reason, Reasons.NOT_TRADABLE, "a stone is not traded here")
	var closed: GameSession = AuctionTestData.session(0)
	add_child_autofree(closed)
	assert_eq(closed.auction.can_sell(stone, 1).reason, Reasons.NOT_TRADABLE, "not tradable comes before the level")
	TestFactory.give(_s, LOG, 5)
	_s.bank.set_locked(LOG, true)
	assert_eq(_house.can_sell(LOG, 99).reason, Reasons.ITEM_LOCKED, "locked comes before the count")
	_s.bank.set_locked(LOG, false)
	assert_eq(_house.can_sell(LOG, 6).reason, Reasons.NOT_ENOUGH_ITEMS)
	assert_true(_house.can_sell(LOG, 5).ok)


func test_not_sellable_when_the_total_is_zero() -> void:
	var item: ItemDef = _s.data.item(LOG)
	var real_value: int = item.value
	item.value = 1  # F-177: with the value in copper the zero total needs a one-copper item (restored below)
	_s = AuctionTestData.session(8)
	add_child_autofree(_s)
	_house = _s.auction
	TestFactory.give(_s, LOG, 6000)
	assert_true(_house.sell(LOG, 5000).ok)
	assert_eq(_house.sell_quote(LOG, 1), 0, "1 copper at the minimum index rounds to 0")
	var gold: int = _s.wallet.get_gold()
	assert_eq(_house.can_sell(LOG, 1).reason, Reasons.NOT_SELLABLE)
	assert_eq(_house.sell(LOG, 1).reason, Reasons.NOT_SELLABLE)
	assert_eq(_s.wallet.get_gold(), gold)
	assert_eq(_s.bank.get_count(LOG), 1000, "nothing changed")
	item.value = real_value


func test_sell_pays_the_quote_computed_before_the_saturation() -> void:
	TestFactory.give(_s, PLATE, 100)
	var quote: int = _house.sell_quote(PLATE, 100)
	var gold: int = _s.wallet.get_gold()
	_seen.clear()
	var result: CommandResult = _house.sell(PLATE, 100)
	assert_true(result.ok)
	assert_eq(_s.wallet.get_gold(), gold, "the money goes to the Mail, not to the wallet (M27-06)")
	assert_eq(_s.mail.messages()[0]["money"], quote)
	assert_eq(_s.bank.get_count(PLATE), 0)
	assert_lt(_house.sell_quote(PLATE, 100), quote, "the price dropped")
	assert_eq(_seen, [["bank", PLATE, 0, -100], ["sold", PLATE, 100, quote]], "no gold_changed and no item_sold")


func test_selling_in_two_parts_gives_the_same_gold_within_one() -> void:
	TestFactory.give(_s, GRIP, 100)
	var start: int = _s.wallet.get_gold()
	var whole: int = _house.sell_quote(GRIP, 100)
	_house.sell(GRIP, 60)
	_house.sell(GRIP, 40)
	assert_eq(_s.wallet.get_gold(), start)
	assert_eq(_s.mail.count(), 1, "one message for the same item")
	assert_between(int(_s.mail.messages()[0]["money"]), whole - 1, whole)


func test_can_buy_reasons_in_order() -> void:
	assert_eq(_house.can_buy(&"test_unknown", 0).reason, Reasons.INVALID_AMOUNT)
	assert_eq(_house.can_buy(&"test_unknown", 1).reason, Reasons.UNKNOWN_ID)
	assert_eq(_house.can_buy(LOG, 1).reason, Reasons.NOT_TRADABLE, "a raw material cannot be bought")
	assert_eq(_house.can_buy(_first_of_category(&"stone"), 1).reason, Reasons.NOT_TRADABLE)
	var low: GameSession = AuctionTestData.session(3)
	add_child_autofree(low)
	assert_eq(low.auction.can_buy(PLATE, 1).reason, Reasons.REQUIREMENT_NOT_MET, "step 8 needs level 8")
	assert_lt(_s.wallet.get_gold(), _house.buy_quote(PLATE, 1))
	assert_eq(_house.can_buy(PLATE, 28).reason, Reasons.OUT_OF_STOCK, "availability comes before gold")
	assert_eq(_house.can_buy(PLATE, 1).reason, Reasons.NOT_ENOUGH_GOLD)
	_s.wallet.add_gold(10000000)
	assert_true(_house.can_buy(PLATE, 1).ok)


func test_buy_spends_then_adds_and_emits_in_order() -> void:
	_s.wallet.add_gold(1000000)
	var price: int = _house.buy_quote(GRIP, 20)
	var before: int = _house.available(GRIP)
	var gold: int = _s.wallet.get_gold()
	_seen.clear()
	assert_true(_house.buy(GRIP, 20).ok)
	assert_eq(_s.wallet.get_gold(), gold - price)
	assert_eq(_s.bank.get_count(GRIP), 20)
	assert_eq(_house.available(GRIP), before - 20)
	assert_eq(_seen, [["gold", gold - price, -price], ["bank", GRIP, 20, 20], ["bought", GRIP, 20, price]])


func test_buying_raises_the_price_for_the_next_buyer_and_selling_does_not_give_pieces_back() -> void:
	_s.wallet.add_gold(10000000)
	var buy_price: int = _house.buy_quote(PLATE, 1)
	var avail: int = _house.available(PLATE)
	var cost: int = _house.buy_quote(PLATE, 4)
	assert_eq(cost, 4 * buy_price, "the pay is the listed price of every piece: the same listing")
	_house.buy(PLATE, 4)
	assert_gt(_house.buy_quote(PLATE, 1), buy_price, "scarcity: the next piece is dearer")
	assert_eq(_house.available(PLATE), avail - 4)
	_house.sell(PLATE, 4)
	assert_eq(_house.available(PLATE), avail - 4, "selling does not give pieces back")


func test_a_rejected_command_changes_nothing() -> void:
	TestFactory.give(_s, PLATE, 2)
	var save: Dictionary = _house.to_save()
	var gold: int = _s.wallet.get_gold()
	assert_lt(gold, _house.buy_quote(PLATE, 1), "the start gold does not buy a plate")
	_seen.clear()
	for result: CommandResult in [_house.buy(PLATE, 1), _house.buy(PLATE, 99), _house.sell(PLATE, 3), _house.sell(LOG, 1), _house.buy(LOG, 1)]:
		assert_false(result.ok)
	assert_eq(_house.to_save(), save)
	assert_eq(_s.wallet.get_gold(), gold)
	assert_eq(_s.bank.get_count(PLATE), 2)
	assert_eq(_seen, [])


func test_bank_full_blocks_a_new_stack_but_not_an_existing_one() -> void:
	_s.wallet.add_gold(10000000)
	_house.buy(GRIP, 1)
	for def: ItemDef in _s.data.items():
		if _s.bank.free_boxes() <= 0:
			break
		if def.category != &"equipment" and def.category != &"tool" and def.category != &"map":
			_s.bank.add(def.id, 1)
	assert_eq(_s.bank.free_boxes(), 0)
	assert_eq(_house.can_buy(FIRST_PLATE, 1).reason, Reasons.BANK_FULL)
	assert_true(_house.can_buy(GRIP, 1).ok, "already in the Deposit")
	var gold: int = _s.wallet.get_gold()
	assert_eq(_house.buy(FIRST_PLATE, 1).reason, Reasons.BANK_FULL)
	assert_eq(_s.wallet.get_gold(), gold, "no gold spent")


func test_clock_emits_one_update_per_advance() -> void:
	_house.advance(100)
	assert_eq(_seen, [], "no block yet")
	_house.advance(299900)
	assert_eq(_seen, [["updated", 1]])
	_seen.clear()
	_house.advance(12 * 3600000)
	assert_eq(_seen, [["updated", 144]], "one signal for the whole advance")


func test_the_session_advances_the_market_also_when_not_built_and_with_the_combat_frozen() -> void:
	var closed: GameSession = AuctionTestData.session(0)
	add_child_autofree(closed)
	closed.advance(300000)
	assert_eq(closed.auction.to_save()["block"], 1)
	closed.advance(300000, true)
	assert_eq(closed.auction.to_save()["block"], 2, "freeze_combat does not touch the market")


func test_the_seed_comes_from_the_slot_without_consuming_a_roll() -> void:
	assert_eq(_s.auction.to_save()["seed"], 1235, "posmod(1234, 2147483647) + 1")
	assert_eq(_s.rng.seed_value(), 1234)
	var bare := RngService.new(1234)
	for i: int in 5:
		assert_eq(_s.rng.randi_range(0, 1000000), bare.randi_range(0, 1000000), "the slot generator is untouched")
	var other: GameSession = AuctionTestData.session(8, 99)
	add_child_autofree(other)
	assert_eq(other.auction.to_save()["seed"], 100)


func _first_of_category(category: StringName) -> StringName:
	for def: ItemDef in _s.data.items():
		if def.category == category:
			return def.id
	return &""
