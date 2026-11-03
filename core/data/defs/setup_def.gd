class_name SetupDef
extends RefCounted
## A weapon setup of a class (`setups` of data/classes/<id>.json, docs/04_DATA_SCHEMA.md §14): the pair of
## `equip.kind` values it matches (`offhand` "" = empty offhand) and its modifiers (source `setup:<id>`, F-72).
## `weapon` becomes `weapon_kind`, `offhand` becomes `offhand_kind`; `alternate` defaults to false.
## `from_dict` returns null (after logging, see DefReader) if a field is missing or mistyped.

var id: StringName = &""
var name: String = ""
var weapon_kind: StringName = &""
var offhand_kind: StringName = &""
var alternate: bool = false
var modifiers: Array[Modifier] = []


static func from_dict(d: Dictionary) -> SetupDef:
	var r := DefReader.new(d, "setup")
	var def := SetupDef.new()
	def.id = r.id("id")
	r.set_context("setup '%s'" % def.id)
	def.name = r.text("name")
	def.weapon_kind = r.id("weapon")
	def.offhand_kind = r.id("offhand")
	if r.has("alternate"):
		def.alternate = r.flag("alternate")
	def.modifiers = r.modifiers("modifiers")
	return def if r.ok else null
