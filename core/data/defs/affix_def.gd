class_name AffixDef
extends RefCounted
## An affix of data/affixes/affixes.json (docs/04_DATA_SCHEMA.md §15): a stat that magic and rare pieces can roll
## on the listed slots, with tiers by item level and a weight for the draw (F-85).
## `from_dict` returns null (after logging, see DefReader) if a field is missing or mistyped.

var id: StringName = &""
var name: String = ""
var stat: StringName = &""
var slots: Array[StringName] = []
var weight: int = 0
var tiers: Array[AffixTier] = []


static func from_dict(d: Dictionary) -> AffixDef:
	var r := DefReader.new(d, "affix")
	var def := AffixDef.new()
	def.id = r.id("id")
	r.set_context("affix '%s'" % def.id)
	def.name = r.text("name")
	def.stat = r.id("stat")
	def.slots = r.id_list("slots")
	def.weight = r.integer("weight")
	for entry: Dictionary in r.dict_list("tiers"):
		var tier: AffixTier = AffixTier.from_dict(entry)
		r.absorb(tier != null)
		if tier != null:
			def.tiers.append(tier)
	return def if r.ok else null
