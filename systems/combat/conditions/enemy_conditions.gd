class_name EnemyConditions
extends RefCounted
## The conditions of one enemy (docs/01_GDD_M28.md §40.3, docs/02_FORMULAS_M28.md F-185…F-188): Bleed, Weaken, Expose and
## Stagger with its immunity, at most one of each. A plain value object: the engine decides who is immune and when time passes
## (`elapse`); the ticks of the Bleed are events of the engine (`BleedClock`), never of `elapse`. Saved with the enemy (`cond`).

const LOG_CATEGORY: String = "combat"
const MS_MAX: int = 60000  # format limit of every duration in a save (F-185)
const TICKS_MAX: int = 60
const WEAKEN_PCT_MAX: float = 90.0  # format limits of `pct` (docs/04_DATA_SCHEMA_M28.md §33.2)
const EXPOSE_PCT_MAX: float = 100.0

var bleed_left: int = 0  # the damage still to be dealt by the ticks
var bleed_ticks: int = 0
var weaken_pct: float = 0.0
var weaken_ms: int = 0
var expose_pct: float = 0.0
var expose_ms: int = 0
var stagger_ms: int = 0  # the window "staggered" (F-188)
var immune_ms: int = 0  # the immunity that follows a Stagger


## True if the condition is on now; for `stagger` the window "staggered" (F-188).
func has(condition: StringName) -> bool:
	match condition:
		ConditionApply.BLEED:
			return bleeds()
		ConditionApply.WEAKEN:
			return weaken_ms > 0
		ConditionApply.EXPOSE:
			return expose_ms > 0
		ConditionApply.STAGGER:
			return stagger_ms > 0
	return false


## F-185…F-188. `damage` is the D of the hit (only Bleed reads it); `stagger_ok` is false for a boss and a Monolith. Returns the new
## attack timer of the enemy: `timer_ms` plus the Stagger, otherwise unchanged.
func apply(app: ConditionApply, damage: int, timer_ms: int, stagger_ok: bool, params: ConditionParams) -> int:
	match app.condition:
		ConditionApply.BLEED:  # F-186
			var total: int = int(floor(float(damage) * app.pct / 100.0 + CombatMath.EPSILON))
			if total > 0:
				bleed_left += total
				bleed_ticks = maxi(bleed_ticks, ceili(float(app.ms) / float(params.tick_ms)))
		ConditionApply.WEAKEN:
			weaken_pct = maxf(weaken_pct, app.pct)
			weaken_ms = maxi(weaken_ms, app.ms)
		ConditionApply.EXPOSE:
			expose_pct = maxf(expose_pct, app.pct)
			expose_ms = maxi(expose_ms, app.ms)
		ConditionApply.STAGGER:  # F-188
			if stagger_ok and immune_ms <= 0:
				stagger_ms = app.ms
				immune_ms = params.stagger_immunity_ms
				return timer_ms + app.ms
	return timer_ms


## Time passes (F-185): the durations and the immunity run down; a condition at 0 is over. Never the Bleed (its ticks are events).
func elapse(ms: int) -> void:
	weaken_ms = maxi(0, weaken_ms - ms)
	expose_ms = maxi(0, expose_ms - ms)
	stagger_ms = maxi(0, stagger_ms - ms)
	immune_ms = maxi(0, immune_ms - ms)
	weaken_pct = weaken_pct if weaken_ms > 0 else 0.0
	expose_pct = expose_pct if expose_ms > 0 else 0.0


func bleeds() -> bool:
	return bleed_ticks > 0 and bleed_left > 0


## F-186: the damage of the next tick, ceil(left / ticks); the last tick takes what is left.
func take_tick() -> int:
	if not bleeds():
		return 0
	var damage: int = ceili(float(bleed_left) / float(bleed_ticks))
	bleed_left -= damage
	bleed_ticks -= 1
	if bleed_ticks <= 0 or bleed_left <= 0:
		bleed_left = 0
		bleed_ticks = 0
	return damage


func is_empty() -> bool:
	return not bleeds() and weaken_ms <= 0 and expose_ms <= 0 and stagger_ms <= 0 and immune_ms <= 0


## `cond` of the save (docs/05_INTERFACES_M28.md §6f): only what is on; {} if nothing is.
func to_save() -> Dictionary:
	var out: Dictionary = {}
	if bleeds():
		out["bleed"] = {"left": bleed_left, "ticks": bleed_ticks}
	if weaken_ms > 0:
		out["weaken"] = {"pct": weaken_pct, "ms": weaken_ms}
	if expose_ms > 0:
		out["expose"] = {"pct": expose_pct, "ms": expose_ms}
	if stagger_ms > 0:
		out["stagger_ms"] = stagger_ms
	if immune_ms > 0:
		out["immune_ms"] = immune_ms
	return out


## Tolerant (F-185): a malformed value or an unknown key is dropped with a warning, a number out of range is limited, a condition
## that ends up with no time is dropped. Never null.
static func from_save(d: Variant) -> EnemyConditions:
	var result := EnemyConditions.new()
	if not (d is Dictionary):
		if d != null:
			Log.warn(LOG_CATEGORY, "saved enemy conditions are not an object: dropped")
		return result
	var saved: Dictionary = d
	for key: Variant in saved:
		match str(key):
			"bleed":
				result._read_bleed(saved[key])
			"weaken":
				var weaken: Array = _read_pct_ms(saved[key], WEAKEN_PCT_MAX, "weaken")
				result.weaken_pct = weaken[0]
				result.weaken_ms = int(weaken[1])
			"expose":
				var expose: Array = _read_pct_ms(saved[key], EXPOSE_PCT_MAX, "expose")
				result.expose_pct = expose[0]
				result.expose_ms = int(expose[1])
			"stagger_ms":
				result.stagger_ms = _read_ms(saved[key], "stagger_ms")
			"immune_ms":
				result.immune_ms = _read_ms(saved[key], "immune_ms")
			_:
				Log.warn(LOG_CATEGORY, "saved enemy condition '%s' is unknown: dropped" % key)
	return result


## For `get_state()` (docs/05_INTERFACES_M28.md §5.10b): only the conditions that are on, `immune_ms` while the immunity lasts.
func view() -> Dictionary:
	var out: Dictionary = {}
	if bleeds():
		out["bleed"] = {"left": bleed_left, "ticks": bleed_ticks}
	if weaken_ms > 0:
		out["weaken"] = {"pct": weaken_pct, "ms": weaken_ms}
	if expose_ms > 0:
		out["expose"] = {"pct": expose_pct, "ms": expose_ms}
	if stagger_ms > 0:
		out["stagger"] = {"ms": stagger_ms}
	if immune_ms > 0:
		out["immune_ms"] = immune_ms
	return out


func _read_bleed(value: Variant) -> void:
	if not (value is Dictionary) or not _is_number((value as Dictionary).get("left")) or not _is_number((value as Dictionary).get("ticks")):
		Log.warn(LOG_CATEGORY, "saved Bleed is malformed: dropped")
		return
	var left: int = maxi(0, int((value as Dictionary)["left"]))
	var ticks: int = clampi(int((value as Dictionary)["ticks"]), 0, TICKS_MAX)
	if left > 0 and ticks > 0:
		bleed_left = left
		bleed_ticks = ticks


# [pct, ms] of Weaken or Expose (pct limited to (0, max], ms to [0, MS_MAX]); [0, 0] if malformed or over.
static func _read_pct_ms(value: Variant, pct_max: float, label: String) -> Array:
	if not (value is Dictionary) or not _is_number((value as Dictionary).get("pct")) or not _is_number((value as Dictionary).get("ms")):
		Log.warn(LOG_CATEGORY, "saved %s is malformed: dropped" % label)
		return [0.0, 0.0]
	var pct: float = minf(float((value as Dictionary)["pct"]), pct_max)
	var ms: int = clampi(int((value as Dictionary)["ms"]), 0, MS_MAX)
	return [pct, float(ms)] if pct > 0.0 and ms > 0 else [0.0, 0.0]


static func _read_ms(value: Variant, label: String) -> int:
	if not _is_number(value):
		Log.warn(LOG_CATEGORY, "saved %s is not a number: dropped" % label)
		return 0
	return clampi(int(value), 0, MS_MAX)


static func _is_number(value: Variant) -> bool:
	return value is int or value is float
