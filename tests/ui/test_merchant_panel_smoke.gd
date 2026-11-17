extends GutTest
## Smoke test of the Mercante tab of a production page (real data, TestFactory session, never a real slot): the entry in the
## list, the rows of the vendor, a refused buy with its reason, a bought scheme that is then learned, reagents in bulk.

const SCENE: PackedScene = preload("res://ui/pages/skill/skill_page.tscn")
const SKILL: StringName = &"forging"

var _session: GameSession
var _page: SkillPage


func before_each() -> void:
	_session = TestFactory.session(1234, TestFactory.real_data())
	TestFactory.learn_discipline(_session, SKILL)


func after_each() -> void:
	if is_instance_valid(_page):
		_page.free()
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func test_merchant_page_lists_schemes_and_reagents_and_buys() -> void:
	_open()
	var entry: Button = _page.find_child("Page_merchant", true, false) as Button
	assert_not_null(entry, "the Mercante entry in the list")
	entry.pressed.emit()
	var panel: MerchantPanel = _page.find_child("MerchantPanel", true, false) as MerchantPanel
	assert_true(panel.visible)
	var scheme_entry: ShopEntryDef = _first_scheme()
	var row: Node = panel.find_child("Row_%s" % scheme_entry.id, true, false)
	assert_not_null(row, "a row per scheme")
	var buy: Button = row.find_child("BuyButton", true, false) as Button
	assert_true(buy.disabled, "no gold or level: the button is disabled with a reason")
	assert_ne(buy.tooltip_text, "")
	TestFactory.set_level(_session, SKILL, 99)
	_session.wallet.add_gold(1000000)
	assert_false(buy.disabled, "buyable once level and gold are there")
	buy.pressed.emit()
	assert_eq(_session.bank.get_count(scheme_entry.effect_item.item_id), 1, "the scheme is in the Deposit")
	var learn: Button = row.find_child("LearnButton", true, false) as Button
	assert_true(learn.visible, "Impara ora after the purchase")
	learn.pressed.emit()
	assert_true(_session.disciplines.knows_recipe(_session.data.item(scheme_entry.effect_item.item_id).recipe_action))
	assert_false(learn.visible)


func test_reagents_are_bought_in_bulk() -> void:
	_open()
	TestFactory.set_level(_session, SKILL, 99)
	_session.wallet.add_gold(1000000)
	(_page.find_child("Page_merchant", true, false) as Button).pressed.emit()
	var panel: MerchantPanel = _page.find_child("MerchantPanel", true, false) as MerchantPanel
	var entry: ShopEntryDef = null
	for candidate: ShopEntryDef in _session.data.shop_entries_of_vendor(&"fabbro"):
		if candidate.effect_item != null and _session.data.item(candidate.effect_item.item_id).category == &"reagent":
			entry = candidate
			break
	var ten: Button = panel.find_child("Row_%s" % entry.id, true, false).find_child("BuyButton_10", true, false) as Button
	assert_false(ten.disabled)
	ten.pressed.emit()
	assert_eq(_session.bank.get_count(entry.effect_item.item_id), 10 * entry.effect_item.qty)


func _first_scheme() -> ShopEntryDef:
	for entry: ShopEntryDef in _session.data.shop_entries_of_vendor(&"fabbro"):
		if entry.effect_item != null and _session.data.item(entry.effect_item.item_id).category == &"recipe":
			return entry
	return null


func _open() -> void:
	_page = SCENE.instantiate() as SkillPage
	_page.page_id = StringName("skill:%s" % SKILL)
	var host: Control = autofree(Control.new())
	host.size = Vector2(1600, 900)
	add_child(host)
	host.add_child(_page)
	_page.bind(_session)
