extends GutTest
## The real contents of M12-05 (docs/04_DATA_SCHEMA.md §5, §6, §7; 02_FORMULAS.md §8.6b, §8.7, §8.8b): bags, contracts, the
## 24 byproducts and the milestones, the three different mastery trees, Rift Dust and Rune Slab, icons and descriptions.

const TRADES: Dictionary = {
	"forestry": {"actions": ["cut_redbirch", "cut_ashpine", "cut_thornalder", "cut_duskelm", "cut_shardcedar", "cut_veilcypress",
			"cut_emberlarch", "cut_riftspruce"], "stat": "skill_interval_pct", "resource": -8.0, "trade": -0.5},
	"quarrying": {"actions": ["quarry_emberbronze", "quarry_ashlead", "quarry_stormzinc", "quarry_duskcobalt", "quarry_glimmerite",
			"quarry_palecinnabar", "quarry_emberheart", "quarry_riftite"], "stat": "double_item_chance", "resource": 8.0, "trade": 0.5},
	"angling": {"actions": ["catch_brookfin", "catch_ashgill", "catch_redscale", "catch_dusk_eel", "catch_shard_gar",
			"catch_mist_barbel", "catch_ember_sturgeon", "catch_riftmaw"], "stat": "skill_xp_pct", "resource": 10.0, "trade": 0.5},
}
const GRADES: Array[String] = ["apprentice", "journeyman", "expert", "master"]

var _data: GameData


func before_all() -> void:
	_data = TestFactory.real_data()


func test_real_data_is_valid() -> void:
	assert_eq(_data.errors, PackedStringArray())


func test_five_bags_with_their_source() -> void:
	var slots: Dictionary = {}
	for item: ItemDef in _data.items():
		if item.category == &"bag":
			slots[item.id] = item.bag_slots
			assert_eq(item.value, 0, "%s is not for sale" % item.id)
	assert_eq(slots, {&"bag_canvas": 6, &"bag_leather": 10, &"bag_reinforced": 14, &"bag_wayfarer": 18, &"bag_runic": 24})
	var canvas: ActionDef = _data.action(&"sew_bag_canvas")
	assert_eq([canvas.level, canvas.outputs[0].item_id, canvas.outputs[0].qty], [1, &"bag_canvas", 1])
	var reinforced: ActionDef = _data.action(&"sew_bag_reinforced")
	assert_eq([reinforced.level, reinforced.outputs[0].item_id], [45, &"bag_reinforced"])
	var byproducts: int = 0
	for input: ItemQty in reinforced.inputs:
		byproducts += 1 if _is_byproduct(input.item_id) else 0
	assert_eq(byproducts, 3, "the reinforced bag uses byproducts of the milestones at 25")
	assert_eq(_data.item(&"bag_reinforced").bag_slots, 14)


func _is_byproduct(item: StringName) -> bool:
	for skill: String in TRADES:
		for action: ActionDef in _data.actions_for_skill(StringName(skill)):
			if action.milestones[0].item == item:
				return true
	return false


func test_twelve_contracts_three_trades_by_four_grades() -> void:
	var found: Dictionary = {}
	for item: ItemDef in _data.items():
		if item.category == &"contract":
			found[item.id] = [item.contract_skill, item.contract_grade]
			assert_eq(item.value, 0)
	assert_eq(found.size(), 12)
	for skill: String in TRADES:
		for grade: String in GRADES:
			assert_eq(found.get(StringName("contract_%s_%s" % [skill, grade])), [StringName(skill), StringName(grade)])


func test_milestones_of_the_24_gathering_actions() -> void:
	var seen: Dictionary = {}
	for skill: String in TRADES:
		var spec: Dictionary = TRADES[skill]
		var actions: Array[ActionDef] = _data.actions_for_skill(StringName(skill))
		assert_eq(actions.size(), 8, skill)
		for index: int in actions.size():
			var action: ActionDef = actions[index]
			assert_eq(action.id, StringName((spec["actions"] as Array)[index]))
			var byproduct: ItemDef = _data.item(action.milestones[0].item)
			assert_eq(byproduct.category, &"material", action.id)
			assert_false(seen.has(byproduct.id), "%s is shared" % byproduct.id)
			seen[byproduct.id] = true
			assert_false(byproduct.name.contains(" "), "%s: one word" % byproduct.name)
			assert_eq([action.milestones[1].type, action.milestones[1].modifiers[0].stat, action.milestones[1].modifiers[0].value],
					[&"resource", StringName(spec["stat"] as String), spec["resource"]], str(action.id))
			assert_eq([action.milestones[2].type, action.milestones[2].modifiers[0].stat, action.milestones[2].modifiers[0].value],
					[&"trade", StringName(spec["stat"] as String), spec["trade"]], str(action.id))
	assert_eq(seen.size(), 24)
	assert_eq(_data.item(&"birch_resin").name, "Resina")
	assert_eq(_data.item(&"copper_nugget").name, "Pepita")
	assert_eq(_data.item(&"trout_scale").name, "Squama")


func test_the_three_gathering_trees_are_different_and_cost_60() -> void:
	var signatures: Dictionary = {}
	for skill: String in TRADES:
		var total: float = 0.0
		var signature: Array = []
		for node: MasteryNodeDef in _data.mastery_nodes(StringName(skill)):
			total += node.cost_pct
			var pairs: Array = []
			for m: Modifier in node.modifiers:
				pairs.append("%s:%s" % [m.stat, m.value])
			pairs.sort()
			signature.append(",".join(pairs))
		assert_eq(total, 60.0, skill)
		signatures[skill] = signature
	var names: Array = signatures.keys()
	for i: int in names.size():
		for j: int in range(i + 1, names.size()):
			var different: int = 0
			for n: int in 6:
				different += 1 if signatures[names[i]][n] != signatures[names[j]][n] else 0
			assert_gte(different, 3, "%s and %s" % [names[i], names[j]])


func test_dust_and_slab_are_materials() -> void:
	assert_eq(_data.item(&"rift_dust").category, &"material")
	assert_eq(_data.item(&"rune_slab").category, &"material")
	assert_eq(_data.item(&"rune_slab").value, 0)


func test_gathering_skills_have_no_f11_rules() -> void:
	for skill: String in TRADES:
		assert_true(_data.skill(StringName(skill)).mastery_bonuses.is_empty(), skill)


func test_every_new_item_has_icon_and_description() -> void:
	for item: ItemDef in _data.items():
		assert_true(FileAccess.file_exists(item.icon), "icon of %s" % item.id)
		assert_false(item.description.is_empty(), "description of %s" % item.id)
