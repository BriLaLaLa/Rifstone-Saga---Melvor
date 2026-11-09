extends GutTest
## F-120 legendary tools and worn legendaries: a legendary tool replaces the unique tool of its slot (which goes back among
## the pieces not worn) and the other way round, the requirement of the craft, fixed modifiers without refinement, the effects
## with the source `equipment:<slot>`, the save. Content: tests/helpers/m14_data.gd.

const UNIQUE: StringName = &"unique_hatchet"
const LEGENDARY: StringName = &"fx_leg_hatchet"

var _s: GameSession = null


func before_each() -> void:
	_s = autofree(LegendaryKit.session(7))


func _unique_worn() -> int:
	var uid: int = TestFactory.give_piece(_s, UNIQUE)
	assert_true(_s.equipment.equip(uid).ok)
	return uid


func test_a_legendary_tool_replaces_the_unique_one_which_goes_back_to_the_armory() -> void:
	var unique_uid: int = _unique_worn()
	var legendary_uid: int = TestFactory.give_piece(_s, LEGENDARY)
	assert_eq(_s.armory.get_instance(legendary_uid).rarity, &"legendary")
	assert_true(_s.equipment.equip(legendary_uid).ok)
	assert_eq(_s.equipment.get_uid(&"tool_forestry"), legendary_uid)
	assert_true(_s.armory.is_worn(legendary_uid))
	assert_false(_s.armory.is_worn(unique_uid), "the unique tool is among the pieces not worn")
	assert_not_null(_s.armory.get_instance(unique_uid), "and still in the Armory")


func test_the_unique_tool_can_be_worn_again_over_the_legendary_one() -> void:
	var unique_uid: int = _unique_worn()
	var legendary_uid: int = TestFactory.give_piece(_s, LEGENDARY)
	assert_true(_s.equipment.equip(legendary_uid).ok)
	assert_true(_s.equipment.equip(unique_uid).ok)
	assert_eq(_s.equipment.get_uid(&"tool_forestry"), unique_uid)
	assert_false(_s.armory.is_worn(legendary_uid))
	assert_eq(_s.equipment.item_effects().size(), 0, "no legendary worn, no effect")


func test_the_unique_tool_still_cannot_be_replaced_by_an_ordinary_piece_or_taken_off() -> void:
	var unique_uid: int = _unique_worn()
	assert_eq(_s.equipment.unequip(&"tool_forestry").reason, Reasons.ITEM_UNIQUE)
	var other: int = TestFactory.give_piece(_s, &"unique_pick")
	assert_eq(_s.equipment.equip(other, &"tool_forestry").reason, Reasons.NOT_EQUIPPABLE)
	assert_eq(_s.equipment.get_uid(&"tool_forestry"), unique_uid)


func test_the_unique_tool_is_never_sold_or_salvaged_but_the_legendary_one_can_be() -> void:
	var unique_uid: int = _unique_worn()
	var legendary_uid: int = TestFactory.give_piece(_s, LEGENDARY)
	assert_true(_s.equipment.equip(legendary_uid).ok)
	assert_eq(_s.shop.sell_instance(unique_uid).reason, Reasons.ITEM_UNIQUE)
	assert_eq(_s.armory.salvage(unique_uid).reason, Reasons.ITEM_UNIQUE)
	assert_eq(_s.armory.salvage(legendary_uid).reason, Reasons.ITEM_EQUIPPED, "worn: not now")
	assert_true(_s.equipment.unequip(&"tool_forestry").ok)
	assert_true(_s.armory.salvage(legendary_uid).ok, "a legendary is salvaged by hand (shards, no component)")


func test_the_requirement_of_the_craft_decides_who_can_wear_it() -> void:
	var pick: int = TestFactory.give_piece(_s, &"fx_leg_pick")  # needs Quarrying 20
	assert_eq(_s.equipment.equip(pick).reason, Reasons.REQUIREMENT_NOT_MET)
	TestFactory.set_level(_s, &"quarrying", 20)
	assert_true(_s.equipment.equip(pick).ok)


func test_the_modifiers_are_fixed_and_scoped_without_the_rarity_multiplier() -> void:
	LegendaryKit.wear(_s, LEGENDARY)
	var ctx: ModifierContext = ModifierContext.for_action(&"forestry", &"forestry_a")
	assert_eq(_s.modifiers.total(&"skill_interval_pct", ctx), -26.0, "as authored, not x1.4")
	assert_eq(_s.modifiers.total(&"double_item_chance", ctx), 3.0)
	assert_eq(_s.modifiers.total(&"skill_interval_pct", ModifierContext.for_action(&"angling", &"angling_a")), 0.0)


func test_no_refinement_for_a_legendary_tool() -> void:
	var uid: int = LegendaryKit.wear(_s, LEGENDARY)
	TestFactory.give(_s, &"emberbronze_ingot", 5)
	_s.wallet.add_gold(100000)
	assert_eq(_s.armory.upgrade_tool(uid).reason, Reasons.NOT_EQUIPPABLE)
	assert_eq(_s.armory.upgrade(uid).reason, Reasons.NOT_EQUIPPABLE)
	assert_eq(_s.armory.get_instance(uid).upgrade, 0)


func test_item_effects_carry_the_source_of_their_slot() -> void:
	LegendaryKit.wear(_s, LEGENDARY)
	LegendaryKit.wear(_s, &"fx_leg_execute")
	var effects: Array[ItemEffectDef] = _s.equipment.item_effects()
	assert_eq(effects.size(), 2)
	var by_source: Dictionary[StringName, StringName] = {}
	for effect: ItemEffectDef in effects:
		by_source[effect.source] = effect.type
	assert_eq(by_source, {&"equipment:weapon": &"execute_mult", &"equipment:tool_forestry": &"gather_bonus_item"} as Dictionary[StringName, StringName])
	assert_eq(effects[0].source, &"equipment:weapon", "in the order of the slots")
	_s.equipment.unequip(&"weapon")
	assert_eq(_s.equipment.item_effects().size(), 1)


func test_a_legendary_piece_is_refined_and_gets_castoni_like_any_piece() -> void:
	var uid: int = LegendaryKit.wear(_s, &"fx_leg_cap")
	var base: float = _s.modifiers.total(&"armor")
	assert_eq(base, 6.0 * 1.4, "x1.4 of the legendary")
	assert_eq(_s.armory.socket_count(uid), 2, "sockets.by_rarity.legendary")
	var saved: Dictionary = _s.armory.to_save()
	for entry: Dictionary in saved["items"]:
		if int(entry["uid"]) == uid:
			entry["upgrade"] = 3
	_s.armory.from_save(saved)
	_s.rebuild_modifiers()
	assert_almost_eq(_s.modifiers.total(&"armor"), 6.0 * 1.4 * 1.3, 0.0001, "x1.4 then x(1 + 10% x 3)")


func test_the_save_keeps_the_rarity_the_uid_and_the_worn_tool() -> void:
	var uid: int = LegendaryKit.wear(_s, LEGENDARY)
	var copy: GameSession = autofree(LegendaryKit.session(99))
	assert_true(copy.from_save(_s.to_save(0)).ok)
	assert_eq(copy.equipment.get_uid(&"tool_forestry"), uid)
	assert_eq(copy.armory.get_instance(uid).rarity, &"legendary")
	assert_eq(copy.equipment.item_effects().size(), 1)
	assert_eq(copy.modifiers.total(&"skill_interval_pct", ModifierContext.for_action(&"forestry", &"forestry_a")), -26.0)
