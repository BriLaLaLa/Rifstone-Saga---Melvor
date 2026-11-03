extends GutTest
## Integration (M3): ore -> ingot -> tool -> equipped -> faster gathering, on the real data with a fixed seed.
## The chain is played through the public API only (actions.start / advance / equipment.equip); nothing is granted:
## ore, logs, ingots and the tool all come from completed cycles. Quantities, intervals and slots are read from the
## data (docs/05_INTERFACES.md 5.8-5.9, docs/02_FORMULAS.md 8.2 / 8.4: smelt_<metal>, forge_<metal>_hatchet|pick|rod).

const SEED: int = 31337
const TICK_MS: int = 100
const METAL: String = "emberbronze"
const SMELT_PREFIX: String = "smelt_"
const FORGE_PREFIX: String = "forge_"
const INTERVAL_STAT: StringName = &"skill_interval_pct"
const MIN_INTERVAL_KEY: String = "action.min_interval_ms"
const GATHERING: StringName = &"gathering"
const ARTISAN: StringName = &"artisan"
const TOOL_KINDS: Array[String] = ["hatchet", "pick", "rod"]
const TOOL_SLOTS: Dictionary[String, StringName] = {
	"hatchet": &"tool_forestry", "pick": &"tool_quarrying", "rod": &"tool_angling",
}
const TOOL_SKILLS: Dictionary[String, StringName] = {
	"hatchet": &"forestry", "pick": &"quarrying", "rod": &"angling",
}
const MAX_STEPS: int = 20000

var _session: GameSession = null
var _done: int = 0


func after_each() -> void:
	if _session != null:
		_session.free()
	_session = null


func test_hatchet_chain_speeds_up_forestry() -> void:
	pending("M4-07: crafted tools become Armory pieces (uid)")
	return
	_run_chain("hatchet")


func test_pick_chain_speeds_up_quarrying() -> void:
	pending("M4-07: crafted tools become Armory pieces (uid)")
	return
	_run_chain("pick")


func test_rod_chain_speeds_up_angling() -> void:
	pending("M4-07: crafted tools become Armory pieces (uid)")
	return
	_run_chain("rod")


func test_every_metal_has_its_three_tools_in_the_right_slots() -> void:
	var data: GameData = TestFactory.real_data()
	var metals: Array[String] = []
	for action: ActionDef in data.actions_for_skill(&"forging"):
		if String(action.id).begins_with(SMELT_PREFIX):
			metals.append(String(action.id).trim_prefix(SMELT_PREFIX))
	assert_gt(metals.size(), 0, "smelt_<metal> recipes exist")
	for metal: String in metals:
		var smelt: ActionDef = data.action(StringName(SMELT_PREFIX + metal))
		var ingot: StringName = smelt.outputs[0].item_id
		for kind: String in TOOL_KINDS:
			var forge: ActionDef = data.action(StringName("%s%s_%s" % [FORGE_PREFIX, metal, kind]))
			assert_not_null(forge, "forge_%s_%s exists" % [metal, kind])
			if forge == null:
				continue
			var needs_ingot: bool = false
			for input: ItemQty in forge.inputs:
				needs_ingot = needs_ingot or input.item_id == ingot
			assert_true(needs_ingot, "%s uses the ingot of smelt_%s" % [forge.id, metal])
			var tool_def: ItemDef = data.item(forge.outputs[0].item_id)
			assert_eq(tool_def.equip.slot, TOOL_SLOTS[kind], "%s goes in %s" % [tool_def.id, TOOL_SLOTS[kind]])
			var speeds: bool = false
			for mod: Modifier in tool_def.equip.modifiers:
				speeds = speeds or (mod.stat == INTERVAL_STAT and mod.value < 0.0 and mod.scope_kind == &"skill"
						and mod.scope_id == TOOL_SKILLS[kind])
			assert_true(speeds, "%s lowers the interval of %s" % [tool_def.id, TOOL_SKILLS[kind]])


# One full chain for a tool kind. All the quantities come from the recipes.
func _run_chain(kind: String) -> void:
	_session = TestFactory.session(SEED, TestFactory.real_data())
	var data: GameData = _session.data
	var smelt: ActionDef = data.action(StringName(SMELT_PREFIX + METAL))
	var forge: ActionDef = data.action(StringName("%s%s_%s" % [FORGE_PREFIX, METAL, kind]))
	var tool_def: ItemDef = data.item(forge.outputs[0].item_id)
	var skill: StringName = TOOL_SKILLS[kind]
	var slot: StringName = TOOL_SLOTS[kind]
	var base_action: ActionDef = data.actions_for_skill(skill)[0]
	var before_ms: int = _session.actions.current_interval_ms(base_action.id)
	assert_eq(_session.bank.get_count(tool_def.id), 0, "starts without the tool")
	# 1. raw materials from gathering cycles, then smelting, then forging
	var ingot: StringName = smelt.outputs[0].item_id
	var ingots_needed: int = 0
	for input: ItemQty in forge.inputs:
		if input.item_id == ingot:
			ingots_needed = input.qty
		else:
			_obtain(input.item_id, input.qty)
	var smelt_cycles: int = ceili(float(ingots_needed) / float(smelt.outputs[0].qty))
	for input: ItemQty in smelt.inputs:
		_gather(input.item_id, input.qty * smelt_cycles)
	_run_cycles(smelt, smelt_cycles)
	assert_eq(_session.bank.get_count(ingot), ingots_needed, "%d cycles of %s" % [smelt_cycles, smelt.id])
	_run_cycles(forge, 1)
	assert_eq(_session.bank.get_count(tool_def.id), forge.outputs[0].qty, "the tool is in the bank")
	assert_eq(_session.bank.get_count(ingot), 0, "ingots consumed")
	assert_gt(_session.skills.get_xp(&"forging"), 0, "forging XP earned")
	# 2. equip: 1 unit from the bank to the slot
	var result: CommandResult = _session.equipment.equip(tool_def.id)
	assert_true(result.ok, "equip: %s" % result.reason)
	assert_eq(_session.equipment.get_item(slot), tool_def.id)
	assert_eq(_session.bank.get_count(tool_def.id), forge.outputs[0].qty - 1, "one unit left the bank")
	# 3. faster gathering
	var pct: float = _session.modifiers.total(INTERVAL_STAT, ModifierContext.for_skill(skill))
	assert_almost_eq(pct, _item_interval_pct(tool_def, skill), 0.0001, "modifier equals the item data")
	assert_lt(pct, 0.0)
	var min_ms: int = int(data.balance_value(MIN_INTERVAL_KEY))
	var after_ms: int = _session.actions.current_interval_ms(base_action.id)
	assert_eq(after_ms, ActionMath.interval_ms(base_action.interval_ms, pct, min_ms), "F-03 with the tool")
	assert_lt(after_ms, before_ms, "%s is faster" % base_action.id)
	for other_skill: StringName in TOOL_SKILLS.values():
		if other_skill != skill:
			var other: ActionDef = data.actions_for_skill(other_skill)[0]
			assert_eq(_session.actions.current_interval_ms(other.id), other.interval_ms, "%s unchanged" % other_skill)
	# 4. the running lane reports the shorter interval
	assert_true(_session.actions.start(skill, base_action.id).ok)
	assert_eq(int(_session.actions.get_lane()["interval_ms"]), after_ms)
	_session.actions.stop()


func _item_interval_pct(item: ItemDef, skill: StringName) -> float:
	var sum: float = 0.0
	for mod: Modifier in item.equip.modifiers:
		if mod.stat == INTERVAL_STAT and mod.scope_id == skill:
			sum += mod.value
	return sum


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
