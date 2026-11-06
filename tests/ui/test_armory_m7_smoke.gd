extends GutTest
## M7-06: refine, salvage and automatic filter in the Equipment page, "+N" of a refined piece, and the Rift Stone card in
## the combat page. Equipment tests use the real data (Upgrade costs, Warding Seal); the stone test the fixtures.

const EQUIP_SCENE: PackedScene = preload("res://ui/pages/equipment/equipment_page.tscn")
const COMBAT_SCENE: PackedScene = preload("res://ui/pages/combat/combat_page.tscn")
const SWORD: StringName = &"emberbronze_sword"
const INGOT: StringName = &"emberbronze_ingot"
const SHARD: StringName = &"rift_shard"
const SOURCE: StringName = &"test:luck"
const STONE_AREA: StringName = &"test_stone_area"
const STONE: StringName = &"test_stone"

var _session: GameSession
var _page: Node


func before_each() -> void:
	_session = TestFactory.session(1234, TestFactory.real_data())


func after_each() -> void:
	if is_instance_valid(_page):
		_page.free()
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


# --- "+N" -------------------------------------------------------------------------------------------------------

func test_refined_piece_shows_plus_n_in_panel_cell_and_slot() -> void:
	var uid: int = _piece(3)
	var worn: int = _piece(2)
	_open_equipment()
	_session.equipment.equip(worn)
	_page._select(uid)
	assert_string_contains(_name_label().text, "+3")
	var cell: Node = _page.find_child("Cell%d" % uid, true, false)
	assert_eq((cell.find_child("UpgradeLabel", true, false) as Label).text, "+3")
	var slot: EquipmentSlotView = (_page.get_node("%Doll") as EquipmentDoll).slot_view(&"weapon")
	assert_string_contains((slot.find_child("SlotLabel", true, false) as Label).text, "+2")


# --- Refine -----------------------------------------------------------------------------------------------------

func test_refine_box_shows_chance_and_cost_from_the_data() -> void:
	var uid: int = _piece(0)
	_open_equipment()
	_page._select(uid)
	var box: RefineBox = _panel().find_child("RefineBox", true, false) as RefineBox
	assert_false(box.visible)
	_button("RefineButton").pressed.emit()
	assert_true(box.visible)
	var cost: Dictionary = Upgrade.cost(0, _session.data.item(SWORD).equip.grade, _session.data)
	assert_string_contains(box.title_text(), "+0")
	assert_string_contains(box.chance_text(), "95")
	assert_string_contains(box.costs_text(), _session.data.item(INGOT).name)
	assert_string_contains(box.costs_text(), NumberFormat.format_int(int(cost["gold"])))
	assert_false(box.seal_visible(), "no Seal below the downgrade level")


func test_seal_option_appears_from_the_downgrade_level() -> void:
	var uid: int = _piece(5)
	_open_equipment()
	_page._select(uid)
	_button("RefineButton").pressed.emit()
	assert_true((_panel().find_child("RefineBox", true, false) as RefineBox).seal_visible())


func test_refused_refine_shows_the_reason_and_changes_nothing() -> void:
	var uid: int = _piece(0)
	_open_equipment()
	_page._select(uid)
	_button("RefineButton").pressed.emit()
	(_panel().find_child("RefineBox", true, false) as RefineBox).confirm_button().pressed.emit()
	var message: Label = _page.get_node("%MessageLabel") as Label
	assert_true(message.visible)
	assert_eq(message.text, EquipmentMessages.refused(Reasons.NOT_ENOUGH_ITEMS))
	assert_eq(_session.armory.get_instance(uid).upgrade, 0)


func test_refine_success_updates_the_piece_and_says_so() -> void:
	_session.modifiers.set_source(SOURCE, [Modifier.make(&"upgrade_success_pct", 100.0)])
	var uid: int = _piece(0)
	_session.wallet.add_gold(100000)
	TestFactory.give(_session, INGOT, 10)
	_open_equipment()
	_page._select(uid)
	_button("RefineButton").pressed.emit()
	(_panel().find_child("RefineBox", true, false) as RefineBox).confirm_button().pressed.emit()
	assert_eq(_session.armory.get_instance(uid).upgrade, 1)
	assert_string_contains((_page.get_node("%MessageLabel") as Label).text, "riuscita")
	assert_string_contains(_name_label().text, "+1")
	assert_string_contains((_panel().find_child("RefineBox", true, false) as RefineBox).title_text(), "+1")


# --- Salvage ----------------------------------------------------------------------------------------------------

func test_salvage_asks_for_confirmation_and_pays_the_yield() -> void:
	var uid: int = _piece(2, &"rare")
	_open_equipment()
	_page._select(uid)
	var box: SalvageBox = _panel().find_child("SalvageBox", true, false) as SalvageBox
	_button("SalvageButton").pressed.emit()
	assert_true(box.visible)
	assert_string_contains(box.yields_text(), _session.data.item(SHARD).name)
	assert_true(_session.armory.has(uid), "nothing happens before the confirmation")
	box.confirm_button().pressed.emit()
	assert_false(_session.armory.has(uid))
	assert_gt(_session.bank.get_count(SHARD), 0)
	assert_false(_panel().visible)
	assert_string_contains((_page.get_node("%MessageLabel") as Label).text, "Smantellato")


func test_salvage_is_disabled_for_a_locked_or_worn_piece() -> void:
	var locked: int = _piece(0)
	var worn: int = _piece(0)
	_open_equipment()
	_session.armory.set_locked(locked, true)
	_session.equipment.equip(worn)
	_page._select(locked)
	assert_true(_button("SalvageButton").disabled)
	_page._select(worn)
	assert_true(_button("SalvageButton").disabled)


# --- Automatic filter -------------------------------------------------------------------------------------------

func test_filter_rule_is_sent_as_a_command_and_reread_at_each_opening() -> void:
	_open_equipment()
	var toggle: Button = _page.get_node("%FilterToggle") as Button
	var filter: FilterPanel = _page.get_node("%FilterPanel") as FilterPanel
	assert_false(filter.visible)
	toggle.button_pressed = true
	assert_true(filter.visible)
	assert_false((_page.get_node("%Scroll") as Control).visible)
	filter.rarity_option(&"weapon").select(1)
	filter.rarity_option(&"weapon").item_selected.emit(1)
	filter.grade_option(&"weapon").select(2)
	filter.grade_option(&"weapon").item_selected.emit(2)
	assert_eq(_session.armory.filter_rule(&"weapon"), {"min_rarity": &"magic", "min_grade": 3})
	toggle.button_pressed = false
	_session.armory.set_filter(&"head", &"rare", 4)
	toggle.button_pressed = true
	assert_eq(filter.rarity_option(&"head").selected, 2)
	assert_eq(filter.grade_option(&"head").selected, 3)
	assert_eq(filter.rarity_option(&"feet").selected, 0)


# --- Rift Stone in the combat page ------------------------------------------------------------------------------

func test_stone_card_has_the_stone_name_look_and_pulse_bar() -> void:
	_session.free()
	_session = TestFactory.session()
	_session.combat.from_save({"state": "riftstone", "area": String(STONE_AREA), "player_hp": 60,
		"player_timer_ms": 999999, "hand": 0, "between_ms": 0, "loot": [], "kills": {}, "deaths": 0, "food_eaten": 0,
		"enemies": [{"monster": String(STONE), "hp": 60, "timer_ms": 1500}], "stone": {"since": 0, "pending": false}})
	_page = COMBAT_SCENE.instantiate()
	_page.page_id = &"combat"
	add_child(_page)
	_page.bind(_session)
	_page._process(0.0)
	var zone: EnemyZone = _page.get_node("%EnemyZone") as EnemyZone
	var card: EnemyCard = zone.target_card()
	assert_true(card.visible)
	assert_true(card.is_stone())
	assert_eq(card.shown_name(), _session.data.rift_stone(STONE).name)
	assert_eq(card.shown_tag(), EnemyView.STONE_TAG_TEXT)
	assert_almost_eq(card.shown_timer(), 0.5, 0.01)
	assert_string_contains((_page.get_node("%StateLabel") as Label).text, CombatTexts.STATE_TEXTS[&"riftstone"])


# --- Helpers ----------------------------------------------------------------------------------------------------

func _piece(upgrade: int, rarity: StringName = &"common") -> int:
	var inst := ItemInstance.new()
	inst.base_id = SWORD
	inst.rarity = rarity
	inst.ilvl = 1
	inst.upgrade = upgrade
	return _session.armory.add(inst)


func _open_equipment() -> void:
	_page = EQUIP_SCENE.instantiate()
	_page.page_id = &"equipment"
	add_child(_page)
	_page.bind(_session)


func _panel() -> PiecePanel:
	return _page.get_node("%PiecePanel") as PiecePanel


func _name_label() -> Label:
	return _panel().find_child("NameLabel", true, false) as Label


func _button(node_name: String) -> Button:
	return _panel().find_child(node_name, true, false) as Button
