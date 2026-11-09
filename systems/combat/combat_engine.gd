class_name CombatEngine
extends CombatFight
## Event-driven group combat (docs/01_GDD.md §10, docs/05_INTERFACES.md §5.10): the commands, the state for the UI, `advance` and
## the save. `advance` jumps from timer to timer (`advance(1000)` = ten `advance(100)`); the mechanics are in `CombatFight`.

const SAVE_KEY: StringName = &"combat"


## unknown_id, requirement_not_met (character level), fracture_active. Stops the main-lane action. The area already fought: no change.
func start(area_id: StringName) -> CommandResult:
	if _frac.active():
		return CommandResult.fail(Reasons.FRACTURE_ACTIVE)
	if not _session.data.has_area(area_id):
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	var area: AreaDef = _session.data.area(area_id)
	for key: StringName in area.requirements:
		if key == &"character" and _session.character.get_level() < area.requirements[key]:
			return CommandResult.fail(Reasons.REQUIREMENT_NOT_MET)
	if is_active() and _area_id == area_id:
		return CommandResult.success()
	stop(Reasons.REPLACED)
	_session.actions.stop(ActionRunner.MAIN, Reasons.REPLACED)
	_area_id = area_id
	_hand = 0
	_fx.reset()
	_player_hp = player_stats().max_hp
	_session.events.combat_started.emit(area_id)
	_session.events.player_hp_changed.emit(_player_hp, _player_hp)
	_begin_encounter()
	return CommandResult.success()


## Back to idle with full hp; the loot bag is kept. Idle: nothing happens.
func stop(reason: StringName = Reasons.STOPPED_BY_USER) -> void:
	if _state == STATE_IDLE:
		return
	if _frac.active():  # a stop during a Fracture is an abandon (01 §17.5): the bag is lost and the fight stops
		_end_fracture(&"abandoned", reason, false)
		return
	_state = STATE_IDLE
	_area_id = &""
	_encounter = Encounter.new()
	_between_ms = 0
	_fx.reset()
	_abilities.reset()
	_stop_log.append(reason)
	_set_hp(player_stats().max_hp)
	_session.events.combat_stopped.emit(reason)


## M13 (05 §5.23), only `FractureSystem.open`: fracture_active. The fight in the area stops (REPLACED) with the action;
## `run.return_area` is the area being fought; full hp, hand 0, the first group.
func start_fracture(run: FractureRun) -> CommandResult:
	if _frac.active():
		return CommandResult.fail(Reasons.FRACTURE_ACTIVE)
	run.return_area = _area_id
	stop(Reasons.REPLACED)
	_session.actions.stop(ActionRunner.MAIN, Reasons.REPLACED)
	_frac.begin(run)
	_area_id = &""
	_hand = 0
	_fx.reset()
	_player_hp = player_stats().max_hp
	_session.events.combat_started.emit(&"")
	_session.events.player_hp_changed.emit(_player_hp, _player_hp)
	_begin_encounter()
	_resume()
	return CommandResult.success()


## Only `FractureSystem.abandon`: a defeat with the outcome `abandoned`; then back to the area.
func abandon_fracture() -> void:
	if _frac.active():
		_end_fracture(&"abandoned", Reasons.FRACTURE_ABANDONED, true)
		_resume()


func in_fracture() -> bool:
	return _frac.active()


func fracture_run() -> FractureRun:
	return _frac.run


## Manual meal (F-29): no_food, not_running.
func eat() -> CommandResult:
	if _state == STATE_IDLE:
		return CommandResult.fail(Reasons.NOT_RUNNING)
	var before: int = _food_count()
	var new_hp: int = AutoEat.eat_one(_session, _player_hp, player_stats().max_hp)
	if new_hp < 0:
		return CommandResult.fail(Reasons.NO_FOOD)
	_food_eaten += before - _food_count()
	_set_hp(new_hp)
	return CommandResult.success()


func state() -> StringName:
	return _state


func area_id() -> StringName:
	return _area_id


func kills(monster_id: StringName) -> int:
	return _kills.get(monster_id, 0)


func total_kills() -> Dictionary[StringName, int]:
	return _kills.duplicate()


func deaths() -> int:
	return _deaths


func food_eaten() -> int:
	return _food_eaten


func stop_reasons_log() -> Array[StringName]:
	return _stop_log.duplicate()


## null if the position is empty or the enemy is dead.
func enemy_stats(index: int) -> CombatantStats:
	if index < 0 or index >= _encounter.enemies.size() or not _encounter.enemies[index].alive():
		return null
	return _encounter.enemies[index].stats


## Copy for the UI (docs/05_INTERFACES.md §5.10). `player_hp` is the maximum while idle.
func get_state() -> Dictionary:
	return CombatView.build(self, _encounter, _abilities, {"state": _state, "area": _area_id, "hand": _hand,
		"player_hp": _player_hp, "player_timer_ms": _player_timer_ms, "between_ms": _between_ms,
		"rule": _fx.target_rule(), "fracture": _frac.view() if _frac.active() else {}})


## Jumps to the next timer that expires, resolves that instant (F-76), repeats; the rest stays in the timers.
func advance(delta_ms: int) -> void:
	var remaining: int = delta_ms
	while _state != STATE_IDLE and remaining >= 0:
		var next: int = _next_timer()
		if next > remaining:
			_consume(remaining)
			break
		_consume(next)
		remaining -= next
		advance_offset_ms = delta_ms - remaining
		_resolve_instant()
		_resume()
	advance_offset_ms = 0


func new_game() -> void:
	_apply(CombatSave.read({}, _session.data))
	_stop_log = []
	_stats = [null, null]
	_fx.reset()
	_abilities.reset()
	_frac.end()
	_resume_area = &""
	loot.from_save([])
	_stone.reset()


## Buffs of the running abilities (`ability:<id>`): the session rebuilds every modifier source after a load.
func rebuild_modifiers() -> void:
	_abilities.rebuild_modifiers()


func to_save() -> Dictionary:
	return CombatSave.write({
		"state": _state, "area": _area_id, "player_hp": _player_hp, "player_timer_ms": _player_timer_ms,
		"hand": _hand, "between_ms": _between_ms, "enemies": _encounter.to_save(), "effects": _fx.to_save(),
		"abilities": _abilities.timers_save(), "buffs": _abilities.buffs_save(),
		"loot": loot.to_save(), "stone": _stone.to_save(), "kills": _kills, "deaths": _deaths, "food_eaten": _food_eaten,
		"fracture": _frac.to_save() if _frac.active() else {},
	})


## Tolerant: an unknown area or monster, or a malformed fight, leaves the engine idle (bag and counters are kept).
## A saved Fracture fight resumes on the run that `FractureSystem` loaded first; without it the engine is idle (05 §5.23).
func from_save(d: Dictionary) -> void:
	new_game()
	if d.get("loot") is Array:
		loot.from_save(d["loot"])
	var parsed: Dictionary = CombatSave.read(d, _session.data, _session.fractures.run())
	_apply(parsed)
	if (parsed["fracture"] as Dictionary).is_empty():
		if _session.fractures.is_active():
			_session.fractures.drop_orphan_run()
	else:
		_frac.begin(_session.fractures.run())
		_frac.from_save(parsed["fracture"])
	_stone.from_save(d.get("stone"))
	_fx.from_save(parsed["effects"])
	_abilities.from_save(parsed["abilities"], parsed["buffs"])


func _apply(parsed: Dictionary) -> void:
	_state = parsed["state"]
	_area_id = parsed["area"]
	_encounter = parsed["encounter"] if parsed["encounter"] != null else Encounter.new()
	_player_hp = parsed["player_hp"]
	_player_timer_ms = parsed["player_timer_ms"]
	_hand = parsed["hand"]
	_between_ms = parsed["between_ms"]
	_kills = parsed["kills"]
	_deaths = parsed["deaths"]
	_food_eaten = parsed["food_eaten"]
