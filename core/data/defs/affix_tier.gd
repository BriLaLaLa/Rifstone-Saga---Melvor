class_name AffixTier
extends RefCounted
## A tier of an affix (`tiers` of data/affixes/affixes.json, docs/04_DATA_SCHEMA.md §15): usable from item level
## `min_ilvl`, value rolled in `[min, max]` in steps of `step` (default 1, F-85).
## `from_dict` returns null (after logging, see DefReader) if a field is missing or mistyped.

var min_ilvl: int = 0
var min: float = 0.0
var max: float = 0.0
var step: float = 1.0


static func from_dict(d: Dictionary) -> AffixTier:
	var r := DefReader.new(d, "affix tier")
	var def := AffixTier.new()
	def.min_ilvl = r.integer("min_ilvl")
	def.min = r.number("min")
	def.max = r.number("max")
	if r.has("step"):
		def.step = r.number("step")
	return def if r.ok else null
