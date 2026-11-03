class_name CharacterSystem
extends RefCounted
## Class, experience and level of the character (docs/01_GDD.md §19, F-71). Only class and xp are state.
##
## Xp is granted through the global `skill_xp_pct` (F-71) and capped at `character_curve.xp_cap`; the level stops at
## `character_curve.max_level`. `character_xp_gained` first, then one `character_level_up` per level gained.
## Dependencies: data, events, modifiers, skills.

const SAVE_KEY: StringName = &"character"
const REQUIREMENT_KEY: StringName = &"character"
const LOG_CATEGORY: String = "character"
const XP_CAP_KEY: String = "character_curve.xp_cap"
const START_CLASS_KEY: String = "character.start_class"
const XP_PCT_STAT: StringName = &"skill_xp_pct"
const SAVE_CLASS_KEY: String = "class"
const SAVE_XP_KEY: String = "xp"

var _session: GameSession
var _data: GameData
var _events: GameEvents
var _modifiers: ModifierService
var _table: XpTable
var _xp_cap: int = 0
var _class_id: StringName = &""
var _xp: int = 0


func _init(session: GameSession) -> void:
	assert(session != null, "CharacterSystem needs a session")
	_session = session
	_data = session.data
	_events = session.events
	_modifiers = session.modifiers
	_table = _data.character_xp_table()
	_xp_cap = int(_data.balance_value(XP_CAP_KEY))
	_reset()


## Start class, 0 xp. No signals.
func new_game() -> void:
	_reset()


## {"class": id, "xp": int} (docs/05_INTERFACES.md §6).
func to_save() -> Dictionary:
	return {SAVE_CLASS_KEY: String(_class_id), SAVE_XP_KEY: _xp}


## Tolerant: unknown class -> start class; xp not integral or negative -> 0; above the cap -> cap. No signals.
func from_save(d: Dictionary) -> void:
	_reset()
	var class_id: StringName = StringName(str(d.get(SAVE_CLASS_KEY, "")))
	if _is_class(class_id):
		_class_id = class_id
	else:
		Log.warn(LOG_CATEGORY, "unknown class '%s' in save: start class" % class_id)
	var xp: Variant = _read_int(d.get(SAVE_XP_KEY))
	if xp == null or int(xp) < 0:
		Log.warn(LOG_CATEGORY, "invalid xp in save: starts at 0")
		return
	_xp = mini(int(xp), _xp_cap)


func class_id() -> StringName:
	return _class_id


func class_def() -> ClassDef:
	return _data.character_class(_class_id)


func get_xp() -> int:
	return _xp


func get_level() -> int:
	return _table.level_for_xp(_xp)


## 0..1 through the current level; 1.0 at the max level.
func get_progress() -> float:
	return _table.progress(_xp)


## F-71: granted = floor(base × (1 + T(skill_xp_pct, global)/100)), xp = min(xp + granted, cap). Returns the xp added.
func add_xp(base_amount: int) -> int:
	if base_amount < 0:
		Log.error(LOG_CATEGORY, "negative xp %d ignored" % base_amount)
		return 0
	var pct: float = _modifiers.total(XP_PCT_STAT, ModifierContext.global_ctx())
	var granted: int = floori(float(base_amount) * (100.0 + pct) / 100.0)
	var old_xp: int = _xp
	var new_xp: int = mini(old_xp + maxi(granted, 0), _xp_cap)
	var gained: int = new_xp - old_xp
	if gained <= 0:
		return 0
	var old_level: int = _table.level_for_xp(old_xp)
	_xp = new_xp
	var new_level: int = _table.level_for_xp(new_xp)
	_events.character_xp_gained.emit(gained)
	for level: int in range(old_level + 1, new_level + 1):
		_events.character_level_up.emit(level)
	return gained


## The key "character" is checked against the character level; the others go to skills.meets_requirements.
## A non-numeric value is an error (false).
func meets_requirements(requirements: Dictionary) -> bool:
	var skill_part: Dictionary = {}
	for key: Variant in requirements:
		var needed: Variant = requirements[key]
		if StringName(str(key)) != REQUIREMENT_KEY:
			skill_part[key] = needed
			continue
		if not (needed is int or needed is float):
			Log.error(LOG_CATEGORY, "character requirement is not a number")
			return false
		if get_level() < int(needed):
			return false
	return _session.skills.meets_requirements(skill_part)


func _reset() -> void:
	_class_id = StringName(str(_data.balance_value(START_CLASS_KEY)))
	_xp = 0


func _is_class(id: StringName) -> bool:
	for def: ClassDef in _data.classes():
		if def.id == id:
			return true
	return false


# int from an int or an integral float (JSON); null otherwise.
func _read_int(v: Variant) -> Variant:
	if v is int:
		return v
	if v is float:
		var f: float = v
		if f == floorf(f):
			return int(f)
	return null
