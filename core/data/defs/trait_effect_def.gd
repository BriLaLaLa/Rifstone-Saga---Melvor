class_name TraitEffectDef
extends RefCounted
## One effect of a trait (`effects` of data/classes/<id>.json, docs/04_DATA_SCHEMA.md §14, types of F-81).
## `params` holds the parameters exactly as validated by DataValidator (JSON numbers stay floats).
## `from_dict` returns null (after logging, see DefReader) if a field is missing or mistyped.

var type: StringName = &""
var params: Dictionary = {}


static func from_dict(d: Dictionary) -> TraitEffectDef:
	var r := DefReader.new(d, "trait effect")
	var def := TraitEffectDef.new()
	def.type = r.id("type")
	r.set_context("trait effect '%s'" % def.type)
	if r.is_dict("params"):
		def.params = r.dict("params").duplicate(true)
	return def if r.ok else null
