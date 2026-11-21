class_name TrainerDef
extends RefCounted
## The Trainer of a discipline, from data/disciplines/trainers.json `trainers` (docs/04_DATA_SCHEMA_M24.md §29.2).
## `fed_by` lists the gathering disciplines that feed an artisan one (presentation only). `from_dict` returns null on a bad field.

var skill: StringName = &""
var name: String = ""
var title: String = ""
var description: String = ""
var fed_by: Array[StringName] = []
var vendor: StringName = &""  # M26 (docs/04_DATA_SCHEMA_M26.md §31.5): the shop stall of the profession; &"" if none
var free_slot: bool = false  # M32: always learnable, does not count in the slots of its category


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
	if r.has("vendor"):
		def.vendor = r.id("vendor")
	if r.has("free_slot"):
		def.free_slot = r.flag("free_slot")
	return def if r.ok else null
