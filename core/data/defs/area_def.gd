class_name AreaDef
extends RefCounted
## A combat area of data/combat/areas.json (docs/04_DATA_SCHEMA.md §8). `monster_ids` (the distinct monsters of the
## packs, in order of first appearance) is computed here. `requirements` uses the key `character` (character level).
## `from_dict` returns null (after logging, see DefReader) if a field is missing or mistyped.

var id: StringName = &""
var name: String = ""
var description: String = ""
var order: int = 0
var requirements: Dictionary[StringName, int] = {}
## Optional `rift_stone_chance_pct` (F-87, Q46): negative = absent, the global `rift_stone.chance_pct` applies.
var rift_stone_chance_pct: float = -1.0
var packs: Array[PackDef] = []
var monster_ids: Array[StringName] = []


static func from_dict(d: Dictionary) -> AreaDef:
	var r := DefReader.new(d, "area")
	var def := AreaDef.new()
	def.id = r.id("id")
	r.set_context("area '%s'" % def.id)
	def.name = r.text("name")
	def.description = r.text("description")
	def.order = r.integer("order")
	def.requirements = r.level_map("requirements")
	if r.has("rift_stone_chance_pct"):
		def.rift_stone_chance_pct = r.number("rift_stone_chance_pct")
	for entry: Dictionary in r.dict_list("packs"):
		var pack: PackDef = PackDef.from_dict(entry)
		r.absorb(pack != null)
		if pack == null:
			continue
		def.packs.append(pack)
		for monster_id: StringName in pack.monster_ids:
			if not def.monster_ids.has(monster_id):
				def.monster_ids.append(monster_id)
	return def if r.ok else null
