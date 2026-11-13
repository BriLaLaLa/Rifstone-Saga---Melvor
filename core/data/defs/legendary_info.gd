class_name LegendaryInfo
extends RefCounted
## The `equip.legendary` object of a legendary base (docs/04_DATA_SCHEMA.md §21, F-120): where it drops and its effects.
## `source_type` is &"boss", &"monolith" or &"dungeon". `from_dict` returns null (after logging, see DefReader) on a bad field.

const SOURCE_BOSS: StringName = &"boss"
const SOURCE_MONOLITH: StringName = &"monolith"
const SOURCE_DUNGEON: StringName = &"dungeon"  # M22 (F-143)

var source_type: StringName = &""
var source_id: StringName = &""
var chance_pct: float = 0.0
var effects: Array[ItemEffectDef] = []


static func from_dict(d: Dictionary) -> LegendaryInfo:
	var r := DefReader.new(d, "legendary")
	var def := LegendaryInfo.new()
	if r.is_dict("source"):
		var source := DefReader.new(r.dict("source"), "legendary source")
		def.source_type = source.id("type")
		def.source_id = source.id("id")
		def.chance_pct = source.number("chance_pct")
		r.absorb(source.ok)
	for entry: Dictionary in r.dict_list("effects"):
		var effect: ItemEffectDef = ItemEffectDef.from_dict(entry)
		r.absorb(effect != null)
		if effect != null:
			def.effects.append(effect)
	return def if r.ok else null
