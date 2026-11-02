class_name ActionMath
extends RefCounted
## Pure interval formulas of the actions (docs/02_FORMULAS.md F-03, F-51). Stat totals arrive already clamped by
## ModifierService (F-05), so `interval_pct` is never below the `skill_interval_pct` minimum.


## F-03: max(min_ms, round(base_ms × (1 + interval_pct / 100))).
static func interval_ms(base_ms: int, interval_pct: float, min_ms: int) -> int:
	return maxi(min_ms, roundi(base_ms * (1.0 + interval_pct / 100.0)))


## F-51 (M8): round(interval_ms × (1 + penalty_pct / 100)) for the secondary lane.
static func secondary_interval_ms(interval_ms: int, penalty_pct: float) -> int:
	return roundi(interval_ms * (1.0 + penalty_pct / 100.0))
