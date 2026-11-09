class_name MasteryMath
extends RefCounted
## Pure mastery formulas (docs/02_FORMULAS.md F-10..F-13, F-15, F-122 step bonuses). No state.
##
## The F-10 parameters come from balance.json (`mastery.base_factor`, `mastery.per_level`, `mastery.ratio_weight`);
## the other formulas take their parameters from the caller, who reads them from the data.

const BASE_FACTOR_KEY: String = "mastery.base_factor"
const PER_LEVEL_KEY: String = "mastery.per_level"
const RATIO_WEIGHT_KEY: String = "mastery.ratio_weight"
const STEP_EVERY_KEY: String = "mastery.step.every_levels"


## F-10: mxp = max(1, floor(t × (base_factor + per_level × L + ratio_weight × R) × (1 + pct/100))),
## with t = base interval in seconds (not the reduced one).
static func mastery_xp(interval_ms: int, item_level: int, skill_ratio: float, mastery_xp_pct: float,
		data: GameData) -> int:
	var base_factor: float = float(data.balance_value(BASE_FACTOR_KEY))
	var per_level: float = float(data.balance_value(PER_LEVEL_KEY))
	var ratio_weight: float = float(data.balance_value(RATIO_WEIGHT_KEY))
	var seconds: float = float(interval_ms) / 1000.0
	var per_second: float = base_factor + per_level * float(item_level) + ratio_weight * skill_ratio
	# (100 + pct) / 100 keeps whole-percent results exact, as in F-02.
	return maxi(1, floori(seconds * per_second * (100.0 + mastery_xp_pct) / 100.0))


## F-102 (M12): the helper's part of a mastery xp: round(mxp × share_pct / 100).
static func helper_share(mastery_xp: int, share_pct: float) -> int:
	return roundi(float(mastery_xp) * share_pct / 100.0)


## F-12: round(mxp × share_pct / 100).
static func pool_gain(mastery_xp: int, share_pct: float) -> int:
	return roundi(float(mastery_xp) * share_pct / 100.0)


## F-13: number of mastery actions of the skill × pool_cap_per_item.
static func pool_cap(action_count: int, per_item: int) -> int:
	return action_count * per_item


## F-15: ceil(pool_cap × cost_pct / 100).
static func node_cost(pool_cap: int, cost_pct: float) -> int:
	return ceili(float(pool_cap) * cost_pct / 100.0)


## F-122 (M14): number of bonus steps at mastery `level`, `floor(level / mastery.step.every_levels)`.
static func step_count(level: int, data: GameData) -> int:
	@warning_ignore("integer_division")
	return maxi(level, 0) / int(data.balance_value(STEP_EVERY_KEY))


## F-122: the bonus of an action with mastery at `level`: `n` x the modifiers of `mastery.step.<kind>` (kind &"gathering"
## or &"crafting"), without scope (`MasterySystem` sets the action scope). Empty below the first step.
static func step_bonus(level: int, kind: StringName, data: GameData) -> Array[Modifier]:
	return _step_modifiers(step_count(level, data), kind, data)


## F-122: the next bonus: `{"level": the mastery level that grants it, "modifiers": the modifiers it adds (one step)}`;
## `{}` when no further step exists up to the maximum mastery level.
static func next_step(level: int, kind: StringName, data: GameData) -> Dictionary:
	var next_level: int = (step_count(level, data) + 1) * int(data.balance_value(STEP_EVERY_KEY))
	if next_level > data.mastery_table().max_level:
		return {}
	return {"level": next_level, "modifiers": _step_modifiers(1, kind, data)}


## The kind of bonus (`mastery.step.<kind>`) of a skill category: gathering skills &"gathering", artisan skills &"crafting".
static func step_kind(category: StringName) -> StringName:
	return &"gathering" if category == &"gathering" else &"crafting"


static func _step_modifiers(times: int, kind: StringName, data: GameData) -> Array[Modifier]:
	var result: Array[Modifier] = []
	if times <= 0:
		return result
	for entry: Variant in data.balance_value("mastery.step.%s" % kind) as Array:
		var row: Dictionary = entry as Dictionary
		result.append(Modifier.make(StringName(str(row["stat"])), float(row["value"]) * float(times)))
	return result
