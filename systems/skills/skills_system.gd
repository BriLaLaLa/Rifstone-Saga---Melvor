class_name SkillsSystem
extends RefCounted
## Experience of every skill (docs/01_GDD.md §3). Only the xp is state: level and progress derive from the F-01 table.
##
## Xp is granted through `skill_xp_pct` (F-02) and capped at `xp_curve.xp_cap`; the level stops at
## `xp_curve.max_level` while xp keeps growing up to the cap. One `level_up` per level gained, after `xp_gained`.
## Dependencies: data, events, modifiers.

const SAVE_KEY: StringName = &"skills"
const LOG_CATEGORY: String = "skills"
const XP_CAP_KEY: String = "xp_curve.xp_cap"
const XP_PCT_STAT: StringName = &"skill_xp_pct"
const SAVE_XP_KEY: String = "xp"
const LEVEL_SOURCE_PREFIX: String = "skill_level:"

var _data: GameData
var _events: GameEvents
var _modifiers: ModifierService
var _table: XpTable
var _xp_cap: int = 0
# skill id -> cumulative xp; holds every skill of the data, in data order.
var _xp: Dictionary[StringName, int] = {}


func _init(session: GameSession) -> void:
	assert(session != null, "SkillsSystem needs a session")
	_data = session.data
	_events = session.events
	_modifiers = session.modifiers
	_table = _data.xp_table()
	_xp_cap = int(_data.balance_value(XP_CAP_KEY))
	_reset()


## Every skill at 0 xp (level 1).
func new_game() -> void:
	_reset()


## {skill_id: {"xp": int}} for every skill (docs/05_INTERFACES.md §6).
func to_save() -> Dictionary:
	var d: Dictionary = {}
	for skill_id: StringName in _xp:
		d[String(skill_id)] = {SAVE_XP_KEY: _xp[skill_id]}
	return d


## Missing skills start at 0; unknown skills and malformed entries are reported and dropped; xp limited to 0..cap.
func from_save(d: Dictionary) -> void:
	_reset()
	for key: Variant in d:
		var skill_id: StringName = StringName(str(key))
		if not _xp.has(skill_id):
			Log.warn(LOG_CATEGORY, "unknown skill '%s' in save ignored" % skill_id)
			continue
		var xp: Variant = _read_xp(d[key])
		if xp == null:
			Log.warn(LOG_CATEGORY, "invalid xp for skill '%s': starts at 0" % skill_id)
			continue
		_xp[skill_id] = clampi(xp, 0, _xp_cap)


func get_xp(skill_id: StringName) -> int:
	if not _is_known(skill_id):
		return 0
	return _xp[skill_id]


## Level from the F-01 table; 0 for an unknown skill.
func get_level(skill_id: StringName) -> int:
	if not _is_known(skill_id):
		return 0
	return _table.level_for_xp(_xp[skill_id])


## 0..1 through the current level; 1.0 at the max level; 0.0 for an unknown skill.
func get_progress(skill_id: StringName) -> float:
	if not _is_known(skill_id):
		return 0.0
	return _table.progress(_xp[skill_id])


## F-02: granted = floor(base × (1 + T(skill_xp_pct, ctx)/100)), then (M12, F-102) floor(granted × share_pct / 100), then xp = min(xp + granted, xp_cap).
## ctx = null uses the skill context. Returns the xp actually added (0 at the cap). Emits xp_gained when > 0,
## then one level_up per level gained. A negative amount or an unknown skill is an error and changes nothing.
func add_xp(skill_id: StringName, base_amount: int, ctx: ModifierContext = null, share_pct: float = 100.0) -> int:
	if not _is_known(skill_id):
		return 0
	if base_amount < 0:
		Log.error(LOG_CATEGORY, "negative xp %d for skill '%s' ignored" % [base_amount, skill_id])
		return 0
	var context: ModifierContext = ctx if ctx != null else ModifierContext.for_skill(skill_id)
	var pct: float = _modifiers.total(XP_PCT_STAT, context)
	# (100 + pct) / 100 keeps whole-percent results exact (10 × 115 / 100 = 11.5, not 11.4999…).
	var granted: int = floori(float(base_amount) * (100.0 + pct) / 100.0)
	if share_pct != 100.0:
		granted = floori(float(granted) * share_pct / 100.0)
	var old_xp: int = _xp[skill_id]
	var new_xp: int = mini(old_xp + maxi(granted, 0), _xp_cap)
	var gained: int = new_xp - old_xp
	if gained <= 0:
		return 0
	var old_level: int = _table.level_for_xp(old_xp)
	_xp[skill_id] = new_xp
	var new_level: int = _table.level_for_xp(new_xp)
	if new_level != old_level:
		_apply_level_source(skill_id)
	_events.xp_gained.emit(skill_id, gained)
	for level: int in range(old_level + 1, new_level + 1):
		_events.level_up.emit(skill_id, level)
	return gained


## True when every {skill_id: level} is reached. An unknown skill or a malformed level is an error (false).
func meets_requirements(requirements: Dictionary) -> bool:
	for key: Variant in requirements:
		var skill_id: StringName = StringName(str(key))
		if not _is_known(skill_id):
			return false
		var needed: Variant = requirements[key]
		if not (needed is int or needed is float):
			Log.error(LOG_CATEGORY, "requirement for skill '%s' is not a number" % skill_id)
			return false
		if get_level(skill_id) < int(needed):
			return false
	return true


## Sum of the levels of every skill.
func total_level() -> int:
	var total: int = 0
	for skill_id: StringName in _xp:
		total += _table.level_for_xp(_xp[skill_id])
	return total


## F-93 (M10): the source `skill_level:<skill_id>` of every skill with `level_modifiers` (`per_level` x level, global);
## skills without them get no source. Called by the session after `new_game`/`from_save`; `add_xp` keeps it current.
func rebuild_modifiers() -> void:
	_modifiers.begin_batch()
	for def: SkillDef in _data.skills():
		_apply_level_source(def.id)
	_modifiers.end_batch()


func _apply_level_source(skill_id: StringName) -> void:
	var def: SkillDef = _data.skill(skill_id)
	if def.level_modifiers.is_empty():
		return
	var level: int = _table.level_for_xp(_xp[skill_id])
	var mods: Array[Modifier] = []
	for entry: LevelModifier in def.level_modifiers:
		mods.append(Modifier.make(entry.stat, entry.per_level * level))
	_modifiers.set_source(StringName(LEVEL_SOURCE_PREFIX + String(skill_id)), mods)


func _reset() -> void:
	_xp.clear()
	for def: SkillDef in _data.skills():
		_xp[def.id] = 0


func _is_known(skill_id: StringName) -> bool:
	if _xp.has(skill_id):
		return true
	Log.error(LOG_CATEGORY, "unknown skill '%s'" % skill_id)
	return false


# {"xp": n} with an integral n (int or integral float from JSON); null otherwise.
func _read_xp(entry: Variant) -> Variant:
	if not entry is Dictionary:
		return null
	var v: Variant = (entry as Dictionary).get(SAVE_XP_KEY)
	if v is int:
		return v
	if v is float:
		var f: float = v
		if f == floorf(f):
			return int(f)
	return null
