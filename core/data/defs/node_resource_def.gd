class_name NodeResourceDef
extends RefCounted
## One resource of the table of a node in data/encounters/nodes.json (docs/04_DATA_SCHEMA_M35B.md §36.1, F-200, F-201): a gathering action
## of the node's discipline and its weight, the percentage of the zone (the weights of a table sum to 100).

var action: StringName = &""
var weight: int = 0


static func from_dict(d: Dictionary) -> NodeResourceDef:
	var r := DefReader.new(d, "node resource")
	var def := NodeResourceDef.new()
	def.action = r.id("action")
	r.set_context("node resource '%s'" % def.action)
	def.weight = r.integer("weight")
	return def if r.ok else null
