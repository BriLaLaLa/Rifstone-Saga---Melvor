class_name CombatEngine
extends RefCounted
## Event-driven group combat (docs/01_GDD.md §10, docs/05_INTERFACES.md §5.10). `advance` jumps from timer to timer,
## so `advance(1000)` and ten `advance(100)` give the same result. All randomness comes from `session.rng`, in the
## order fixed by 05 §5.10. Player stats are recomputed (cached only until a modifier, equipment or level change);
## enemy stats come from the monster data. Everything but those derived numbers is saved.
## Trait effects (M6) hook in through `EffectSet`; the save format lives in `CombatSave`.
## Dependencies: data, events, modifiers, rng, bank, wallet, character, equipment, loadout, actions (only `stop`).

const SAVE_KEY: StringName = &"combat"
const LOG_CATEGORY: String = "combat"
const STATE_IDLE: StringName = &"idle"
const STATE_ENCOUNTER: StringName = &"encounter"
const STATE_BETWEEN: StringName = &"between"
const STATE_RIFTSTONE: StringName = &"riftstone"  # M7
const PLAYER: int = -1
const SHARD_ITEM: StringName = KillRewards.SHARD_ITEM

var loot: LootBag

var _session: GameSession
var _state: StringName = STATE_IDLE
var _area_id: StringName = &""
var _encounter: Encounter = Encounter.new()
var _player_hp: int = 0
var _player_timer_ms: int = 0
var _hand: int = 0
var _between_ms: int = 0
var _fx: EffectSet
var _kills: Dictionary[StringName, int] = {}
var _deaths: int = 0
var _food_eaten: int = 0
var _stop_log: Array[StringName] = []
var _stats: Array[CombatantStats] = [null, null]


func _init(session: GameSession) -> void:
	_session = session
	loot = LootBag.new(session)
	_fx = EffectSet.new(session)
	session.events.modifiers_changed.connect(_on_stats_source_changed)
	session.events.equipment_changed.connect(_on_loadout_changed.unbind(2))
	session.events.character_level_up.connect(_on_stats_source_changed.unbind(1))
	session.events.traits_changed.connect(_on_loadout_changed)


# --- commands ---------------------------------------------------------------------------------------------------

## unknown_id, requirement_not_met (character level). Stops the main-lane action (REPLACED). Starting the area
## already fought changes nothing; another area replaces the current fight.
func start(area_id: StringName) -> CommandResult:
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
	_state = STATE_IDLE
	_area_id = &""
	_encounter = Encounter.new()
	_between_ms = 0
	_fx.reset()
	_stop_log.append(reason)
	_set_hp(player_stats().max_hp)
	_session.events.combat_stopped.emit(reason)


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


# --- queries ----------------------------------------------------------------------------------------------------

func is_active() -> bool:
	return _state != STATE_IDLE


func in_encounter() -> bool:
	return _state == STATE_ENCOUNTER or _state == STATE_RIFTSTONE


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


## Stats of the player's hand (F-70, F-74), cached until something that feeds them changes.
func player_stats(hand: int = 0) -> CombatantStats:
	var index: int = clampi(hand, 0, 1)
	if _stats[index] == null:
		var stats: CombatantStats = CombatantStats.for_player(_session, index)
		_fx.modify_stats(stats)
		_stats[index] = stats
	return _stats[index]


## null if the position is empty or the enemy is dead.
func enemy_stats(index: int) -> CombatantStats:
	if index < 0 or index >= _encounter.enemies.size() or not _encounter.enemies[index].alive():
		return null
	return _encounter.enemies[index].stats


## Copy for the UI (docs/05_INTERFACES.md §5.10). `player_hp` is the maximum while idle.
func get_state() -> Dictionary:
	var max_hp: int = player_stats().max_hp
	var enemies: Array[Dictionary] = []
	for enemy: Encounter.Enemy in _encounter.enemies:
		enemies.append({"monster": enemy.def.id, "hp": enemy.hp, "max_hp": enemy.stats.max_hp,
			"timer_ms": enemy.timer_ms, "interval_ms": enemy.stats.attack_interval_ms})
	return {
		"state": _state, "area": _area_id, "player_hp": max_hp if _state == STATE_IDLE else _player_hp,
		"player_max_hp": max_hp, "player_timer_ms": _player_timer_ms,
		"player_interval_ms": player_stats(_hand).attack_interval_ms, "hand": _hand, "between_ms": _between_ms,
		"enemies": enemies, "target": _encounter.target(_fx.target_rule()), "abilities": [], "buffs": {},
	}


# --- the engine -------------------------------------------------------------------------------------------------

## Jumps to the next timer that expires, resolves that instant (F-76), repeats; the rest stays in the timers.
func advance(delta_ms: int) -> void:
	var remaining: int = delta_ms
	while _state != STATE_IDLE and remaining >= 0:
		var next: int = _next_timer()
		if next > remaining:
			_consume(remaining)
			return
		_consume(next)
		remaining -= next
		_resolve_instant()


func _next_timer() -> int:
	if _state == STATE_BETWEEN:
		return _between_ms
	var next: int = _player_timer_ms
	for enemy: Encounter.Enemy in _encounter.enemies:
		if enemy.alive():
			next = mini(next, enemy.timer_ms)
	return next


func _consume(ms: int) -> void:
	if ms <= 0:
		return
	if _state == STATE_BETWEEN:
		_between_ms -= ms
		return
	_player_timer_ms -= ms
	for enemy: Encounter.Enemy in _encounter.enemies:
		if enemy.alive():
			enemy.timer_ms -= ms


# F-76: player base attack, then the enemies by position; whoever dies (or ends the encounter) stops the rest.
func _resolve_instant() -> void:
	if _state == STATE_BETWEEN:
		if _between_ms <= 0:
			_begin_encounter()
		return
	if _player_timer_ms <= 0:
		_player_attack()
	for i: int in _encounter.enemies.size():
		if _state != STATE_ENCOUNTER:
			return
		var enemy: Encounter.Enemy = _encounter.enemies[i]
		if enemy.alive() and enemy.timer_ms <= 0:
			_enemy_attack(i, enemy)


func _begin_encounter() -> void:
	_encounter = Encounter.spawn(_session.data.area(_area_id), _session.data, _session.rng)
	_state = STATE_ENCOUNTER
	_player_timer_ms = player_stats(_hand).attack_interval_ms
	var ctx: EffectContext = _ctx()
	_fx.encounter_start(ctx)
	_player_timer_ms = ctx.player_timer_ms
	_session.events.encounter_started.emit(_encounter.monster_ids())


# Base attack: the effects may widen it to every living enemy (F-81) or change its damage. All the rolls come first
# (position order), then the hand and the timer, then the outcomes (hit event, hp, leech, kill).
func _player_attack() -> void:
	var first: int = _encounter.target(_fx.target_rule())
	if first < 0:
		return
	var ctx: EffectContext = _ctx()
	_fx.before_attack(ctx)
	var targets: Array[int] = [first]
	if ctx.attack_all:
		targets = _encounter.alive_indices()
	var attacks: Array[Dictionary] = []
	for index: int in targets:
		attacks.append(Encounter.roll_attack(player_stats(_hand), _encounter.enemies[index].stats, 0.0, _session.rng,
			_session.data, ctx.damage_mult))
	_hand = 1 if _hand == 0 and _is_dual_wielding() else 0
	_player_timer_ms = player_stats(_hand).attack_interval_ms
	for k: int in targets.size():
		if _state != STATE_ENCOUNTER:
			return
		var damage: int = attacks[k]["damage"]
		_session.events.combat_hit.emit(PLAYER, targets[k], attacks[k]["hit"], damage, false)
		if damage > 0:
			_hurt_enemy(targets[k], damage)
			_heal_from_hit(damage)


func _enemy_attack(index: int, enemy: Encounter.Enemy) -> void:
	enemy.timer_ms = enemy.stats.attack_interval_ms
	var me: CombatantStats = player_stats()
	var attack: Dictionary = Encounter.roll_attack(enemy.stats, me, me.block_chance, _session.rng, _session.data)
	var damage: int = attack["damage"]
	_session.events.combat_hit.emit(index, PLAYER, attack["hit"], damage, attack["blocked"])
	if damage <= 0:
		return
	_set_hp(maxi(0, _player_hp - damage))
	if _player_hp <= 0:
		_die()
		return
	var ctx: EffectContext = _ctx()
	_fx.damaged(ctx, damage)
	if ctx.reflect_damage > 0:
		_hurt_enemy(index, ctx.reflect_damage)
	if _fx.blocks_auto_eat(_ctx()):
		return
	var before: int = _food_count()
	_set_hp(AutoEat.after_hit(_session, _player_hp, me.max_hp))
	_food_eaten += before - _food_count()


func _hurt_enemy(index: int, damage: int) -> void:
	var enemy: Encounter.Enemy = _encounter.enemies[index]
	enemy.hp = maxi(0, enemy.hp - damage)
	_session.events.monster_hp_changed.emit(index, enemy.hp, enemy.stats.max_hp)
	if enemy.hp == 0:
		_kill(index, enemy)


func _heal_from_hit(damage: int) -> void:
	var ctx: EffectContext = _ctx()
	_fx.hit(ctx, damage)
	_set_hp(mini(ctx.player_max_hp, _player_hp + ctx.heal))


# Kill (05 §5.10): xp (F-28), then gold (F-31), drops in data order (F-32), shard (F-07); last enemy ends the encounter.
func _kill(index: int, enemy: Encounter.Enemy) -> void:
	var def: MonsterDef = enemy.def
	KillRewards.grant(_session, loot, def)
	_kills[def.id] = _kills.get(def.id, 0) + 1
	_session.events.monster_killed.emit(index, def.id)
	var ctx: EffectContext = _ctx()
	_fx.kill(ctx)
	_player_timer_ms = ctx.player_timer_ms
	if _encounter.alive_count() == 0:
		_encounter = Encounter.new()
		_state = STATE_BETWEEN
		_between_ms = int(_session.data.balance_value("combat.respawn_ms"))
		_session.events.encounter_cleared.emit()


func _die() -> void:
	loot.lose_all()
	_deaths += 1
	_set_hp(player_stats().max_hp)
	_session.events.player_died.emit()
	stop(Reasons.PLAYER_DIED)


# --- helpers ----------------------------------------------------------------------------------------------------

## What the effect hooks see of the fight right now.
func _ctx() -> EffectContext:
	var ctx := EffectContext.new()
	ctx.player_hp = _player_hp
	ctx.player_max_hp = player_stats().max_hp
	ctx.player_timer_ms = _player_timer_ms
	return ctx


func _set_hp(hp: int) -> void:
	if hp == _player_hp:
		return
	_player_hp = hp
	_session.events.player_hp_changed.emit(hp, player_stats().max_hp)


func _is_dual_wielding() -> bool:
	var setup: SetupDef = _session.equipment.setup_def()
	return setup != null and setup.alternate and _session.equipment.offhand_weapon() != null


func _food_count() -> int:
	var food: StringName = _session.equipment.get_food()
	return _session.bank.get_count(food) if food != &"" else 0


# A trait or the setup changed: the effects and the stats they modify are stale.
func _on_loadout_changed() -> void:
	_fx.invalidate()
	_on_stats_source_changed()


# Derived stats are stale: drop them; the current hp never exceeds the new maximum (docs/01_GDD.md §10.9).
func _on_stats_source_changed() -> void:
	_stats = [null, null]
	if _state != STATE_IDLE and _player_hp > player_stats().max_hp:
		_set_hp(player_stats().max_hp)


# --- save -------------------------------------------------------------------------------------------------------

func new_game() -> void:
	_apply(CombatSave.read({}, _session.data))
	_stop_log = []
	_stats = [null, null]
	_fx.reset()
	loot.from_save([])


func to_save() -> Dictionary:
	return CombatSave.write({
		"state": _state, "area": _area_id, "player_hp": _player_hp, "player_timer_ms": _player_timer_ms,
		"hand": _hand, "between_ms": _between_ms, "enemies": _encounter.to_save(), "effects": _fx.to_save(),
		"loot": loot.to_save(), "kills": _kills, "deaths": _deaths, "food_eaten": _food_eaten,
	})


## Tolerant: an unknown area or monster, or a malformed fight, leaves the engine idle (bag and counters are kept).
func from_save(d: Dictionary) -> void:
	new_game()
	if d.get("loot") is Array:
		loot.from_save(d["loot"])
	var parsed: Dictionary = CombatSave.read(d, _session.data)
	_apply(parsed)
	_fx.from_save(parsed["effects"])


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
