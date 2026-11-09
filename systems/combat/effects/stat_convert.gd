class_name StatConvert
extends TraitEffect
## F-120 `stat_convert` (`from`, `to`, `pct`), hook `modify_stats`: after the stats are computed `to` grows by
## floor(from x pct/100), then the limits of stats.json apply (`CombatantStats.add_to_stat`). Passive: no trigger.


func modify_stats(stats: CombatantStats, data: GameData) -> void:
	var source: float = stats.stat_value(StringName(str(params["from"])))
	var gained: int = int(floor(source * float(params["pct"]) / 100.0 + CombatMath.EPSILON))
	if gained != 0:
		stats.add_to_stat(StringName(str(params["to"])), float(gained), data)
