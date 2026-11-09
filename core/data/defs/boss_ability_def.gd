class_name BossAbilityDef
extends RefCounted
## The single ability of a boss (docs/04_DATA_SCHEMA.md §11.3, F-112): `heavy_strike`, `shield` or `summon`. Only the
## fields of its type are filled (the others keep their neutral defaults).
## `from_dict` returns null (after logging, see DefReader) if a field is missing or mistyped.

const HEAVY_STRIKE: StringName = &"heavy_strike"
const SHIELD: StringName = &"shield"
const SUMMON: StringName = &"summon"

var type: StringName = &""
var every_ms: int = 0
var mult: float = 0.0  # heavy_strike
var duration_ms: int = 0  # shield
var shield_pct: int = 0  # shield
var count: int = 0  # summon
var max_alive: int = 0  # summon
var monsters: Array[StringName] = []  # summon


static func from_dict(d: Dictionary) -> BossAbilityDef:
	var r := DefReader.new(d, "boss ability")
	var def := BossAbilityDef.new()
	def.type = r.id("type")
	r.set_context("boss ability '%s'" % def.type)
	def.every_ms = r.integer("every_ms")
	match def.type:
		HEAVY_STRIKE:
			def.mult = r.number("mult")
		SHIELD:
			def.duration_ms = r.integer("duration_ms")
			def.shield_pct = r.integer("shield_pct")
		SUMMON:
			def.count = r.integer("count")
			def.max_alive = r.integer("max_alive")
			def.monsters = r.id_list("monsters")
		_:
			r.fail("unknown type")
	return def if r.ok else null
