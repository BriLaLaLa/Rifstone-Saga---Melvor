class_name Modifier
extends RefCounted
## One `{stat, value, scope}` entry (docs/01_GDD.md §15, docs/04_DATA_SCHEMA.md §1).
##
## The scope is `global` (always applies), `skill:<id>` (applies when the context skill is `id`) or
## `action:<id>` (applies when the context action is `id`). Modifiers are values: `scaled` returns a copy.

const SCOPE_GLOBAL: StringName = &"global"
const SCOPE_SKILL: StringName = &"skill"
const SCOPE_ACTION: StringName = &"action"
const SCOPE_SEPARATOR: String = ":"

var stat: StringName = &""
var value: float = 0.0
var scope_kind: StringName = SCOPE_GLOBAL
var scope_id: StringName = &""


## Builds a modifier from its JSON form. `default_scope` (same syntax as the `scope` field) is used when the
## dictionary has no `scope`. Returns null (and logs an error) when `stat`, `value` or the scope are malformed.
static func from_dict(d: Dictionary, default_scope: String = "global") -> Modifier:
	var raw_stat: Variant = d.get("stat")
	if not (raw_stat is String or raw_stat is StringName) or str(raw_stat).is_empty():
		Log.error("modifiers", "modifier without a valid 'stat': %s" % [d])
		return null
	var raw_value: Variant = d.get("value")
	if not (raw_value is float or raw_value is int):
		Log.error("modifiers", "modifier '%s' without a numeric 'value'" % [raw_stat])
		return null
	var raw_scope: Variant = d.get("scope", default_scope)
	if not (raw_scope is String or raw_scope is StringName):
		Log.error("modifiers", "modifier '%s' with a non-string 'scope'" % [raw_stat])
		return null
	var parts: Array[StringName] = _parse_scope(str(raw_scope))
	if parts.is_empty():
		Log.error("modifiers", "modifier '%s' with invalid scope '%s'" % [raw_stat, raw_scope])
		return null
	return make(StringName(str(raw_stat)), float(raw_value), parts[0], parts[1])


static func make(
	stat: StringName, value: float, scope_kind: StringName = &"global", scope_id: StringName = &""
) -> Modifier:
	var mod := Modifier.new()
	mod.stat = stat
	mod.value = value
	mod.scope_kind = scope_kind
	mod.scope_id = scope_id
	return mod


## F-05 scope rule; a null context is the global context.
func applies_to(ctx: ModifierContext) -> bool:
	match scope_kind:
		SCOPE_GLOBAL:
			return true
		SCOPE_SKILL:
			return ctx != null and ctx.skill_id != &"" and ctx.skill_id == scope_id
		SCOPE_ACTION:
			return ctx != null and ctx.action_id != &"" and ctx.action_id == scope_id
	return false


## A copy with `value * factor` and the same stat and scope.
func scaled(factor: float) -> Modifier:
	return make(stat, value * factor, scope_kind, scope_id)


# Returns [kind, id] or an empty array when the scope string is invalid.
static func _parse_scope(scope: String) -> Array[StringName]:
	if scope == String(SCOPE_GLOBAL):
		return [SCOPE_GLOBAL, &""]
	var separator: int = scope.find(SCOPE_SEPARATOR)
	if separator <= 0:
		return []
	var kind := StringName(scope.substr(0, separator))
	var id: String = scope.substr(separator + SCOPE_SEPARATOR.length())
	if (kind != SCOPE_SKILL and kind != SCOPE_ACTION) or id.is_empty():
		return []
	return [kind, StringName(id)]
