class_name ArtisanResolver
extends RefCounted
## One completed cycle of an artisan action (docs/01_GDD.md §5):
## 1. the cycle needs every input in the bank (checked at the start of the cycle and again here);
## 2. preservation roll (F-08): when it succeeds no input is consumed;
## 3. double roll (F-06): every product x2;
## 4. inputs out, products in; when the products do not find room the cycle does not count and nothing is consumed
##    (outcome `bank_full`); when the inputs are gone (e.g. sold mid-cycle) the cycle fails with `missing_inputs`;
## 5. skill xp (F-02) and mastery (F-10, F-12) through their systems. No rift shard (F-07).
## Since M10 no recipe makes equipment or tools (the data validator forbids it): pieces come from blueprints
## (BlueprintCraft), drops and the starting kit. Rolls go through `session.rng`, in this order: preservation, double.

const PRESERVATION_STAT: StringName = &"preservation_chance"
const DOUBLE_STAT: StringName = &"double_item_chance"
## F-06: a successful double roll multiplies every product by this factor.
const DOUBLE_FACTOR: int = 2


## ok when every input of the action is in the bank in the needed quantity, otherwise `missing_inputs`.
static func can_start(session: GameSession, action: ActionDef) -> CommandResult:
	var needed: Dictionary[StringName, int] = _sum(action.inputs, 1)
	for item_id: StringName in needed:
		if not session.bank.has(item_id, needed[item_id]):
			return CommandResult.fail(Reasons.MISSING_INPUTS)
	return CommandResult.success()


static func resolve(session: GameSession, action: ActionDef) -> ActionOutcome:
	var outcome := ActionOutcome.new()
	if not can_start(session, action).ok:
		outcome.reason = Reasons.MISSING_INPUTS
		return outcome
	var ctx: ModifierContext = ModifierContext.for_action(action.skill_id, action.id)
	var preserved: bool = session.rng.roll_pct(session.modifiers.total(PRESERVATION_STAT, ctx))
	var factor: int = DOUBLE_FACTOR if session.rng.roll_pct(session.modifiers.total(DOUBLE_STAT, ctx)) else 1
	var consumed: Dictionary[StringName, int] = {}
	if not preserved:
		consumed = _sum(action.inputs, 1)
	var produced: Dictionary[StringName, int] = _sum(action.outputs, factor)
	if not _fits(session, consumed, produced):
		outcome.reason = Reasons.BANK_FULL
		return outcome
	for item_id: StringName in consumed:
		var removed: CommandResult = session.bank.remove(item_id, consumed[item_id])
		assert(removed.ok, "bank.remove failed after the inputs check")
	for item_id: StringName in produced:
		var added: CommandResult = session.bank.add(item_id, produced[item_id])
		assert(added.ok, "bank.add failed after the room check")
	outcome.consumed = consumed
	outcome.outputs = produced
	outcome.xp = session.skills.add_xp(action.skill_id, action.xp, ctx)
	outcome.mastery_xp = session.mastery.add_for_action(action)
	outcome.ok = true
	return outcome


# Quantities per item (duplicate entries added up), each times `factor`.
static func _sum(list: Array[ItemQty], factor: int) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	for entry: ItemQty in list:
		result[entry.item_id] = result.get(entry.item_id, 0) + entry.qty * factor
	return result


# True when, after removing `consumed`, every product can enter the bank: each one is a known item and the new
# stacks fit in the free slots (slots freed by fully consumed inputs count).
static func _fits(session: GameSession, consumed: Dictionary[StringName, int],
		produced: Dictionary[StringName, int]) -> bool:
	var slots_delta: int = 0
	for item_id: StringName in consumed:
		if session.bank.get_count(item_id) - consumed[item_id] == 0:
			slots_delta -= 1
	for item_id: StringName in produced:
		if not session.data.has_item(item_id):
			return false
		if session.bank.get_count(item_id) - consumed.get(item_id, 0) == 0:
			slots_delta += 1
	return slots_delta <= session.bank.free_boxes()
