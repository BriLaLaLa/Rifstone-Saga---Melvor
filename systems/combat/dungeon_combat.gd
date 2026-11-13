class_name DungeonCombat
extends RefCounted
## The part of `CombatEngine` that is specific to a dungeon run (docs/05_INTERFACES.md §5.29, F-112, F-141, F-142): the run in
## progress, the room being fought, the scene (`intro`) and the fight of a boss stage with the ability of its monster, the
## rewards of a kill and the extra save keys. It holds no flow of its own: the engine decides when to call it. The run itself is
## `DungeonSystem`'s; it is read here and never changed. Randomness from `session.rng`.

const NO_TIMER: int = FractureCombat.NO_TIMER

var run: DungeonRun = null
var paused: bool = false  # nothing runs (after a load, until "Riprendi")
var room_layer: int = 0
var room_kind: StringName = &""
var stage: DungeonStageDef = null  # the stage of the scene or of the fight; null outside the boss
var stage_index: int = 0  # 1..3
var intro_ms: int = 0  # time left of the scene of `stage`
var fighting: bool = false  # the fight of `stage` is on (after its scene)
# State of the ability of the stage monster (F-112); saved with the fight.
var ability_ms: int = 0
var shield: int = 0
var shield_ms: int = 0

var _session: GameSession
var _sink: DungeonSink = null


func _init(session: GameSession) -> void:
	_session = session


func active() -> bool:
	return run != null


## A run starts (or is resumed from a save): paused if the run is.
func begin(new_run: DungeonRun) -> void:
	run = new_run
	_sink = DungeonSink.new(_session, run)
	paused = run.paused
	room_layer = run.layer
	room_kind = &""
	_clear_stage()


func end() -> void:
	run = null
	_sink = null
	paused = false
	_clear_stage()


## A room fight begins: no stage.
func begin_room(layer: int, kind: StringName) -> void:
	room_layer = layer
	room_kind = kind
	_clear_stage()


## F-141: the scene of `new_stage` begins (`intro_ms`), then its fight.
func begin_stage(new_stage: DungeonStageDef) -> void:
	_clear_stage()
	stage = new_stage
	stage_index = _stage_number(new_stage)
	intro_ms = new_stage.intro_ms
	room_layer = run.layer
	room_kind = &"boss"


## The fight of the stage is over (or the room): the ability and the shield stop.
func end_fight() -> void:
	fighting = false
	ability_ms = 0
	shield = 0
	shield_ms = 0


# --- the timers: what the engine asks -------------------------------------------------------------------------------------

## Time to the next event while the time of the fight does not run, or -1 if it runs: `NO_TIMER` when paused and in `await`
## (nothing happens until `DungeonSystem` acts), the time left of the scene in `intro`.
func held_timer(state: StringName) -> int:
	if run == null:
		return -1
	if paused or state == CombatState.STATE_AWAIT:
		return NO_TIMER
	return intro_ms if state == CombatState.STATE_INTRO else -1


## True if `ms` is not time of the fight: nothing in `await` or when paused, the scene runs down in `intro`.
func hold(state: StringName, ms: int) -> bool:
	if run == null:
		return false
	if paused or state == CombatState.STATE_AWAIT:
		return true
	if state == CombatState.STATE_INTRO:
		intro_ms = maxi(0, intro_ms - ms)
		return true
	return false


## Time passes during a fight: the ability and the shield of the stage monster run.
func tick(ms: int) -> void:
	if not fighting:
		return
	ability_ms = maxi(0, ability_ms - ms)
	shield_ms = maxi(0, shield_ms - ms)
	if shield_ms == 0:
		shield = 0


## Time to the next use of the ability of the stage monster, `NO_TIMER` outside a stage fight or once it is dead.
func next_ability_ms(encounter: Encounter) -> int:
	if not fighting or stage == null or stage.ability == null:
		return NO_TIMER
	for enemy: Encounter.Enemy in encounter.enemies:
		if is_chief(enemy) and enemy.alive():
			return ability_ms
	return NO_TIMER


# --- the fight of a stage -------------------------------------------------------------------------------------------------

## The monsters of the stage (F-139): its monster first, then its escorts. The fight and the ability timer start now.
func stage_encounter() -> Encounter:
	fighting = true
	ability_ms = stage.ability.every_ms if stage.ability != null else 0
	shield = 0
	shield_ms = 0
	var defs: Array[MonsterDef] = [stage.monster]
	for id: StringName in stage.escorts:
		defs.append(_session.data.monster(id))
	return Encounter.of_defs(defs, _session.data)


## The monster of the stage (not an escort or a summoned monster that has the same id).
func is_chief(enemy: Encounter.Enemy) -> bool:
	return stage != null and not enemy.summoned and enemy.def.id == stage.monster.id


func ability_due(enemy: Encounter.Enemy) -> bool:
	return fighting and stage != null and stage.ability != null and enemy.alive() and ability_ms <= 0 and is_chief(enemy)


## F-112: the ability of the stage monster is due. Restarts its timer. `heavy_strike` returns the attack to apply (`hit`,
## `blocked`, `damage`); `shield` (not renewed while one is up) and `summon` act at once and return `{}`. The positions of the new
## enemies go in `summoned`.
func use_ability(enemy: Encounter.Enemy, encounter: Encounter, me: CombatantStats, summoned: Array[int]) -> Dictionary:
	var data: GameData = _session.data
	var ability: BossAbilityDef = stage.ability
	ability_ms = ability.every_ms
	match ability.type:
		BossAbilityDef.HEAVY_STRIKE:
			return BossAbility.heavy_strike(enemy.stats, me, ability, _session.rng, data)
		BossAbilityDef.SHIELD:
			if shield <= 0:
				shield = BossAbility.shield_amount(enemy.stats.max_hp, ability)
				shield_ms = ability.duration_ms
		BossAbilityDef.SUMMON:
			_summon(ability, encounter, summoned)
	return {}


# F-112 `summon`: at most `count`, `max_alive` summoned alive and `combat.max_pack_size` enemies in all; a dead summoned enemy
# leaves its position free.
func _summon(ability: BossAbilityDef, encounter: Encounter, summoned: Array[int]) -> void:
	var data: GameData = _session.data
	var alive_summoned: int = 0
	for e: Encounter.Enemy in encounter.enemies:
		if e.summoned and e.alive():
			alive_summoned += 1
	var max_pack: int = int(data.balance_value("combat.max_pack_size"))
	var room: int = mini(mini(ability.count, ability.max_alive - alive_summoned), max_pack - encounter.alive_count())
	for i: int in maxi(0, room):
		var fresh := Encounter.Enemy.new(data.monster(ability.monsters[i % ability.monsters.size()]), data)
		fresh.summoned = true
		var slot: int = -1
		for k: int in encounter.enemies.size():
			if encounter.enemies[k].summoned and not encounter.enemies[k].alive():
				slot = k
				break
		if slot < 0:
			encounter.enemies.append(fresh)
			slot = encounter.enemies.size() - 1
		else:
			encounter.enemies[slot] = fresh
		summoned.append(slot)


## F-112: the shield of the stage monster takes the damage first; returns what is left for the hp.
func absorb(enemy: Encounter.Enemy, damage: int) -> int:
	if not fighting or shield <= 0 or not is_chief(enemy):
		return damage
	var taken: int = mini(shield, damage)
	shield -= taken
	if shield == 0:
		shield_ms = 0
	return damage - taken


## F-142: xp (F-130 as outside a dungeon), gold and drops of a killed enemy into the bag of the run; a summoned enemy gives
## nothing. Always false: a monster of a dungeon is not a kill of an area (no counter, no F-87).
func reward(enemy: Encounter.Enemy, card_mult: float = 1.0) -> bool:
	if not enemy.summoned:
		_sink.card_mult = card_mult
		KillRewards.grant(_session, _sink, enemy.def)
	return false


# --- view and save --------------------------------------------------------------------------------------------------------

## `get_state()["dungeon"]` (05 §5.29).
func view(state: StringName) -> Dictionary:
	return {"layer": room_layer, "kind": room_kind, "stage": stage_index, "paused": paused,
		"intro_left_ms": intro_ms if state == CombatState.STATE_INTRO else 0}


## `combat.dungeon` of the save.
func to_save() -> Dictionary:
	return {"room": {"layer": room_layer, "kind": String(room_kind)}, "intro_ms": intro_ms,
		"boss": {"ability_ms": ability_ms, "shield": shield, "shield_ms": shield_ms}}


## Tolerant: anything malformed counts as the start values. The stage is the one of `run` (`state` tells if its fight is on).
func from_save(d: Dictionary, state: StringName) -> void:
	var room: Variant = d.get("room")
	if room is Dictionary:
		room_layer = maxi(0, _int(room as Dictionary, "layer"))
		room_kind = StringName(str((room as Dictionary).get("kind", "")))
	var def: DungeonDef = DungeonRun.find_def(run.dungeon_id, _session.data)
	if def != null and run.stage >= 1 and run.stage <= def.stages.size():
		stage = def.stages[run.stage - 1]
		stage_index = run.stage
		intro_ms = clampi(_int(d, "intro_ms"), 0, stage.intro_ms)
		fighting = state == CombatState.STATE_ENCOUNTER
	var boss: Variant = d.get("boss")
	if boss is Dictionary and fighting:
		ability_ms = maxi(0, _int(boss as Dictionary, "ability_ms"))
		shield = maxi(0, _int(boss as Dictionary, "shield"))
		shield_ms = maxi(0, _int(boss as Dictionary, "shield_ms"))


func _clear_stage() -> void:
	stage = null
	stage_index = 0
	intro_ms = 0
	end_fight()


# The 1-based position of `new_stage` among the stages of the dungeon of the run (the run's own number if it is not among them).
func _stage_number(new_stage: DungeonStageDef) -> int:
	var def: DungeonDef = DungeonRun.find_def(run.dungeon_id, _session.data)
	var found: int = def.stages.find(new_stage) if def != null else -1
	return found + 1 if found >= 0 else run.stage


static func _int(d: Dictionary, key: String) -> int:
	var v: Variant = d.get(key)
	return int(v) if v is int or v is float else 0
