extends GutTest
## BankItemPanel sale section (M3-06): slider and preview from `shop.sell_value`, "Vendi" / "Tutti tranne 1" /
## "Tutti" emit `sell_requested`, locked or valueless items cannot be sold; BankPage sends `shop.sell` and shows the
## reason of a refusal.

const PANEL_SCENE: PackedScene = preload("res://ui/pages/bank/bank_item_panel.tscn")
const PAGE_SCENE: PackedScene = preload("res://ui/pages/bank/bank_page.tscn")
const LOG := &"test_log"
const SHARD := &"rift_shard"

var _session: GameSession
var _panel: BankItemPanel
var _page: BankPage
var _sales: Array = []


func before_each() -> void:
	_session = TestFactory.session()
	_sales = []


func after_each() -> void:
	if is_instance_valid(_panel):
		_panel.free()
	if is_instance_valid(_page):
		_page.free()
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func test_slider_preview_and_buttons_emit_quantities() -> void:
	TestFactory.give(_session, LOG, 5)
	_open_panel(LOG)
	var slider: HSlider = _panel.get_node("%SellSlider")
	assert_eq(slider.max_value, 5.0)
	assert_eq(_label("%SellPreview").text, "Vendita di 1: %s oro" % _session.shop.sell_value(LOG, 1))
	slider.value = 3
	assert_eq(_label("%SellPreview").text, "Vendita di 3: %s oro" % _session.shop.sell_value(LOG, 3))
	_button("%SellButton").pressed.emit()
	_button("%SellButOneButton").pressed.emit()
	_button("%SellAllButton").pressed.emit()
	assert_eq(_sales, [[LOG, 3], [LOG, 4], [LOG, 5]])


func test_locked_item_cannot_be_sold() -> void:
	TestFactory.give(_session, LOG, 2)
	_session.bank.set_locked(LOG, true)
	_open_panel(LOG)
	assert_true(_button("%SellButton").disabled)
	assert_true(_button("%SellAllButton").disabled)
	assert_true(_label("%SellNote").visible)
	assert_eq(_label("%SellNote").text, "Sblocca l'oggetto per venderlo.")
	assert_false(_label("%SellPreview").visible)
	_session.bank.set_locked(LOG, false)
	_panel.show_item(_session, LOG)
	assert_false(_button("%SellButton").disabled)
	assert_false(_label("%SellNote").visible)


func test_valueless_item_cannot_be_sold() -> void:
	TestFactory.give(_session, SHARD, 2)
	_open_panel(SHARD)
	assert_true(_button("%SellButton").disabled)
	assert_eq(_label("%SellNote").text, "Questo oggetto non si vende.")


func test_single_item_has_no_slider_nor_all_but_one() -> void:
	TestFactory.give(_session, LOG, 1)
	_open_panel(LOG)
	assert_false((_panel.get_node("%SellSlider") as HSlider).visible)
	assert_false(_button("%SellButOneButton").visible)
	assert_false(_button("%SellAllButton").disabled)


func test_lock_button_toggles_from_the_bank_state() -> void:
	TestFactory.give(_session, LOG, 2)
	_open_panel(LOG)
	var locks: Array = []
	_panel.lock_requested.connect(func(id: StringName, locked: bool) -> void: locks.append([id, locked]))
	_button("%LockButton").pressed.emit()
	_session.bank.set_locked(LOG, true)
	_panel.show_item(_session, LOG)
	_button("%LockButton").pressed.emit()
	assert_eq(locks, [[LOG, true], [LOG, false]])


func test_page_sells_through_the_shop_and_shows_refusals() -> void:
	TestFactory.give(_session, LOG, 4)
	_page = PAGE_SCENE.instantiate() as BankPage
	add_child(_page)
	_page.bind(_session)
	var panel: BankItemPanel = _page.get_node("%ItemPanel")
	panel.show_item(_session, LOG)
	var expected: int = _session.wallet.get_gold() + _session.shop.sell_value(LOG, 3)
	(panel.get_node("%SellButOneButton") as Button).pressed.emit()
	assert_eq(_session.bank.get_count(LOG), 1)
	assert_eq(_session.wallet.get_gold(), expected)
	assert_eq(panel.item_id(), LOG, "panel stays open on the rest")
	_session.bank.set_locked(LOG, true)
	panel.sell_requested.emit(LOG, 1)
	assert_eq(_session.bank.get_count(LOG), 1, "locked: not sold")
	assert_eq((_page.get_node("%MessageLabel") as Label).text, "L'oggetto è bloccato: sbloccalo per venderlo.")
	_session.bank.set_locked(LOG, false)
	(panel.get_node("%SellAllButton") as Button).pressed.emit()
	assert_eq(panel.item_id(), &"", "panel closed when the stack is gone")


func test_equip_and_food_buttons_only_for_the_right_items() -> void:
	pending("M4-08: pezzi nell'Armeria, pagina da rifare")
	return
	TestFactory.give(_session, LOG, 1)
	TestFactory.give(_session, &"test_helm", 1)
	TestFactory.give(_session, &"test_ration", 2)
	_open_panel(LOG)
	assert_false(_button("%EquipButton").visible)
	assert_false(_button("%FoodButton").visible)
	_panel.show_item(_session, &"test_helm")
	assert_true(_button("%EquipButton").visible)
	assert_false(_button("%FoodButton").visible)
	_panel.show_item(_session, &"test_ration")
	assert_false(_button("%EquipButton").visible)
	assert_true(_button("%FoodButton").visible)
	assert_eq(_button("%FoodButton").text, "Usa come cibo")
	_session.equipment.set_food(&"test_ration")
	_panel.show_item(_session, &"test_ration")
	assert_true(_button("%FoodButton").disabled, "already the chosen food")
	assert_eq(_button("%FoodButton").text, "Cibo scelto")


func test_page_equips_and_chooses_food_through_the_model() -> void:
	pending("M4-08: pezzi nell'Armeria, pagina da rifare")
	return
	pending("M4-08: la bank non equipaggia più")
	return
	TestFactory.give(_session, &"test_helm", 1)
	TestFactory.give(_session, &"test_ration", 2)
	TestFactory.give(_session, &"test_helm_high", 1)
	_page = PAGE_SCENE.instantiate() as BankPage
	add_child(_page)
	_page.bind(_session)
	var panel: BankItemPanel = _page.get_node("%ItemPanel")
	panel.show_item(_session, &"test_helm")
	(panel.get_node("%EquipButton") as Button).pressed.emit()
	assert_eq(_session.equipment.get_item(&"head"), &"test_helm")
	assert_eq(_session.bank.get_count(&"test_helm"), 0)
	panel.show_item(_session, &"test_ration")
	(panel.get_node("%FoodButton") as Button).pressed.emit()
	assert_eq(_session.equipment.get_food(), &"test_ration")
	assert_true((panel.get_node("%FoodButton") as Button).disabled, "panel redrawn on equipment_changed")
	panel.show_item(_session, &"test_helm_high")
	(panel.get_node("%EquipButton") as Button).pressed.emit()
	assert_eq(_session.equipment.get_item(&"head"), &"test_helm", "requirement not met: nothing changed")
	assert_eq((_page.get_node("%MessageLabel") as Label).text, "Requisiti non soddisfatti.")


func _open_panel(item_id: StringName) -> void:
	_panel = PANEL_SCENE.instantiate() as BankItemPanel
	add_child(_panel)
	_panel.sell_requested.connect(func(id: StringName, qty: int) -> void: _sales.append([id, qty]))
	assert_true(_panel.show_item(_session, item_id))


func _label(path: String) -> Label:
	return _panel.get_node(path) as Label


func _button(path: String) -> Button:
	return _panel.get_node(path) as Button
