class_name TrainerDef
extends RefCounted
## The Trainer of a discipline, from data/disciplines/trainers.json `trainers` (docs/04_DATA_SCHEMA_M24.md §29.2).
## `fed_by` lists the gathering disciplines that feed an artisan one (presentation only). `from_dict` returns null on a bad field.

var skill: StringName = &""
var name: String = ""
var title: String = ""
var description: String = ""
var fed_by: Array[StringName] = []


static func from_dict(d: Dictionary) -> TrainerDef:
	var r := DefReader.new(d, "trainer")
	var def := TrainerDef.new()
	def.skill = r.id("skill")
	r.set_context("trainer '%s'" % def.skill)
	def.name = r.text("name")
	def.title = r.text("title")
	def.description = r.text("description")
	if r.has("fed_by"):
		def.fed_by = r.id_list("fed_by")
	return def if r.ok else null
