class_name HelperGradeDef
extends RefCounted
## A helper grade of `helper.grades` in balance.json (F-101): its id and the interval multiplier.

var id: StringName = &""
var interval_mult: float = 1.0


static func from_dict(d: Dictionary) -> HelperGradeDef:
	var r := DefReader.new(d, "helper grade")
	var def := HelperGradeDef.new()
	def.id = r.id("id")
	r.set_context("helper grade '%s'" % def.id)
	def.interval_mult = r.number("interval_mult")
	return def if r.ok else null
