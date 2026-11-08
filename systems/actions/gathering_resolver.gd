class_name GatheringResolver
extends RefCounted
## One completed cycle of a gathering action (docs/01_GDD.md §4):
## 1. products: base quantities, all doubled when the `double_item_chance` roll succeeds (F-06);
## 2. rift shard roll (F-07): `gathering.rift_shard_base_chance_pct + T(rift_shard_chance)`, total limited to 0..100;
## 2b. (M12, F-103) byproduct roll of the mastery milestone 25, after the shard (never doubled);
## 3. everything goes to the bank; when the new items do not all find a slot the cycle does not count:
##    nothing is added, no xp, no mastery, outcome `bank_full`;
## 4. skill xp (F-02) and mastery (F-10, F-12) through their systems.
## Every roll goes through `session.rng`, always in this order (double, shard, byproduct), so runs are reproducible.

const DOUBLE_STAT: StringName = &"double_item_chance"
const SHARD_STAT: StringName = &"rift_shard_chance"
const SHARD_BASE_KEY: String = "gathering.rift_shard_base_chance_pct"
const HELPER_XP_KEY: String = "helper.xp_pct"
const HELPER_MASTERY_KEY: String = "helper.mastery_pct"
const SHARD_ITEM: StringName = &"rift_shard"
const SHARD_QTY: int = 1
const BYPRODUCT_QTY: int = 1  # F-103: never doubled
## F-06: a successful double roll multiplies every product by this factor.
const DOUBLE_FACTOR: int = 2


## `helper_grade` non-empty (M12, F-101/F-102) = the helper profile: the context ignores the player's tool
## (`ModifierContext.for_helper`), xp and mastery are the `helper.xp_pct` / `helper.mastery_pct` share; the rolls are the same.
static func resolve(session: GameSession, action: ActionDef, helper_grade: StringName = &"") -> ActionOutcome:
	var outcome := ActionOutcome.new()
	var is_helper: bool = helper_grade != &""
	var ctx: ModifierContext = ModifierContext.for_action(action.skill_id, action.id)
	if is_helper:
		ctx = ModifierContext.for_helper(action.skill_id, action.id)
	var factor: int = DOUBLE_FACTOR if session.rng.roll_pct(session.modifiers.total(DOUBLE_STAT, ctx)) else 1
	var produced: Dictionary[StringName, int] = {}
	for output: ItemQty in action.outputs:
		produced[output.item_id] = produced.get(output.item_id, 0) + output.qty * factor
	outcome.shard = session.rng.roll_pct(_shard_chance(session, ctx))
	if outcome.shard:
		produced[SHARD_ITEM] = produced.get(SHARD_ITEM, 0) + SHARD_QTY
	var byproduct: StringName = _byproduct(session, action)
	if byproduct != &"":
		produced[byproduct] = produced.get(byproduct, 0) + BYPRODUCT_QTY
	if not _fits(session.bank, produced):
		outcome.reason = Reasons.BANK_FULL
		return outcome
	for item_id: StringName in produced:
		var added: CommandResult = session.bank.add(item_id, produced[item_id])
		assert(added.ok, "bank.add failed after the room check")
	outcome.outputs = produced
	var xp_share: float = float(session.data.balance_value(HELPER_XP_KEY)) if is_helper else 100.0
	var mastery_share: float = float(session.data.balance_value(HELPER_MASTERY_KEY)) if is_helper else 100.0
	outcome.xp = session.skills.add_xp(action.skill_id, action.xp, ctx, xp_share)
	outcome.mastery_xp = session.mastery.add_for_action(action, mastery_share)
	outcome.ok = true
	return outcome


# F-103: the byproduct of the 25 milestone (third roll, after double and shard) when the action reached it; else "".
# The roll happens only if the milestone is active, with `mastery.milestones.byproduct_chance_pct`.
static func _byproduct(session: GameSession, action: ActionDef) -> StringName:
	var milestone: MilestoneDef = action.milestone_of(MilestoneDef.TYPE_BYPRODUCT)
	var at: int = int(session.data.balance_value(MasteryMilestones.BYPRODUCT_AT_KEY))
	if milestone == null or not session.mastery.milestone_active(action.id, at):
		return &""
	var chance: float = float(session.data.balance_value(MasteryMilestones.BYPRODUCT_CHANCE_KEY))
	return milestone.item if session.rng.roll_pct(chance) else &""


# F-07 for gathering: base chance from balance.json plus the stat total, limited to 0..100 percent.
static func _shard_chance(session: GameSession, ctx: ModifierContext) -> float:
	var base: float = float(session.data.balance_value(SHARD_BASE_KEY))
	return clampf(base + session.modifiers.total(SHARD_STAT, ctx), 0.0, 100.0)


# True when every item can enter the bank: each new item must pass can_add and together they need free slots.
static func _fits(bank: Bank, items: Dictionary[StringName, int]) -> bool:
	var new_items: int = 0
	for item_id: StringName in items:
		if not bank.can_add(item_id):
			return false
		if bank.get_count(item_id) == 0:
			new_items += 1
	return new_items <= bank.free_boxes()
