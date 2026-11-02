class_name MasteryNodeDef
extends RefCounted
## A mastery node of data/mastery/<skill>.json (docs/04_DATA_SCHEMA.md §7). `pos` `[col, row]` becomes Vector2i.
##
## `skill_id` comes from the file's top-level `"skill"`, so the caller passes it as `file_skill_id`; an empty one is
## a conversion error. Modifiers without `scope` get `skill:<skill_id>`, as the schema says.
## `from_dict` returns null (after logging, see DefReader) if a field is missing or mistyped.

var id: StringName = &""
var skill_id: StringName = &""
var name: String = ""
var description: String = ""
var cost_pct: float = 0.0
var requires: Array[StringName] = []
var pos: Vector2i = Vector2i.ZERO
var modifiers: Array[Modifier] = []


static func from_dict(d: Dictionary, file_skill_id: StringName = &"") -> MasteryNodeDef:
	var r := DefReader.new(d, "mastery node")
	var def := MasteryNodeDef.new()
	def.id = r.id("id")
	r.set_context("mastery node '%s'" % def.id)
	def.skill_id = file_skill_id
	def.name = r.text("name")
	def.description = r.text("description")
	def.cost_pct = r.number("cost_pct")
	def.requires = r.id_list("requires")
	def.pos = r.int_pair("pos")
	if file_skill_id == &"":
		r.fail("no skill id given (it comes from the file's 'skill')")
	else:
		var default_scope: String = "%s%s%s" % [Modifier.SCOPE_SKILL, Modifier.SCOPE_SEPARATOR, file_skill_id]
		def.modifiers = r.modifiers("modifiers", default_scope)
	return def if r.ok else null
