class_name LootTableDef
extends RefCounted
## A loot table of data/combat/loot_tables.json (docs/04_DATA_SCHEMA.md §8b, M12): entries rolled like the `drops`
## of a monster (F-32), shared by areas, monsters and Rift Stones through their `loot_tables`.
## `from_dict` returns null (after logging, see DefReader) if a field is missing or mistyped.

var id: StringName = &""
var entries: Array[DropEntry] = []


static func from_dict(d: Dictionary) -> LootTableDef:
	var r := DefReader.new(d, "loot table")
	var def := LootTableDef.new()
	def.id = r.id("id")
	r.set_context("loot table '%s'" % def.id)
	for entry: Dictionary in r.dict_list("entries"):
		var drop: DropEntry = DropEntry.from_dict(entry)
		r.absorb(drop != null)
		if drop != null:
			def.entries.append(drop)
	return def if r.ok else null
