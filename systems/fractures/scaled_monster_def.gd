class_name ScaledMonsterDef
extends MonsterDef
## A monster as it appears in a Fracture (F-110, F-111): a MonsterDef copy with the levels, hp, xp and gold already
## scaled, plus the multipliers that act on the derived combat numbers (`CombatantStats.for_monster` reads them).
## `is_boss` marks a boss (it is not a monster of the data: no kill counter).

var damage_mult: float = 1.0  # F-110: min and max hit x this (floor, minimum 1)
var risk_damage_pct: float = 0.0  # F-111 `monster_damage_pct`: min and max hit x (1 + v/100) (floor, minimum 1)
var risk_speed_pct: float = 0.0  # F-111 `monster_speed_pct`: attack interval = F-26 with pct = -v
var risk_defence_pct: float = 0.0  # F-111 `monster_defence_pct`: evasion x (1 + v/100) (round)
var is_boss: bool = false


## A copy of `source` (every MonsterDef field; the lists are copied, the drop entries are shared: they are read-only).
static func copy_of(source: MonsterDef) -> ScaledMonsterDef:
	var def := ScaledMonsterDef.new()
	def.id = source.id
	def.name = source.name
	def.description = source.description
	def.icon = source.icon
	def.sprite = source.sprite
	def.hp = source.hp
	def.xp = source.xp
	def.style = source.style
	def.attack_interval_ms = source.attack_interval_ms
	def.attack_level = source.attack_level
	def.power_level = source.power_level
	def.defence_level = source.defence_level
	def.accuracy_bonus = source.accuracy_bonus
	def.power_bonus = source.power_bonus
	def.evasion_bonus = source.evasion_bonus
	def.damage_reduction = source.damage_reduction
	def.gold_min = source.gold_min
	def.gold_max = source.gold_max
	def.rift_shard_chance = source.rift_shard_chance
	def.drops = source.drops.duplicate()
	def.loot_tables = source.loot_tables.duplicate()
	return def
