class_name DefReader
extends RefCounted
## Typed field reader shared by the `from_dict` of the Def classes (helper of core/data/defs/, not used elsewhere).
##
## It only converts types: JSON numbers (always float) become `int` where the contract wants `int`, ids become
## `StringName`, `#rrggbb` becomes `Color`, `[a, b]` becomes `Vector2i`. Semantic checks (ranges, references, unknown
## fields) belong to DataValidator (M1-04).
## Error policy: a missing or mistyped field never turns into an invented default. Each problem logs one
## `Log.error` (category "data", with the Def's context) and clears `ok`; the Def's `from_dict` then returns null.
## A float with a fractional part in an `int` field is a type error, not a silent truncation.

const LOG_CATEGORY: String = "data"

var ok: bool = true

var _d: Dictionary = {}
var _context: String = ""


func _init(d: Dictionary, context: String) -> void:
	_d = d
	_context = context


## Replaces the context used in error messages (e.g. once the id is known: "item 'redbirch_log'").
func set_context(context: String) -> void:
	_context = context


func context() -> String:
	return _context


func has(key: String) -> bool:
	return _d.has(key)


## Logs a conversion error for this Def and clears `ok`.
func fail(message: String) -> void:
	ok = false
	Log.error(LOG_CATEGORY, "%s: %s" % [_context, message])


## Records the outcome of a nested conversion that already logged its own error.
func absorb(child_ok: bool) -> void:
	if not child_ok:
		ok = false


func text(key: String) -> String:
	if not _present(key):
		return ""
	var raw: Variant = _d[key]
	if raw is String:
		return raw as String
	_fail_type(key, raw, "a string")
	return ""


func id(key: String) -> StringName:
	return StringName(text(key))


func integer(key: String) -> int:
	if not _present(key):
		return 0
	return _to_int(_d[key], key)


func number(key: String) -> float:
	if not _present(key):
		return 0.0
	var raw: Variant = _d[key]
	if raw is float or raw is int:
		return float(raw)
	_fail_type(key, raw, "a number")
	return 0.0


func flag(key: String) -> bool:
	if not _present(key):
		return false
	var raw: Variant = _d[key]
	if raw is bool:
		return raw as bool
	_fail_type(key, raw, "a boolean")
	return false


## `#rrggbb` (any string accepted by `Color.html`) to Color.
func color(key: String) -> Color:
	if not _present(key):
		return Color()
	var raw: Variant = _d[key]
	if raw is String and Color.html_is_valid(raw as String):
		return Color.html(raw as String)
	_fail_type(key, raw, "a '#rrggbb' color")
	return Color()


## `[a, b]` of integers to Vector2i(a, b): grid positions `[col, row]` and ranges `[min, max]`.
func int_pair(key: String) -> Vector2i:
	if not _present(key):
		return Vector2i.ZERO
	var raw: Variant = _d[key]
	if not raw is Array or (raw as Array).size() != 2:
		_fail_type(key, raw, "an array of 2 integers")
		return Vector2i.ZERO
	var pair: Array = raw as Array
	return Vector2i(_to_int(pair[0], key), _to_int(pair[1], key))


## True if `key` holds an object; otherwise logs (missing or wrong type) and returns false.
func is_dict(key: String) -> bool:
	if not _present(key):
		return false
	var raw: Variant = _d[key]
	if raw is Dictionary:
		return true
	_fail_type(key, raw, "an object")
	return false


## The object under `key`; call after `is_dict` (empty, without logging, if it is not an object).
func dict(key: String) -> Dictionary:
	var raw: Variant = _d.get(key)
	if raw is Dictionary:
		return raw as Dictionary
	return {}


## The objects of the array under `key`; non-object elements are logged and left out.
func dict_list(key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for element: Variant in _array(key):
		if element is Dictionary:
			result.append(element as Dictionary)
		else:
			_fail_type(key, element, "an array of objects")
	return result


func id_list(key: String) -> Array[StringName]:
	var result: Array[StringName] = []
	for element: Variant in _array(key):
		if element is String:
			result.append(StringName(element as String))
		else:
			_fail_type(key, element, "an array of strings")
	return result


## `{skill_id: level}` to a typed dictionary; a string `_doc` (comment, allowed by the schema) is skipped.
func level_map(key: String) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	if not is_dict(key):
		return result
	var raw: Dictionary = dict(key)
	for skill: Variant in raw:
		if str(skill) == "_doc" and raw[skill] is String:
			continue
		result[StringName(str(skill))] = _to_int(raw[skill], "%s.%s" % [key, skill])
	return result


## The modifiers under `key`, built with `Modifier.from_dict(entry, default_scope)`. With `ignore_scope` the
## entries' `scope` is dropped, so `default_scope` is used for all of them.
func modifiers(key: String, default_scope: String = "global", ignore_scope: bool = false) -> Array[Modifier]:
	var result: Array[Modifier] = []
	for entry: Dictionary in dict_list(key):
		var source: Dictionary = entry
		if ignore_scope and entry.has("scope"):
			source = entry.duplicate()
			source.erase("scope")
		var mod: Modifier = Modifier.from_dict(source, default_scope)
		if mod == null:
			ok = false
			continue
		result.append(mod)
	return result


func _array(key: String) -> Array:
	if not _present(key):
		return []
	var raw: Variant = _d[key]
	if raw is Array:
		return raw as Array
	_fail_type(key, raw, "an array")
	return []


# False (after logging) when the key is missing. A present null is reported by the caller's type check.
func _present(key: String) -> bool:
	if _d.has(key):
		return true
	fail("missing field '%s'" % key)
	return false


func _to_int(raw: Variant, key: String) -> int:
	if raw is int:
		return raw as int
	if raw is float and is_finite(raw as float) and (raw as float) == floorf(raw as float):
		return int(raw as float)
	_fail_type(key, raw, "an integer")
	return 0


func _fail_type(key: String, raw: Variant, expected: String) -> void:
	fail("field '%s' must be %s, got %s" % [key, expected, JSON.stringify(raw)])
