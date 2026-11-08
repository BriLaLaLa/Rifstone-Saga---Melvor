class_name RiftStoneDef
extends RefCounted
## A Rift Stone of data/combat/rift_stones.json (docs/04_DATA_SCHEMA.md §16, F-87): the special encounter of an area.
## `summon_pack` is an index into the `packs` of the area, -1 when the stone summons nobody. `shards` becomes
## `shards_min`/`shards_max`. `to_monster` gives the stats-bearing MonsterDef of the stone (it does not attack: the
## engine runs its pulse).
## `from_dict` returns null (after logging, see DefReader) if a field is missing or mistyped.

var id: StringName = &""
var name: String = ""
var description: String = ""
var icon: String = ""
var area_id: StringName = &""
var hp: int = 0
var xp: int = 0
var pulse_damage: int = 0
var pulse_ms: int = 0
var summon_pack: int = -1
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
	def.hp = r.integer("hp")
	def.xp = r.integer("xp")
	def.pulse_damage = r.integer("pulse_damage")
	def.pulse_ms = r.integer("pulse_ms")
	if r.has("summon_pack") and d["summon_pack"] != null:
		def.summon_pack = r.integer("summon_pack")
	elif not r.has("summon_pack"):
		r.fail("missing field 'summon_pack'")
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
## `style` is the one given (the neutral style, see `KillRewards`/`RiftStone`), gold 0, no drops of its own.
func to_monster(style: StringName) -> MonsterDef:
	var m := MonsterDef.new()
	m.id = id
	m.name = name
	m.description = description
	m.icon = icon
	m.hp = hp
	m.xp = xp
	m.style = style
	m.attack_interval_ms = pulse_ms
	m.attack_level = 1
	m.power_level = 1
	m.defence_level = 1
	return m
