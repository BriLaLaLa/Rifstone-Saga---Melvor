class_name DungeonSystem
extends RefCounted
## The dungeons the player enters with a ticket (docs/01_GDD.md §33, docs/05_INTERFACES.md §5.29): the run in progress
## (`DungeonRun`), the commands that make the choices (F-140, F-141), the prizes (F-142, F-143), the delivery of the bag and the
## bag still waiting for room. The fights are run by the combat engine, which tells this system what happened with
## `dungeon_room_cleared`, `dungeon_stage_started`, `dungeon_stage_cleared` and `dungeon_finished` (`died` / `fled`).
## No timers (`advance`) and no modifier source: the engine moves the run forward.
## Dependencies: data, events, rng, bank, armory, cards, wallet, deposit, character, fractures, combat (the commands only).

const SAVE_KEY: StringName = &"dungeon"
const LOG_CATEGORY: String = "dungeon"
const SEED_MAX: int = 2147483647  # F-144 rule 4: the seed is a randi_range(1, SEED_MAX) of the generator of the slot
const OUTCOME_WON: StringName = &"won"
const OUTCOME_LEFT: StringName = &"left"
const OUTCOME_DIED: StringName = &"died"
const OUTCOME_FLED: StringName = &"fled"
const AMBUSH: StringName = &"ambush"
const FORAGE: StringName = &"forage"

var _session: GameSession
var _engine: Object = null  # a test seam: the combat engine unless `use_engine` replaced it (see `engine`)
var _run: DungeonRun = null
var _pending: FractureBag = FractureBag.new()
var _wins: Dictionary[StringName, int] = {}


func _init(session: GameSession) -> void:
	assert(session != null, "DungeonSystem needs a session")
	_session = session
	session.events.dungeon_room_cleared.connect(_on_room_cleared)
	session.events.dungeon_stage_started.connect(_on_stage_started)
	session.events.dungeon_stage_cleared.connect(_on_stage_cleared)
	session.events.dungeon_finished.connect(_on_finished)


## Tests only: the object that receives the engine calls of §5.29 (`start_dungeon`, `begin_dungeon_room`...), null = the real engine.
func use_engine(engine_object: Object) -> void:
	_engine = engine_object


func is_active() -> bool:
	return _run != null


## The run in progress, null outside a dungeon. The engine reads it and does not change it.
func run() -> DungeonRun:
	return _run


## Copy for the UI: `{}` outside a run (docs/05_INTERFACES.md §5.29). Nothing of the hidden map but direction and hint.
func state() -> Dictionary:
	if _run == null:
		return {}
	var engine_state: Dictionary = engine().get_state() if _run.phase == DungeonRun.PHASE_INTRO else {}
	return DungeonView.build(_run, _def(), _session.data, engine_state, wins(_run.dungeon_id))


## `&"ok"` or the reason `open` would refuse with, in the order of `open`.
func can_open(dungeon_id: StringName) -> StringName:
	var def: DungeonDef = DungeonRun.find_def(dungeon_id, _session.data)
	if def == null:
		return Reasons.UNKNOWN_ID
	if _session.character.get_level() < def.req_character:
		return Reasons.REQUIREMENT_NOT_MET
	if _run != null:
		return Reasons.DUNGEON_ACTIVE
	if _session.fractures.is_active() or _session.combat.in_fracture():
		return Reasons.FRACTURE_ACTIVE
	if has_pending():
		return Reasons.DUNGEON_BAG_PENDING
	if _session.bank.get_count(def.ticket) < 1:
		return Reasons.NOT_ENOUGH_ITEMS
	return &"ok"


## unknown_id, requirement_not_met, dungeon_active, fracture_active, dungeon_bag_pending, not_enough_items. The ticket is
## consumed now and never given back (F-144 rule 3); the run starts in the entrance room.
func open(dungeon_id: StringName) -> CommandResult:
	var reason: StringName = can_open(dungeon_id)
	if reason != &"ok":
		return CommandResult.fail(reason)
	var def: DungeonDef = DungeonRun.find_def(dungeon_id, _session.data)
	if not engine().has_method(&"start_dungeon"):
		Log.error(LOG_CATEGORY, "the combat engine cannot run a dungeon yet")
		return CommandResult.fail(Reasons.NO_DUNGEON)
	_session.bank.remove(def.ticket, 1)
	_run = DungeonRun.create(def, _session.rng.randi_range(1, SEED_MAX), _session.combat.area_id(), _session.data)
	var started: CommandResult = engine().start_dungeon(_run)
	if not started.ok:
		_run = null
		_session.bank.add(def.ticket, 1)
		return started
	_session.events.dungeon_opened.emit(def.id)
	_enter_room(0, 0)
	return CommandResult.success()


## no_dungeon, dungeon_paused, not_awaiting, invalid_choice. At a fork: enters the room behind exit `index`; at an event:
## the first or the second choice (F-140).
func choose(index: int) -> CommandResult:
	var refused: StringName = _refusal(false)
	if refused != &"":
		return CommandResult.fail(refused)
	if not _awaits():
		return CommandResult.fail(Reasons.NOT_AWAITING)
	var room: DungeonRoom = _run.map.room(_run.layer, _run.index)
	var count: int = room.exits.size() if _run.phase == DungeonRun.PHASE_AWAIT else 2
	if index < 0 or index >= count:
		return CommandResult.fail(Reasons.INVALID_CHOICE)
	if _run.phase == DungeonRun.PHASE_AWAIT:
		_enter_room(_run.layer + 1, room.exits[index])
	else:
		_event(room, index)
	return CommandResult.success()


## no_dungeon, dungeon_paused, not_awaiting. Ends the run at a fork or an event: the bag is delivered, no boss reward.
func leave() -> CommandResult:
	var refused: StringName = _refusal(false)
	if refused != &"":
		return CommandResult.fail(refused)
	if not _awaits():
		return CommandResult.fail(Reasons.NOT_AWAITING)
	_conclude(OUTCOME_LEFT, false)
	return CommandResult.success()


## no_dungeon, dungeon_paused, not_fighting (only in a fight or an intro). A defeat: the bag is lost.
func flee() -> CommandResult:
	var refused: StringName = _refusal(true)
	if refused != &"":
		return CommandResult.fail(refused)
	engine().abandon_dungeon(OUTCOME_FLED)
	return CommandResult.success()


## no_dungeon, not_paused.
func resume() -> CommandResult:
	if _run == null:
		return CommandResult.fail(Reasons.NO_DUNGEON)
	if not _run.paused:
		return CommandResult.fail(Reasons.NOT_PAUSED)
	_run.paused = false
	if engine().has_method(&"set_dungeon_paused"):
		engine().set_dungeon_paused(false)
	_session.events.dungeon_paused_changed.emit(false)
	return CommandResult.success()


## What waits for room after a win: `{}` if nothing, else `{"stacks": [...], "pieces": int, "cards": int}`.
func pending() -> Dictionary:
	if _pending.is_empty():
		return {}
	return {"stacks": _pending.stacks(), "pieces": _pending.pieces().size(), "cards": _pending.cards().size()}


func has_pending() -> bool:
	return not _pending.is_empty()


## F-116: tries again with what waits. no_dungeon (nothing waits); bank_full / armory_full if something stays.
func collect() -> CommandResult:
	if _pending.is_empty():
		return CommandResult.fail(Reasons.NO_DUNGEON)
	DungeonDelivery.deliver(_session, _pending)
	_emit_bag_changed(_pending)
	if not _pending.stacks().is_empty():
		return CommandResult.fail(Reasons.BANK_FULL)
	return CommandResult.fail(Reasons.ARMORY_FULL) if not _pending.cards().is_empty() else CommandResult.success()


## The tickets of `dungeon_id` in the Bank (0 for an unknown dungeon).
func tickets(dungeon_id: StringName) -> int:
	var def: DungeonDef = DungeonRun.find_def(dungeon_id, _session.data)
	return _session.bank.get_count(def.ticket) if def != null else 0


## The runs won (a statistic, not a stat): of `dungeon_id`, or all of them with the empty id.
func wins(dungeon_id: StringName = &"") -> int:
	if dungeon_id != &"":
		return _wins.get(dungeon_id, 0)
	var total: int = 0
	for count: int in _wins.values():
		total += count
	return total


func new_game() -> void:
	_run = null
	_pending = FractureBag.new()
	_wins = {}


func to_save() -> Dictionary:
	var wins_out: Dictionary = {}
	for id: StringName in _wins:
		wins_out[String(id)] = _wins[id]
	return {"run": _run.to_save() if _run != null else {}, "pending": _pending.to_save() if has_pending() else {},
		"wins": wins_out}


## Tolerant: an invalid run is dropped with its bag, an invalid `pending` or `wins` is emptied. No signal; a run is always
## loaded paused (the combat engine, loaded after this system, reads the pause from the run).
func from_save(d: Dictionary) -> void:
	new_game()
	if d.get("run") is Dictionary and not (d["run"] as Dictionary).is_empty():
		_run = DungeonRun.from_save(d["run"], _session.data)
	if d.get("pending") is Dictionary:
		_pending.from_save(d["pending"], _session.data)
	if d.get("wins") is Dictionary:
		for key: Variant in d["wins"] as Dictionary:
			var count: Variant = (d["wins"] as Dictionary)[key]
			if DungeonRun.find_def(StringName(str(key)), _session.data) != null and count is int and count >= 0:
				_wins[StringName(str(key))] = count
			elif count is float and count == floorf(count) and count >= 0.0:
				_wins[StringName(str(key))] = int(count)
			else:
				Log.warn(LOG_CATEGORY, "saved win counter skipped: %s" % str(key))


## The object the engine commands go to.
func engine() -> Object:
	return _engine if _engine != null else _session.combat


# --- reactions to the combat engine -------------------------------------------------------------------------------------

# F-141: the last enemy of a room is dead: the prize, then the fork (or the boss after the last fork level).
func _on_room_cleared(layer: int, _kind: StringName) -> void:
	if _run == null or _run.phase != DungeonRun.PHASE_FIGHT or layer != _run.layer or _run.stage > 0:
		return
	var def: DungeonDef = _def()
	var room: DungeonRoom = _run.map.room(_run.layer, _run.index)
	var type: DungeonRoomType = _type_of(def, room.kind, true)
	var reward: Dictionary = def.trap_reward if room.kind == &"trap" else (type.reward if type != null else {})
	_finish_room(room, reward, DungeonView.room_level(_def(), type))


# The intro of the stage is over: the stage fights.
func _on_stage_started(stage: int, _monster_id: StringName) -> void:
	if _run != null and stage == _run.stage:
		_run.phase = DungeonRun.PHASE_FIGHT


# F-142: the prize of a stage that is not the last; then the next intro, or the win.
func _on_stage_cleared(stage: int) -> void:
	if _run == null or stage != _run.stage:
		return
	var def: DungeonDef = _def()
	if stage < def.stages.size():
		var done: DungeonStageDef = def.stages[stage - 1]
		DungeonRewards.room_reward(done.reward, EquipmentPool.monster_level(done.monster), _sink(), _session)
		_begin_stage(stage + 1)
		return
	_run.cleared += 1
	_run.path.append(Vector2i(_run.layer, _run.index))
	_conclude(OUTCOME_WON, true)


# The engine ended the run for the player: the bag is lost (a win or an exit is concluded by this system).
func _on_finished(outcome: StringName, _rooms: int, _pieces: int) -> void:
	if _run == null or (outcome != OUTCOME_DIED and outcome != OUTCOME_FLED):
		return
	var counts: Dictionary = _run.bag.counts()
	_run.bag.clear()
	_run = null
	_session.events.dungeon_loot_lost.emit(counts["stacks"], counts["pieces"], counts["cards"])
	_emit_bag_changed(_pending)


# --- the flow ----------------------------------------------------------------------------------------------------------

# F-141: enter the room (`layer`, `index`): a fight starts, an event waits for its choice.
func _enter_room(layer: int, index: int) -> void:
	_run.layer = layer
	_run.index = index
	var room: DungeonRoom = _run.map.room(layer, index)
	_session.events.dungeon_room_entered.emit(layer, room.kind)
	if DungeonView.EVENT_CHOICES.has(room.kind):
		_run.phase = DungeonRun.PHASE_EVENT
		_session.events.dungeon_choice_ready.emit(&"event", 2)
		return
	_begin_fight(room.kind)


# A room fight of `kind` (a room type, `entrance`, `ambush` or `forage`): composition with the generator of the slot (F-138).
func _begin_fight(kind: StringName) -> void:
	_run.phase = DungeonRun.PHASE_FIGHT
	var def: DungeonDef = _def()
	var monsters: Array[MonsterDef] = []
	for id: StringName in DungeonGenerator.compose(def, kind, _session.rng):
		monsters.append(def.monster_def(id))
	engine().begin_dungeon_room(monsters, _run.layer, kind)


# F-140: the choice `choice` (0 or 1) of the trap or rest room.
func _event(room: DungeonRoom, choice: int) -> void:
	var def: DungeonDef = _def()
	if room.kind == &"trap" and choice == 0:  # "Attraversa di corsa": loss = max(0, min(hp - 1, floor(max_hp x pct / 100)))
		var view: Dictionary = engine().get_state()
		var max_hp: int = int(view.get("player_max_hp", 0))
		var loss: int = maxi(0, mini(int(view.get("player_hp", 0)) - 1, floori(float(max_hp) * def.trap_dash_hp_pct / 100.0)))
		var changed: int = int(engine().dungeon_adjust_hp(-loss, 1))
		_session.events.dungeon_trap_triggered.emit(room.trap_kind, -changed)
		_finish_room(room, def.trap_reward, 0)
	elif room.kind == &"trap":  # "Aggira": the ambush first
		_begin_fight(AMBUSH)
	elif choice == 0:  # "Riposa": heal = min(max_hp - hp, floor(max_hp x heal_pct / 100))
		var max_hp: int = int(engine().get_state().get("player_max_hp", 0))
		engine().dungeon_adjust_hp(floori(float(max_hp) * def.rest_heal_pct / 100.0), 1)
		_finish_room(room, {}, 0)
	else:  # "Fruga": the forage pack first
		_begin_fight(FORAGE)


# The room is beaten: prize, counters, then the fork, or the boss after the last fork level.
func _finish_room(room: DungeonRoom, reward: Dictionary, level: int) -> void:
	DungeonRewards.room_reward(reward, level, _sink(), _session)
	_run.cleared += 1
	_run.path.append(Vector2i(room.layer, room.index))
	if room.layer >= _def().forks:
		_begin_stage(1)
		return
	_run.phase = DungeonRun.PHASE_AWAIT
	_session.events.dungeon_choice_ready.emit(&"fork", room.exits.size())


# The boss, stage `stage` (1..3): its scene first (intro), the fight when the engine says so.
func _begin_stage(stage: int) -> void:
	_run.layer = _run.map.layers() - 1
	_run.index = 0
	_run.stage = stage
	_run.phase = DungeonRun.PHASE_INTRO
	engine().begin_dungeon_stage(_def().stages[stage - 1])


# Ends the run: the loot of the boss on a win, the bag delivered (F-116), the counters; the engine hears `dungeon_finished` and
# returns to the area (the run is still readable while the signal is emitted).
func _conclude(outcome: StringName, boss_loot: bool) -> void:
	var def: DungeonDef = _def()
	if boss_loot:
		DungeonRewards.boss_loot(_session, _sink(), def)
		_wins[def.id] = _wins.get(def.id, 0) + 1
	var pieces: int = _run.bag.pieces().size()
	var rooms: int = _run.cleared
	_pending = DungeonDelivery.deliver(_session, _run.bag)
	_session.events.dungeon_finished.emit(outcome, rooms, pieces)
	_run = null
	_emit_bag_changed(_pending)


# --- helpers ---------------------------------------------------------------------------------------------------------

# The refusal of a command that needs a run: no_dungeon, dungeon_paused, and (`fighting`) not_fighting; &"" if none.
func _refusal(fighting: bool) -> StringName:
	if _run == null:
		return Reasons.NO_DUNGEON
	if _run.paused:
		return Reasons.DUNGEON_PAUSED
	if fighting and _run.phase != DungeonRun.PHASE_FIGHT and _run.phase != DungeonRun.PHASE_INTRO:
		return Reasons.NOT_FIGHTING
	return &""


func _awaits() -> bool:
	return _run.phase == DungeonRun.PHASE_AWAIT or _run.phase == DungeonRun.PHASE_EVENT


func _def() -> DungeonDef:
	return DungeonRun.find_def(_run.dungeon_id, _session.data)


func _sink() -> LootSink:
	return DungeonRewards.BagSink.new(_session, _run.bag)


# The type that composes (and rewards) the room of `kind`; with `inside_event` a trap or a rest room gives its ambush / forage.
func _type_of(def: DungeonDef, kind: StringName, inside_event: bool) -> DungeonRoomType:
	match kind:
		&"entrance":
			return def.entrance
		&"trap":
			return def.trap_ambush if inside_event else null
		&"rest":
			return def.rest_forage if inside_event else null
	return def.room_type(kind)


func _emit_bag_changed(bag: FractureBag) -> void:
	var counts: Dictionary = bag.counts()
	_session.events.dungeon_bag_changed.emit(counts["stacks"], counts["pieces"], counts["cards"])
