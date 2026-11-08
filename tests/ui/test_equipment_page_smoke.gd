extends GutTest
## EquipmentPage (M6-00b, the Armory and the equipment in one page) with a TestFactory session: inventory of the pieces
## not worn, filters, capacity, the doll with the 12 slots, drag highlight of the compatible slots only, drop = equip,
## right click (equip / second hand / Rimuovi), click = select, refused commands show their reason and change nothing,
## the piece panel (lock, sell), the comparison tooltip, redraw on the model signals, unbind.

const SCENE: PackedScene = preload("res://ui/pages/equipment/equipment_page.tscn")
const BLADE := &"test_blade"
const GREATSWORD := &"test_greatsword"
const SHIELD := &"test_shield"
const HELM := &"test_helm"
const HELM_HIGH := &"test_helm_high"
const HATCHET := &"unique_hatchet"  # the unique tool of the fixtures (M10): only the kit can wear it
const RATION := &"test_ration"
const DR := &"damage_reduction"
const OBSERVED: Array[StringName] = [
	&"armory_changed", &"armory_capacity_changed", &"equipment_changed", &"character_level_up",
	&"modifiers_changed", &"food_changed", &"bank_changed",
]

var _session: GameSession
var _page: EquipmentPage


func before_each() -> void:
	_session = TestFactory.session()


func after_each() -> void:
	if is_instance_valid(_page):
		_page.free()
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


# --- Layout ------------------------------------------------------------------------------------------------------

func test_the_doll_has_the_12_slots_all_empty_at_start() -> void:
	_open()
	assert_eq(_doll().slot_views().size(), 12)
	for slot: StringName in Equipment.SLOTS:
		assert_not_null(_view(slot), "slot %s" % slot)
		assert_eq(_view(slot).uid(), 0)
		assert_not_null(_view(slot).find_child("Icon", true, false).texture, "empty icon of %s" % slot)
	assert_eq(_label("%ClassLabel").text, _session.character.class_def().name)
	assert_string_contains(_label("%SetupLabel").text, "Mani nude")
	assert_eq(_label("%EmptyLabel").text, "L'Armeria è vuota: forgia o compra dei pezzi.")
	assert_eq(_label("%CapacityLabel").text, "Pezzi: 0 / %s" % NumberFormat.format_int(_session.armory.capacity()))
	assert_false(_panel().visible)


func test_slot_labels_come_from_the_slot_texts() -> void:
	_open()
	assert_eq((_view(&"weapon").find_child("SlotLabel", true, false) as Label).text, "In mano")
	assert_eq((_view(&"offhand").find_child("SlotLabel", true, false) as Label).text, "Seconda mano")
	assert_eq((_view(&"head").find_child("SlotLabel", true, false) as Label).text, "Testa")


func test_the_doll_fits_the_minimum_resolution() -> void:
	var host: Control = Control.new()
	host.size = Vector2(1020, 664)
	add_child_autofree(host)
	_page = SCENE.instantiate() as EquipmentPage
	host.add_child(_page)
	_page.bind(_session)
	await wait_physics_frames(3)
	var area: Rect2 = Rect2(Vector2.ZERO, _doll().size)
	for view: EquipmentSlotView in _doll().slot_views():
		assert_true(area.encloses(Rect2(view.position, view.size)), "slot %s inside the doll area" % view.slot())


# --- Inventory ---------------------------------------------------------------------------------------------------

func test_the_inventory_lists_only_the_pieces_not_worn_with_the_rarity_color() -> void:
	var common: int = TestFactory.give_piece(_session, HELM)
	var magic: int = TestFactory.give_piece(_session, HELM, &"magic")
	var rare: int = TestFactory.give_piece(_session, BLADE, &"rare")
	_open()
	assert_eq(_cell_uids(), [common, magic, rare])
	assert_eq(_border(common), UiStyle.RARITY_COMMON)
	assert_eq(_border(magic), UiStyle.RARITY_MAGIC)
	assert_eq(_border(rare), UiStyle.RARITY_RARE)
	assert_true(_session.equipment.equip(magic).ok)
	assert_eq(_cell_uids(), [common, rare], "a worn piece leaves the inventory (redraw on equipment_changed)")
	assert_eq(_view(&"head").uid(), magic)
	assert_eq(_label("%CapacityLabel").text,
			"Pezzi: 2 / %s (+1 indossati)" % NumberFormat.format_int(_session.armory.capacity()))
	assert_true(_session.armory.set_locked(common, true).ok)
	assert_true(_cell(common).find_child("LockMarker", true, false).visible, "redraw on armory_changed")


func test_filters_by_slot_and_rarity() -> void:
	var helm: int = TestFactory.give_piece(_session, HELM, &"magic")
	var blade: int = TestFactory.give_piece(_session, BLADE, &"rare")
	var shield: int = TestFactory.give_piece(_session, SHIELD)
	_open()
	var slot_option: OptionButton = _page.get_node("%SlotFilter") as OptionButton
	slot_option.select(_option_index(slot_option, &"weapon"))
	slot_option.item_selected.emit(slot_option.selected)
	assert_eq(_cell_uids(), [blade])
	slot_option.select(0)
	slot_option.item_selected.emit(0)
	var rarity_option: OptionButton = _page.get_node("%RarityFilter") as OptionButton
	rarity_option.select(_option_index(rarity_option, &"magic"))
	rarity_option.item_selected.emit(rarity_option.selected)
	assert_eq(_cell_uids(), [helm])
	rarity_option.select(_option_index(rarity_option, &"rare"))
	rarity_option.item_selected.emit(rarity_option.selected)
	slot_option.select(_option_index(slot_option, &"offhand"))
	slot_option.item_selected.emit(slot_option.selected)
	assert_eq(_cell_uids(), [])
	assert_eq(_label("%EmptyLabel").text, "Nessun pezzo corrisponde ai filtri.")
	assert_ne(shield, 0)


func test_a_full_armory_is_marked() -> void:
	_open()
	assert_false(_label("%FullLabel").visible)
	while _session.armory.can_add(1):
		TestFactory.give_piece(_session, HELM)
	assert_true(_label("%FullLabel").visible)
	assert_eq(_label("%FullLabel").text, "Armeria piena")


# --- Drag and drop -----------------------------------------------------------------------------------------------

func test_dragging_lights_only_the_compatible_slots() -> void:
	var helm: int = TestFactory.give_piece(_session, HELM)
	var sword: int = TestFactory.give_piece(_session, BLADE)
	var greatsword: int = TestFactory.give_piece(_session, GREATSWORD)
	var shield: int = TestFactory.give_piece(_session, SHIELD)
	var hatchet: int = TestFactory.give_piece(_session, HATCHET)
	_open()
	_page.show_drag_targets(PieceDrag.payload(helm, &""))
	assert_eq(_glowing(), [&"head"])
	_page.show_drag_targets(PieceDrag.payload(sword, &""))
	assert_eq(_glowing(), [&"weapon"], "a sword alone in the second hand has no setup")
	assert_true(_session.equipment.equip(TestFactory.give_piece(_session, BLADE)).ok)
	_page.show_drag_targets(PieceDrag.payload(sword, &""))
	assert_eq(_glowing(), [&"weapon", &"offhand"], "with a sword in hand it fits the second hand too")
	assert_true(_session.equipment.unequip(&"weapon").ok)
	_page.show_drag_targets(PieceDrag.payload(greatsword, &""))
	assert_eq(_glowing(), [&"weapon"])
	_page.show_drag_targets(PieceDrag.payload(shield, &""))
	assert_eq(_glowing(), [&"offhand"])
	_page.show_drag_targets(PieceDrag.payload(hatchet, &""))
	assert_eq(_glowing(), [&"tool_forestry"])
	_page.clear_drag_targets()
	assert_eq(_glowing(), [])


func test_requirements_and_a_missing_setup_keep_a_slot_dark() -> void:
	var high: int = TestFactory.give_piece(_session, HELM_HIGH)
	var shield: int = TestFactory.give_piece(_session, SHIELD)
	var sword: int = TestFactory.give_piece(_session, BLADE)
	_open()
	_page.show_drag_targets(PieceDrag.payload(high, &""))
	assert_eq(_glowing(), [], "character level 1 < 10")
	assert_true(_session.equipment.equip(TestFactory.give_piece(_session, GREATSWORD)).ok)
	_page.show_drag_targets(PieceDrag.payload(sword, &""))
	assert_eq(_glowing(), [&"weapon"], "with a greatsword in hand the second hand is not a target")
	_page.show_drag_targets(PieceDrag.payload(shield, &""))
	assert_eq(_glowing(), [&"offhand"], "a shield next to a greatsword: the model makes the greatsword leave")


func test_a_worn_piece_lights_nothing_and_a_dark_slot_refuses_the_drop() -> void:
	var helm: int = TestFactory.give_piece(_session, HELM)
	_open()
	assert_true(_session.equipment.equip(helm).ok)
	_page.show_drag_targets(PieceDrag.payload(helm, &"head"))
	assert_eq(_glowing(), [])
	var payload: Dictionary = PieceDrag.payload(TestFactory.give_piece(_session, HELM), &"")
	assert_false(_view(&"head")._can_drop_data(Vector2.ZERO, payload), "not lit: no drop")
	assert_false(_view(&"head")._can_drop_data(Vector2.ZERO, "not a piece"))


func test_dropping_on_a_lit_slot_equips_through_the_command() -> void:
	var helm: int = TestFactory.give_piece(_session, HELM)
	_open()
	var payload: Dictionary = PieceDrag.payload(helm, &"")
	_page.show_drag_targets(payload)
	assert_true(_view(&"head")._can_drop_data(Vector2.ZERO, payload))
	_view(&"head")._drop_data(Vector2.ZERO, payload)
	assert_eq(_session.equipment.get_uid(&"head"), helm)
	assert_eq(_view(&"head").uid(), helm)
	assert_eq(_glowing(), [], "the light goes off after the drop")
	assert_eq(_cell_uids(), [])
	assert_false(_label("%MessageLabel").visible)


func test_dropping_a_sword_on_the_second_hand() -> void:
	var first: int = TestFactory.give_piece(_session, BLADE)
	var second: int = TestFactory.give_piece(_session, BLADE)
	assert_true(_session.equipment.equip(first).ok)
	_open()
	var payload: Dictionary = PieceDrag.payload(second, &"")
	_page.show_drag_targets(payload)
	_view(&"offhand")._drop_data(Vector2.ZERO, payload)
	assert_eq(_session.equipment.get_uid(&"offhand"), second)
	assert_string_contains(_label("%SetupLabel").text, "Due spade")


func test_dragging_a_worn_piece_to_the_inventory_removes_it() -> void:
	var helm: int = TestFactory.give_piece(_session, HELM)
	assert_true(_session.equipment.equip(helm).ok)
	_open()
	var payload: Variant = _view(&"head").drag_payload()
	assert_eq(PieceDrag.uid_of(payload), helm)
	assert_eq(PieceDrag.from_of(payload), &"head")
	var scroll: InventoryScroll = _page.get_node("%Scroll") as InventoryScroll
	assert_true(scroll._can_drop_data(Vector2.ZERO, payload))
	scroll._drop_data(Vector2.ZERO, payload)
	assert_eq(_session.equipment.get_uid(&"head"), 0)
	assert_eq(_cell_uids(), [helm])
	assert_false(scroll._can_drop_data(Vector2.ZERO, PieceDrag.payload(helm, &"")), "inventory to inventory: no")


func test_an_empty_slot_has_nothing_to_drag() -> void:
	_open()
	assert_null(_view(&"head").drag_payload())


# --- Right click and selection -----------------------------------------------------------------------------------

func test_right_click_equips_in_the_natural_slot() -> void:
	var helm: int = TestFactory.give_piece(_session, HELM)
	_open()
	_click(_cell(helm), MOUSE_BUTTON_RIGHT)
	assert_eq(_session.equipment.get_uid(&"head"), helm)


func test_right_click_on_a_sword_with_a_sword_in_hand_goes_to_the_second_hand() -> void:
	var first: int = TestFactory.give_piece(_session, BLADE)
	var second: int = TestFactory.give_piece(_session, BLADE)
	_open()
	_click(_cell(first), MOUSE_BUTTON_RIGHT)
	assert_eq(_session.equipment.get_uid(&"weapon"), first, "weapon slot first")
	_click(_cell(second), MOUSE_BUTTON_RIGHT)
	assert_eq(_session.equipment.get_uid(&"offhand"), second)
	assert_eq(_session.equipment.get_uid(&"weapon"), first)
	assert_eq(EquipTargets.right_click_slot(_session, second), &"", "equipped pieces are not targets of anything")


func test_right_click_on_a_third_sword_replaces_the_weapon_and_a_greatsword_never_goes_to_the_second_hand() -> void:
	var greatsword: int = TestFactory.give_piece(_session, GREATSWORD)
	var sword: int = TestFactory.give_piece(_session, BLADE)
	_open()
	assert_eq(EquipTargets.right_click_slot(_session, greatsword), &"")
	_click(_cell(greatsword), MOUSE_BUTTON_RIGHT)
	assert_eq(_session.equipment.get_uid(&"weapon"), greatsword)
	_click(_cell(sword), MOUSE_BUTTON_RIGHT)
	assert_eq(_session.equipment.get_uid(&"weapon"), sword, "two-handed in hand: natural slot, the greatsword leaves")
	assert_eq(_session.equipment.get_uid(&"offhand"), 0)


func test_right_click_on_a_full_slot_removes_and_on_an_empty_one_does_nothing() -> void:
	var helm: int = TestFactory.give_piece(_session, HELM)
	assert_true(_session.equipment.equip(helm).ok)
	_open()
	_click(_view(&"body"), MOUSE_BUTTON_RIGHT)
	assert_false(_label("%MessageLabel").visible, "empty slot: no command, no error")
	_click(_view(&"head"), MOUSE_BUTTON_RIGHT)
	assert_eq(_session.equipment.get_uid(&"head"), 0)
	assert_true(_session.armory.has(helm))
	assert_eq(_cell_uids(), [helm])


func test_left_click_selects_and_the_panel_shows_the_piece() -> void:
	var rare: int = TestFactory.give_piece(_session, BLADE, &"rare")
	_open()
	_click(_cell(rare), MOUSE_BUTTON_LEFT)
	assert_true(_panel().visible)
	assert_eq(_panel().uid(), rare)
	assert_eq((_panel().find_child("NameLabel", true, false) as Label).text, _session.data.item(BLADE).name)
	assert_eq((_panel().find_child("NameLabel", true, false) as Label).get_theme_color("font_color"),
			UiStyle.RARITY_RARE)
	assert_eq(_session.equipment.get_uid(&"weapon"), 0, "a click only selects")
	_click(_cell(rare), MOUSE_BUTTON_RIGHT)
	_click(_view(&"weapon"), MOUSE_BUTTON_LEFT)
	assert_eq(_panel().uid(), rare, "clicking the worn piece selects it too")
	assert_true((_panel().find_child("UnequipButton", true, false) as Button).visible)


func test_panel_buttons_equip_in_hand_and_second_hand() -> void:
	var first: int = TestFactory.give_piece(_session, BLADE)
	var second: int = TestFactory.give_piece(_session, BLADE)
	_open()
	_click(_cell(first), MOUSE_BUTTON_LEFT)
	assert_eq((_button("EquipButton")).text, "In mano")
	assert_true(_button("OffhandButton").visible)
	_button("EquipButton").pressed.emit()
	_click(_cell(second), MOUSE_BUTTON_LEFT)
	_button("OffhandButton").pressed.emit()
	assert_eq(_session.equipment.get_uid(&"offhand"), second)


func test_lock_and_sell_through_the_panel() -> void:
	var helm: int = TestFactory.give_piece(_session, HELM)
	_open()
	_click(_cell(helm), MOUSE_BUTTON_LEFT)
	_button("LockButton").pressed.emit()
	assert_true(_session.armory.get_instance(helm).locked)
	assert_true(_button("SellButton").disabled)
	_button("LockButton").pressed.emit()
	assert_false(_button("SellButton").disabled)
	_button("SellButton").pressed.emit()
	assert_false(_session.armory.has(helm))
	assert_false(_panel().visible, "the sold piece closes the panel")


# --- Refused commands --------------------------------------------------------------------------------------------

func test_a_refused_equip_shows_the_reason_and_changes_nothing() -> void:
	var high: int = TestFactory.give_piece(_session, HELM_HIGH)
	_open()
	_click(_cell(high), MOUSE_BUTTON_RIGHT)
	assert_true(_label("%MessageLabel").visible)
	assert_eq(_label("%MessageLabel").text, "Requisiti non soddisfatti.")
	assert_eq(_session.equipment.get_uid(&"head"), 0)
	assert_eq(_cell_uids(), [high])


func test_a_drop_the_model_refuses_shows_the_reason() -> void:
	var helm: int = TestFactory.give_piece(_session, HELM)
	_open()
	_page._on_slot_dropped(&"weapon", helm)
	assert_eq(_label("%MessageLabel").text, "Questo pezzo non si può mettere in quello slot.")
	assert_eq(_session.equipment.get_uid(&"weapon"), 0)
	assert_eq(_session.equipment.get_uid(&"head"), 0)


func test_remove_with_a_full_armory_shows_the_reason() -> void:
	var uid: int = TestFactory.give_piece(_session, HELM)
	_session.equipment.equip(uid)
	while _session.armory.can_add(1):
		TestFactory.give_piece(_session, HELM)
	_open()
	_click(_view(&"head"), MOUSE_BUTTON_RIGHT)
	assert_eq(_session.equipment.get_uid(&"head"), uid, "nothing changed")
	assert_eq(_label("%MessageLabel").text, "L'Armeria è piena: non c'è posto per i pezzi che tornano indietro.")


func test_a_sold_or_unknown_piece_is_reported() -> void:
	_open()
	_page._on_slot_dropped(&"head", 999)
	assert_eq(_label("%MessageLabel").text, "Il pezzo non è più nell'Armeria.")


func test_combat_in_progress_refuses_the_hands_with_its_reason() -> void:
	var first: int = TestFactory.give_piece(_session, BLADE)
	var second: int = TestFactory.give_piece(_session, BLADE)
	assert_true(_session.equipment.equip(first).ok)
	assert_true(_session.combat.start(&"test_area").ok)
	_open()
	_click(_cell(second), MOUSE_BUTTON_RIGHT)
	assert_eq(_label("%MessageLabel").text, "Non puoi cambiare arma durante il combattimento.")
	assert_eq(_session.equipment.get_uid(&"offhand"), 0, "nothing changed")
	_click(_view(&"weapon"), MOUSE_BUTTON_RIGHT)
	assert_eq(_session.equipment.get_uid(&"weapon"), first)
	_session.combat.stop()


# --- Tooltip, stats, food ----------------------------------------------------------------------------------------

func test_the_tooltip_compares_with_the_piece_worn_in_the_same_slot() -> void:
	var worn: int = TestFactory.give_piece(_session, HELM)
	var candidate: int = TestFactory.give_piece(_session, HELM_HIGH)
	assert_true(_session.equipment.equip(worn).ok)
	var text: String = ArmoryTexts.tooltip_text(_session, candidate)
	assert_string_contains(text, _session.data.item(HELM_HIGH).name)
	assert_string_contains(text, "Rispetto a %s" % _session.data.item(HELM).name)
	var name: String = _session.data.stats.info(DR)["name"]
	assert_string_contains(text, "%s +2" % name)
	assert_string_contains(text, "[color=#%s]" % UiStyle.GOOD.to_html(false))
	assert_false(ArmoryTexts.tooltip_text(_session, worn).contains("Rispetto a"), "the worn piece has no comparison")
	assert_eq(ArmoryTexts.tooltip_text(_session, 999), "")


func test_the_comparison_marks_worse_values_red_and_a_shorter_interval_green() -> void:
	var greatsword: int = TestFactory.give_piece(_session, GREATSWORD)
	var sword: int = TestFactory.give_piece(_session, BLADE)
	assert_true(_session.equipment.equip(greatsword).ok)
	var text: String = ArmoryTexts.tooltip_text(_session, sword)
	assert_string_contains(text, "[color=#%s]" % UiStyle.BAD.to_html(false))
	assert_string_contains(text, "-0,8 intervallo d'attacco (s)")
	assert_true(text.contains("[color=#%s]-0,8" % UiStyle.GOOD.to_html(false)))
	assert_string_contains(text, "Assetto: Spadone → Spada")
	assert_true(ArmoryTexts.is_improvement(&"attack_interval_pct", -5.0))
	assert_false(ArmoryTexts.is_improvement(&"power_bonus", -5.0))


func test_stats_show_the_final_values_and_the_summary_keeps_the_sources() -> void:
	_open()
	assert_string_contains((_page.get_node("%StatsText") as RichTextLabel).text, "Nessun bonus attivo.")
	var uid: int = TestFactory.give_piece(_session, HELM, &"magic")
	assert_true(_session.equipment.equip(uid).ok)
	var text: String = (_page.get_node("%StatsText") as RichTextLabel).text
	var info: Dictionary = _session.data.stats.info(DR)
	assert_string_contains(text, info["name"])
	assert_string_contains(text, ItemTooltipLines.format_stat(info["format"], _session.modifiers.total(DR)))
	var summary: String = EquipmentStatsText.summary(_session)
	assert_string_contains(summary, _session.data.item(HELM).name)
	assert_string_contains(summary, "Testa")


func test_summary_shows_the_tool_scoped_to_a_skill() -> void:
	# M10: the interval modifier of a unique tool is scoped to the skill of its slot (tool_forestry -> forestry).
	_session.free()
	_session = TestFactory.session(1234, TestFactory.real_data())  # with the starting kit
	var text: String = EquipmentStatsText.summary(_session)
	assert_string_contains(text, _session.data.skill(&"forestry").name)
	assert_string_contains(text, _session.data.item(&"unique_hatchet").name)


func test_setup_source_is_shown_as_text() -> void:
	var setup: SetupDef = _session.character.class_def().setups[0]
	var expected: String = "Assetto: %s" % setup.name
	assert_eq(EquipmentStatsText.source_name(StringName("setup:%s" % setup.id), _session), expected)


func test_food_slot_shows_the_choice_the_deposit_count_and_clears_it() -> void:
	TestFactory.give(_session, RATION, 3)
	_open()
	var slot: FoodSlotView = (_page.get_node("%Doll") as EquipmentDoll).food_slot()
	assert_eq((slot.find_child("CountLabel", true, false) as Label).text, FoodSlotView.NONE_TEXT)
	assert_true(slot.clear_button().disabled)
	slot.open_requested.emit()
	assert_eq(slot.menu().item_count, 1, "one food in the Bank")
	slot.menu().id_pressed.emit(0)
	assert_eq(_session.equipment.get_food(), RATION)
	assert_eq((slot.find_child("CountLabel", true, false) as Label).text, "×3 nel deposito")
	assert_eq((slot.find_child("SlotLabel", true, false) as Label).text, _session.data.item(RATION).name)
	slot.clear_button().pressed.emit()
	assert_eq(_session.equipment.get_food(), &"")
	assert_eq(_session.bank.get_count(RATION), 3, "Togli leaves the food in the Bank")
	assert_eq((slot.find_child("CountLabel", true, false) as Label).text, FoodSlotView.NONE_TEXT)


func test_setup_follows_the_worn_weapons() -> void:
	_open()
	assert_string_contains(_label("%SetupLabel").text, "Mani nude")
	assert_true(_session.equipment.equip(TestFactory.give_piece(_session, GREATSWORD)).ok)
	assert_string_contains(_label("%SetupLabel").text, "Spadone")
	_click(_view(&"weapon"), MOUSE_BUTTON_RIGHT)
	assert_string_contains(_label("%SetupLabel").text, "Mani nude")


func test_new_pieces_appear_without_reopening_the_page() -> void:
	_open()
	var uid: int = TestFactory.give_piece(_session, HELM)
	assert_eq(_cell_uids(), [uid])


func test_unbind_disconnects_everything() -> void:
	_open()
	_page.unbind()
	for event_name: StringName in OBSERVED:
		for connection: Dictionary in Signal(_session.events, event_name).get_connections():
			assert_ne((connection["callable"] as Callable).get_object(), _page, "%s still connected" % event_name)


# --- Helpers -----------------------------------------------------------------------------------------------------

func _open() -> void:
	_page = SCENE.instantiate() as EquipmentPage
	_page.page_id = &"equipment"
	add_child(_page)
	_page.bind(_session)


func _label(path: String) -> Label:
	return _page.get_node(path) as Label


func _doll() -> EquipmentDoll:
	return _page.get_node("%Doll") as EquipmentDoll


func _view(slot: StringName) -> EquipmentSlotView:
	return _doll().slot_view(slot)


func _panel() -> PiecePanel:
	return _page.get_node("%PiecePanel") as PiecePanel


func _button(node_name: String) -> Button:
	return _panel().find_child(node_name, true, false) as Button


func _cell(uid: int) -> InventoryCell:
	return _page.find_child("Cell%d" % uid, true, false) as InventoryCell


func _cell_uids() -> Array[int]:
	var uids: Array[int] = []
	for child: Node in (_page.get_node("%Grid") as Control).get_children():
		if not child.is_queued_for_deletion():
			uids.append((child as InventoryCell).uid())
	return uids


func _glowing() -> Array[StringName]:
	var slots: Array[StringName] = []
	for slot: StringName in Equipment.SLOTS:
		if _view(slot).is_glowing():
			slots.append(slot)
	return slots


func _border(uid: int) -> Color:
	return (_cell(uid).get_theme_stylebox("panel") as StyleBoxFlat).border_color


func _option_index(option: OptionButton, metadata: StringName) -> int:
	for i: int in option.item_count:
		if option.get_item_metadata(i) == metadata:
			return i
	return -1


func _click(control: Control, button: MouseButton) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	control._gui_input(event)
