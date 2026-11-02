class_name GatheringResolver
extends RefCounted
## One completed cycle of a gathering action (docs/01_GDD.md §4):
## 1. products: base quantities, all doubled when the `double_item_chance` roll succeeds (F-06);
## 2. rift shard roll (F-07): `gathering.rift_shard_base_chance_pct + T(rift_shard_chance)`, total limited to 0..100;
## 3. everything goes to the bank; when the new items do not all find a slot the cycle does not count:
##    nothing is added, no xp, no mastery, outcome `bank_full`;
## 4. skill xp (F-02) and mastery (F-10, F-12) through their systems.
## Every roll goes through `session.rng`, always in this order (double, then shard), so runs are reproducible.

const DOUBLE_STAT: StringName = &"double_item_chance"
const SHARD_STAT: StringName = &"rift_shard_chance"
const SHARD_BASE_KEY: String = "gathering.rift_shard_base_chance_pct"
const SHARD_ITEM: StringName = &"rift_shard"
const SHARD_QTY: int = 1
## F-06: a successful double roll multiplies every product by this factor.
const DOUBLE_FACTOR: int = 2


static func resolve(session: GameSession, action: ActionDef) -> ActionOutcome:
	var outcome := ActionOutcome.new()
	var ctx: ModifierContext = ModifierContext.for_action(action.skill_id, action.id)
	var factor: int = DOUBLE_FACTOR if session.rng.roll_pct(session.modifiers.total(DOUBLE_STAT, ctx)) else 1
	var produced: Dictionary[StringName, int] = {}
	for output: ItemQty in action.outputs:
		produced[output.item_id] = produced.get(output.item_id, 0) + output.qty * factor
	outcome.shard = session.rng.roll_pct(_shard_chance(session, ctx))
	if outcome.shard:
		produced[SHARD_ITEM] = produced.get(SHARD_ITEM, 0) + SHARD_QTY
	if not _fits(session.bank, produced):
		outcome.reason = Reasons.BANK_FULL
		return outcome
	for item_id: StringName in produced:
		var added: CommandResult = session.bank.add(item_id, produced[item_id])
		assert(added.ok, "bank.add failed after the room check")
	outcome.outputs = produced
	outcome.xp = session.skills.add_xp(action.skill_id, action.xp, ctx)
	outcome.mastery_xp = session.mastery.add_for_action(action)
	outcome.ok = true
	return outcome


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
	return new_items <= bank.capacity() - bank.used()
