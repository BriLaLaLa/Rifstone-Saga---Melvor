extends GutTest
## The Armory filter with the five rarities (M14, docs/01_GDD.md §25 and §28.4): it knows Masterwork and legendary, it never
## salvages a legendary, the grade goes up to 15 (the piece grades), the rule survives the save.
## Content: tests/helpers/m14_data.gd (legendary pieces) and its fixtures (ordinary pieces).

var _s: GameSession = null


func before_each() -> void:
	_s = autofree(LegendaryKit.session(3))


func _inst(base_id: StringName, rarity: StringName) -> ItemInstance:
	return ItemRoller.create(_s.data.item(base_id), rarity, 1, _s.data, RngService.new(5))


func test_the_filter_knows_the_five_levels() -> void:
	assert_eq(ArmoryFilter.RARITY_ORDER, Rarities.ORDER)
	for rarity: StringName in Rarities.ORDER:
		assert_true(_s.armory.set_filter(&"head", rarity, 1).ok, "%s is a level of the filter" % rarity)
	assert_eq(_s.armory.set_filter(&"head", &"epic", 1).reason, Reasons.UNKNOWN_ID)


func test_grades_go_up_to_15() -> void:
	assert_true(_s.armory.set_filter(&"head", &"common", 15).ok)
	assert_eq(_s.armory.set_filter(&"head", &"common", 16).reason, Reasons.INVALID_AMOUNT)
	assert_eq(_s.armory.set_filter(&"head", &"common", 0).reason, Reasons.INVALID_AMOUNT)


func test_a_masterwork_level_keeps_masterworks_and_salvages_the_rare() -> void:
	assert_true(_s.armory.set_filter(&"head", &"masterwork", 1).ok)
	var legendary: ItemInstance = _inst(&"fx_leg_cap", &"legendary")
	var rare: ItemInstance = _inst(&"test_helm", &"rare")
	assert_true(_s.armory.is_filtered(rare), "a rare is under a Masterwork rule")
	assert_false(_s.armory.is_filtered(legendary))


func test_a_legendary_is_never_filtered_whatever_the_rule() -> void:
	assert_true(_s.armory.set_filter(&"head", &"legendary", 15).ok)
	var legendary: ItemInstance = _inst(&"fx_leg_cap", &"legendary")
	assert_false(_s.armory.is_filtered(legendary), "even under the strictest rule")
	var uid: int = _s.armory.add_drop(legendary)
	assert_gt(uid, 0, "stored")
	assert_eq(_s.armory.get_instance(uid).rarity, &"legendary")
	var common: ItemInstance = _inst(&"test_helm", &"common")
	assert_true(_s.armory.is_filtered(common))
	assert_eq(_s.armory.add_drop(common), 0, "the common one is salvaged at once")


func test_the_rule_with_a_masterwork_level_survives_the_save() -> void:
	assert_true(_s.armory.set_filter(&"weapon", &"masterwork", 8).ok)
	var copy: GameSession = autofree(LegendaryKit.session(9))
	assert_true(copy.from_save(_s.to_save(0)).ok)
	assert_eq(copy.armory.filter_rule(&"weapon"), {"min_rarity": &"masterwork", "min_grade": 8})
