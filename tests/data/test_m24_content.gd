extends GutTest
## Real contents of M24-05 (docs/04_DATA_SCHEMA_M24.md §29; 02_FORMULAS_M24.md §8.10, §8.11, F-154): the Herbalist, the Tonics and
## their Recipes, the Trainers, the nodes of every area, the Engraver slab.

const TIER_LEVELS: Array[int] = [1, 10, 20, 30, 45, 60, 75, 90]
const HERB_VALUES: Array[int] = [100, 300, 600, 1000, 1800, 3000, 5000, 8500]
const TONIC_XP: Array[int] = [12, 21, 33, 48, 69, 96, 129, 174]
const TONIC_HEAL: Array[int] = [30, 53, 83, 120, 165, 225, 300, 390]
const TONIC_VALUE: Array[int] = [400, 1200, 2400, 4000, 7200, 12000, 20000, 34000]
const FISH: Array[StringName] = [&"brookfin", &"ashgill", &"redscale", &"dusk_eel", &"shard_gar", &"mist_barbel", &"ember_sturgeon", &"riftmaw"]
const GATHERING: Array[StringName] = [&"forestry", &"quarrying", &"angling", &"herbalism"]
const ARTISAN: Array[StringName] = [&"forging", &"woodwright", &"hearthcraft", &"riftbinding"]

var _data: GameData


func before_all() -> void:
	_data = TestFactory.real_data()


func test_real_data_is_valid() -> void:
	assert_eq(_data.errors, PackedStringArray())


func test_four_gathering_and_four_artisan_disciplines() -> void:
	var gathering: Array[StringName] = _data.disciplines(&"gathering")
	var artisan: Array[StringName] = _data.disciplines(&"artisan")
	gathering.sort()
	artisan.sort()
	var want_g: Array[StringName] = GATHERING.duplicate()
	var want_a: Array[StringName] = ARTISAN.duplicate()
	want_g.sort()
	want_a.sort()
	assert_eq(gathering, want_g)
	assert_eq(artisan, want_a)
	assert_eq(_data.skill(&"hearthcraft").name, "Cuoco e alchimista")
	assert_eq(_data.skill(&"herbalism").name, "Erborista")


func test_every_discipline_has_a_trainer() -> void:
	for id: StringName in GATHERING + ARTISAN:
		var trainer: TrainerDef = _data.trainer(id)
		assert_not_null(trainer, String(id))
		if trainer != null:
			assert_false(trainer.name.is_empty() or trainer.title.is_empty() or trainer.description.is_empty(), String(id))
	assert_eq(_data.trainer(&"hearthcraft").fed_by, [&"angling", &"herbalism"] as Array[StringName])
	assert_eq(_data.trainer(&"forging").fed_by, [&"quarrying"] as Array[StringName])
	assert_eq(_data.trainer(&"woodwright").fed_by, [&"forestry"] as Array[StringName])


func test_every_area_has_the_four_nodes_summing_to_100() -> void:
	for area: AreaDef in _data.areas():
		var nodes: AreaNodesDef = _data.area_nodes(area.id)
		assert_not_null(nodes, String(area.id))
		if nodes == null:
			continue
		assert_eq(nodes.max_level, area.level_max, "max_level of %s" % area.id)
		var total: int = 0
		var skills: Array[StringName] = []
		for entry: NodeEntryDef in nodes.entries:
			total += entry.weight
			skills.append(entry.skill)
			assert_gte(entry.weight, 10, "%s %s" % [area.id, entry.skill])
		skills.sort()
		var want: Array[StringName] = GATHERING.duplicate()
		want.sort()
		assert_eq(skills, want, String(area.id))
		assert_eq(total, 100, String(area.id))


func test_gen_nodes_is_reproducible() -> void:
	var generator: GDScript = load("res://tools/gen_nodes.gd") as GDScript
	var areas: Array = (JSON.parse_string(FileAccess.get_file_as_string("res://data/combat/areas.json")) as Dictionary)["areas"] as Array
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/config/balance.json")) as Dictionary
	var profile: Array = (balance["encounters"] as Dictionary)["resource_profile"] as Array
	var actions: Dictionary = {}
	for skill: String in ["forestry", "quarrying", "angling", "herbalism"]:
		actions[skill] = (JSON.parse_string(FileAccess.get_file_as_string("res://data/actions/%s.json" % skill)) as Dictionary)["actions"] as Array
	var result: Dictionary = generator.call("generate", areas, actions, profile) as Dictionary
	assert_eq(result["errors"], PackedStringArray())
	assert_eq(result["text"], FileAccess.get_file_as_string("res://data/encounters/nodes.json"))


func test_herbs_follow_the_gathering_tiers() -> void:
	var actions: Array[ActionDef] = _data.actions_for_skill(&"herbalism")
	assert_eq(actions.size(), 8)
	var intervals: Array[int] = [3000, 3200, 3500, 3800, 4200, 4600, 5000, 5500]
	var xps: Array[int] = [10, 18, 28, 40, 58, 80, 108, 145]
	for i: int in mini(actions.size(), 8):
		assert_eq([actions[i].level, actions[i].interval_ms, actions[i].xp], [TIER_LEVELS[i], intervals[i], xps[i]], String(actions[i].id))
		assert_eq(_data.item(actions[i].outputs[0].item_id).value, HERB_VALUES[i])
		assert_eq(actions[i].milestones.size(), 3)
		assert_eq(actions[i].milestones[0].type, &"byproduct")
		assert_eq(_data.item(actions[i].milestones[0].item).category, &"material")


func test_tonics_follow_8_11() -> void:
	for i: int in 8:
		var action: ActionDef = _data.action(StringName("brew_tonic_%d" % (i + 1)))
		assert_true(action.discover)
		assert_eq([action.level, action.interval_ms, action.xp], [TIER_LEVELS[i], 3000, TONIC_XP[i]])
		var herb: StringName = _data.actions_for_skill(&"herbalism")[i].outputs[0].item_id
		assert_eq([action.inputs[0].item_id, action.inputs[0].qty, action.inputs[1].item_id, action.inputs[1].qty], [herb, 2, FISH[i], 1])
		var tonic: ItemDef = _data.item(action.outputs[0].item_id)
		assert_eq(tonic.id, StringName("tonic_%d" % (i + 1)))
		assert_eq(tonic.food_heal, TONIC_HEAL[i])
		assert_eq(tonic.value, TONIC_VALUE[i])
		assert_eq(tonic.value, 2 * HERB_VALUES[i] + 2 * _data.item(FISH[i]).value)
		var cooked: ItemDef = _data.item(StringName("seared_" + String(FISH[i])))
		assert_eq(tonic.food_heal, roundi(1.5 * cooked.food_heal))


func test_every_discover_action_has_a_dropped_recipe() -> void:
	var dropped: Dictionary = {}
	for table: LootTableDef in _data.loot_tables():
		for entry: DropEntry in table.entries:
			dropped[entry.item_id] = true
	var count: int = 0
	for skill: SkillDef in _data.skills():
		for action: ActionDef in _data.actions_for_skill(skill.id):
			if not action.discover:
				continue
			count += 1
			var recipe: ItemDef = _data.recipe_item_for(action.id)
			assert_not_null(recipe, String(action.id))
			if recipe != null:
				assert_eq(recipe.value >= 1, dropped.has(recipe.id), "%s: a dropped Recipe is sold (Q183), a bought one is not" % recipe.id)
				var sold: bool = _data.shop_entry_selling(recipe.id) != null  # M26-04: schemes are sold, Tonics drop, never both
				assert_true(dropped.has(recipe.id) != sold, "%s drops xor is sold" % recipe.id)
	assert_eq(count, 8 + 28)


func test_recipes_drop_from_the_area_of_their_step_about_every_two_hours() -> void:
	var table: LootTableDef = _data.loot_table(&"loot_area_redrock_plains")
	var chance: float = 0.0
	for entry: DropEntry in table.entries:
		if entry.item_id == &"recipe_tonic_1":
			chance = entry.chance_pct
	assert_gt(chance, 0.0)
	var kills_per_two_hours: float = 100.0 / chance
	assert_between(kills_per_two_hours, 300.0, 600.0)


func test_rune_slab_needs_only_combat_drops() -> void:
	var slab: ActionDef = _data.action(&"make_rune_slab")
	assert_eq([slab.inputs[0].item_id, slab.inputs[0].qty, slab.inputs[1].item_id, slab.inputs[1].qty], [&"rift_dust", 3, &"rift_shard", 1])


func test_new_icons_exist() -> void:
	for id: StringName in [&"redrock_clover", &"rift_orchid", &"clover_seed", &"orchid_nectar", &"tonic_1", &"tonic_8", &"recipe_tonic_1", &"recipe_tonic_8"]:
		assert_true(FileAccess.file_exists(_data.item(id).icon), String(id))
	assert_true(FileAccess.file_exists(_data.skill(&"herbalism").icon))
