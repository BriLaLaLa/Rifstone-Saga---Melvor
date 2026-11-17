extends GutTest
## M26-06 (docs/05_INTERFACES_M26.md §5.36): can_buy_many / buy_many and the recipe_known check. Real data (F-170, F-171).

var _session: GameSession
var _shop: Shop
var _purchased: Array = []


func before_each() -> void:
	_session = TestFactory.session_no_kit(11, TestFactory.real_data())
	add_child_autofree(_session)
	_shop = _session.shop
	_session.wallet.add_gold(5000 - _session.wallet.get_gold())
	TestFactory.learn_discipline(_session, &"forging")
	TestFactory.set_level(_session, &"forging", 30)
	_purchased = []
	_session.events.shop_purchased.connect(func(id: StringName, n: int) -> void: _purchased.append([id, n]))


func test_invalid_amount_comes_first() -> void:
	assert_eq(_shop.can_buy_many(&"nope", 0).reason, Reasons.INVALID_AMOUNT)
	assert_eq(_shop.can_buy_many(&"buy_recipe_forge_ashlead_plate", 2).reason, Reasons.INVALID_AMOUNT, "limited entry, count > 1")
	assert_eq(_shop.can_buy_many(&"nope", 1).reason, Reasons.UNKNOWN_ID)


func test_buy_many_reagents_pays_the_total_and_signals_once() -> void:
	assert_true(_shop.buy_many(&"buy_reagent_forging_1", 10).ok)
	assert_eq(_session.wallet.get_gold(), 5000 - 20, "F-171: 10 x 2 gold")
	assert_eq(_session.bank.get_count(&"reagent_forging_1"), 10)
	assert_eq(_purchased, [[&"buy_reagent_forging_1", 10]])


func test_not_enough_gold_changes_nothing() -> void:
	var result: CommandResult = _shop.buy_many(&"buy_reagent_forging_1", 3000)
	assert_eq(result.reason, Reasons.NOT_ENOUGH_GOLD)
	assert_eq(_session.wallet.get_gold(), 5000)
	assert_eq(_session.bank.get_count(&"reagent_forging_1"), 0)
	assert_true(_purchased.is_empty())


func test_requirement_comes_before_gold() -> void:
	assert_eq(_shop.can_buy_many(&"buy_reagent_forging_4", 1).reason, Reasons.REQUIREMENT_NOT_MET, "needs forging 90")


func test_buy_is_buy_many_of_one() -> void:
	assert_true(_shop.buy(&"buy_reagent_forging_1").ok)
	assert_eq(_session.bank.get_count(&"reagent_forging_1"), 1)
	assert_eq(_purchased, [[&"buy_reagent_forging_1", 1]])


func test_a_scheme_already_known_is_refused_before_gold() -> void:
	assert_true(_shop.can_buy(&"buy_recipe_forge_ashlead_plate").ok)
	TestFactory.teach_recipes(_session, &"forging")
	_session.wallet.spend(5000)
	assert_eq(_shop.can_buy(&"buy_recipe_forge_ashlead_plate").reason, Reasons.RECIPE_KNOWN)
