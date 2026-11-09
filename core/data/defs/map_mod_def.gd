class_name MapModDef
extends RefCounted
## A Card modifier of data/maps/map_mods.json (docs/04_DATA_SCHEMA.md §11.2): a risk and a reward with the same intensity.
## `from_dict` returns null (after logging, see DefReader) if a field is missing or mistyped.

var id: StringName = &""
var name: String = ""
var description: String = ""
var min_grade: int = 1
var weight: int = 1
var risk: MapEffectDef = null
var reward: MapEffectDef = null


static func from_dict(d: Dictionary) -> MapModDef:
	var r := DefReader.new(d, "map mod")
	var def := MapModDef.new()
	def.id = r.id("id")
	r.set_context("map mod '%s'" % def.id)
	def.name = r.text("name")
	def.description = r.text("description")
	def.min_grade = r.integer("min_grade")
	def.weight = r.integer("weight")
	if r.is_dict("risk"):
		def.risk = MapEffectDef.from_dict(r.dict("risk"))
		r.absorb(def.risk != null)
	if r.is_dict("reward"):
		def.reward = MapEffectDef.from_dict(r.dict("reward"))
		r.absorb(def.reward != null)
	if def.risk == null or def.reward == null:
		r.fail("needs a risk and a reward")
	return def if r.ok else null
