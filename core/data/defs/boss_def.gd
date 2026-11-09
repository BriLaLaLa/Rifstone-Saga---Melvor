class_name BossDef
extends MonsterDef
## A Fracture boss of data/maps/bosses.json (docs/04_DATA_SCHEMA.md §11.3): a MonsterDef (so the combat engine treats it
## as an enemy) with its `grade`, its single `ability` (F-112) and the guaranteed Rift Dust range `rewards.dust` (F-115).
## `from_dict` returns null (after logging, see DefReader) if a field is missing or mistyped.

var grade: int = 0
var ability: BossAbilityDef = null
var dust_min: int = 0
var dust_max: int = 0


static func from_dict(d: Dictionary) -> BossDef:
	var def := BossDef.new()
	var base: MonsterDef = MonsterDef.read_into(def, d, "boss")
	var r := DefReader.new(d, "boss '%s'" % def.id)
	r.absorb(base != null)
	def.grade = r.integer("grade")
	if r.is_dict("ability"):
		def.ability = BossAbilityDef.from_dict(r.dict("ability"))
		r.absorb(def.ability != null)
	else:
		r.fail("missing field 'ability'")
	if r.is_dict("rewards"):
		var rewards := DefReader.new(r.dict("rewards"), r.context() + " rewards")
		var dust: Vector2i = rewards.int_pair("dust")
		def.dust_min = dust.x
		def.dust_max = dust.y
		r.absorb(rewards.ok)
	else:
		r.fail("missing field 'rewards'")
	return def if r.ok else null
