class_name CombatSave
extends RefCounted
## Save format of the combat engine (docs/05_INTERFACES.md §6), kept apart from `CombatEngine`: it only turns the
## engine's plain values into the `combat` dictionary and back. It owns the rules of the format: an idle engine saves
## the bag and the counters only (the rest is written as 0 / ""), and a load is tolerant.

const LOG_CATEGORY: String = "combat"


## `snapshot`: state, area, player_hp, player_timer_ms, hand, between_ms, enemies (Array), effects (Dictionary), loot
## (Array), abilities and buffs (Dictionaries: timers and running buffs), kills (Dictionary[StringName, int]),
## deaths, food_eaten, stone (the F-87 counter and pending flag, saved also when idle).
static func write(snapshot: Dictionary) -> Dictionary:
	var kills_out: Dictionary = {}
	var kills: Dictionary = snapshot["kills"]
	for id: StringName in kills:
		kills_out[String(id)] = kills[id]
	var idle: bool = snapshot["state"] == CombatEngine.STATE_IDLE
	var result: Dictionary = {
		"state": String(snapshot["state"]), "area": "" if idle else String(snapshot["area"]),
		"player_hp": 0 if idle else snapshot["player_hp"],
		"player_timer_ms": 0 if idle else snapshot["player_timer_ms"],
		"hand": 0 if idle else snapshot["hand"],
		"between_ms": 0 if idle else snapshot["between_ms"],
		"enemies": [] if idle else snapshot["enemies"],
		"effects": {} if idle else snapshot["effects"], "abilities": {} if idle else snapshot["abilities"],
		"buffs": {} if idle else snapshot["buffs"],
		"loot": snapshot["loot"], "kills": kills_out, "deaths": snapshot["deaths"],
		"food_eaten": snapshot["food_eaten"], "stone": snapshot["stone"],
	}
	if not idle and snapshot.get("fracture") is Dictionary and not (snapshot["fracture"] as Dictionary).is_empty():  # M13
		result["fracture"] = snapshot["fracture"]
	return result


## Tolerant read (an unknown area or monster, or a malformed fight, gives `idle` with the bag and counters kept).
## Returns the same keys as `write` takes plus `encounter` (Encounter, null when idle); `loot` stays in `d`.
## `run`: the Fracture already loaded by `FractureSystem` (null = none); a saved Fracture fight needs it (M13).
static func read(d: Dictionary, data: GameData, run: FractureRun = null) -> Dictionary:
	var result: Dictionary = {
		"state": CombatEngine.STATE_IDLE, "area": &"", "encounter": null, "player_hp": 0, "player_timer_ms": 0,
		"hand": 0, "between_ms": 0, "effects": {}, "abilities": {}, "buffs": {}, "fracture": {},
		"kills": _read_kills(d, data), "deaths": maxi(0, _int(d, "deaths")),
		"food_eaten": maxi(0, _int(d, "food_eaten")),
	}
	var saved_state := StringName(str(d.get("state", "idle")))
	if not [CombatEngine.STATE_ENCOUNTER, CombatEngine.STATE_RIFTSTONE, CombatEngine.STATE_BETWEEN].has(saved_state):
		return result
	var area_id := StringName(str(d.get("area", "")))
	var fracture: Variant = d.get("fracture")
	if fracture is Dictionary:
		if run == null:
			Log.warn(LOG_CATEGORY, "saved Fracture fight without a valid Fracture: idle")
			return result
		result["fracture"] = fracture
		area_id = &""
	elif not data.has_area(area_id):
		Log.warn(LOG_CATEGORY, "saved fight in unknown area '%s': idle" % area_id)
		return result
	var encounter := Encounter.new()
	if saved_state != CombatEngine.STATE_BETWEEN:
		encounter = Encounter.from_save(d["enemies"] if d.get("enemies") is Array else [], data, run if fracture is Dictionary else null)
		if encounter == null:
			Log.warn(LOG_CATEGORY, "saved fight with an unknown monster or a malformed enemy: idle")
			return result
	result["area"] = area_id
	result["encounter"] = encounter
	var live: bool = encounter.alive_count() > 0
	result["state"] = CombatEngine.STATE_BETWEEN if not live else (
			CombatEngine.STATE_RIFTSTONE if encounter.has_stone() else CombatEngine.STATE_ENCOUNTER)
	result["hand"] = clampi(_int(d, "hand"), 0, 1)
	result["player_hp"] = maxi(1, _int(d, "player_hp"))  # clamped to the maximum when the modifiers are rebuilt
	result["player_timer_ms"] = maxi(0, _int(d, "player_timer_ms"))
	result["between_ms"] = maxi(0, _int(d, "between_ms"))
	if not live and saved_state != CombatEngine.STATE_BETWEEN:
		result["between_ms"] = int(data.balance_value("combat.respawn_ms"))
	result["effects"] = d.get("effects", {})
	result["abilities"] = d.get("abilities", {})
	result["buffs"] = d.get("buffs", {})
	return result


static func _read_kills(d: Dictionary, data: GameData) -> Dictionary[StringName, int]:
	var kills: Dictionary[StringName, int] = {}
	var saved: Variant = d.get("kills")
	if not (saved is Dictionary):
		return kills
	for key: Variant in (saved as Dictionary):
		var id := StringName(str(key))
		var count: Variant = (saved as Dictionary)[key]
		if not data.has_monster(id) or not (count is int or count is float) or int(count) <= 0:
			Log.warn(LOG_CATEGORY, "saved kill count of '%s' discarded" % id)
			continue
		kills[id] = int(count)
	return kills


static func _int(d: Dictionary, key: String) -> int:
	var v: Variant = d.get(key)
	return int(v) if v is int or v is float else 0
