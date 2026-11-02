class_name ModifierService
extends RefCounted
## The single modifier system (docs/03_ARCHITECTURE.md §9): sources register lists of modifiers by id,
## formulas read stat totals with `total` (F-05).
##
## `set_source` replaces whatever the source had, so applying the same source twice cannot stack.
## Every change emits `modifiers_changed` on the session EventBus, once per change or once per batch.
## Modifiers are never saved: the owning systems rebuild them from their state.

var _stats: StatRegistry
var _events: GameEvents
# source id -> Array[Modifier] (only modifiers on registered stats)
var _sources: Dictionary[StringName, Array] = {}
var _batch_depth: int = 0
var _dirty: bool = false
# "stat|skill|action" -> clamped total; cleared on every change
var _cache: Dictionary[String, float] = {}


func _init(stats: StatRegistry, events: GameEvents) -> void:
	assert(stats != null, "ModifierService needs a StatRegistry")
	_stats = stats
	_events = events


## Replaces the modifiers of `source_id`. Modifiers on unknown stats are reported and left out.
func set_source(source_id: StringName, mods: Array[Modifier]) -> void:
	var kept: Array[Modifier] = []
	for mod: Modifier in mods:
		if mod == null:
			Log.error("modifiers", "source '%s': null modifier ignored" % source_id)
		elif not _stats.has(mod.stat):
			Log.error("modifiers", "source '%s': unknown stat '%s' ignored" % [source_id, mod.stat])
		else:
			kept.append(mod)
	_sources[source_id] = kept
	_changed()


func clear_source(source_id: StringName) -> void:
	if _sources.erase(source_id):
		_changed()


func clear_all() -> void:
	if _sources.is_empty():
		return
	_sources.clear()
	_changed()


func has_source(source_id: StringName) -> bool:
	return _sources.has(source_id)


## F-05: sum of the applicable modifiers of `stat`, limited to the stat's min/max. null = global context.
func total(stat: StringName, ctx: ModifierContext = null) -> float:
	if not _stats.has(stat):
		Log.error("modifiers", "total of unknown stat '%s'" % stat)
		return 0.0
	var key: String = _cache_key(stat, ctx)
	if _cache.has(key):
		return _cache[key]
	var sum: float = 0.0
	for source_id: StringName in _sources:
		sum += _source_sum(source_id, stat, ctx)
	var result: float = _stats.clamp_total(stat, sum)
	_cache[key] = result
	return result


## Per-source contributions to `stat` in `ctx` (before the min/max limit), for tooltips.
## Sources without applicable modifiers are left out. Entries: {"source": StringName, "value": float}.
func breakdown(stat: StringName, ctx: ModifierContext = null) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _stats.has(stat):
		Log.error("modifiers", "breakdown of unknown stat '%s'" % stat)
		return result
	for source_id: StringName in _sources:
		if _source_applies(source_id, stat, ctx):
			result.append({"source": source_id, "value": _source_sum(source_id, stat, ctx)})
	return result


## Suspends `modifiers_changed` until the matching `end_batch`; batches can nest.
func begin_batch() -> void:
	_batch_depth += 1


## Closes a batch; the outermost one emits `modifiers_changed` once if anything changed inside it.
func end_batch() -> void:
	if _batch_depth == 0:
		Log.error("modifiers", "end_batch without begin_batch")
		return
	_batch_depth -= 1
	if _batch_depth == 0 and _dirty:
		_dirty = false
		_emit()


func _changed() -> void:
	_cache.clear()
	if _batch_depth > 0:
		_dirty = true
	else:
		_emit()


func _emit() -> void:
	if _events != null:
		_events.modifiers_changed.emit()


func _source_sum(source_id: StringName, stat: StringName, ctx: ModifierContext) -> float:
	var sum: float = 0.0
	for mod: Modifier in _sources[source_id]:
		if mod.stat == stat and mod.applies_to(ctx):
			sum += mod.value
	return sum


func _source_applies(source_id: StringName, stat: StringName, ctx: ModifierContext) -> bool:
	for mod: Modifier in _sources[source_id]:
		if mod.stat == stat and mod.applies_to(ctx):
			return true
	return false


static func _cache_key(stat: StringName, ctx: ModifierContext) -> String:
	if ctx == null:
		return "%s||" % stat
	return "%s|%s|%s" % [stat, ctx.skill_id, ctx.action_id]
