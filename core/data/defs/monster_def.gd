class_name MonsterDef
extends RefCounted
## A monster of data/combat/monsters.json (docs/04_DATA_SCHEMA.md §8). `gold` `[min, max]` becomes
## `gold_min`/`gold_max`; every field is required except `sprite`.
## `from_dict` returns null (after logging, see DefReader) if a field is missing or mistyped.

var id: StringName = &""
var name: String = ""
var description: String = ""
var icon: String = ""
var sprite: Dictionary = {}  # reserved (M6-00a): {idle, attack, hit, death}, optional, no use yet
var hp: int = 0
var xp: int = 0
var style: StringName = &""
var attack_interval_ms: int = 0
var attack_level: int = 0
var power_level: int = 0
var defence_level: int = 0
var accuracy_bonus: int = 0
var power_bonus: int = 0
var evasion_bonus: int = 0
var damage_reduction: float = 0.0
var gold_min: int = 0
var gold_max: int = 0
var rift_shard_chance: float = 0.0
var drops: Array[DropEntry] = []
var loot_tables: Array[StringName] = []  # M12: ids of data/combat/loot_tables.json, rolled after the drops
var is_miniboss: bool = false  # M22 (F-139): the area miniboss, never in a pack
var dungeon: StringName = &""  # M22: the dungeon this monster belongs to (set by DungeonDef); &"" for the monsters of the areas


static func from_dict(d: Dictionary) -> MonsterDef:
	return read_into(MonsterDef.new(), d, "monster")


## Fills `def` (a MonsterDef or a subclass such as BossDef) from `d`; `kind` names it in the messages.
static func read_into(def: MonsterDef, d: Dictionary, kind: String) -> MonsterDef:
	var r := DefReader.new(d, kind)
	def.id = r.id("id")
	r.set_context("%s '%s'" % [kind, def.id])
	def.name = r.text("name")
	def.description = r.text("description")
	def.icon = r.text("icon")
	def.sprite = d["sprite"] as Dictionary if d.get("sprite") is Dictionary else {}
	def.hp = r.integer("hp")
	def.xp = r.integer("xp")
	def.style = r.id("style")
	def.attack_interval_ms = r.integer("attack_interval_ms")
	def.attack_level = r.integer("attack_level")
	def.power_level = r.integer("power_level")
	def.defence_level = r.integer("defence_level")
	def.accuracy_bonus = r.integer("accuracy_bonus")
	def.power_bonus = r.integer("power_bonus")
	def.evasion_bonus = r.integer("evasion_bonus")
	def.damage_reduction = r.number("damage_reduction")
	var gold: Vector2i = r.int_pair("gold")
	def.gold_min = gold.x
	def.gold_max = gold.y
	def.rift_shard_chance = r.number("rift_shard_chance")
	if r.has("loot_tables"):
		def.loot_tables = r.id_list("loot_tables")
	if r.has("miniboss"):
		def.is_miniboss = r.flag("miniboss")
	for entry: Dictionary in r.dict_list("drops"):
		var drop: DropEntry = DropEntry.from_dict(entry)
		r.absorb(drop != null)
		if drop != null:
			def.drops.append(drop)
	return def if r.ok else null
