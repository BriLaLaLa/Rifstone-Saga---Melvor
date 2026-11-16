class_name NodeEntryDef
extends RefCounted
## One gathering node of an area in data/encounters/nodes.json (docs/04_DATA_SCHEMA_M24.md §29.3): a discipline and its weight (F-153).

var skill: StringName = &""
var weight: int = 0


static func from_dict(d: Dictionary) -> NodeEntryDef:
	var r := DefReader.new(d, "node entry")
	var def := NodeEntryDef.new()
	def.skill = r.id("skill")
	r.set_context("node entry '%s'" % def.skill)
	def.weight = r.integer("weight")
	return def if r.ok else null
