class_name AreaNodesDef
extends RefCounted
## The gathering nodes of an area in data/encounters/nodes.json (docs/04_DATA_SCHEMA_M24.md §29.3): the highest resource
## level the area gives (F-154) and the weighted disciplines (F-153).

var area: StringName = &""
var max_level: int = 0
var entries: Array[NodeEntryDef] = []


static func from_dict(d: Dictionary) -> AreaNodesDef:
	var r := DefReader.new(d, "area nodes")
	var def := AreaNodesDef.new()
	def.area = r.id("area")
	r.set_context("area nodes '%s'" % def.area)
	def.max_level = r.integer("max_level")
	for entry: Dictionary in r.dict_list("nodes"):
		var node: NodeEntryDef = NodeEntryDef.from_dict(entry)
		r.absorb(node != null)
		if node != null:
			def.entries.append(node)
	return def if r.ok else null
