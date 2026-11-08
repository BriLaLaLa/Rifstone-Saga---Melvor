class_name EngraverResolver
extends RefCounted
## One completed cycle of an action with `kind: crystallize` (docs/05_INTERFACES.md §5.22, F-104): N Rift Dust for one
## Crystal, with a chance that grows with the Engraver level. One `roll_pct` on `session.rng` per cycle, no
## preservation or double roll. The room is checked before the roll (no roll when the Crystal does not fit).
## Success: inputs out, Crystal in, xp (F-02) and mastery in full. Failure: `fail_loss` of the dust is lost, no Crystal,
## xp in proportion to the dust lost, no mastery; the cycle counts (`outcome.failed`).

const CHANCE_MIN_KEY: String = "engraver.crystal_chance_min_pct"
const CHANCE_MAX_KEY: String = "engraver.crystal_chance_max_pct"
const LOSS_KEY: String = "engraver.crystal_fail_loss_pct"
const EPSILON: float = 1e-9
const MAX_LEVEL: int = 99  # the (L - 1) / 98 span of F-104


## F-104: chance_pct = min + (max - min) x (L - 1) / 98.
static func crystal_chance_pct(engraver_level: int, data: GameData) -> float:
	var low: float = float(data.balance_value(CHANCE_MIN_KEY))
	var high: float = float(data.balance_value(CHANCE_MAX_KEY))
	var level: int = clampi(engraver_level, 1, MAX_LEVEL)
	return low + (high - low) * float(level - 1) / float(MAX_LEVEL - 1)


## F-104: floor(qty x crystal_fail_loss_pct / 100).
static func fail_loss(qty: int, data: GameData) -> int:
	return floori(float(qty) * float(data.balance_value(LOSS_KEY)) / 100.0 + EPSILON)


static func can_start(session: GameSession, action: ActionDef) -> CommandResult:
	return ArtisanResolver.can_start(session, action)


static func resolve(session: GameSession, action: ActionDef) -> ActionOutcome:
	var outcome := ActionOutcome.new()
	if not can_start(session, action).ok:
		outcome.reason = Reasons.MISSING_INPUTS
		return outcome
	var needed: Dictionary[StringName, int] = _sum(action.inputs)
	var produced: Dictionary[StringName, int] = _sum(action.outputs)
	if not _fits(session, needed, produced):
		outcome.reason = Reasons.BANK_FULL
		return outcome
	var ctx: ModifierContext = ModifierContext.for_action(action.skill_id, action.id)
	var chance: float = crystal_chance_pct(session.skills.get_level(action.skill_id), session.data)
	if session.rng.roll_pct(chance):
		_apply(session, needed, produced)
		outcome.consumed = needed
		outcome.outputs = produced
		outcome.xp = session.skills.add_xp(action.skill_id, action.xp, ctx)
		outcome.mastery_xp = session.mastery.add_for_action(action)
		outcome.ok = true
		return outcome
	var total: int = 0
	for item_id: StringName in needed:
		total += needed[item_id]
	var lost: Dictionary[StringName, int] = {}
	var lost_total: int = 0
	for item_id: StringName in needed:
		lost[item_id] = fail_loss(needed[item_id], session.data)
		lost_total += lost[item_id]
	_apply(session, lost, {})
	outcome.consumed = lost
	outcome.xp = session.skills.add_xp(action.skill_id, action.xp * lost_total / total, ctx)
	outcome.failed = true
	outcome.ok = true
	return outcome


static func _apply(session: GameSession, removed: Dictionary[StringName, int], added: Dictionary[StringName, int]) -> void:
	for item_id: StringName in removed:
		if removed[item_id] > 0:
			var result: CommandResult = session.bank.remove(item_id, removed[item_id])
			assert(result.ok, "bank.remove failed after the inputs check")
	for item_id: StringName in added:
		var result: CommandResult = session.bank.add(item_id, added[item_id])
		assert(result.ok, "bank.add failed after the room check")


static func _sum(list: Array[ItemQty]) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	for entry: ItemQty in list:
		result[entry.item_id] = result.get(entry.item_id, 0) + entry.qty
	return result


# True when, after the inputs are consumed, every product fits (slots freed by fully consumed inputs count).
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
