class_name CombatView
extends RefCounted
## The `get_state()` copy for the UI (docs/05_INTERFACES.md §5.10), kept apart from `CombatEngine`.


## `player_hp` is the maximum while idle; `target` follows the trait rule (F-76).
static func build(engine: CombatEngine, encounter: Encounter, abilities: AbilityRunner,
		snapshot: Dictionary) -> Dictionary:
	var me: CombatantStats = engine.player_stats()
	var data: GameData = snapshot["data"]
	var player_acc: int = engine.player_stats(snapshot["hand"]).accuracy
	var enemies: Array[Dictionary] = []
	for enemy: Encounter.Enemy in encounter.enemies:
		# F-129: "hit_pct" = whole % of the player on this enemy, "enemy_hit_pct" = of this enemy on the player
		var entry: Dictionary = {"monster": enemy.def.id, "hp": enemy.hp, "max_hp": enemy.stats.max_hp,
			"timer_ms": enemy.timer_ms, "interval_ms": enemy.stats.attack_interval_ms,
			"hit_pct": CombatMath.hit_pct(player_acc, enemy.stats.evasion, data),
			"enemy_hit_pct": CombatMath.hit_pct(enemy.stats.accuracy, me.evasion, data)}
		if enemy.summoned:
			entry["summoned"] = true
		enemies.append(entry)
	var idle: bool = snapshot["state"] == CombatEngine.STATE_IDLE
	var view: Dictionary = {
		"state": snapshot["state"], "area": snapshot["area"], "player_hp": me.max_hp if idle else snapshot["player_hp"],
		"player_max_hp": me.max_hp, "player_timer_ms": snapshot["player_timer_ms"],
		"player_interval_ms": engine.player_stats(snapshot["hand"]).attack_interval_ms, "hand": snapshot["hand"],
		"between_ms": snapshot["between_ms"], "enemies": enemies, "target": encounter.target(snapshot["rule"]),
		"abilities": abilities.view(), "buffs": abilities.buffs(),
		# M15 (05 §5.25): the stone of the fight ({} outside it), the skip setting and the number of living enemies
		"stone": snapshot.get("stone", {}), "skip_stone_level": snapshot.get("skip_stone_level", 0),
		"enemies_alive": encounter.alive_count(),
	}
	if not (snapshot.get("fracture", {}) as Dictionary).is_empty():  # M13: only inside a Fracture
		view["fracture"] = snapshot["fracture"]
	return view
