extends GutTest
## RarityColors (M14-06, docs/01_GDD.md §28.4): white, blue, yellow, purple (Masterwork), orange (Legendary).


func test_five_rarities_have_five_different_colors() -> void:
	var seen: Array[Color] = []
	for rarity: StringName in Rarities.ORDER:
		var color: Color = RarityColors.color(rarity)
		assert_ne(color, UiStyle.RARITY_UNKNOWN, String(rarity))
		assert_false(seen.has(color), String(rarity))
		seen.append(color)


func test_masterwork_is_purple_and_legendary_is_orange() -> void:
	var purple: Color = RarityColors.color(Rarities.MASTERWORK)
	assert_true(purple.b > purple.g and purple.r > purple.g, "purple: blue and red above green")
	var orange: Color = RarityColors.color(Rarities.LEGENDARY)
	assert_true(orange.r > orange.g and orange.g > orange.b, "orange: red > green > blue")


func test_ui_style_answers_with_the_same_colors() -> void:
	for rarity: StringName in Rarities.ORDER:
		assert_eq(UiStyle.rarity_color(rarity), RarityColors.color(rarity))
	assert_eq(RarityColors.color(&"nope"), UiStyle.RARITY_UNKNOWN)


func test_rarity_names_in_italian() -> void:
	assert_eq(ArmoryTexts.rarity_name(&"masterwork"), "Capolavoro")
	assert_eq(ArmoryTexts.rarity_name(&"legendary"), "Leggendario")
