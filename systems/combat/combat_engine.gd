class_name CombatEngine
extends RefCounted
## Event-driven group combat (docs/01_GDD.md §10, docs/05_INTERFACES.md §5.10). `advance` jumps from timer to timer,
## so `advance(1000)` and ten `advance(100)` give the same result. All randomness comes from `session.rng`, in the
## order fixed by 05 §5.10. Player stats are recomputed (cached only until a modifier, equipment or level change);
## enemy stats come from the monster data. Everything but those derived numbers is saved.
## Dependencies: data, events, modifiers, rng, bank, wallet, character, equipment, actions (only `stop`).

const SAVE_KEY: StringName = &"combat"
const LOG_CATEGORY: String = "combat"
const STATE_IDLE: StringName = &"idle"
const STATE_ENCOUNTER: StringName = &"encounter"
const STATE_BETWEEN: StringName = &"between"
const STATE_RIFTSTONE: StringName = &"riftstone"  # M7
const PLAYER: int = -1
const SHARD_ITEM: StringName = &"rift_shard"
const EPSILON: float = 1e-9

var loot: LootBag

var _session: GameSession
var _state: StringName = STATE_IDLE
var _area_id: StringName = &""
var _encounter: Encounter = Encounter.new()
var _player_hp: int = 0
var _player_timer_ms: int = 0
var _hand: int = 0
var _between_ms: int = 0
var _target_rule: StringName = Encounter.RULE_FIRST
var _kills: Dictionary[StringName, int] = {}
var _deaths: int = 0
var _food_eaten: int = 0
var _stop_log: Array[StringName] = []
var _stats: Array[CombatantStats] = [null, null]


func _init(session: GameSession) -> void:
	_session = session
	loot = LootBag.new(session)
	session.events.modifiers_changed.connect(_on_stats_source_changed)
	session.events.equipment_changed.connect(_on_equipment_changed)
	session.events.character_level_up.connect(_on_level_up)


# --- commands ---------------------------------------------------------------------------------------------------

## unknown_id, requirement_not_met (character level). Stops the main-lane action (REPLACED). Starting the area
## already fought changes nothing; another area replaces the current fight.
func start(area_id: StringName) -> CommandResult:
	var area: AreaDef = Encounter.find_area(_session.data, area_id)
	if area == null:
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	for key: StringName in area.requirements:
		if key == &"character" and _session.character.get_level() < area.requirements[key]:
			return CommandResult.fail(Reasons.REQUIREMENT_NOT_MET)
	if is_active() and _area_id == area_id:
		return CommandResult.success()
	stop(Reasons.REPLACED)
	_session.actions.stop(ActionRunner.MAIN, Reasons.REPLACED)
	_area_id = area_id
	_hand = 0
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
		_stats[index] = CombatantStats.for_player(_session, index)
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
		"enemies": enemies, "target": _encounter.target(_target_rule), "abilities": [], "buffs": {},
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
	_session.events.encounter_started.emit(_encounter.monster_ids())


func _player_attack() -> void:
	var index: int = _encounter.target(_target_rule)
	if index < 0:
		return
	var enemy: Encounter.Enemy = _encounter.enemies[index]
	var attack: Dictionary = Encounter.roll_attack(player_stats(_hand), enemy.stats, 0.0, _session.rng, _session.data)
	_hand = 1 if _hand == 0 and _is_dual_wielding() else 0
	_player_timer_ms = player_stats(_hand).attack_interval_ms
	var damage: int = attack["damage"]
	_session.events.combat_hit.emit(PLAYER, index, attack["hit"], damage, false)
	if damage <= 0:
		return
	enemy.hp = maxi(0, enemy.hp - damage)
	_session.events.monster_hp_changed.emit(index, enemy.hp, enemy.stats.max_hp)
	if enemy.hp == 0:
		_kill(index, enemy)


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
	var before: int = _food_count()
	_set_hp(AutoEat.after_hit(_session, _player_hp, me.max_hp))
	_food_eaten += before - _food_count()


# Kill (05 §5.10): xp (F-28), then gold (F-31), drops in data order (F-32), shard (F-07); last enemy ends the encounter.
func _kill(index: int, enemy: Encounter.Enemy) -> void:
	var def: MonsterDef = enemy.def
	_session.character.add_xp(def.xp)
	var gold_pct: float = _session.modifiers.total(&"gold_drop_pct")
	var rolled: int = _session.rng.randi_range(def.gold_min, def.gold_max)
	_session.wallet.add_gold(int(floor(float(rolled) * (1.0 + gold_pct / 100.0) + EPSILON)))
	for drop: DropEntry in def.drops:
		if _session.rng.roll_pct(drop.chance_pct):
			loot.add(drop.item_id, _session.rng.randi_range(drop.qty_min, drop.qty_max))
	var shard_pct: float = def.rift_shard_chance + _session.modifiers.total(&"rift_shard_chance")
	if _session.rng.roll_pct(shard_pct):
		loot.add(SHARD_ITEM, 1)
	_kills[def.id] = _kills.get(def.id, 0) + 1
	_session.events.monster_killed.emit(index, def.id)
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


func _on_equipment_changed(_slot_id: StringName, _uid: int) -> void:
	_on_stats_source_changed()


func _on_level_up(_level: int) -> void:
	_on_stats_source_changed()


# Derived stats are stale: drop them; the current hp never exceeds the new maximum (docs/01_GDD.md §10.9).
func _on_stats_source_changed() -> void:
	_stats = [null, null]
	if _state != STATE_IDLE and _player_hp > player_stats().max_hp:
		_set_hp(player_stats().max_hp)


# --- save -------------------------------------------------------------------------------------------------------

func new_game() -> void:
	_state = STATE_IDLE
	_area_id = &""
	_encounter = Encounter.new()
	_player_hp = 0
	_player_timer_ms = 0
	_hand = 0
	_between_ms = 0
	_kills = {}
	_deaths = 0
	_food_eaten = 0
	_stop_log = []
	_stats = [null, null]
	loot.from_save([])


func to_save() -> Dictionary:
	var kills_out: Dictionary = {}
	for id: StringName in _kills:
		kills_out[String(id)] = _kills[id]
	return {
		"state": String(_state), "area": String(_area_id), "player_hp": _player_hp,
		"player_timer_ms": _player_timer_ms, "hand": _hand, "between_ms": _between_ms,
		"enemies": _encounter.to_save(), "loot": loot.to_save(), "kills": kills_out, "deaths": _deaths,
		"food_eaten": _food_eaten,
	}


## Tolerant: an unknown area or monster, or a malformed fight, leaves the engine idle (bag and counters are kept).
func from_save(d: Dictionary) -> void:
	new_game()
	if d.get("loot") is Array:
		loot.from_save(d["loot"])
	_load_counters(d)
	var saved_state := StringName(str(d.get("state", "idle")))
	if saved_state != STATE_ENCOUNTER and saved_state != STATE_BETWEEN:
		return
	var area_id_saved := StringName(str(d.get("area", "")))
	if Encounter.find_area(_session.data, area_id_saved) == null:
		Log.warn(LOG_CATEGORY, "saved fight in unknown area '%s': idle" % area_id_saved)
		return
	var encounter := Encounter.new()
	if saved_state == STATE_ENCOUNTER:
		encounter = Encounter.from_save(d["enemies"] if d.get("enemies") is Array else [], _session.data)
		if encounter == null:
			Log.warn(LOG_CATEGORY, "saved fight with an unknown monster or a malformed enemy: idle")
			return
	_area_id = area_id_saved
	_encounter = encounter
	_state = STATE_ENCOUNTER if encounter.alive_count() > 0 else STATE_BETWEEN
	_hand = clampi(_int(d, "hand"), 0, 1)
	_player_hp = maxi(1, _int(d, "player_hp"))  # clamped to the maximum when the modifiers are rebuilt
	_player_timer_ms = maxi(0, _int(d, "player_timer_ms"))
	_between_ms = maxi(0, _int(d, "between_ms"))
	if _state == STATE_BETWEEN and saved_state == STATE_ENCOUNTER:
		_between_ms = int(_session.data.balance_value("combat.respawn_ms"))


func _load_counters(d: Dictionary) -> void:
	_deaths = maxi(0, _int(d, "deaths"))
	_food_eaten = maxi(0, _int(d, "food_eaten"))
	var saved_kills: Variant = d.get("kills")
	if not (saved_kills is Dictionary):
		return
	for key: Variant in (saved_kills as Dictionary):
		var id := StringName(str(key))
		var count: Variant = (saved_kills as Dictionary)[key]
		if not Encounter.is_known_monster(_session.data, id) or not (count is int or count is float) or int(count) <= 0:
			Log.warn(LOG_CATEGORY, "saved kill count of '%s' discarded" % id)
			continue
		_kills[id] = int(count)


func _int(d: Dictionary, key: String) -> int:
	var v: Variant = d.get(key)
	return int(v) if v is int or v is float else 0
