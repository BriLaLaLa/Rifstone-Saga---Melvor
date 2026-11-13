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
var loot_tables: Array[StringName] = []  # M12: ids of data/combat/loot_tables.json, rolled by every monster of the area
## M17 (V3): the levels the area covers (0 = absent, old format) and its place on the clickable map (x, y in 0..1; presentation only).
var level_min: int = 0
var level_max: int = 0
var map_pos: Vector2 = Vector2(-1.0, -1.0)
## M22 (F-139): the area miniboss (a monster outside the packs, `is_miniboss`) and how many escorts come with it; &"" / 0 when absent.
var miniboss_id: StringName = &""
var miniboss_escorts: int = 0


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
	if d.has("level_min"):
		def.level_min = r.integer("level_min")
		def.level_max = r.integer("level_max")
	if d.get("map_pos") is Array and (d["map_pos"] as Array).size() == 2:
		def.map_pos = Vector2(float((d["map_pos"] as Array)[0]), float((d["map_pos"] as Array)[1]))
	if r.has("loot_tables"):
		def.loot_tables = r.id_list("loot_tables")
	if r.has("miniboss") and r.is_dict("miniboss"):  # M22 (F-139)
		var miniboss := DefReader.new(r.dict("miniboss"), r.context() + " miniboss")
		def.miniboss_id = miniboss.id("monster")
		def.miniboss_escorts = miniboss.integer("escorts")
		r.absorb(miniboss.ok)
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
