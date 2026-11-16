class_name GatheringResolver
extends RefCounted
## The units of a gathering node (docs/01_GDD_M24.md §35.2, F-155); each unit is one cycle of a gathering action (docs/01_GDD.md §4):
## 1. products: base quantities, all doubled when the `double_item_chance` roll succeeds (F-06);
## 2. rift shard roll (F-07): `gathering.rift_shard_base_chance_pct + T(rift_shard_chance)`, total limited to 0..100;
## 2b. (M12, F-103) byproduct roll of the mastery milestone 25, after the shard (never doubled);
## 3. everything goes to the bank; the first unit whose new items do not all find a slot closes the node:
##    what already entered stays, the rest is not produced (outcome `bank_full`);
## 4. skill xp (F-02, F-160) and mastery (F-10, F-12) through their systems, once for the whole node.
## 5. (M14, F-120) the `on_gather` effects of the legendary tool, only for the player: their rolls come first (grade up, bonus item),
##    then the order above; the bonus item is added to the product (never doubled). Without such a tool nothing is drawn.
## Every roll goes through `session.rng`, always in this order (effects, double, shard, byproduct) for each unit, so runs are reproducible.

const DOUBLE_STAT: StringName = &"double_item_chance"
const SHARD_STAT: StringName = &"rift_shard_chance"
const SHARD_BASE_KEY: String = "gathering.rift_shard_base_chance_pct"
const SHARD_ITEM: StringName = &"rift_shard"
const SHARD_QTY: int = 1
const BYPRODUCT_QTY: int = 1  # F-103: never doubled
const BONUS_QTY: int = 1  # F-120 gather_bonus_item: never doubled
## F-06: a successful double roll multiplies every product by this factor.
const DOUBLE_FACTOR: int = 2


## M24 (F-155): `units` units of `action`; `xp_pct` is the xp percentage of the node color (F-154). `outcome.ok` is true when at
## least one unit was put (`outcome.units`, `outcome.reason` = `bank_full` if the node closed early); with none the outcome is
## `bank_full` and nothing changes. xp: `floor(n x action.xp x xp_pct / 100)` then F-02; mastery: F-10 x n, the pool F-12 once.
static func resolve_units(session: GameSession, action: ActionDef, units: int, xp_pct: float) -> ActionOutcome:
	var outcome := ActionOutcome.new()
	var ctx: ModifierContext = ModifierContext.for_action(action.skill_id, action.id)
	var produced: Dictionary[StringName, int] = {}
	var done: int = 0
	for i: int in units:
		var unit: Dictionary[StringName, int] = _roll_unit(session, action, ctx)
		var merged: Dictionary[StringName, int] = produced.duplicate()
		for item_id: StringName in unit:
			merged[item_id] = merged.get(item_id, 0) + unit[item_id]
		if not _fits(session.bank, merged):
			outcome.reason = Reasons.BANK_FULL
			break
		produced = merged
		outcome.shard = outcome.shard or unit.has(SHARD_ITEM)
		done += 1
	if done == 0:
		return outcome
	for item_id: StringName in produced:
		var added: CommandResult = session.bank.add(item_id, produced[item_id])
		assert(added.ok, "bank.add failed after the room check")
	outcome.outputs = produced
	outcome.units = done
	outcome.ok = true
	var base_xp: int = floori(float(done * action.xp) * xp_pct / 100.0)
	if base_xp > 0:
		outcome.xp = session.skills.add_xp(action.skill_id, base_xp, ctx)
	outcome.mastery_xp = session.mastery.add_for_action(action, done)
	return outcome


# The products of one unit.
static func _roll_unit(session: GameSession, action: ActionDef, ctx: ModifierContext) -> Dictionary[StringName, int]:
	var gather: GatherContext = GatherEffects.roll(session, action)  # F-120
	var worked: ActionDef = gather.upgraded_action if gather != null and gather.grade_up else action
	var factor: int = DOUBLE_FACTOR if session.rng.roll_pct(session.modifiers.total(DOUBLE_STAT, ctx)) else 1
	var produced: Dictionary[StringName, int] = {}
	for output: ItemQty in worked.outputs:  # the grade-up gives the product of the next resource, xp stays
		produced[output.item_id] = produced.get(output.item_id, 0) + output.qty * factor
	if session.rng.roll_pct(_shard_chance(session, ctx)):
		produced[SHARD_ITEM] = produced.get(SHARD_ITEM, 0) + SHARD_QTY
	var byproduct: StringName = _byproduct(session, action, gather.byproduct_mult if gather != null else 1.0)
	if byproduct != &"":
		produced[byproduct] = produced.get(byproduct, 0) + BYPRODUCT_QTY
	if gather != null:
		for bonus: StringName in gather.bonus_items:
			produced[bonus] = produced.get(bonus, 0) + BONUS_QTY
	return produced


# F-103: the byproduct of the 25 milestone (third roll, after double and shard) when the action reached it; else "".
# The roll happens only if the milestone is active, with `mastery.milestones.byproduct_chance_pct`.
static func _byproduct(session: GameSession, action: ActionDef, chance_mult: float = 1.0) -> StringName:
	var milestone: MilestoneDef = action.milestone_of(MilestoneDef.TYPE_BYPRODUCT)
	var at: int = int(session.data.balance_value(MasteryMilestones.BYPRODUCT_AT_KEY))
	if milestone == null or not session.mastery.milestone_active(action.id, at):
		return &""
	var chance: float = byproduct_chance(session.data, chance_mult)
	return milestone.item if session.rng.roll_pct(chance) else &""


## F-103 chance in percent of the byproduct of the milestone 25 x `chance_mult` (F-120 `byproduct_mult`), at most 100.
static func byproduct_chance(data: GameData, chance_mult: float = 1.0) -> float:
	return minf(100.0, float(data.balance_value(MasteryMilestones.BYPRODUCT_CHANCE_KEY)) * chance_mult)


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
