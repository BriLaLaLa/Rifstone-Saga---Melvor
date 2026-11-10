class_name RiftStoneDef
extends RefCounted
## A Rift Stone of data/combat/rift_stones.json (docs/04_DATA_SCHEMA.md §22, F-87, M15): one stone per (area, `level`),
## the level a multiple of 5 (Z2). The hp comes from F-125 (`StoneFight.max_hp`), the pulse from `metin.pulse_damage`:
## neither is in the data. `wave_packs` are indices into the `packs` of the area (empty = all the packs). `shards` becomes
## `shards_min`/`shards_max`. `to_monster` gives the stats-bearing MonsterDef of the stone (it does not attack: the
## engine runs its pulse).
## `from_dict` returns null (after logging, see DefReader) if a field is missing or mistyped.

var id: StringName = &""
var name: String = ""
var description: String = ""
var icon: String = ""
var area_id: StringName = &""
var level: int = 0
var xp: int = 0
var pulse_ms: int = 0
var wave_packs: Array[int] = []
var shards_min: int = 0
var shards_max: int = 0
var drops: Array[DropEntry] = []
var loot_tables: Array[StringName] = []  # M12: ids of data/combat/loot_tables.json, rolled after the drops


static func from_dict(d: Dictionary) -> RiftStoneDef:
	var r := DefReader.new(d, "rift stone")
	var def := RiftStoneDef.new()
	def.id = r.id("id")
	r.set_context("rift stone '%s'" % def.id)
	def.name = r.text("name")
	def.description = r.text("description")
	def.icon = r.text("icon")
	def.area_id = r.id("area")
	def.level = r.integer("level")
	def.xp = r.integer("xp")
	def.pulse_ms = r.integer("pulse_ms")
	if not r.has("wave_packs"):
		r.fail("missing field 'wave_packs'")
	elif d["wave_packs"] != null:
		if not d["wave_packs"] is Array:
			r.fail("field 'wave_packs' must be null or an array of integers")
		else:
			for index: Variant in (d["wave_packs"] as Array):
				if index is int or (index is float and float(index) == floorf(float(index))):
					def.wave_packs.append(int(index))
				else:
					r.fail("field 'wave_packs' must hold integers, got %s" % JSON.stringify(index))
	var shards: Vector2i = r.int_pair("shards")
	def.shards_min = shards.x
	def.shards_max = shards.y
	if r.has("loot_tables"):
		def.loot_tables = r.id_list("loot_tables")
	for entry: Dictionary in r.dict_list("drops"):
		var drop: DropEntry = DropEntry.from_dict(entry)
		r.absorb(drop != null)
		if drop != null:
			def.drops.append(drop)
	return def if r.ok else null


## The stone as a monster for the combat stats: levels 1, no bonuses, no reduction, attack interval = the pulse.
## `style` is the one given (the neutral style, see `KillRewards`/`RiftStone`), `max_hp` is F-125, gold 0, no drops of its own.
func to_monster(style: StringName, max_hp: int) -> MonsterDef:
	var m := MonsterDef.new()
	m.id = id
	m.name = name
	m.description = description
	m.icon = icon
	m.hp = max_hp
	m.xp = xp
	m.style = style
	m.attack_interval_ms = pulse_ms
	m.attack_level = 1
	m.power_level = 1
	m.defence_level = 1
	return m
