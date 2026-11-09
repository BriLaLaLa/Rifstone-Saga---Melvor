class_name CombatView
extends RefCounted
## The `get_state()` copy for the UI (docs/05_INTERFACES.md §5.10), kept apart from `CombatEngine`.


## `player_hp` is the maximum while idle; `target` follows the trait rule (F-76).
static func build(engine: CombatEngine, encounter: Encounter, abilities: AbilityRunner,
		snapshot: Dictionary) -> Dictionary:
	var me: CombatantStats = engine.player_stats()
	var enemies: Array[Dictionary] = []
	for enemy: Encounter.Enemy in encounter.enemies:
		var entry: Dictionary = {"monster": enemy.def.id, "hp": enemy.hp, "max_hp": enemy.stats.max_hp,
			"timer_ms": enemy.timer_ms, "interval_ms": enemy.stats.attack_interval_ms}
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
	}
	if not (snapshot.get("fracture", {}) as Dictionary).is_empty():  # M13: only inside a Fracture
		view["fracture"] = snapshot["fracture"]
	return view
