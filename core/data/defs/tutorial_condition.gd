class_name TutorialCondition
extends RefCounted
## An end condition of a tutorial step or of a starter quest goal (docs/04_DATA_SCHEMA_M30.md §34.2): `ack`, `event` or `metric`.
## `from_dict` returns null (after logging, see DefReader) if a field is missing or mistyped; ranges and references are the
## validator's job (DataValidatorTutorial).

const TYPE_ACK: StringName = &"ack"
const TYPE_EVENT: StringName = &"event"
const TYPE_METRIC: StringName = &"metric"

var type: StringName = &""
var signal_name: StringName = &""
var args: Dictionary = {}  # event: filter, keys = argument names of the signal; values scalar, Array or {gte,lte,gt,lt}
var count: int = 1
var metric: StringName = &""
var arg: StringName = &""
var gte: int = 0


static func from_dict(d: Dictionary) -> TutorialCondition:
	var r := DefReader.new(d, "tutorial condition")
	var def := TutorialCondition.new()
	def.type = r.id("type")
	match def.type:
		TYPE_EVENT:
			def.signal_name = r.id("signal")
			if r.has("args") and r.is_dict("args"):
				def.args = r.dict("args").duplicate(true)
			def.count = r.integer("count") if r.has("count") else 1
		TYPE_METRIC:
			def.metric = r.id("metric")
			def.arg = r.id("arg") if r.has("arg") else &""
			def.gte = r.integer("gte")
	return def if r.ok else null
