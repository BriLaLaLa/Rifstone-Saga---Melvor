class_name MapEffectDef
extends RefCounted
## The risk or the reward of a Card modifier (docs/04_DATA_SCHEMA.md §11.2): a closed `type` (F-111) and the range
## `[min, max]` that the intensity step (F-109) walks through.
## `from_dict` returns null (after logging, see DefReader) if a field is missing or mistyped.

var type: StringName = &""
var min_value: float = 0.0
var max_value: float = 0.0


static func from_dict(d: Dictionary) -> MapEffectDef:
	var r := DefReader.new(d, "map effect")
	var def := MapEffectDef.new()
	def.type = r.id("type")
	r.set_context("map effect '%s'" % def.type)
	def.min_value = r.number("min")
	def.max_value = r.number("max")
	return def if r.ok else null


## F-109: `min + round((max - min) * step / steps)`.
func value_at(step: int, steps: int) -> float:
	return min_value + roundf((max_value - min_value) * float(step) / float(steps))
