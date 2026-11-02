class_name MasteryMath
extends RefCounted
## Pure mastery formulas (docs/02_FORMULAS.md F-10..F-13, F-15, F-11 multiplier). No state.
##
## The F-10 parameters come from balance.json (`mastery.base_factor`, `mastery.per_level`, `mastery.ratio_weight`);
## the other formulas take their parameters from the caller, who reads them from the data.

const BASE_FACTOR_KEY: String = "mastery.base_factor"
const PER_LEVEL_KEY: String = "mastery.per_level"
const RATIO_WEIGHT_KEY: String = "mastery.ratio_weight"


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


## F-12: round(mxp × share_pct / 100).
static func pool_gain(mastery_xp: int, share_pct: float) -> int:
	return roundi(float(mastery_xp) * share_pct / 100.0)


## F-13: number of mastery actions of the skill × pool_cap_per_item.
static func pool_cap(action_count: int, per_item: int) -> int:
	return action_count * per_item


## F-15: ceil(pool_cap × cost_pct / 100).
static func node_cost(pool_cap: int, cost_pct: float) -> int:
	return ceili(float(pool_cap) * cost_pct / 100.0)


## F-11: `every_levels: k` → floor(L / k); `at_level: n` → 1 when L ≥ n, else 0; a rule with neither → 0.
static func rule_multiplier(rule: MasteryBonusRule, level: int) -> int:
	if rule.every_levels > 0:
		@warning_ignore("integer_division")
		return maxi(level, 0) / rule.every_levels
	if rule.at_level > 0:
		return 1 if level >= rule.at_level else 0
	return 0
