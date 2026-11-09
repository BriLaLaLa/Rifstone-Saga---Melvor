extends GutTest
## Shop descriptions with the numbers of the data (M14-06, docs/01_GDD.md §29), real data.

const SCENE: PackedScene = preload("res://ui/pages/shop/shop_page.tscn")

var _session: GameSession


func before_each() -> void:
	_session = TestFactory.session(1234, TestFactory.real_data())


func after_each() -> void:
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func test_auto_eat_tiers_show_the_thresholds_of_the_balance() -> void:
	var tiers: Array = _session.data.balance_value("combat.auto_eat_tiers") as Array
	for index: int in 3:
		var entry: ShopEntryDef = _session.data.shop_entry(StringName("auto_eat_%d" % (index + 1)))
		var tier: Dictionary = tiers[index + 1]
		var text: String = ShopTexts.describe(entry, _session.data)
		assert_string_contains(text, "%s%%" % NumberFormat.format_number(float(tier["threshold_pct"])))
		assert_string_contains(text, "%s%%" % NumberFormat.format_number(float(tier["target_pct"])))


func test_loot_pocket_shows_the_slots_from_the_effect() -> void:
	var entry: ShopEntryDef = _session.data.shop_entry(&"loot_pocket")
	assert_eq(ShopTexts.describe(entry, _session.data),
			"Caselle della borsa del bottino: +%d" % int(entry.effect_modifiers[0].value))


func test_auto_loot_has_a_line_from_the_registry() -> void:
	var entry: ShopEntryDef = _session.data.shop_entry(&"auto_loot")
	assert_string_contains(ShopTexts.describe(entry, _session.data), "Raccolta automatica del bottino")


func test_page_shows_the_effect_line_of_every_row() -> void:
	var page: ShopPage = SCENE.instantiate() as ShopPage
	page.page_id = &"shop"
	add_child(page)
	page.bind(_session)
	for entry: ShopEntryDef in _session.data.shop_entries():
		var row: Node = page.find_child("Row_%s" % entry.id, true, false)
		var label: Label = row.find_child("EffectLabel", true, false) as Label
		assert_eq(label.text, ShopTexts.describe(entry, _session.data), String(entry.id))
	page.free()
