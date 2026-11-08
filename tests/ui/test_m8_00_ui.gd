extends GutTest
## M8-00: cap on the floating numbers per card, Refine / Salvage reachable at the top of the piece panel, "Slot:" label
## of the subtitle, equipment page split.

const EQUIP_SCENE: PackedScene = preload("res://ui/pages/equipment/equipment_page.tscn")
const SWORD: StringName = &"emberbronze_sword"

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


func test_numbers_per_card_are_capped_and_the_oldest_are_dropped() -> void:
	var holder := Control.new()
	holder.size = Vector2(100, 100)
	add_child_autofree(holder)
	var labels: Array[Label] = []
	for i: int in 10:
		labels.append(HitNumbers.spawn(holder, "-%d" % i, Color.WHITE, false))
		assert_lte(holder.get_child_count(), CombatTexts.MAX_HIT_NUMBERS)
	assert_eq(holder.get_child_count(), CombatTexts.MAX_HIT_NUMBERS)
	assert_eq((holder.get_child(0) as Label).text, "-%d" % (10 - CombatTexts.MAX_HIT_NUMBERS), "newest kept")
	assert_between(CombatTexts.MAX_HIT_NUMBERS, 3, 4)


func test_card_has_salvage_but_refine_moved_to_the_forge_bench() -> void:
	var uid: int = _piece()
	_open_equipment()
	_page._select(uid)
	var panel: PiecePanel = _page.get_node("%PiecePanel") as PiecePanel
	assert_true((panel.find_child("SalvageButton", true, false) as Button).is_visible_in_tree())
	assert_null(panel.find_child("RefineButton", true, false))
	assert_null(panel.find_child("RefineBox", true, false))
	assert_null(panel.find_child("CurrencyBox", true, false))


func test_unworn_piece_says_slot_not_a_state() -> void:
	var uid: int = _piece()
	_open_equipment()
	_page._select(uid)
	var sub: Label = _page.get_node("%PiecePanel").find_child("SubtitleLabel", true, false) as Label
	assert_string_contains(sub.text, "Livello oggetto")
	assert_false(sub.text.contains("+0"), "no +0 on a piece that is not refined")
	var state: Label = _page.get_node("%PiecePanel").find_child("StateLabel", true, false) as Label
	assert_false(state.text.contains("In mano"))
	_session.equipment.equip(uid)
	assert_string_contains(state.text, "Indossato")


func test_equipment_page_script_is_well_under_the_limit() -> void:
	var file := FileAccess.open("res://ui/pages/equipment/equipment_page.gd", FileAccess.READ)
	assert_lt(file.get_as_text().count("\n"), 360)


func _piece() -> int:
	var inst := ItemInstance.new()
	inst.base_id = SWORD
	inst.rarity = &"common"
	inst.ilvl = 1
	return _session.armory.add(inst)


func _open_equipment() -> void:
	_page = EQUIP_SCENE.instantiate()
	_page.page_id = &"equipment"
	add_child(_page)
	_page.bind(_session)
