class_name CombatCycle
extends CombatState
## The cycle of the area under `CombatFight` (M28-02, docs/05_INTERFACES_M28.md §5.10b): the start of an encounter, the end of one
## (`_cleared`, `_dungeon_cleared`), the journey (F-153) and the node (F-155, F-161). Moved out of `CombatFight` unchanged.


func _begin_encounter() -> void:
	_encounter = _frac.next_encounter() if _frac.active() else _area_encounter()  # F-50 / a miniboss / a pending stone (F-87)
	_state = STATE_RIFTSTONE if _encounter.has_stone() else STATE_ENCOUNTER
	if _frac.active() and _encounter.enemies.is_empty():  # no pack or no boss in the data: nothing to fight
		Log.error("combat", "Fracture grade %d has nothing to fight: counted as won" % _frac.run.grade)
		_end_fracture(&"won", Reasons.FRACTURE_WON, true)
		return
	_open_encounter()


# The timers and the effects of a fight that starts now (`_encounter` and `_state` are already set).
func _open_encounter() -> void:
	_player_timer_ms = player_stats(_hand).attack_interval_ms
	var ctx: EffectContext = _ctx()
	_fx.encounter_start(ctx)
	_player_timer_ms = ctx.player_timer_ms
	_session.events.encounter_started.emit(_encounter.monster_ids())


# F-139: the miniboss of the area if one waits (a pending Rift Stone goes first), else a pack or the stone (F-77, F-87).
func _area_encounter() -> Encounter:
	if _miniboss_pending and not _stone.pending:
		_miniboss_pending = false
		var pack: Array[MonsterDef] = Miniboss.pack(_session.data.area(_area_id), _session.rng, _session.data)
		if not pack.is_empty():
			return Encounter.of_defs(pack, _session.data)
	return _stone.next_encounter(_area_id)


# The last enemy of the encounter is dead. In a dungeon the run waits for DungeonSystem; in a Fracture the next group comes after
# `BETWEEN`; in an area a journey starts (F-153), and after a normal encounter (not a stone, a Fracture or a miniboss) the miniboss
# of the area may be next (F-139, rolled first).
func _cleared() -> void:
	if _dg.active():
		_dungeon_cleared()
		return
	var normal: bool = _state == STATE_ENCOUNTER and not _frac.active() and not _encounter.has_miniboss()
	_encounter = Encounter.new()
	if normal and not _stone.pending and not _miniboss_pending:
		_miniboss_pending = Miniboss.roll(_session.data.area(_area_id), _session.rng, _session.data)
	if _frac.active():
		_state = STATE_BETWEEN
		_between_ms = int(_session.data.balance_value("combat.respawn_ms"))
		_session.events.encounter_cleared.emit()
		return
	_start_travel()
	_session.events.encounter_cleared.emit()
	_announce_travel()


# F-153: the journey to the next encounter of the area; the kind is decided now (a Rift Stone or a miniboss that waits: a fight).
func _start_travel() -> void:
	_state = STATE_TRAVEL
	_cy.begin_travel(_area_id, _stone.pending or _miniboss_pending)


func _announce_travel() -> void:
	if _state == STATE_TRAVEL:  # a handler of an earlier signal may have stopped the fight
		_session.events.travel_started.emit(_cy.next["kind"], _cy.next["skill"], _cy.travel_total_ms)


# The end of the journey: the fight begins, or the node (worked, or skipped if the discipline is not learned).
func _arrive() -> void:
	var skill: StringName = _cy.next["skill"]
	var is_node: bool = _cy.next["kind"] == EncounterCycle.NODE
	_cy.clear()
	var work: NodeWork = NodeWork.begin(_session, _area_id, skill) if is_node else null
	if work == null:
		_begin_encounter()
		return
	_cy.node = work
	_state = STATE_NODE
	_session.events.node_started.emit(work.skill_id, work.action_id, work.skipped, work.duration_ms)


# F-161: a node instant: every attempt whose instant is reached, in order, each with its signals; a skipped node ends at its time.
func _resolve_node() -> void:
	var work: NodeWork = _cy.node
	while work.due_attempts() > 0 and _cy.node == work:  # a handler of a signal may have stopped the fight
		var outcome: ActionOutcome = work.resolve_attempt(_session)
		if outcome.ok:
			_session.events.action_completed.emit(ActionRunner.NODE, work.skill_id, work.action_id, outcome.outputs)
			_session.events.node_attempt_done.emit(work.skill_id, work.action_id, work.attempt, work.attempts, outcome.units,
					work.units, work.last_attempt["color"])
	if _cy.node == work and work.is_over():
		_finish_node()


# The node is over (F-155, F-161): the journey starts again.
func _finish_node() -> void:
	var work: NodeWork = _cy.node
	_cy.skipped += 1 if work.skipped else 0
	_cy.worked += 0 if work.skipped else 1
	_start_travel()
	_session.events.node_finished.emit(work.skill_id, work.action_id, work.units, work.end_reason())
	_announce_travel()


# F-141: a room or a stage of the dungeon is beaten: the engine waits, then tells DungeonSystem (it acts at once). The signals
# come last: the state is already final when the system reacts (a new scene, a fork, the end of the run).
func _dungeon_cleared() -> void:
	var stage: int = _dg.stage_index if _dg.fighting else 0
	var layer: int = _dg.room_layer
	var kind: StringName = _dg.room_kind
	_dg.end_fight()
	_encounter = Encounter.new()
	_state = STATE_AWAIT
	_session.events.encounter_cleared.emit()
	if stage > 0:
		_session.events.dungeon_stage_cleared.emit(stage)
	else:
		_session.events.dungeon_room_cleared.emit(layer, kind)
