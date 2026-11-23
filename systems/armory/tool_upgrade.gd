class_name ToolUpgrade
extends RefCounted
## F-94 refinement of the unique tools (docs/01_GDD.md §23.1, docs/02_FORMULAS.md): pure functions over
## `tool_upgrade` of balance.json and the `equip` of the tool. No state: `Armory.upgrade_tool` spends the materials.
## The step towards `+T` (T 1..max_level) needs the craft level `min_level`, `plates` plates and `handles` handles of the
## grade, and gold; it always succeeds. The effect of a tool at `+N` is `skill_interval_pct` -(base + per_level x N)
## plus (M35, F-196) `node_units_pct` and the active heads of F-197 (`heads[i]` at `head_steps[i] <= N`).

const SECTION_KEY: String = "tool_upgrade"
const SLOT_PREFIX: String = "tool_"
const INTERVAL_STAT: StringName = &"skill_interval_pct"
const UNITS_STAT: StringName = &"node_units_pct"


static func _section(data: GameData) -> Dictionary:
	return data.balance_value(SECTION_KEY) as Dictionary


## Highest refinement level (+9): one row of `tool_upgrade.levels` per step.
static func max_level(data: GameData) -> int:
	return (_section(data)["levels"] as Array).size()


## The skill of a tool slot (`tool_forestry` -> `forestry`); &"" if the slot is not a tool slot.
static func skill_of_slot(slot: StringName) -> StringName:
	return StringName(String(slot).trim_prefix(SLOT_PREFIX)) if String(slot).begins_with(SLOT_PREFIX) else &""


## F-94: `skill_interval_pct` of a tool at `+level` (-5 at +0, -23 at +9).
static func interval_pct(level: int, data: GameData) -> float:
	var section: Dictionary = _section(data)
	return -(float(section["interval_base_pct"]) + float(section["interval_per_level_pct"]) * level)


## Row of the step towards `+target` (1..max_level) as the UI reads it: {target, min_level, grade, plates: ItemQty,
## handles: ItemQty, gold, interval_pct, head_step}. Empty for a target out of range or a section without component lists.
static func step(target: int, data: GameData) -> Dictionary:
	var section: Dictionary = _section(data)
	var levels: Array = section["levels"] as Array
	if target < 1 or target > levels.size():
		return {}
	var row: Dictionary = levels[target - 1] as Dictionary
	var grade: int = int(row["grade"])
	var plate_items: Array = section.get("plate_items", []) as Array
	var handle_items: Array = section.get("handle_items", []) as Array
	if grade < 1 or grade > plate_items.size() or grade > handle_items.size():
		Log.error("armory", "tool_upgrade has no plate/handle item for grade %d" % grade)
		return {}
	return {
		"target": target,
		"min_level": int(row["min_level"]),
		"grade": grade,
		"plates": _qty(StringName(str(plate_items[grade - 1])), int(row["plates"])),
		"handles": _qty(StringName(str(handle_items[grade - 1])), int(row["handles"])),
		"gold": int(row["gold"]),
		"interval_pct": interval_pct(target, data),
		"head_step": target if head_steps(data).has(target) else 0,  # M35: a head is chosen at this step («Scegli una testa»)
	}


## M35 (F-196): `tool_upgrade.units_per_level_pct`, 0 while the key is absent (real data before M35-D2).
static func units_per_level(data: GameData) -> float:
	return float(_section(data).get("units_per_level_pct", 0))


## M35 (F-197): the refinement levels (3, 6, 9) at which a head is chosen; empty while the key is absent (real data before M35-D2).
static func head_steps(data: GameData) -> Array[int]:
	var result: Array[int] = []
	for step: Variant in _section(data).get("head_steps", []) as Array:
		result.append(int(step))
	return result


## F-198: the gold of changing the head of step `step` (3, 6 or 9); 0 for a step that is not a head step.
static func respec_gold(step: int, data: GameData) -> int:
	var levels: Array = _section(data)["levels"] as Array
	if not head_steps(data).has(step) or step < 1 or step > levels.size():
		return 0
	return floori(int((levels[step - 1] as Dictionary)["gold"]) * int(_section(data).get("respec_pct", 0)) / 100.0)


## Modifiers of the unique tool `def` at `+level` with the chosen `heads`: the interval of F-94 and `node_units_pct` of F-196 (scope
## of its skill), the other base modifiers unchanged, and the modifiers of every head chosen whose step is reached (F-197).
## No F-86 scaling, no affixes, no sockets.
static func modifiers(def: ItemDef, level: int, heads: Array[StringName], data: GameData) -> Array[Modifier]:
	var skill: StringName = skill_of_slot(def.equip.slot)
	var result: Array[Modifier] = [Modifier.make(INTERVAL_STAT, interval_pct(level, data), Modifier.SCOPE_SKILL, skill)]
	if units_per_level(data) > 0.0 and level > 0:
		result.append(Modifier.make(UNITS_STAT, units_per_level(data) * level, Modifier.SCOPE_SKILL, skill))
	for m: Modifier in def.equip.modifiers:
		if m.stat != INTERVAL_STAT:
			result.append(m)
	var steps: Array[int] = head_steps(data)
	for i: int in mini(heads.size(), steps.size()):
		var head: ToolHead = head_def(def, heads[i])
		if head != null and steps[i] <= level and i < head.steps.size():
			result.append_array(head.steps[i] as Array[Modifier])
	return result


## The head `head_id` of the unique tool `def`; null if it has no such head.
static func head_def(def: ItemDef, head_id: StringName) -> ToolHead:
	for head: ToolHead in def.equip.heads:
		if head.id == head_id:
			return head
	return null


## F-198 refusals in order after `unknown_id` and `not_equippable` (the Armory): not_a_tool is checked first here, then invalid_step,
## head_locked, unknown_head, head_unchanged, not_enough_gold (only a change of a head already chosen costs).
static func check_head(inst: ItemInstance, step: int, head_id: StringName, wallet: Wallet, data: GameData) -> CommandResult:
	var def: ItemDef = data.item(inst.base_id) if data.has_item(inst.base_id) else null
	if def == null or def.equip == null or not def.equip.unique:
		return CommandResult.fail(Reasons.NOT_A_TOOL)
	var index: int = head_steps(data).find(step)
	if index < 0:
		return CommandResult.fail(Reasons.INVALID_STEP)
	if inst.upgrade < step:
		return CommandResult.fail(Reasons.HEAD_LOCKED)
	if head_def(def, head_id) == null:
		return CommandResult.fail(Reasons.UNKNOWN_HEAD)
	var current: StringName = inst.heads[index] if index < inst.heads.size() else &""
	if current == head_id:
		return CommandResult.fail(Reasons.HEAD_UNCHANGED)
	if current != &"" and wallet.get_gold() < respec_gold(step, data):
		return CommandResult.fail(Reasons.NOT_ENOUGH_GOLD)
	return CommandResult.success()


static func _qty(item_id: StringName, qty: int) -> ItemQty:
	var result := ItemQty.new()
	result.item_id = item_id
	result.qty = qty
	return result


## F-94 refusals in order after `unknown_id`: not_a_tool, upgrade_max, level_too_low, not_enough_gold, not_enough_items.
## Success carries nothing; the caller reads `step(inst.upgrade + 1, data)` to spend.
static func check(inst: ItemInstance, skills: SkillsSystem, wallet: Wallet, bank: Bank, data: GameData) -> CommandResult:
	var def: ItemDef = data.item(inst.base_id) if data.has_item(inst.base_id) else null
	if def == null or def.equip == null or not def.equip.unique:
		return CommandResult.fail(Reasons.NOT_A_TOOL)
	if inst.upgrade >= max_level(data):
		return CommandResult.fail(Reasons.UPGRADE_MAX)
	var next: Dictionary = step(inst.upgrade + 1, data)
	if next.is_empty():
		return CommandResult.fail(Reasons.NOT_ENOUGH_ITEMS)
	if skills.get_level(skill_of_slot(def.equip.slot)) < int(next["min_level"]):
		return CommandResult.fail(Reasons.LEVEL_TOO_LOW)
	if wallet.get_gold() < int(next["gold"]):
		return CommandResult.fail(Reasons.NOT_ENOUGH_GOLD)
	var plates: ItemQty = next["plates"]
	var handles: ItemQty = next["handles"]
	if not bank.has(plates.item_id, plates.qty) or not bank.has(handles.item_id, handles.qty):
		return CommandResult.fail(Reasons.NOT_ENOUGH_ITEMS)
	return CommandResult.success()


## Spends the step towards `+(inst.upgrade + 1)` (gold, plates, handles) and raises the tool; `check` has passed.
static func apply(inst: ItemInstance, wallet: Wallet, bank: Bank, data: GameData) -> void:
	var next: Dictionary = step(inst.upgrade + 1, data)
	if int(next["gold"]) > 0:
		wallet.spend(int(next["gold"]))
	for key: String in ["plates", "handles"]:
		var qty: ItemQty = next[key]
		Upgrade.spend(bank, qty.item_id, qty.qty)
	inst.upgrade += 1


## A fresh `heads` list: one empty choice per head step.
static func blank_heads(data: GameData) -> Array[StringName]:
	var result: Array[StringName] = []
	result.resize(head_steps(data).size())
	result.fill(&"")
	return result


## F-198: validates (`check_head`) and then sets `heads` of `inst` at `step`; a change of a head already chosen spends `respec_gold`.
static func choose_head(inst: ItemInstance, step: int, head_id: StringName, wallet: Wallet, data: GameData) -> CommandResult:
	var checked: CommandResult = check_head(inst, step, head_id, wallet, data)
	if not checked.ok:
		return checked
	var index: int = head_steps(data).find(step)
	if inst.heads.size() <= index:
		inst.heads.resize(index + 1)
	if inst.heads[index] != &"":
		wallet.spend(respec_gold(step, data))
	inst.heads[index] = head_id
	return checked


## F-198: the gold of changing the head of `step` of `inst`: 0 for a step with no choice yet or that is not a head step.
static func head_cost(inst: ItemInstance, step: int, data: GameData) -> int:
	var index: int = head_steps(data).find(step)
	if index < 0 or index >= inst.heads.size() or inst.heads[index] == &"":
		return 0
	return respec_gold(step, data)
