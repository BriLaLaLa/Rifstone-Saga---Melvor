extends GutTest
## ArmoryPage (M4-08) with a TestFactory session: a cell per piece of `armory.instances()` with the rarity color of
## `UiStyle`, capacity `used / capacity`, filters by slot and rarity, the piece panel (affixes, requirements, comparison
## with the worn piece) that keeps only the uid, equip / remove / lock / sell as commands with the reason of a refusal,
## the sword in the offhand, redraw on the Armory signals, unbind.

const SCENE: PackedScene = preload("res://ui/pages/armory/armory_page.tscn")
const BLADE := &"test_blade"
const HELM := &"test_helm"
const HELM_HIGH := &"test_helm_high"
const SHIELD := &"test_shield"
const OBSERVED: Array[StringName] = [
	&"armory_changed", &"armory_capacity_changed", &"equipment_changed", &"character_level_up",
]

var _session: GameSession
var _page: ArmoryPage


func before_each() -> void:
	_session = TestFactory.session()


func after_each() -> void:
	if is_instance_valid(_page):
		_page.free()
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func test_empty_armory_shows_the_message_and_the_capacity() -> void:
	_open()
	assert_eq(_cells().size(), 0)
	assert_true(_label("%EmptyLabel").visible)
	assert_eq(_label("%EmptyLabel").text, "L'Armeria è vuota: forgia o compra dei pezzi.")
	assert_eq(_label("%CapacityLabel").text, "Pezzi: 0 / %s" % NumberFormat.format_int(_session.armory.capacity()))
	assert_eq(_label("%TitleLabel").text, "Armeria")
	assert_false(_label("%FullLabel").visible)
	assert_false(_panel().visible)


func test_a_cell_per_piece_with_rarity_color_and_markers() -> void:
	var common: int = TestFactory.give_piece(_session, HELM)
	var magic: int = TestFactory.give_piece(_session, HELM, &"magic")
	var rare: int = TestFactory.give_piece(_session, BLADE, &"rare")
	_open()
	assert_eq(_cells().size(), 3)
	assert_eq(_border(common), UiStyle.RARITY_COMMON)
	assert_eq(_border(magic), UiStyle.RARITY_MAGIC)
	assert_eq(_border(rare), UiStyle.RARITY_RARE)
	assert_false(_cell(common).find_child("LockMarker", true, false).visible)
	assert_false(_cell(common).find_child("WornMarker", true, false).visible)
	_session.armory.set_locked(common, true)
	assert_true(_cell(common).find_child("LockMarker", true, false).visible, "redraw on armory_changed")
	assert_true(_session.equipment.equip(magic).ok)
	assert_true(_cell(magic).find_child("WornMarker", true, false).visible, "redraw on equipment_changed")
	assert_eq(_label("%CapacityLabel").text, "Pezzi: 2 / %s" % NumberFormat.format_int(_session.armory.capacity()),
			"a worn piece does not use a slot")


func test_click_opens_the_panel_with_name_rarity_and_requirements() -> void:
	var uid: int = TestFactory.give_piece(_session, HELM_HIGH, &"magic", 5)
	_open()
	_cell(uid).pressed.emit(uid)
	assert_true(_panel().visible)
	assert_eq(_panel().uid(), uid)
	assert_eq(_panel_label("NameLabel").text, _session.data.item(HELM_HIGH).name)
	assert_string_contains(_panel_label("SubtitleLabel").text, "Magico")
	assert_string_contains(_panel_label("SubtitleLabel").text, "Livello oggetto 5")
	var lines: String = _lines_text()
	assert_string_contains(lines, "Richiede il livello 10 del personaggio")
	assert_string_contains(lines, UiStyle.BAD.to_html(false), "unmet requirement in red")
	TestFactory.set_character_level(_session, 10)
	assert_false(_lines_text().contains(UiStyle.BAD.to_html(false)), "redraw on character_level_up")


func test_rare_piece_lists_its_affixes_with_name_and_grade() -> void:
	var uid: int = TestFactory.give_piece(_session, BLADE, &"rare", 1)
	var inst: ItemInstance = _session.armory.get_instance(uid)
	assert_gt(inst.affixes.size(), 0, "a rare piece rolls affixes")
	_open()
	_cell(uid).pressed.emit(uid)
	var lines: String = _lines_text()
	assert_string_contains(lines, "Affissi")
	assert_string_contains(lines, "Modificatori")
	for roll: AffixRoll in inst.affixes:
		assert_string_contains(lines, _session.data.affix(roll.affix_id).name)
	assert_string_contains(lines, "grado 1")


func test_panel_compares_with_the_piece_worn_in_the_slot() -> void:
	var worn: int = TestFactory.give_piece(_session, HELM)
	var candidate: int = TestFactory.give_piece(_session, HELM_HIGH)
	assert_true(_session.equipment.equip(worn).ok)
	TestFactory.set_character_level(_session, 10)
	_open()
	_cell(candidate).pressed.emit(candidate)
	var lines: String = _lines_text()
	assert_string_contains(lines, "Rispetto a %s" % _session.data.item(HELM).name)
	var stat: Dictionary = _session.data.stats.info(&"damage_reduction")
	assert_string_contains(lines, ItemTooltipLines.format_stat(stat["format"], 2.0), "4 - 2 = +2")
	_cell(worn).pressed.emit(worn)
	assert_false(_lines_text().contains("Rispetto a"), "no comparison for the worn piece itself")


func test_equip_from_the_panel_uses_the_command() -> void:
	var uid: int = TestFactory.give_piece(_session, HELM)
	_open()
	_cell(uid).pressed.emit(uid)
	assert_eq(_button("EquipButton").text, "Equipaggia")
	assert_false(_button("OffhandButton").visible)
	_button("EquipButton").pressed.emit()
	assert_eq(_session.equipment.get_uid(&"head"), uid)
	assert_true(_panel().visible, "panel stays on the piece")
	assert_false(_button("EquipButton").visible, "worn: no equip button")
	assert_true(_button("UnequipButton").visible)
	assert_string_contains(_panel_label("StateLabel").text, "Testa")
	_button("UnequipButton").pressed.emit()
	assert_eq(_session.equipment.get_uid(&"head"), 0)
	assert_true(_session.armory.has(uid))
	assert_true(_button("EquipButton").visible)


func test_sword_goes_in_hand_or_in_the_offhand() -> void:
	var first: int = TestFactory.give_piece(_session, BLADE)
	var second: int = TestFactory.give_piece(_session, BLADE)
	_open()
	_cell(first).pressed.emit(first)
	assert_eq(_button("EquipButton").text, "In mano")
	assert_true(_button("OffhandButton").visible)
	assert_eq(_button("OffhandButton").text, "Seconda mano")
	_button("EquipButton").pressed.emit()
	assert_eq(_session.equipment.get_uid(&"weapon"), first)
	_cell(second).pressed.emit(second)
	_button("OffhandButton").pressed.emit()
	assert_eq(_session.equipment.get_uid(&"offhand"), second, "a sword in the offhand")
	assert_eq(_session.equipment.setup(), &"dual_swords")
	assert_false(_label("%MessageLabel").visible)


func test_greatsword_and_shield_have_a_single_equip_button() -> void:
	var great: int = TestFactory.give_piece(_session, &"test_greatsword")
	var shield: int = TestFactory.give_piece(_session, SHIELD)
	_open()
	for uid: int in [great, shield]:
		_cell(uid).pressed.emit(uid)
		assert_eq(_button("EquipButton").text, "Equipaggia")
		assert_false(_button("OffhandButton").visible)


func test_refused_equip_shows_the_reason_and_changes_nothing() -> void:
	var uid: int = TestFactory.give_piece(_session, HELM_HIGH)
	_open()
	_cell(uid).pressed.emit(uid)
	_button("EquipButton").pressed.emit()
	assert_true(_label("%MessageLabel").visible)
	assert_eq(_label("%MessageLabel").text, "Requisiti non soddisfatti.")
	assert_eq(_session.equipment.get_uid(&"head"), 0)
	_button("LockButton").pressed.emit()
	assert_false(_label("%MessageLabel").visible, "the next successful command hides the message")


func test_lock_and_unlock_through_the_armory() -> void:
	var uid: int = TestFactory.give_piece(_session, HELM)
	_open()
	_cell(uid).pressed.emit(uid)
	assert_eq(_button("LockButton").text, "Blocca")
	_button("LockButton").pressed.emit()
	assert_true(_session.armory.get_instance(uid).locked)
	assert_eq(_button("LockButton").text, "Sblocca")
	assert_true(_button("SellButton").disabled, "a locked piece is not sold")
	assert_eq(_panel_label("SellNote").text, "Sblocca il pezzo per venderlo.")
	_button("LockButton").pressed.emit()
	assert_false(_session.armory.get_instance(uid).locked)
	assert_false(_button("SellButton").disabled)


func test_sell_gives_the_gold_and_closes_the_panel() -> void:
	var uid: int = TestFactory.give_piece(_session, HELM)
	_open()
	_cell(uid).pressed.emit(uid)
	var value: int = _session.data.item(HELM).value
	assert_eq(_button("SellButton").text, "Vendi (%s oro)" % NumberFormat.format_int(value))
	var gold: int = _session.wallet.get_gold()
	_button("SellButton").pressed.emit()
	assert_eq(_session.wallet.get_gold(), gold + value)
	assert_false(_session.armory.has(uid))
	assert_eq(_cells().size(), 0)
	assert_false(_panel().visible, "the panel closes when the piece is gone")


func test_a_worn_piece_cannot_be_sold() -> void:
	var uid: int = TestFactory.give_piece(_session, HELM)
	assert_true(_session.equipment.equip(uid).ok)
	_open()
	_cell(uid).pressed.emit(uid)
	assert_true(_button("SellButton").disabled)
	assert_eq(_panel_label("SellNote").text, "Rimuovi il pezzo per venderlo.")


func test_filters_by_slot_and_rarity() -> void:
	var helm: int = TestFactory.give_piece(_session, HELM)
	var blade: int = TestFactory.give_piece(_session, BLADE, &"magic")
	var rare_helm: int = TestFactory.give_piece(_session, HELM, &"rare")
	_open()
	var slot_option: OptionButton = _page.get_node("%SlotFilter")
	var rarity_option: OptionButton = _page.get_node("%RarityFilter")
	assert_eq(slot_option.item_count, Equipment.SLOTS.size() + 1)
	assert_eq(slot_option.get_item_text(0), "Tutti gli slot")
	assert_eq(rarity_option.get_item_text(0), "Tutte le rarità")
	slot_option.item_selected.emit(_slot_index(&"head"))
	assert_eq(_cell_uids(), [helm, rare_helm])
	rarity_option.item_selected.emit(_rarity_index(&"rare"))
	assert_eq(_cell_uids(), [rare_helm])
	slot_option.item_selected.emit(0)
	rarity_option.item_selected.emit(0)
	assert_eq(_cell_uids(), [helm, blade, rare_helm])
	slot_option.item_selected.emit(_slot_index(&"body"))
	assert_eq(_cells().size(), 0)
	assert_eq(_label("%EmptyLabel").text, "Nessun pezzo corrisponde ai filtri.")


func test_full_armory_is_marked() -> void:
	while _session.armory.can_add(1):
		TestFactory.give_piece(_session, HELM)
	_open()
	assert_true(_label("%FullLabel").visible)
	assert_eq(_label("%FullLabel").text, "Armeria piena")


func test_close_button_empties_the_panel() -> void:
	var uid: int = TestFactory.give_piece(_session, HELM)
	_open()
	_cell(uid).pressed.emit(uid)
	assert_true(_panel().visible)
	_page.find_child("CloseButton", true, false).pressed.emit()
	assert_false(_panel().visible)
	assert_eq(_panel().uid(), 0)


func test_new_pieces_appear_without_reopening_the_page() -> void:
	_open()
	var uid: int = TestFactory.give_piece(_session, HELM)
	assert_not_null(_cell(uid), "armory_changed added")


func test_unbind_disconnects_everything() -> void:
	_open()
	for event_name: StringName in OBSERVED:
		assert_gt(Signal(_session.events, event_name).get_connections().size(), 0, "%s connected" % event_name)
	_page.unbind()
	for event_name: StringName in OBSERVED:
		for connection: Dictionary in Signal(_session.events, event_name).get_connections():
			assert_ne((connection["callable"] as Callable).get_object(), _page, "%s still connected" % event_name)


func _open() -> void:
	_page = SCENE.instantiate() as ArmoryPage
	_page.page_id = &"armory"
	add_child(_page)
	_page.bind(_session)


func _label(path: String) -> Label:
	return _page.get_node(path) as Label


func _panel() -> ArmoryItemPanel:
	return _page.get_node("%ItemPanel") as ArmoryItemPanel


func _panel_label(node_name: String) -> Label:
	return _panel().find_child(node_name, true, false) as Label


func _button(node_name: String) -> Button:
	return _panel().find_child(node_name, true, false) as Button


func _lines_text() -> String:
	return (_panel().find_child("LinesLabel", true, false) as RichTextLabel).text


func _cell(uid: int) -> ArmoryCell:
	return _page.find_child("Cell%d" % uid, true, false) as ArmoryCell


func _cells() -> Array[Node]:
	return (_page.get_node("%Grid") as Container).get_children()


func _cell_uids() -> Array[int]:
	var uids: Array[int] = []
	for cell: Node in _cells():
		uids.append((cell as ArmoryCell).uid())
	return uids


func _border(uid: int) -> Color:
	return (_cell(uid).get_theme_stylebox("panel") as StyleBoxFlat).border_color


func _slot_index(slot: StringName) -> int:
	return Equipment.SLOTS.find(slot) + 1


func _rarity_index(rarity: StringName) -> int:
	return ItemInstance.RARITIES.find(rarity) + 1


func test_window_panel_variation_is_opaque_and_rarity_colors_come_from_the_style() -> void:
	var box: StyleBoxFlat = UiThemeBuilder.build().get_stylebox("panel", "WindowPanel") as StyleBoxFlat
	assert_not_null(box, "WindowPanel is a flat opaque box")
	if box != null:
		assert_eq(box.bg_color.a, 1.0)
	assert_eq(UiStyle.rarity_color(&"magic"), UiStyle.RARITY_MAGIC)
	assert_eq(UiStyle.rarity_color(&"nonsense"), UiStyle.RARITY_UNKNOWN)
