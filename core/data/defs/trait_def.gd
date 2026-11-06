class_name TraitDef
extends RefCounted
## A trait of a class (`traits` of data/classes/<id>.json, docs/04_DATA_SCHEMA.md §14). `setups` are the ids of the
## class setups that allow it (empty = all); `modifiers` are the source `trait:<id>`.
## `from_dict` returns null (after logging, see DefReader) if a field is missing or mistyped.

var id: StringName = &""
var name: String = ""
var description: String = ""
var unlock_level: int = 0
var setups: Array[StringName] = []
var effects: Array[TraitEffectDef] = []
var modifiers: Array[Modifier] = []


static func from_dict(d: Dictionary) -> TraitDef:
	var r := DefReader.new(d, "trait")
	var def := TraitDef.new()
	def.id = r.id("id")
	r.set_context("trait '%s'" % def.id)
	def.name = r.text("name")
	def.description = r.text("description")
	def.unlock_level = r.integer("unlock_level")
	def.setups = r.id_list("setups")
	for entry: Dictionary in r.dict_list("effects"):
		var effect: TraitEffectDef = TraitEffectDef.from_dict(entry)
		r.absorb(effect != null)
		if effect != null:
			def.effects.append(effect)
	def.modifiers = r.modifiers("modifiers")
	return def if r.ok else null


## True if the trait works with this setup id (empty `setups` = every setup).
func allows_setup(setup_id: StringName) -> bool:
	return setups.is_empty() or setups.has(setup_id)
