extends GutTest
## Integration (M3, reworked for M10): ore -> ingot -> plate (and grips from logs) -> blueprint -> piece in the Armory ->
## equipped, on the real data with a fixed seed. No recipe produces equipment or tools any more (docs/01_GDD.md 5.1).
## The chain is played through the public API only (actions.start / start_blueprint / advance / equipment.equip);
## ore, logs, ingots, plates and grips come from completed cycles. The blueprint and the rare component are drops
## (M10-04), so they are granted. Quantities and intervals are read from the data.

const SEED: int = 31337
const TICK_MS: int = 100
const METAL: String = "emberbronze"
const SMELT_PREFIX: String = "smelt_"
const PLATE_PREFIX: String = "forge_"
const PLATE_SUFFIX: String = "_plate"
const BASE: StringName = &"mw_sword_1"  # M14-05: the blueprint crafts a Masterwork
const BLUEPRINT: StringName = &"bp_mw_sword_1"
const GATHERING: StringName = &"gathering"
const ARTISAN: StringName = &"artisan"
const MAX_STEPS: int = 20000

var _session: GameSession = null
var _done: int = 0


func after_each() -> void:
	if _session != null:
		_session.free()
	_session = null


func test_no_recipe_produces_equipment_or_tools() -> void:
	var data: GameData = TestFactory.real_data()
	for skill: SkillDef in data.skills_by_category(ARTISAN):
		for action: ActionDef in data.actions_for_skill(skill.id):
			for output: ItemQty in action.outputs:
				var category: StringName = data.item(output.item_id).category
				assert_false(category == &"equipment" or category == &"tool",
						"%s must not produce %s" % [action.id, output.item_id])


func test_every_metal_has_smelting_and_plate_recipes_with_matching_items() -> void:
	var data: GameData = TestFactory.real_data()
	var metals: Array[String] = []
	for action: ActionDef in data.actions_for_skill(&"forging"):
		if String(action.id).begins_with(SMELT_PREFIX):
			metals.append(String(action.id).trim_prefix(SMELT_PREFIX))
	assert_eq(metals.size(), 8, "eight metals, one per grade")
	for metal: String in metals:
		var smelt: ActionDef = data.action(StringName(SMELT_PREFIX + metal))
		var ingot: StringName = smelt.outputs[0].item_id
		var plate: ActionDef = data.action(StringName("%s%s%s" % [PLATE_PREFIX, metal, PLATE_SUFFIX]))
		assert_not_null(plate, "forge_%s_plate exists" % metal)
		if plate == null:
			continue
		var needs_ingot: bool = false
		for input: ItemQty in plate.inputs:
			needs_ingot = needs_ingot or input.item_id == ingot
		assert_true(needs_ingot, "%s uses the ingot of smelt_%s" % [plate.id, metal])
		assert_eq(data.item(plate.outputs[0].item_id).category, &"component", "%s makes a component" % plate.id)


func test_ore_to_plate_to_blueprint_to_worn_piece() -> void:
	_session = TestFactory.session_no_kit(SEED, TestFactory.real_data())
	var data: GameData = _session.data
	var blueprint: ItemDef = data.item(BLUEPRINT)
	assert_eq(_session.armory.instances().size(), 0, "starts without pieces")
	# 1. raw materials -> ingots -> plates, grips from logs: everything from completed cycles
	var smelt: ActionDef = data.action(StringName(SMELT_PREFIX + METAL))
	var plate_action: ActionDef = data.action(StringName("%s%s%s" % [PLATE_PREFIX, METAL, PLATE_SUFFIX]))
	var needs: Dictionary = {}
	for input: ItemQty in BlueprintCraft.inputs(blueprint):
		needs[input.item_id] = input.qty
	var plate: StringName = plate_action.outputs[0].item_id
	var plate_cycles: int = ceili(float(needs[plate]) / float(plate_action.outputs[0].qty))
	var ingot: StringName = smelt.outputs[0].item_id
	var ingots_needed: int = plate_cycles * plate_action.inputs[0].qty
	var smelt_cycles: int = ceili(float(ingots_needed) / float(smelt.outputs[0].qty))
	for input: ItemQty in smelt.inputs:
		_gather(input.item_id, input.qty * smelt_cycles)
	_run_cycles(smelt, smelt_cycles)
	assert_eq(_session.bank.get_count(ingot), ingots_needed, "%d cycles of %s" % [smelt_cycles, smelt.id])
	_run_cycles(plate_action, plate_cycles)
	assert_eq(_session.bank.get_count(plate), needs[plate], "the plates of the blueprint")
	assert_eq(_session.bank.get_count(ingot), 0, "ingots consumed")
	for item_id: StringName in needs:
		if item_id != plate and data.item(item_id).category == &"component":
			_obtain(item_id, needs[item_id])
		elif item_id != plate:
			TestFactory.give(_session, item_id, needs[item_id])  # the rare component: a drop of the area
	TestFactory.give(_session, BLUEPRINT, 1)  # a drop (M10-04)
	# 2. the blueprint becomes a piece after its duration
	var level: int = _session.skills.get_level(&"forging")
	assert_gte(level, BlueprintCraft.required_level(blueprint, data), "the smelting XP made the level")
	var started: CommandResult = _session.actions.start_blueprint(BLUEPRINT)
	assert_true(started.ok, "start: %s" % started.reason)
	var duration: int = int(_session.actions.blueprint_state()["duration_ms"])
	_session.advance(duration)
	var pieces: Array[ItemInstance] = _session.armory.instances()
	assert_eq(pieces.size(), 1, "the piece is in the Armory")
	assert_eq(pieces[0].base_id, BASE)
	assert_ne(pieces[0].rarity, &"common", "never common")
	assert_eq(_session.bank.get_count(BASE), 0, "not in the bank")
	assert_eq(_session.bank.get_count(BLUEPRINT), 0, "the blueprint is consumed")
	assert_eq(_session.bank.get_count(plate), 0, "plates consumed")
	assert_false(_session.actions.is_running(), "the lane stopped by itself")
	# 3. equip: the Armory piece goes to the slot and its modifiers are active
	var uid: int = pieces[0].uid
	assert_true(_session.equipment.equip(uid).ok)
	assert_eq(_session.equipment.get_item(&"weapon"), BASE)
	assert_true(_session.armory.is_worn(uid))
	assert_true(_session.modifiers.has_source(&"equipment:weapon"))


# Gathers `qty` of an item running the first gathering action available that produces it.
func _gather(item_id: StringName, qty: int) -> void:
	var action: ActionDef = _gathering_action_for(item_id)
	assert_not_null(action, "a gathering action produces %s" % item_id)
	if action == null:
		return
	var start: int = _session.bank.get_count(item_id)
	assert_true(_session.actions.start(action.skill_id, action.id).ok, "start %s" % action.id)
	var steps: int = 0
	while _session.bank.get_count(item_id) - start < qty and steps < MAX_STEPS:
		_session.advance(TICK_MS)
		steps += 1
	_session.actions.stop()
	assert_gte(_session.bank.get_count(item_id) - start, qty, "%d x %s gathered" % [qty, item_id])


# Gathers `qty` of an item, or crafts it from gathered inputs when no gathering action produces it (the handle).
func _obtain(item_id: StringName, qty: int) -> void:
	if _gathering_action_for(item_id) != null:
		_gather(item_id, qty)
		return
	var recipe: ActionDef = _gathering_action_for(item_id, ARTISAN)
	assert_not_null(recipe, "an artisan action produces %s" % item_id)
	if recipe == null:
		return
	var cycles: int = ceili(float(qty) / float(recipe.outputs[0].qty))
	for input: ItemQty in recipe.inputs:
		_gather(input.item_id, input.qty * cycles)
	_run_cycles(recipe, cycles)


func _gathering_action_for(item_id: StringName, category: StringName = GATHERING) -> ActionDef:
	for skill: SkillDef in _session.data.skills_by_category(category):
		for action: ActionDef in _session.data.actions_for_skill(skill.id):
			if action.level > _session.skills.get_level(skill.id):
				continue
			for output: ItemQty in action.outputs:
				if output.item_id == item_id:
					return action
	return null


func _run_cycles(action: ActionDef, cycles: int) -> void:
	var start: CommandResult = _session.actions.start(action.skill_id, action.id)
	assert_true(start.ok, "start %s: %s" % [action.id, start.reason])
	_done = 0
	_session.events.action_completed.connect(_on_completed)
	var steps: int = 0
	while _done < cycles and steps < MAX_STEPS:
		_session.advance(TICK_MS)
		steps += 1
	_session.events.action_completed.disconnect(_on_completed)
	_session.actions.stop()
	assert_eq(_done, cycles, "%d cycles of %s" % [cycles, action.id])


func _on_completed(_lane: StringName, _skill: StringName, _action: StringName, _outputs: Dictionary) -> void:
	_done += 1
