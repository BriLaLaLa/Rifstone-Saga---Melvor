class_name ClassDef
extends RefCounted
## A character class of data/classes/<id>.json (docs/04_DATA_SCHEMA.md §14).
## `traits` and `abilities` (TraitDef, AbilityDef) are added by M6: in M4 the file lists are empty and not read.
## `from_dict` returns null (after logging, see DefReader) if a field is missing or mistyped.

var id: StringName = &""
var name: String = ""
var description: String = ""
var icon: String = ""
var order: int = 0
var weapon_kinds: Array[StringName] = []
var offhand_kinds: Array[StringName] = []
var setups: Array[SetupDef] = []


static func from_dict(d: Dictionary) -> ClassDef:
	var r := DefReader.new(d, "class")
	var def := ClassDef.new()
	def.id = r.id("id")
	r.set_context("class '%s'" % def.id)
	def.name = r.text("name")
	def.description = r.text("description")
	def.icon = r.text("icon")
	def.order = r.integer("order")
	def.weapon_kinds = r.id_list("weapon_kinds")
	def.offhand_kinds = r.id_list("offhand_kinds")
	for entry: Dictionary in r.dict_list("setups"):
		var setup: SetupDef = SetupDef.from_dict(entry)
		r.absorb(setup != null)
		if setup != null:
			def.setups.append(setup)
	return def if r.ok else null


## F-72: the first setup (file order) with this weapon kind and offhand kind (&"" = empty offhand); null if none.
func setup_for(weapon_kind: StringName, offhand_kind: StringName) -> SetupDef:
	for setup: SetupDef in setups:
		if setup.weapon_kind == weapon_kind and setup.offhand_kind == offhand_kind:
			return setup
	return null
