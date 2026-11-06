class_name StatTrade
extends TraitEffect
## F-81 `stat_trade` (`zero`: [stat], `mult`: {stat: factor}): after the stats are computed the stats in `zero` are 0,
## the others multiplied by the factor, then limited by stats.json (`CombatantStats.scale_stat`). Passive: no trigger.


func modify_stats(stats: CombatantStats, data: GameData) -> void:
	for stat: Variant in params.get("zero", []):
		stats.scale_stat(StringName(str(stat)), 0.0, data)
	var factors: Dictionary = params.get("mult", {})
	for stat: Variant in factors:
		stats.scale_stat(StringName(str(stat)), float(factors[stat]), data)
