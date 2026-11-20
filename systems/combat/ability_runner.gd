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
	var ward: int = 0  # M28 (F-191): the Ward the ability grants (0 = none) and its time
	var ward_ms: int = 0
	var kind: StringName = &""  # the kind of the ability (`on_ability`, F-192)

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
## M28-08b: `ward_ms` is the time the Ward has left; a `ward` ability that the Ward blocks becomes usable when it ends (event).
func next_ms(hp: int, max_hp: int, ward_amount: int = 0, mult_of: Callable = Callable(), ward_ms: int = 0) -> int:
	var next: int = NO_TIMER
	for def: AbilityDef in _session.loadout.active_abilities():
		var wait: int = maxi(_timer(def), _buffs.get(def.id, 0))  # a buff is used again once it ends
		if _usable(def, hp, max_hp, ward_amount, mult_of):
			next = mini(next, wait)
		elif def.kind == AbilityDef.KIND_WARD and ward_ms > 0 and _ward_amount_of(def, max_hp, mult_of) > 0:
			next = mini(next, maxi(wait, ward_ms))  # once the Ward is gone the amount is above 0
	return next


## The first ready and usable ability in slot order, used now (cooldown restarts); null if none.
## `stats` are the player's, `rule` the F-76 target rule. M28 (F-190, F-191): `mult_of(def, target_index)` gives the `M` of a hit
## on that target (>= 0) or the factor of the amount of a heal (-1); an empty Callable is 1.0. `ward_amount` is the Ward of
## the player now. With both at their defaults it rolls and returns what it did before M28.
func take_due(encounter: Encounter, hp: int, stats: CombatantStats, rule: StringName,
		mult_of: Callable = Callable(), ward_amount: int = 0) -> Use:
	for def: AbilityDef in _session.loadout.active_abilities():
		if _timer(def) > 0 or _buffs.has(def.id) or not _usable(def, hp, stats.max_hp, ward_amount, mult_of):
			continue
		_timers[def.id] = def.cooldown_ms
		var use := Use.new()
		use.id = def.id
		use.kind = def.kind
		match def.kind:
			AbilityDef.KIND_STRIKE, AbilityDef.KIND_CLEAVE:
				_roll_hits(def, encounter, stats, rule, use, mult_of)
			AbilityDef.KIND_HEAL:
				var heal_mult: float = _mult(mult_of, def, -1)
				use.heal = int(floor(float(stats.max_hp) * def.heal_pct / 100.0 * heal_mult + CombatMath.EPSILON))
			AbilityDef.KIND_BUFF:
				_buffs[def.id] = def.duration_ms
				_session.modifiers.set_source(_source(def.id), def.modifiers)
			AbilityDef.KIND_WARD:
				use.ward = _ward_amount_of(def, stats.max_hp, mult_of)
				use.ward_ms = def.duration_ms
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


func _usable(def: AbilityDef, hp: int, max_hp: int, ward_amount: int = 0, mult_of: Callable = Callable()) -> bool:
	match def.kind:
		AbilityDef.KIND_HEAL:
			return hp < max_hp
		AbilityDef.KIND_WARD:  # F-191: only if it would give more than the Ward the player has now
			return _ward_amount_of(def, max_hp, mult_of) > ward_amount
	return true


# F-189, F-191: the Ward an ability of kind `ward` gives, `floor(max_hp * ward_pct / 100 * A)`.
func _ward_amount_of(def: AbilityDef, max_hp: int, mult_of: Callable) -> int:
	return int(floor(float(max_hp) * def.ward_pct / 100.0 * _mult(mult_of, def, -1) + CombatMath.EPSILON))


# M28 (F-190): the `M` of a hit of `def` on `target_index`, or the factor of an amount (-1); 1.0 without a Callable.
static func _mult(mult_of: Callable, def: AbilityDef, target_index: int) -> float:
	return float(mult_of.call(def, target_index)) if mult_of.is_valid() else 1.0


# F-80: all the rolls first, in target order (hit, then damage on a hit); no block (enemies do not block).
func _roll_hits(def: AbilityDef, encounter: Encounter, stats: CombatantStats, rule: StringName, use: Use, mult_of: Callable) -> void:
	if def.kind == AbilityDef.KIND_STRIKE:
		var target: int = encounter.target(def.target_rule if def.target_rule != &"" else rule)
		if target >= 0:
			for _hit: int in def.hits:  # the hits stay on the same list, on the same target (F-191)
				use.targets.append(target)
	else:
		use.targets = encounter.alive_indices()
		if def.targets > 0 and use.targets.size() > def.targets:
			use.targets.resize(def.targets)
	for index: int in use.targets:
		var enemy: Encounter.Enemy = encounter.enemies[index]
		var mult: float = _mult(mult_of, def, index)
		if def.execute_mult != 1.0 and float(enemy.hp) * 100.0 <= float(enemy.stats.max_hp) * def.execute_hp_pct:
			mult *= def.execute_mult  # F-191 `execute`: read when the rolls are made
		var attack: Dictionary = Encounter.roll_power_attack(stats, enemy.stats, def.power_mult, mult, _session.rng, _session.data)
		if attack["damage"] > 0:
			if not def.applies.is_empty():
				attack["applies"] = def.applies
			if def.drain_pct > 0.0:
				attack["drain"] = int(floor(float(attack["damage"]) * def.drain_pct / 100.0 + CombatMath.EPSILON))
		use.attacks.append(attack)


## F-192 `kill_cooldown_cut`: every cooldown that runs is cut by `ms` (never under 0); the duration of the buffs does not change.
func cut_cooldowns(ms: int) -> void:
	if ms <= 0:
		return
	for def: AbilityDef in _session.loadout.active_abilities():
		_timers[def.id] = maxi(0, _timer(def) - ms)


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
