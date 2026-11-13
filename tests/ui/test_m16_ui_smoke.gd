extends GutTest
## M16-03..06 smoke tests: dead enemies leave the screen with a Monolith, item and monster levels, owned products and the
## "Bonus" summary on the skill cards, the working dot in the menu, the Pieces tab of the Deposit and the two reports of the
## player (refined piece stats, finished Masterwork) checked on the Equipment page. Real data; no test on exact texts.

const COMBAT_SCENE: PackedScene = preload("res://ui/pages/combat/combat_page.tscn")
const SKILL_SCENE: PackedScene = preload("res://ui/pages/skill/skill_page.tscn")
const EQUIPMENT_SCENE: PackedScene = preload("res://ui/pages/equipment/equipment_page.tscn")
const BANK_SCENE: PackedScene = preload("res://ui/pages/bank/bank_page.tscn")
const SIDEBAR_SCENE: PackedScene = preload("res://ui/screens/main/sidebar.tscn")
const CELL_SCENE: PackedScene = preload("res://ui/pages/equipment/inventory_cell.tscn")
const SLOT_SCENE: PackedScene = preload("res://ui/components/item_slot/item_slot.tscn")
const AREA_ID: StringName = &"test_area"
const SWORD: StringName = &"emberbronze_sword"
const BODY: StringName = &"mw_body_3"

var _session: GameSession = null
var _node: Node = null


func after_each() -> void:
	if is_instance_valid(_node):
		_node.free()
	_node = null
	if is_instance_valid(_session):
		_session.free()
	_session = null
	await wait_physics_frames(1)


func _real() -> void:
	_session = TestFactory.session_no_kit(1234, TestFactory.real_data())


# --- M16-03: dead enemies and Monoliths -------------------------------------------------------------------------

func test_dead_enemies_stay_dimmed_without_a_stone_and_leave_with_one() -> void:
	_session = TestFactory.session()
	var page: CombatPage = COMBAT_SCENE.instantiate() as CombatPage
	page.page_id = &"combat"
	_node = page
	add_child(page)
	page.bind(_session)
	_session.combat.start(AREA_ID)
	page._process(0.0)
	var zone: EnemyZone = page.get_node("%EnemyZone") as EnemyZone
	var state: Dictionary = _session.combat.get_state().duplicate(true)
	var enemies: Array = state["enemies"]
	while enemies.size() < 3:
		enemies.append(enemies[0].duplicate(true))
	enemies[2]["hp"] = 0
	state["target"] = 0
	state["enemies_alive"] = enemies.size() - 1
	zone.refresh(_session, state)
	assert_true(zone.queue_card(2).visible, "without a Monolith the dead one stays, dimmed")
	state["stone"] = {"since": 0, "pending": false}
	zone.refresh(_session, state)
	assert_false(zone.queue_card(2).visible, "with a Monolith the dead one is gone")
	assert_true(zone.queue_card(1).visible, "the living ones stay")


# --- M16-04: levels ---------------------------------------------------------------------------------------------

func test_piece_cell_shows_the_item_level_and_the_monster_level_is_in_the_tag() -> void:
	_real()
	var uid: int = TestFactory.give_piece(_session, SWORD, &"common", 7)
	var cell: InventoryCell = CELL_SCENE.instantiate() as InventoryCell
	_node = cell
	add_child(cell)
	cell.set_piece(_session.armory.get_instance(uid), _session.data.item(SWORD), false)
	assert_ne(LevelBadge.text_of(cell), "", "the piece shows its level")
	assert_string_contains(LevelBadge.text_of(cell), "7")
	var monster_id: StringName = &"plains_boar"
	assert_gt(EnemyView.level_of(_session.data, monster_id), 0)
	assert_string_contains(EnemyView.tag_text(_session.data, monster_id, &"blade"), "Liv %d" % EnemyView.level_of(_session.data, monster_id))
	assert_eq(EnemyView.level_of(_session.data, &"no_such_monster"), 0)


func test_item_cell_shows_the_equipment_level_of_the_definition() -> void:
	_real()
	var def: ItemDef = _session.data.item(SWORD)
	var cell: ItemSlotView = SLOT_SCENE.instantiate() as ItemSlotView
	_node = cell
	add_child(cell)
	cell.set_item(def, 1)
	var level: int = ItemSlotView.equip_level(def)
	assert_eq(LevelBadge.text_of(cell) != "", level > 0)
	cell.set_item(_session.data.item(&"redbirch_log"), 5)
	assert_eq(LevelBadge.text_of(cell), "", "a material has no equipment level")


# --- M16-05: skill cards ----------------------------------------------------------------------------------------

func _open_skill(skill: StringName) -> SkillPage:
	var page: SkillPage = SKILL_SCENE.instantiate() as SkillPage
	page.page_id = StringName("skill:%s" % skill)
	_node = page
	add_child(page)
	page.bind(_session)
	return page


func test_craft_card_shows_owned_products_and_bonus_tag_holds_the_mastery_lines() -> void:
	_real()
	var action: ActionDef = null
	for candidate: ActionDef in _session.data.actions_for_skill(&"forging"):
		if candidate.mastery and not candidate.inputs.is_empty() and not candidate.outputs.is_empty() \
				and not _session.data.item(candidate.outputs[0].item_id).is_equippable():
			action = candidate
			break
	assert_not_null(action, "forging has a craft with mastery")
	if action == null:
		return
	var product: StringName = action.outputs[0].item_id
	TestFactory.give(_session, product, 37)
	var page: SkillPage = _open_skill(&"forging")
	var card: Node = page.find_child(String(action.id).to_pascal_case(), true, false)
	var label: Label = card.find_child("Product%sLabel" % String(product).to_pascal_case(), true, false) as Label
	assert_not_null(label)
	assert_string_contains(label.text, "37")
	var tag: MasteryBonusTag = card.find_child("BonusTag", true, false) as MasteryBonusTag
	assert_not_null(tag)
	assert_false(tag is BaseButton and tag.text.is_empty())
	assert_string_contains(tag.summary_text(), MasteryStepRow.NONE_TEXT)
	var step_row: Node = card.find_child("MasteryStepRow", true, false)
	assert_true(step_row.get_parent().get_parent() is PopupPanel, "the lines moved into the summary popup")


func test_gathering_card_summary_lists_the_resource_milestones() -> void:
	_real()
	var action: ActionDef = null
	for candidate: ActionDef in _session.data.actions_for_skill(&"forestry"):
		if candidate.mastery and not candidate.milestones.is_empty():
			action = candidate
			break
	assert_not_null(action)
	if action == null:
		return
	var page: SkillPage = _open_skill(&"forestry")
	var tag: MasteryBonusTag = page.find_child(String(action.id).to_pascal_case(), true, false) \
			.find_child("BonusTag", true, false) as MasteryBonusTag
	assert_string_contains(tag.summary_text(), MasteryBonusTag.MILESTONES_TITLE)


# --- M16-06: working dot, Pieces tab ----------------------------------------------------------------------------

func test_menu_dot_follows_combat_and_skill_work() -> void:
	_session = TestFactory.session()
	var sidebar: Sidebar = SIDEBAR_SCENE.instantiate() as Sidebar
	_node = sidebar
	add_child(sidebar)
	sidebar.bind(_session, func(_id: StringName) -> bool: return true)
	assert_false(sidebar.is_working(&"combat"))
	_session.combat.start(AREA_ID)
	assert_true(sidebar.is_working(&"combat"))
	_session.combat.stop()
	assert_false(sidebar.is_working(&"combat"))
	var skill: SkillDef = _session.data.skills_by_category(&"gathering")[0]
	var action: ActionDef = _session.data.actions_for_skill(skill.id)[0]
	var started: CommandResult = _session.actions.start(skill.id, action.id)
	assert_true(started.ok, "start: %s" % started.reason)
	assert_true(sidebar.is_working(StringName("skill:%s" % skill.id)))
	_session.actions.stop()
	assert_false(sidebar.is_working(StringName("skill:%s" % skill.id)))


func test_pieces_tab_shows_waiting_and_armory_pieces_without_copies() -> void:
	_real()
	var uid: int = TestFactory.give_piece(_session, SWORD)
	var waiting: ItemInstance = ItemInstance.new()
	waiting.base_id = SWORD
	waiting.rarity = &"common"
	_session.combat.loot.add_piece(waiting)
	var bank: BankPage = BANK_SCENE.instantiate() as BankPage
	_node = bank
	add_child(bank)
	bank.bind(_session)
	var tabs: DepositTabs = bank.get_node("%DepositTabs") as DepositTabs
	var section: Control = tabs.find_child("PendingSection", true, false) as Control
	assert_true(section.visible)
	assert_eq(tabs.find_child("PendingGrid", true, false).get_child_count(), 1)
	assert_not_null(tabs.equipment_grid().get_node_or_null(DepositTabs.PIECE_CELL_NAME % uid))
	assert_eq(_session.armory.instances().size(), 1, "the waiting piece is not copied into the Armory")


# --- Player reports (not reproduced by the model): checked on the Equipment page ---------------------------------

func _open_equipment() -> EquipmentPage:
	var page: EquipmentPage = EQUIPMENT_SCENE.instantiate() as EquipmentPage
	_node = page
	add_child(page)
	page.bind(_session)
	return page


func test_finished_masterwork_body_appears_in_the_equipment_inventory() -> void:
	_real()
	var page: EquipmentPage = _open_equipment()
	TestFactory.set_level(_session, &"forging", BlueprintCraft.required_level(_session.data.item(&"bp_mw_body_3"), _session.data))
	TestFactory.give(_session, &"bp_mw_body_3", 1)
	for entry: ItemQty in BlueprintCraft.inputs(_session.data.item(&"bp_mw_body_3")):
		TestFactory.give(_session, entry.item_id, entry.qty)
	assert_true(_session.actions.start_blueprint(&"bp_mw_body_3").ok)
	_session.advance(int(_session.actions.blueprint_state()["duration_ms"]) + 1000)
	var pieces: Array[ItemInstance] = _session.armory.instances()
	assert_eq(pieces.size(), 1)
	if pieces.is_empty():
		return
	assert_not_null((page.get_node("%Grid") as Node).get_node_or_null(EquipmentInventory.CELL_NAME % pieces[0].uid),
			"the Masterwork piece has a cell while the page is open")


func test_refining_a_worn_piece_changes_the_stats_shown() -> void:
	_real()
	var req: Dictionary = _session.data.item(BODY).equip.requirements
	TestFactory.set_character_level(_session, int(req.get("character", 1)))
	for skill_id: StringName in req:
		if skill_id != &"character":
			TestFactory.set_level(_session, skill_id, int(req[skill_id]))
	var uid: int = TestFactory.give_piece(_session, BODY, &"rare", 1)
	assert_true(_session.equipment.equip(uid).ok)
	var page: EquipmentPage = _open_equipment()
	page._select(uid)
	var panel_stats: RichTextLabel = page.find_child("StatsLabel", true, false) as RichTextLabel
	var totals: RichTextLabel = page.get_node("%StatsText") as RichTextLabel
	var panel_before: String = panel_stats.text
	var totals_before: String = totals.text
	var price: Dictionary = Upgrade.cost(0, Upgrade.material_grade(_session.armory.get_instance(uid), _session.data), _session.data)
	_session.wallet.add_gold(int(price["gold"]) * 1000)
	TestFactory.give(_session, price["ingot"], int(price["ingots"]) * 1000)
	TestFactory.give(_session, Upgrade.SHARD_ITEM, int(price["shards"]) * 1000 + 1)
	if int(price["dust"]) > 0:
		TestFactory.give(_session, Upgrade.DUST_ITEM, int(price["dust"]) * 1000)
	for i: int in 40:
		assert_true(_session.armory.upgrade(uid).ok)
		if _session.armory.get_instance(uid).upgrade > 0:
			break
	assert_gt(_session.armory.get_instance(uid).upgrade, 0, "a refinement succeeded")
	assert_ne(panel_stats.text, panel_before, "the piece card follows the refinement (F-86 scaled modifiers)")
	assert_ne(totals.text, totals_before, "the totals follow the refinement")
