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
		"skip_stone_level": snapshot.get("skip_stone_level", 0),  # M15 (F-128): a slot setting, saved also when idle
	}
	if not idle and snapshot.get("wave") is Dictionary and not (snapshot["wave"] as Dictionary).is_empty():  # M15 (F-126)
		result["wave"] = snapshot["wave"]
	if not idle and snapshot.get("fracture") is Dictionary and not (snapshot["fracture"] as Dictionary).is_empty():  # M13
		result["fracture"] = snapshot["fracture"]
	if not idle and snapshot.get("dungeon") is Dictionary and not (snapshot["dungeon"] as Dictionary).is_empty():  # M22
		result["dungeon"] = snapshot["dungeon"]
	if snapshot.get("miniboss_pending") == true:  # M22 (F-139): additive, absent = false
		result["miniboss_pending"] = true
	return result


## Tolerant read (an unknown area or monster, or a malformed fight, gives `idle` with the bag and counters kept).
## Returns the same keys as `write` takes plus `encounter` (Encounter, null when idle); `loot` stays in `d`.
## `run`: the Fracture already loaded by `FractureSystem` (null = none); a saved Fracture fight needs it (M13).
## `dungeon_run`: the same for the run of `DungeonSystem` (M22); the states `await` and `intro` exist only in a dungeon.
static func read(d: Dictionary, data: GameData, run: FractureRun = null, dungeon_run: DungeonRun = null) -> Dictionary:
	var result: Dictionary = {
		"state": CombatEngine.STATE_IDLE, "area": &"", "encounter": null, "player_hp": 0, "player_timer_ms": 0,
		"hand": 0, "between_ms": 0, "effects": {}, "abilities": {}, "buffs": {}, "fracture": {}, "dungeon": {},
		"kills": _read_kills(d, data), "deaths": maxi(0, _int(d, "deaths")),
		"food_eaten": maxi(0, _int(d, "food_eaten")), "skip_stone_level": _skip_level(d, data),
	}
	var saved_state := StringName(str(d.get("state", "idle")))
	if not [CombatEngine.STATE_ENCOUNTER, CombatEngine.STATE_RIFTSTONE, CombatEngine.STATE_BETWEEN, CombatEngine.STATE_AWAIT,
			CombatEngine.STATE_INTRO].has(saved_state):
		return result
	var area_id := StringName(str(d.get("area", "")))
	var fracture: Variant = d.get("fracture")
	var dungeon: Variant = d.get("dungeon")
	var in_dungeon: bool = dungeon is Dictionary
	if in_dungeon:
		if dungeon_run == null:
			Log.warn(LOG_CATEGORY, "saved dungeon fight without a valid run: idle")
			return result
		result["dungeon"] = dungeon
		area_id = &""
	elif saved_state == CombatEngine.STATE_AWAIT or saved_state == CombatEngine.STATE_INTRO:
		Log.warn(LOG_CATEGORY, "saved state '%s' outside a dungeon: idle" % saved_state)
		return result
	elif fracture is Dictionary:
		if run == null:
			Log.warn(LOG_CATEGORY, "saved Fracture fight without a valid Fracture: idle")
			return result
		result["fracture"] = fracture
		area_id = &""
	elif not data.has_area(area_id):
		Log.warn(LOG_CATEGORY, "saved fight in unknown area '%s': idle" % area_id)
		return result
	var encounter := Encounter.new()
	if saved_state == CombatEngine.STATE_ENCOUNTER or saved_state == CombatEngine.STATE_RIFTSTONE:
		encounter = Encounter.from_save(d["enemies"] if d.get("enemies") is Array else [], data, run if fracture is Dictionary else null)
		if encounter == null:
			Log.warn(LOG_CATEGORY, "saved fight with an unknown monster or a malformed enemy: idle")
			return result
	result["area"] = area_id
	result["encounter"] = encounter
	var live: bool = encounter.alive_count() > 0
	result["state"] = CombatEngine.STATE_BETWEEN if not live else (
			CombatEngine.STATE_RIFTSTONE if encounter.has_stone() else CombatEngine.STATE_ENCOUNTER)
	if in_dungeon:  # no `between` in a dungeon: no live enemy = the scene of a stage or the wait for the next choice
		result["state"] = CombatEngine.STATE_ENCOUNTER if live else (
				CombatEngine.STATE_INTRO if saved_state == CombatEngine.STATE_INTRO else CombatEngine.STATE_AWAIT)
	result["hand"] = clampi(_int(d, "hand"), 0, 1)
	result["player_hp"] = maxi(1, _int(d, "player_hp"))  # clamped to the maximum when the modifiers are rebuilt
	result["player_timer_ms"] = maxi(0, _int(d, "player_timer_ms"))
	result["between_ms"] = maxi(0, _int(d, "between_ms"))
	if not live and saved_state != CombatEngine.STATE_BETWEEN and not in_dungeon:
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


# F-128: an integer in 0..99; malformed or out of range = 0, absent = the value of a new slot (`combat.skip_stone_level`).
static func _skip_level(d: Dictionary, data: GameData) -> int:
	var saved: Variant = d.get("skip_stone_level")
	if (saved is int or saved is float) and float(saved) == floorf(float(saved)) and int(saved) >= 0 and int(saved) <= 99:
		return int(saved)
	if d.has("skip_stone_level"):
		Log.warn(LOG_CATEGORY, "saved skip_stone_level %s is not 0..99: reset to 0" % JSON.stringify(saved))
		return 0
	return int(data.balance_value("combat.skip_stone_level"))


static func _int(d: Dictionary, key: String) -> int:
	var v: Variant = d.get(key)
	return int(v) if v is int or v is float else 0
