extends GutTest
## ShopPage (M3-06) with a TestFactory session: one row per entry grouped by category, price from `shop.price`,
## Compra enabled exactly when `can_buy` succeeds (disabled shows the reason), missing requirements, counters,
## refresh on events, everything disconnected by unbind.

const SCENE: PackedScene = preload("res://ui/pages/shop/shop_page.tscn")
const OBSERVED: Array[StringName] = [&"shop_purchased", &"item_sold", &"gold_changed", &"bank_changed", &"level_up",
		&"character_level_up", &"deposit_changed"]

var _session: GameSession
var _page: ShopPage


func before_each() -> void:
	_session = TestFactory.session()


func after_each() -> void:
	if is_instance_valid(_page):
		_page.free()
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func test_one_row_per_entry_with_prices_from_the_shop() -> void:
	_open()
	for entry: ShopEntryDef in _session.data.shop_entries():
		assert_not_null(_row(entry.id), "row of %s" % entry.id)
		assert_eq(_row_label(entry.id, "NameLabel").text, entry.name)
		assert_eq(_row_label(entry.id, "PriceLabel").text,
				"Prezzo: %s oro" % NumberFormat.format_int(_session.shop.price(entry.id)))
	assert_eq(_label("%TitleLabel").text, "Shop")
	assert_eq(_label("%GoldLabel").text, "Oro: %s" % NumberFormat.format_int(_session.wallet.get_gold()))


func test_buy_disabled_with_reason_when_gold_is_missing() -> void:
	_open()
	var buy: Button = _buy(&"test_upgrade_1")
	assert_true(buy.disabled)
	assert_eq(_session.shop.can_buy(&"test_upgrade_1").reason, Reasons.NOT_ENOUGH_GOLD)
	assert_eq(_row_label(&"test_upgrade_1", "ReasonLabel").text, "Oro insufficiente.")
	assert_true(_row_label(&"test_upgrade_1", "ReasonLabel").visible)
	assert_eq(buy.tooltip_text, "Oro insufficiente.")


func test_buy_enabled_when_can_buy_succeeds_and_buying_updates_the_page() -> void:
	_open()
	_session.wallet.add_gold(1000)
	var gold: int = _session.wallet.get_gold()
	var price: int = _session.shop.price(&"test_upgrade_1")
	var buy: Button = _buy(&"test_upgrade_1")
	assert_false(buy.disabled, "gold event refreshed the row")
	assert_eq(_label("%GoldLabel").text, ShopPage.GOLD_TEXT % NumberFormat.format_int(gold))
	assert_false(_row_label(&"test_upgrade_1", "ReasonLabel").visible)
	buy.pressed.emit()
	assert_eq(_session.shop.purchase_count(&"test_upgrade_1"), 1)
	assert_eq(_session.wallet.get_gold(), gold - price)
	assert_true(buy.disabled)
	assert_eq(_row_label(&"test_upgrade_1", "ReasonLabel").text, "Hai già acquistato il massimo.")
	assert_eq(_row_label(&"test_upgrade_1", "CountLabel").text, "Acquisti: 1 / 1")


func test_missing_requirements_are_listed() -> void:
	_open()
	_session.wallet.add_gold(5000)
	var text: String = _row_label(&"test_upgrade_2", "RequiresLabel").text
	assert_true(text.begins_with("Richiede: "))
	assert_string_contains(text, "Miglioria di prova I")
	assert_string_contains(text, "livello 10")
	assert_string_contains(text, "livello totale 20")
	assert_true(_buy(&"test_upgrade_2").disabled)
	assert_eq(_row_label(&"test_upgrade_2", "ReasonLabel").text, "Requisiti non soddisfatti.")
	assert_false(_row_label(&"test_upgrade_1", "RequiresLabel").visible)


func test_unlimited_entry_has_no_counter_and_item_entry_fills_the_armory() -> void:
	_open()
	_session.wallet.add_gold(150)
	assert_false(_row_label(&"test_buy_hatchet", "CountLabel").visible)
	assert_true(_row_label(&"test_upgrade_1", "CountLabel").visible)
	assert_false(_buy(&"test_buy_hatchet").disabled)
	_buy(&"test_buy_hatchet").pressed.emit()
	assert_eq(_session.armory.used(), 1, "the tool is a piece of the Armory")
	assert_eq(_session.bank.get_count(&"test_blade"), 0, "not in the bank")


func test_character_requirement_is_listed_and_follows_the_level() -> void:
	_session.data.shop_entry(&"test_buy_hatchet").req_character = 5
	_open()
	_session.wallet.add_gold(500)
	assert_string_contains(_row_label(&"test_buy_hatchet", "RequiresLabel").text, "livello del personaggio 5")
	assert_true(_buy(&"test_buy_hatchet").disabled)
	_session.character.add_xp(_session.data.character_xp_table().xp_for_level(5))
	assert_false(_row_label(&"test_buy_hatchet", "RequiresLabel").visible)
	assert_false(_buy(&"test_buy_hatchet").disabled)



func test_unbind_disconnects_everything() -> void:
	_open()
	_page.unbind()
	for event_name: StringName in OBSERVED:
		var sig: Signal = Signal(_session.events, event_name)
		for connection: Dictionary in sig.get_connections():
			assert_ne((connection["callable"] as Callable).get_object(), _page, "%s still connected" % event_name)
	var shown: String = _label("%GoldLabel").text
	_session.wallet.add_gold(10)
	assert_eq(_label("%GoldLabel").text, shown, "no refresh after unbind")


func _open() -> void:
	_page = SCENE.instantiate() as ShopPage
	_page.page_id = &"shop"
	add_child(_page)
	_page.bind(_session)


func _label(path: String) -> Label:
	return _page.get_node(path) as Label


func _row(entry_id: StringName) -> Node:
	return _page.find_child("Row_%s" % entry_id, true, false)


func _row_label(entry_id: StringName, node_name: String) -> Label:
	return _row(entry_id).find_child(node_name, true, false) as Label


func _buy(entry_id: StringName) -> Button:
	return _row(entry_id).find_child("BuyButton", true, false) as Button



func test_no_slot_entries_in_the_shop() -> void:
	var shop: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/shop/shop.json"))
	for entry: Dictionary in shop["entries"]:
		assert_ne(entry["category"], "bank", "M12: the Deposit grows with bags, not with purchases")


func test_vendors_are_listed_and_empty_ones_say_coming_soon() -> void:
	_open()
	for vendor: String in DataValidatorItems.SHOP_VENDORS:
		assert_not_null(_page.find_child("Section_%s" % vendor, true, false), vendor)
	var armorer: Node = _page.find_child("Section_armaiolo", true, false)
	assert_eq((armorer.find_child("ComingSoon", true, false) as Label).text, "In arrivo")
	assert_null(_page.find_child("Section_deposito", true, false), "M12: no Deposito stall")


func test_every_real_shop_entry_has_a_vendor() -> void:
	var shop: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/shop/shop.json"))
	for entry: Dictionary in shop["entries"]:
		assert_true(DataValidatorItems.SHOP_VENDORS.has(str(entry["vendor"])), str(entry["id"]))


func test_market_stall_and_village_requirement_text() -> void:
	var real: GameSession = TestFactory.session_no_kit(7, TestFactory.real_data())
	add_child_autofree(real)
	var page: ShopPage = SCENE.instantiate()
	add_child_autofree(page)
	page.bind(real)
	assert_not_null(page.find_child("Section_mercato", true, false), "Market stall always listed")
	var required: Dictionary = {&"storehouse": 1}
	var missing: Array[String] = page.missing_village(required)
	assert_eq(missing.size(), 1, "level 0 does not satisfy the requirement")
	assert_true(missing[0].contains("1"))
	real.wallet.add_gold(300)
	TestFactory.give(real, &"redbirch_shieldcore", 20)
	TestFactory.give(real, &"emberbronze_plate", 4)
	assert_true(real.village.upgrade(&"storehouse").ok)
	assert_true(page.missing_village(required).is_empty(), "satisfied requirement shows nothing")
	page.unbind()
