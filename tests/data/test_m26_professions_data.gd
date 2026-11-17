extends GutTest
## Real data of M26-04 (docs/04_DATA_SCHEMA_M26.md §31; 02_FORMULAS_M26.md F-166, F-169, F-170, F-171): colours, 28 schemes,
## 12 reagents, prices and the Maestro's `vendor`. The expected values are the oracle (the generator is tools/gen_professions.gd).

const SKILLS: Array[StringName] = [&"forging", &"woodwright", &"hearthcraft"]
const VENDORS: Dictionary = {&"forging": &"fabbro", &"woodwright": &"falegname", &"hearthcraft": &"cuoco"}
const SCHEME_COUNT: Dictionary = {&"forging": 7, &"woodwright": 14, &"hearthcraft": 7}
## F-170: total copper of the schemes of a skill.
const SCHEME_TOTAL: Dictionary = {&"forging": 7070000, &"woodwright": 6060000, &"hearthcraft": 2020000}
## F-171: [price, value] of the four reagents of a skill; unlock level 10, 30, 60, 90.
const REAGENTS: Dictionary = {
	&"forging": [[200, 0], [700, 100], [2100, 500], [6000, 1500]],
	&"woodwright": [[100, 0], [200, 0], [600, 100], [1700, 400]],
	&"hearthcraft": [[100, 0], [200, 0], [600, 100], [1700, 400]],
}
const BAND_LEVELS: Array[int] = [10, 30, 60, 90]
const TIER_LEVELS: Array[int] = [1, 10, 20, 30, 45, 60, 75, 90]

var _data: GameData


func before_all() -> void:
	_data = TestFactory.real_data()


func test_real_data_is_valid() -> void:
	assert_eq(_data.errors, PackedStringArray())


func test_colors_on_every_non_single_action_of_the_three_trades() -> void:
	for skill: StringName in SKILLS:
		for a: ActionDef in _data.actions_for_skill(skill):
			if a.single:
				assert_true(a.colors.is_empty(), "%s single" % a.id)
				continue
			assert_eq(a.colors, {&"yellow": a.level + 10, &"green": a.level + 20, &"grey": a.level + 30}, String(a.id))
	for a: ActionDef in _data.actions_for_skill(&"riftbinding"):
		assert_true(a.colors.is_empty(), "%s has no colours (Q148)" % a.id)


func test_f166_examples() -> void:
	assert_eq(_data.action(&"forge_ashlead_plate").colors, {&"yellow": 20, &"green": 30, &"grey": 40})
	assert_eq(_data.action(&"forge_riftite_plate").colors, {&"yellow": 100, &"green": 110, &"grey": 120})
	assert_eq(_data.action(&"cook_brookfin").colors, {&"yellow": 11, &"green": 21, &"grey": 31})


func test_28_schemes_in_the_expected_families() -> void:
	var counts: Dictionary = {&"forging": 0, &"woodwright": 0, &"hearthcraft": 0}
	for skill: StringName in SKILLS:
		for a: ActionDef in _data.actions_for_skill(skill):
			if not a.discover or String(a.id).begins_with("brew_"):
				continue
			counts[skill] += 1
			assert_gte(a.level, TIER_LEVELS[1], "%s is tier 2 or more" % a.id)
			var family_ok: bool = (String(a.id).begins_with("forge_") and String(a.id).ends_with("_plate")) \
					or (String(a.id).begins_with("carve_") and (String(a.id).ends_with("_shieldcore") or String(a.id).ends_with("_handle"))) \
					or String(a.id).begins_with("cook_")
			assert_true(family_ok, String(a.id))
			assert_not_null(_data.recipe_item_for(a.id), "recipe of %s" % a.id)
	assert_eq(counts, SCHEME_COUNT)


func test_scheme_prices_follow_f170() -> void:
	var totals: Dictionary = {&"forging": 0, &"woodwright": 0, &"hearthcraft": 0}
	for skill: StringName in SKILLS:
		for a: ActionDef in _data.actions_for_skill(skill):
			if not a.discover or String(a.id).begins_with("brew_"):
				continue
			var recipe: ItemDef = _data.recipe_item_for(a.id)
			var entry: ShopEntryDef = _data.shop_entry_selling(recipe.id)
			assert_not_null(entry, String(a.id))
			if entry == null:
				continue
			var product: ItemDef = _data.item(a.outputs[0].item_id)
			assert_eq(entry.cost_gold, maxi(100, 50 * product.value), String(a.id))
			assert_eq([entry.max_purchases, entry.category, entry.vendor], [1, &"profession", VENDORS[skill]], String(a.id))
			assert_eq(entry.req_skills, {skill: a.level}, String(a.id))
			assert_eq(recipe.value, 0)
			totals[skill] += entry.cost_gold
	assert_eq(totals, SCHEME_TOTAL)
	assert_eq(_data.shop_entry(&"buy_recipe_forge_ashlead_plate").cost_gold, 105000)
	assert_eq(_data.shop_entry(&"buy_recipe_forge_riftite_plate").cost_gold, 2975000)
	assert_eq(_data.shop_entry(&"buy_recipe_carve_ashpine_handle").cost_gold, 30000)
	assert_eq(_data.shop_entry(&"buy_recipe_cook_ashgill").cost_gold, 30000)
	assert_eq(_data.shop_entry(&"buy_recipe_carve_riftspruce_shieldcore").cost_gold, 1700000)


func test_12_reagents_with_f171_prices_and_values() -> void:
	var count: int = 0
	for skill: StringName in SKILLS:
		for band: int in 4:
			var id := StringName("reagent_%s_%d" % [skill, band + 1])
			var item: ItemDef = _data.item(id)
			var want: Array = (REAGENTS[skill] as Array)[band] as Array
			assert_eq(item.category, &"reagent", String(id))
			assert_eq(item.value, want[1], "value of %s" % id)
			assert_true(FileAccess.file_exists(item.icon), "icon of %s" % id)
			var entry: ShopEntryDef = _data.shop_entry_selling(id)
			assert_not_null(entry, String(id))
			if entry != null:
				assert_eq([entry.cost_gold, entry.max_purchases, entry.vendor, entry.req_skills],
						[want[0], 0, VENDORS[skill], {skill: BAND_LEVELS[band]}], String(id))
				assert_gt(entry.cost_gold, item.value)
			count += 1
	assert_eq(count, 12)


func test_schemes_end_with_the_reagent_of_their_band() -> void:
	var bands: Dictionary = {10: 1, 20: 1, 30: 2, 45: 2, 60: 3, 75: 3, 90: 4}
	for skill: StringName in SKILLS:
		for a: ActionDef in _data.actions_for_skill(skill):
			if not a.discover or String(a.id).begins_with("brew_"):
				continue
			var last: ItemQty = a.inputs.back()
			assert_eq(last.item_id, StringName("reagent_%s_%d" % [skill, bands[a.level]]), String(a.id))
			assert_eq(last.qty, 1)
			for index: int in a.inputs.size() - 1:
				assert_ne(_data.item(a.inputs[index].item_id).category, &"reagent", String(a.id))


func test_no_action_outputs_a_reagent_and_the_trainers_have_their_vendor() -> void:
	for skill: StringName in SKILLS:
		for a: ActionDef in _data.actions_for_skill(skill):
			for o: ItemQty in a.outputs:
				assert_ne(_data.item(o.item_id).category, &"reagent", String(a.id))
		assert_eq(_data.trainer(skill).vendor, VENDORS[skill])
	assert_eq(_data.trainer(&"riftbinding").vendor, &"")
