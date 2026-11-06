class_name AbilityRunner
extends RefCounted
## Active abilities of the equipped loadout (docs/02_FORMULAS.md F-79, F-80): one cooldown timer per ability and the
## running buffs. The engine ticks it, asks when something is due (`next_ms`) and takes the due uses (`take_due`);
## this class rolls the hits and registers the buffs but never changes hp or enemies (the engine applies a `Use`).
## A cooldown starts full at the start of the combat, keeps running between encounters, and at zero the ability waits
## for a valid target: any ability needs an encounter in progress, `heal` needs hp below the maximum, `buff` needs
## its buff not running. An ability the setup does not allow keeps its timer frozen. Abilities hit with the main
## hand's stats. Buff modifiers are the source `ability:<id>`. Dependencies: data, rng, modifiers, character, loadout.

const NO_TIMER: int = 1 << 40
const LOG_CATEGORY: String = "combat"

## What one ability does, for the engine: the `ability_used` event, the hits to apply and the hp to heal.
class Use extends RefCounted:
	var id: StringName = &""
	var targets: Array[int] = []
	var attacks: Array[Dictionary] = []  # {"hit", "blocked", "damage"}, same order as `targets`
	var heal: int = 0

var _session: GameSession
var _timers: Dictionary[StringName, int] = {}  # remaining ms to the next use
var _buffs: Dictionary[StringName, int] = {}  # remaining ms of the running buffs


func _init(session: GameSession) -> void:
	_session = session


## New combat or back to idle: full cooldowns (lazy), no buffs.
func reset() -> void:
	_timers.clear()
	_clear_buffs()


## Time passes (also between encounters): cooldowns of the allowed abilities and the buffs run down.
func tick(ms: int) -> void:
	for def: AbilityDef in _session.loadout.active_abilities():
		_timers[def.id] = maxi(0, _timer(def) - ms)
	var expired: Array[StringName] = []
	for id: StringName in _buffs:
		_buffs[id] -= ms
		if _buffs[id] <= 0:
			expired.append(id)
	_session.modifiers.begin_batch()
	for id: StringName in expired:
		_buffs.erase(id)
		_session.modifiers.clear_source(_source(id))
	_session.modifiers.end_batch()


## Ms to the next ability use during an encounter (0 = ready now), `NO_TIMER` if none can happen.
func next_ms(hp: int, max_hp: int) -> int:
	var next: int = NO_TIMER
	for def: AbilityDef in _session.loadout.active_abilities():
		if _usable(def, hp, max_hp):
			next = mini(next, maxi(_timer(def), _buffs.get(def.id, 0)))  # a buff is used again once it ends
	return next


## The first ready and usable ability in slot order, used now (cooldown restarts); null if none.
## `stats` are the player's, `rule` the F-76 target rule.
func take_due(encounter: Encounter, hp: int, stats: CombatantStats, rule: StringName) -> Use:
	for def: AbilityDef in _session.loadout.active_abilities():
		if _timer(def) > 0 or _buffs.has(def.id) or not _usable(def, hp, stats.max_hp):
			continue
		_timers[def.id] = def.cooldown_ms
		var use := Use.new()
		use.id = def.id
		match def.kind:
			AbilityDef.KIND_STRIKE, AbilityDef.KIND_CLEAVE:
				_roll_hits(def, encounter, stats, rule, use)
			AbilityDef.KIND_HEAL:
				use.heal = int(floor(float(stats.max_hp) * def.heal_pct / 100.0 + CombatMath.EPSILON))
			AbilityDef.KIND_BUFF:
				_buffs[def.id] = def.duration_ms
				_session.modifiers.set_source(_source(def.id), def.modifiers)
		return use
	return null


## For the UI: one entry per equipped ability in slot order (`timer_ms` = time left to the next use).
func view() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var setup_id: StringName = _session.equipment.setup()
	for slot: int in _session.loadout.ability_slots():
		var def: AbilityDef = _def(_session.loadout.get_ability(slot))
		if def != null:
			out.append({"id": def.id, "timer_ms": _timer(def), "cooldown_ms": def.cooldown_ms,
				"enabled": def.allows_setup(setup_id)})
	return out


func buffs() -> Dictionary:
	return _buffs.duplicate()


# --- save (docs/05_INTERFACES.md §6: `abilities` {id: ms left}, `buffs` {id: ms left}) --------------------------------

func timers_save() -> Dictionary:
	return _to_dict(_timers)


func buffs_save() -> Dictionary:
	return _to_dict(_buffs)


## Tolerant: unknown ids, non-numbers and buffs of other kinds are dropped with a warning; values are clamped
## (timer 0..cooldown, buff 1..duration). The buff modifiers are registered again.
func from_save(timers: Variant, buffs_saved: Variant) -> void:
	reset()
	if timers is Dictionary:
		for key: Variant in (timers as Dictionary):
			var def: AbilityDef = _def(StringName(str(key)))
			var value: Variant = (timers as Dictionary)[key]
			if def == null or not (value is int or value is float):
				Log.warn(LOG_CATEGORY, "saved ability timer '%s' discarded" % key)
				continue
			_timers[def.id] = clampi(int(value), 0, def.cooldown_ms)
	if buffs_saved is Dictionary:
		for key: Variant in (buffs_saved as Dictionary):
			var def: AbilityDef = _def(StringName(str(key)))
			var value: Variant = (buffs_saved as Dictionary)[key]
			if def == null or def.kind != AbilityDef.KIND_BUFF or not (value is int or value is float):
				Log.warn(LOG_CATEGORY, "saved buff '%s' discarded" % key)
				continue
			_buffs[def.id] = clampi(int(value), 1, def.duration_ms)
	rebuild_modifiers()


## Sources `ability:<id>` of the running buffs (the session clears every source before it rebuilds them).
func rebuild_modifiers() -> void:
	for id: StringName in _buffs:
		_session.modifiers.set_source(_source(id), _def(id).modifiers)


# --- helpers ----------------------------------------------------------------------------------------------------

func _timer(def: AbilityDef) -> int:
	return _timers.get(def.id, def.cooldown_ms)


func _usable(def: AbilityDef, hp: int, max_hp: int) -> bool:
	match def.kind:
		AbilityDef.KIND_HEAL:
			return hp < max_hp
	return true


# F-80: all the rolls first, in target order (hit, then damage on a hit); no block (enemies do not block).
func _roll_hits(def: AbilityDef, encounter: Encounter, stats: CombatantStats, rule: StringName, use: Use) -> void:
	if def.kind == AbilityDef.KIND_STRIKE:
		if encounter.target(rule) >= 0:
			use.targets.append(encounter.target(rule))
	else:
		use.targets = encounter.alive_indices()
		if def.targets > 0 and use.targets.size() > def.targets:
			use.targets.resize(def.targets)
	for index: int in use.targets:
		use.attacks.append(_roll(def, stats, encounter.enemies[index].stats))


func _roll(def: AbilityDef, attacker: CombatantStats, defender: CombatantStats) -> Dictionary:
	var data: GameData = _session.data
	var result: Dictionary = {"hit": false, "blocked": false, "damage": 0}
	if _session.rng.randf() >= CombatMath.hit_chance(attacker.accuracy, defender.evasion, data):
		return result
	result["hit"] = true
	var raw: int = _session.rng.randi_range(attacker.min_hit, attacker.max_hit)
	var scaled: int = int(floor(float(raw) * def.power_mult + CombatMath.EPSILON))
	var relation: StringName = CombatMath.triangle(attacker.style, defender.style, data)
	var dr: float = CombatMath.effective_dr(defender.damage_reduction, relation, data)
	result["damage"] = CombatMath.damage_after_dr(CombatMath.triangle_damage(scaled, relation, data), dr)
	return result


func _clear_buffs() -> void:
	_session.modifiers.begin_batch()
	for id: StringName in _buffs:
		_session.modifiers.clear_source(_source(id))
	_session.modifiers.end_batch()
	_buffs.clear()


func _def(id: StringName) -> AbilityDef:
	var class_def: ClassDef = _session.character.class_def()
	if class_def != null:
		for def: AbilityDef in class_def.abilities:
			if def.id == id:
				return def
	return null


static func _source(id: StringName) -> StringName:
	return StringName("ability:%s" % id)


static func _to_dict(values: Dictionary[StringName, int]) -> Dictionary:
	var out: Dictionary = {}
	for id: StringName in values:
		out[String(id)] = values[id]
	return out
