class_name ItemEffectDef
extends RefCounted
## One effect of a legendary (`equip.legendary.effects`, docs/04_DATA_SCHEMA.md §21, types of F-81 and F-120). In the data
## the parameters sit next to `type`; here they are in `params` (the same shape as a trait effect). `source` is empty in
## the data and set by `Equipment.item_effects()` to `equipment:<slot>`.
## `from_dict` returns null (after logging, see DefReader) if a field is missing or mistyped.

var type: StringName = &""
var params: Dictionary = {}
var source: StringName = &""


static func from_dict(d: Dictionary) -> ItemEffectDef:
	var r := DefReader.new(d, "item effect")
	var def := ItemEffectDef.new()
	def.type = r.id("type")
	r.set_context("item effect '%s'" % def.type)
	for key: Variant in d:
		if str(key) != "type":
			def.params[str(key)] = d[key]
	return def if r.ok else null


## A copy with the given source.
func with_source(new_source: StringName) -> ItemEffectDef:
	var copy := ItemEffectDef.new()
	copy.type = type
	copy.params = params.duplicate(true)
	copy.source = new_source
	return copy
