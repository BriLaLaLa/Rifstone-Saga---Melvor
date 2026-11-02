class_name AreaDef
extends RefCounted
## A combat area of data/combat/areas.json (docs/04_DATA_SCHEMA.md §8). `monsters` becomes `monster_ids`.
## `from_dict` returns null (after logging, see DefReader) if a field is missing or mistyped.

var id: StringName = &""
var name: String = ""
var description: String = ""
var order: int = 0
var requirements: Dictionary[StringName, int] = {}
var monster_ids: Array[StringName] = []


static func from_dict(d: Dictionary) -> AreaDef:
	var r := DefReader.new(d, "area")
	var def := AreaDef.new()
	def.id = r.id("id")
	r.set_context("area '%s'" % def.id)
	def.name = r.text("name")
	def.description = r.text("description")
	def.order = r.integer("order")
	def.requirements = r.level_map("requirements")
	def.monster_ids = r.id_list("monsters")
	return def if r.ok else null
