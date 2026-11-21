class_name TutorialConditions
extends RefCounted
## Pure logic of the tutorial conditions (docs/05_INTERFACES_M30.md §5.42, docs/04_DATA_SCHEMA_M30.md §34.2): the filter on the
## arguments of an EventBus signal, and the arguments of every signal read from the script of GameEvents.

const COMPARES: PackedStringArray = ["gte", "lte", "gt", "lt"]

static var _signals: Dictionary = {}  # signal name -> Array[{"name": String, "type": int}]


## §34.2: each key of the filter is an argument name; a scalar means equal, an Array equal to any of its elements, an object
## `{gte|lte|gt|lt: n}` a numeric comparison (all its keys must hold). An empty filter is true; a name the signal lacks is false.
static func matches(args_filter: Dictionary, arg_names: PackedStringArray, values: Array) -> bool:
	for key: Variant in args_filter:
		var index: int = arg_names.find(str(key))
		if index < 0 or index >= values.size():
			return false
		if not _value_matches(args_filter[key], values[index]):
			return false
	return true


## Argument names of a signal of GameEvents, from its script. An unknown signal gives [] and a `push_error`.
static func signal_arg_names(events: GameEvents, signal_name: StringName) -> PackedStringArray:
	var result: PackedStringArray = []
	var args: Variant = script_signals(events.get_script() as Script).get(signal_name)
	if args == null:
		push_error("TutorialConditions: unknown signal '%s'" % signal_name)
		return result
	for arg: Dictionary in (args as Array):
		result.append(str(arg["name"]))
	return result


## Every signal declared by the GameEvents script (cached): `{name: [{"name": String, "type": int}, ...]}`.
static func script_signals(script: Script = null) -> Dictionary:
	if _signals.is_empty():
		var source: Script = script if script != null else (GameEvents as Script)
		for info: Dictionary in source.get_script_signal_list():
			var args: Array[Dictionary] = []
			for a: Dictionary in (info["args"] as Array):
				args.append({"name": str(a["name"]), "type": int(a["type"])})
			_signals[StringName(str(info["name"]))] = args
	return _signals


static func _value_matches(expected: Variant, actual: Variant) -> bool:
	if expected is Array:
		for option: Variant in (expected as Array):
			if _equal(option, actual):
				return true
		return false
	if expected is Dictionary:
		return _compare(expected as Dictionary, actual)
	return _equal(expected, actual)


# String and StringName compare by text; numbers by value (JSON numbers are floats); the rest by ==.
static func _equal(a: Variant, b: Variant) -> bool:
	if (a is String or a is StringName) and (b is String or b is StringName):
		return str(a) == str(b)
	if (a is int or a is float) and (b is int or b is float):
		return float(a) == float(b)
	return typeof(a) == typeof(b) and a == b


static func _compare(rule: Dictionary, actual: Variant) -> bool:
	if not (actual is int or actual is float) or rule.is_empty():
		return false
	var x: float = float(actual)
	for op: Variant in rule:
		var limit: Variant = rule[op]
		if not COMPARES.has(str(op)) or not (limit is int or limit is float):
			return false
		var n: float = float(limit)
		match str(op):
			"gte": if x < n: return false
			"lte": if x > n: return false
			"gt": if x <= n: return false
			"lt": if x >= n: return false
	return true
