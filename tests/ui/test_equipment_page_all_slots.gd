extends GutTest
## EquipmentPage (M6-00b) with the real data: drag highlight, drop, right click and Rimuovi on every slot that has
## pieces in the data (10 of the 12: the data has no neck and ring pieces yet), and the four weapon setups reached with
## right clicks. A refused command shows its reason and changes nothing.

const SCENE: PackedScene = preload("res://ui/pages/equipment/equipment_page.tscn")
const PIECE_OF_SLOT: Dictionary[StringName, StringName] = {
	&"head": &"emberbronze_helm", &"body": &"emberbronze_cuirass", &"legs": &"emberbronze_greaves",
	&"feet": &"emberbronze_boots", &"hands": &"emberbronze_gauntlets", &"weapon": &"emberbronze_sword",
	&"offhand": &"emberbronze_shield", &"tool_forestry": &"emberbronze_hatchet",
	&"tool_quarrying": &"emberbronze_pick", &"tool_angling": &"emberbronze_rod",
}
const SWORD := &"emberbronze_sword"
const GREATSWORD := &"emberbronze_greatsword"
const SHIELD := &"emberbronze_shield"

var _session: GameSession
var _page: EquipmentPage


func before_each() -> void:
	_session = TestFactory.session(1234, TestFactory.real_data())


func after_each() -> void:
	if is_instance_valid(_page):
		_page.free()
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func test_the_12_slots_exist_and_neck_and_ring_never_light_up() -> void:
	_open()
	assert_eq(_doll().slot_views().size(), 12)
	for base_id: StringName in PIECE_OF_SLOT.values():
		_page.show_drag_targets(PieceDrag.payload(TestFactory.give_piece(_session, base_id), &""))
		assert_false(_view(&"neck").is_glowing())
		assert_false(_view(&"ring").is_glowing())
	for slot: StringName in [&"neck", &"ring"]:
		assert_false(_view(slot)._can_drop_data(Vector2.ZERO, PieceDrag.payload(1, &"")), "%s refuses drops" % slot)
		assert_not_null((_view(slot).find_child("Icon", true, false) as TextureRect).texture, "icon of %s" % slot)


func test_every_slot_lights_drops_and_removes() -> void:
	_open()
	for slot: StringName in PIECE_OF_SLOT:
		var uid: int = TestFactory.give_piece(_session, PIECE_OF_SLOT[slot])
		var payload: Dictionary = PieceDrag.payload(uid, &"")
		_page.show_drag_targets(payload)
		var lit: Array[StringName] = []
		for view: EquipmentSlotView in _doll().slot_views():
			if view.is_glowing():
				lit.append(view.slot())
		assert_eq(lit, [slot], "only %s lights up for %s" % [slot, PIECE_OF_SLOT[slot]])
		_view(slot)._drop_data(Vector2.ZERO, payload)
		assert_eq(_session.equipment.get_uid(slot), uid, "dropped on %s" % slot)
		assert_eq(_view(slot).uid(), uid)
		_click(_view(slot), MOUSE_BUTTON_RIGHT)
		assert_eq(_session.equipment.get_uid(slot), 0, "Rimuovi on %s" % slot)
		assert_eq(_view(slot).uid(), 0)
		_click(_cell(uid), MOUSE_BUTTON_RIGHT)
		assert_eq(_session.equipment.get_uid(slot), uid, "right click equips in %s" % slot)
		assert_false(_label("%MessageLabel").visible)


func test_the_four_setups_with_right_clicks() -> void:
	_open()
	var great: int = TestFactory.give_piece(_session, GREATSWORD)
	var sword: int = TestFactory.give_piece(_session, SWORD)
	var second: int = TestFactory.give_piece(_session, SWORD)
	var shield: int = TestFactory.give_piece(_session, SHIELD)
	_click(_cell(great), MOUSE_BUTTON_RIGHT)
	assert_string_contains(_label("%SetupLabel").text, "Spadone")
	_click(_cell(sword), MOUSE_BUTTON_RIGHT)
	assert_string_contains(_label("%SetupLabel").text, "Spada")
	assert_eq(_session.equipment.get_uid(&"weapon"), sword)
	_click(_cell(shield), MOUSE_BUTTON_RIGHT)
	assert_string_contains(_label("%SetupLabel").text, "Spada e scudo")
	_click(_view(&"offhand"), MOUSE_BUTTON_RIGHT)
	_click(_cell(second), MOUSE_BUTTON_RIGHT)
	assert_eq(_session.equipment.get_uid(&"offhand"), second, "the second sword goes to the second hand")
	assert_string_contains(_label("%SetupLabel").text, "Due spade")
	assert_eq(_session.equipment.setup_def().id, &"dual_swords")
	var text: String = ArmoryTexts.tooltip_text(_session, great)
	assert_string_contains(text, "Assetto: Due spade → Spadone")


func test_a_two_handed_weapon_drop_on_a_worn_pair_makes_the_second_hand_leave() -> void:
	_open()
	assert_true(_session.equipment.equip(TestFactory.give_piece(_session, SWORD)).ok)
	assert_true(_session.equipment.equip(TestFactory.give_piece(_session, SHIELD)).ok)
	var great: int = TestFactory.give_piece(_session, GREATSWORD)
	var payload: Dictionary = PieceDrag.payload(great, &"")
	_page.show_drag_targets(payload)
	_view(&"weapon")._drop_data(Vector2.ZERO, payload)
	assert_eq(_session.equipment.get_uid(&"weapon"), great)
	assert_eq(_session.equipment.get_uid(&"offhand"), 0)
	assert_eq(_view(&"offhand").uid(), 0)


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


func _cell(uid: int) -> InventoryCell:
	return _page.find_child("Cell%d" % uid, true, false) as InventoryCell


func _click(control: Control, button: MouseButton) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	control._gui_input(event)
