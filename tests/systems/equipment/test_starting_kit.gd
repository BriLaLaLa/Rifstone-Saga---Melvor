extends GutTest
## The starting kit (docs/01_GDD.md §1.1, 05_INTERFACES.md §5.9/§5.11/§5.17): Armory.new_game, Equipment.new_game and
## Shop.new_game on the M10 fixtures (start.armory: blade worn as weapon, greatsword kept, shield worn as offhand;
## start.tools: the three unique tools; start.purchases and start.food).

const BlueprintData := preload("res://tests/systems/actions/blueprint_data.gd")

var _data: GameData = BlueprintData.data()
var _session: GameSession = null


func before_each() -> void:
	_session = autofree(TestFactory.session(21, _data))


func test_the_armory_holds_the_kit_with_consecutive_uids() -> void:
	var bases: Array[StringName] = []
	for inst: ItemInstance in _session.armory.instances():
		bases.append(inst.base_id)
		assert_eq(inst.rarity, &"common")
		assert_true(inst.affixes.is_empty())
		assert_eq(inst.upgrade, 0)
		assert_false(inst.locked)
	assert_eq(bases, [&"test_blade", &"test_greatsword", &"test_shield", &"test_hatchet", &"test_pickaxe", &"test_rod"] as Array[StringName])
	assert_eq(_session.armory.get_instance(1).base_id, &"test_blade")
	assert_eq(_session.armory.get_instance(6).base_id, &"test_rod")


func test_the_kit_is_worn() -> void:
	assert_eq(_session.equipment.get_uid(&"weapon"), 1)
	assert_eq(_session.equipment.get_uid(&"offhand"), 3)
	assert_eq(_session.equipment.get_uid(&"tool_forestry"), 4)
	assert_eq(_session.equipment.get_uid(&"tool_quarrying"), 5)
	assert_eq(_session.equipment.get_uid(&"tool_angling"), 6)
	assert_eq(_session.equipment.get_uid(&"body"), 0)
	assert_true(_session.armory.is_worn(1) and _session.armory.is_worn(3) and _session.armory.is_worn(6))
	assert_false(_session.armory.is_worn(2), "the greatsword stays in the Armory")
	assert_eq(_session.armory.used(), 1, "only the greatsword counts")
	assert_eq(_session.equipment.setup(), &"sword_shield")
	assert_eq(_session.modifiers.total(&"skill_interval_pct", ModifierContext.for_skill(&"forestry")), -5.0)


func test_food_gold_and_purchases() -> void:
	assert_eq(_session.equipment.get_food(), &"test_ration")
	assert_eq(_session.bank.get_count(&"test_ration"), 20)
	assert_eq(_session.wallet.get_gold(), 50, "the owned purchase costs nothing")
	assert_eq(_session.shop.purchase_count(&"test_upgrade_1"), 1)
	assert_eq(_session.modifiers.total(&"auto_eat_tier"), 1.0, "the owned upgrade works from the start")
	assert_eq(_session.shop.can_buy(&"test_upgrade_1").reason, Reasons.MAX_PURCHASES)


func test_a_unique_tool_is_not_sold_salvaged_or_taken_off() -> void:
	for slot: StringName in [&"tool_forestry", &"tool_quarrying", &"tool_angling"]:
		var uid: int = _session.equipment.get_uid(slot)
		assert_eq(_session.equipment.unequip(slot).reason, Reasons.ITEM_UNIQUE)
		assert_eq(_session.shop.sell_instance(uid).reason, Reasons.ITEM_UNIQUE)
		assert_eq(_session.armory.salvage(uid).reason, Reasons.ITEM_UNIQUE)
		assert_eq(_session.armory.set_locked(uid, true).reason, Reasons.ITEM_UNIQUE)
		assert_eq(_session.equipment.get_uid(slot), uid)
	assert_eq(_session.wallet.get_gold(), 50)


func test_no_other_piece_goes_into_a_tool_slot() -> void:
	var spare: int = _session.armory.create(&"test_blade", &"common", 1)
	assert_eq(_session.equipment.equip(spare, &"tool_forestry").reason, Reasons.NOT_EQUIPPABLE)
	assert_eq(_session.equipment.equip(4, &"tool_quarrying").reason, Reasons.NOT_EQUIPPABLE, "already worn")
	assert_eq(_session.equipment.get_uid(&"tool_forestry"), 4)


func test_the_kit_pieces_can_be_sold_unless_worn_or_unique() -> void:
	assert_eq(_session.shop.sell_instance(1).reason, Reasons.ITEM_EQUIPPED)


func test_a_new_game_again_resets_the_kit() -> void:
	_session.armory.create(&"test_helm", &"common", 1)
	_session.equipment.unequip(&"weapon")
	_session.new_game()
	assert_eq(_session.armory.instances().size(), 6)
	assert_eq(_session.equipment.get_uid(&"weapon"), 1)
	assert_eq(_session.armory.used(), 1)


func test_the_kit_survives_a_save() -> void:
	var loaded: GameSession = autofree(TestFactory.session(22, _data))
	assert_true(loaded.from_save(_session.to_save(0)).ok)
	assert_eq(loaded.equipment.get_uid(&"tool_angling"), 6)
	assert_eq(loaded.equipment.get_uid(&"offhand"), 3)
	assert_eq(loaded.equipment.get_food(), &"test_ration")
	assert_eq(loaded.shop.purchase_count(&"test_upgrade_1"), 1)
	assert_eq(loaded.armory.used(), 1)
