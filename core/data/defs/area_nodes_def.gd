class_name AreaNodesDef
extends RefCounted
## The gathering nodes of an area in data/encounters/nodes.json (docs/04_DATA_SCHEMA_M24.md §29.3, M25 §30.1): the highest resource
## level the area gives (F-154), the weighted disciplines (F-153) and their difficulty and minimum level (F-161, already resolved).

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
			if node.difficulty == 0:  # F-161: omitted, the cap of the area
				node.difficulty = def.max_level
			if node.min_level == 0:  # omitted, never skipped for difficulty
				node.min_level = 1
			def.entries.append(node)
	return def if r.ok else null


## F-161: the difficulty `D` of the node of `skill_id` (the cap of the area if the file has no value); 0 if the area has no such node.
func difficulty_of(skill_id: StringName) -> int:
	var entry: NodeEntryDef = _entry(skill_id)
	return entry.difficulty if entry != null else 0


## F-161: the minimum level of the node of `skill_id` (1 if the file has no value); 0 if the area has no such node.
func min_level_of(skill_id: StringName) -> int:
	var entry: NodeEntryDef = _entry(skill_id)
	return entry.min_level if entry != null else 0


## M35B: the resource table of `skill_id` in this area, in order of increasing level; [] if the area has no such node.
func resources_of(skill_id: StringName) -> Array[NodeResourceDef]:
	var entry: NodeEntryDef = _entry(skill_id)
	var result: Array[NodeResourceDef] = []
	if entry != null:
		result.append_array(entry.resources)
	return result


func _entry(skill_id: StringName) -> NodeEntryDef:
	for entry: NodeEntryDef in entries:
		if entry.skill == skill_id:
			return entry
	return null
