class_name NodeEntryDef
extends RefCounted
## One gathering node of an area in data/encounters/nodes.json (docs/04_DATA_SCHEMA_M24.md §29.3, M25 §30.1): a discipline, its
## weight (F-153) and, optional in the file, its difficulty and minimum level (F-161). Both are 0 here when the file omits them:
## `AreaNodesDef.from_dict` resolves them (the defaults need the `max_level` of the area), so outside it they are never 0.

var skill: StringName = &""
var weight: int = 0
var difficulty: int = 0
var min_level: int = 0


static func from_dict(d: Dictionary) -> NodeEntryDef:
	var r := DefReader.new(d, "node entry")
	var def := NodeEntryDef.new()
	def.skill = r.id("skill")
	r.set_context("node entry '%s'" % def.skill)
	def.weight = r.integer("weight")
	if d.has("difficulty"):
		def.difficulty = r.integer("difficulty")
	if d.has("min_level"):
		def.min_level = r.integer("min_level")
	return def if r.ok else null
