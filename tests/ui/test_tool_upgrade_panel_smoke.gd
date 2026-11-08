extends GutTest
## ToolUpgradePanel inside the SkillPage of a gathering skill (M10-06) with a TestFactory session on the M10 fixtures
## (never a real slot): the tool with its "+N", the cost of the next step with "owned / required" and the minimum level
## read from `armory.tool_next_step`, the effects from the modifiers, refine command and refusals, the equipment page
## without Rimuovi for the tool.

const BlueprintData := preload("res://tests/systems/actions/blueprint_data.gd")
const SCENE: PackedScene = preload("res://ui/pages/skill/skill_page.tscn")
const EQUIPMENT_SCENE: PackedScene = preload("res://ui/pages/equipment/equipment_page.tscn")
const FORESTRY: StringName = &"forestry"
const SLOT: StringName = &"tool_forestry"

var _session: GameSession
var _page: Page
var _host: Control


func before_each() -> void:
	_session = TestFactory.session(1234, BlueprintData.data())


func after_each() -> void:
	if is_instance_valid(_page):
		_page.free()
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func test_panel_shows_tool_cost_and_minimum_level() -> void:
	_open_skill()
	var panel: ToolUpgradePanel = _panel()
	var uid: int = _session.armory.tool_uid(SLOT)
	var step: Dictionary = _session.armory.tool_next_step(uid)
	var inst: ItemInstance = _session.armory.get_instance(uid)
	assert_eq((panel.get_node("%ToolName") as Label).text, ArmoryTexts.piece_name(inst, _session.data.item(inst.base_id)))
	var plates: ItemQty = step["plates"]
	var texts: PackedStringArray = _lines(panel.get_node("%CostLines"))
	assert_true(texts[0].ends_with("0 / %d" % plates.qty), texts[0])
	assert_eq((panel.get_node("%MinLevelLabel") as Label).text,
			ToolUpgradeTexts.MIN_LEVEL_TEXT % NumberFormat.format_int(int(step["min_level"])))
	assert_true(panel.get_node("%UpgradeButton").visible)
	assert_gt(_lines(panel.get_node("%EffectLines")).size(), 0)


func test_refusal_is_worded_and_nothing_changes() -> void:
	_open_skill()
	var uid: int = _session.armory.tool_uid(SLOT)
	var before: int = _session.armory.get_instance(uid).upgrade
	(_panel().get_node("%UpgradeButton") as Button).pressed.emit()
	var message: Label = _page.get_node("%MessageLabel") as Label
	assert_true(message.visible)
	assert_eq(message.text, ToolUpgradeTexts.refused(_session.armory.upgrade_tool(uid).reason))
	assert_eq(_session.armory.get_instance(uid).upgrade, before)


func test_refine_pays_and_redraws() -> void:
	_open_skill()
	var uid: int = _session.armory.tool_uid(SLOT)
	var step: Dictionary = _session.armory.tool_next_step(uid)
	TestFactory.set_level(_session, FORESTRY, int(step["min_level"]))
	_session.wallet.add_gold(int(step["gold"]))
	TestFactory.give(_session, (step["plates"] as ItemQty).item_id, (step["plates"] as ItemQty).qty)
	TestFactory.give(_session, (step["handles"] as ItemQty).item_id, (step["handles"] as ItemQty).qty)
	_session.events.level_up.emit(FORESTRY, int(step["min_level"]))
	(_panel().get_node("%UpgradeButton") as Button).pressed.emit()
	assert_eq(_session.armory.get_instance(uid).upgrade, 1)
	assert_false((_page.get_node("%MessageLabel") as Label).visible)
	assert_string_contains((_panel().get_node("%ToolName") as Label).text, "+1")


func test_max_level_hides_the_button() -> void:
	_open_skill()
	var uid: int = _session.armory.tool_uid(SLOT)
	var inst: ItemInstance = _session.armory.get_instance(uid)
	assert_true(inst != null)
	for i: int in ToolUpgrade.max_level(_session.data):
		var step: Dictionary = _session.armory.tool_next_step(uid)
		TestFactory.set_level(_session, FORESTRY, int(step["min_level"]))
		_session.wallet.add_gold(int(step["gold"]))
		TestFactory.give(_session, (step["plates"] as ItemQty).item_id, (step["plates"] as ItemQty).qty)
		TestFactory.give(_session, (step["handles"] as ItemQty).item_id, (step["handles"] as ItemQty).qty)
		assert_true(_session.armory.upgrade_tool(uid).ok)
	assert_false(_panel().get_node("%UpgradeButton").visible)
	assert_eq((_panel().get_node("%NextTitle") as Label).text, ToolUpgradeTexts.MAX_TEXT)


func test_other_skills_have_their_own_panel_and_forging_has_none() -> void:
	_open_skill()
	assert_not_null(_panel())
	_page.free()
	_open_skill(&"forging")
	assert_null(_page.get_node("%Extras").get_child(0) as ToolUpgradePanel)


func test_unbind_disconnects_everything() -> void:
	var before: int = _session.events.gold_changed.get_connections().size()
	_open_skill()
	assert_gt(_session.events.gold_changed.get_connections().size(), before)
	_page.unbind()
	assert_eq(_session.events.gold_changed.get_connections().size(), before)


func test_equipment_page_shows_the_tool_without_remove() -> void:
	_page = EQUIPMENT_SCENE.instantiate() as Page
	_host = autofree(Control.new())
	_host.size = Vector2(1600, 900)
	add_child(_host)
	_host.add_child(_page)
	_page.bind(_session)
	var uid: int = _session.armory.tool_uid(SLOT)
	var panel: PiecePanel = _page.get_node("%PiecePanel") as PiecePanel
	assert_true(panel.show_piece(_session, uid))
	for node_name: String in ["UnequipButton", "LockButton", "SalvageButton", "SellButton"]:
		assert_false((panel.get_node("%" + node_name) as Control).visible, node_name)
	var slot_view: EquipmentSlotView = _page.get_node("%Doll").find_child("Slot_tool_forestry", true, false)
	assert_null(slot_view.drag_payload(), "a unique tool cannot be dragged off")
	_page.call("_on_slot_right_clicked", SLOT)
	assert_eq(_session.equipment.get_uid(SLOT), uid, "right click does not take the tool off")


func test_salvage_preview_uses_the_blueprint_components() -> void:
	var data: GameData = _session.data
	var base: ItemDef = data.item(data.blueprint_for_base(&"test_blade").blueprint.base_id) if data.has_item(
			&"test_blade") else null
	if base == null:
		pending("no test_blade in the fixtures")
		return
	var uid: int = _session.armory.create(base.id, &"common", 1)
	assert_gt(RefineTexts.salvage_lines(_session, uid).size(), 0)


func _open_skill(skill_id: StringName = FORESTRY) -> void:
	_page = SCENE.instantiate() as SkillPage
	_page.page_id = StringName(PageHost.ROUTE_SKILL + PageHost.ROUTE_SEPARATOR + skill_id)
	_host = autofree(Control.new())
	_host.size = Vector2(1600, 900)
	add_child(_host)
	_host.add_child(_page)
	_page.bind(_session)


func _panel() -> ToolUpgradePanel:
	return _page.get_node("%Extras").get_child(0) as ToolUpgradePanel


func _lines(box: Node) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for child: Node in box.get_children():
		if not child.is_queued_for_deletion():
			out.append((child as Label).text)
	return out
