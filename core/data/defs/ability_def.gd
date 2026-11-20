class_name AbilityDef
extends RefCounted
## An ability of a class (`abilities` of data/classes/<id>.json, docs/04_DATA_SCHEMA.md §14, M28: §33.3). The fields of the
## file's `params` object are flattened: only those of `kind` are set, the others stay 0/empty/neutral.
## `strike`: power_mult; `cleave`: power_mult, targets; `heal`: heal_pct; `buff`: modifiers, duration_ms; `ward` (M28): ward_pct,
## duration_ms. M28 optional params: `hits` and `target` (strike only), `execute`, `apply`, `drain_pct` (strike and cleave); absent =
## the neutral default (one hit, the rule of the traits, no execute, no condition, no drain).
## `from_dict` returns null (after logging, see DefReader) if a field is missing or mistyped.

const KIND_STRIKE: StringName = &"strike"
const KIND_CLEAVE: StringName = &"cleave"
const KIND_HEAL: StringName = &"heal"
const KIND_BUFF: StringName = &"buff"
const KIND_WARD: StringName = &"ward"

var id: StringName = &""
var name: String = ""
var description: String = ""
var unlock_level: int = 0
var setups: Array[StringName] = []
var kind: StringName = &""
var cooldown_ms: int = 0
var power_mult: float = 0.0
var targets: int = 0
var heal_pct: float = 0.0
var modifiers: Array[Modifier] = []
var duration_ms: int = 0
var hits: int = 1
var target_rule: StringName = &""  # &"" = the rule of the traits (F-76)
var execute_hp_pct: float = 0.0  # no execute: 0 and 1
var execute_mult: float = 1.0
var applies: Array[ConditionApply] = []
var drain_pct: float = 0.0
var ward_pct: float = 0.0


static func from_dict(d: Dictionary) -> AbilityDef:
	var r := DefReader.new(d, "ability")
	var def := AbilityDef.new()
	def.id = r.id("id")
	r.set_context("ability '%s'" % def.id)
	def.name = r.text("name")
	def.description = r.text("description")
	def.unlock_level = r.integer("unlock_level")
	def.setups = r.id_list("setups")
	def.kind = r.id("kind")
	def.cooldown_ms = r.integer("cooldown_ms")
	if r.is_dict("params"):
		var p := DefReader.new(r.dict("params"), r.context() + " params")
		match def.kind:
			KIND_STRIKE:
				def.power_mult = p.number("power_mult")
				if p.has("hits"):
					def.hits = p.integer("hits")
				if p.has("target"):
					def.target_rule = p.id("target")
				_read_extras(def, p)
			KIND_CLEAVE:
				def.power_mult = p.number("power_mult")
				def.targets = p.integer("targets")
				_read_extras(def, p)
			KIND_HEAL:
				def.heal_pct = p.number("heal_pct")
			KIND_BUFF:
				def.modifiers = p.modifiers("modifiers")
				def.duration_ms = p.integer("duration_ms")
			KIND_WARD:
				def.ward_pct = p.number("ward_pct")
				def.duration_ms = p.integer("duration_ms")
			_:
				p.fail("unknown kind '%s'" % def.kind)
		r.absorb(p.ok)
	return def if r.ok else null


# `execute`, `apply` and `drain_pct` of strike and cleave.
static func _read_extras(def: AbilityDef, p: DefReader) -> void:
	if p.has("execute") and p.is_dict("execute"):
		var e := DefReader.new(p.dict("execute"), p.context() + " execute")
		def.execute_hp_pct = e.number("hp_pct")
		def.execute_mult = e.number("mult")
		p.absorb(e.ok)
	if p.has("apply"):
		for entry: Dictionary in p.dict_list("apply"):
			var app: ConditionApply = ConditionApply.from_dict(entry)
			if app == null:
				p.absorb(false)
			else:
				def.applies.append(app)
	if p.has("drain_pct"):
		def.drain_pct = p.number("drain_pct")


## True if the ability works with this setup id (empty `setups` = every setup).
func allows_setup(setup_id: StringName) -> bool:
	return setups.is_empty() or setups.has(setup_id)
