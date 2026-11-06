class_name AbilityDef
extends RefCounted
## An ability of a class (`abilities` of data/classes/<id>.json, docs/04_DATA_SCHEMA.md §14). The fields of the
## file's `params` object are flattened: only those of `kind` are set, the others stay 0/empty.
## `strike`: power_mult; `cleave`: power_mult, targets; `heal`: heal_pct; `buff`: modifiers, duration_ms.
## `from_dict` returns null (after logging, see DefReader) if a field is missing or mistyped.

const KIND_STRIKE: StringName = &"strike"
const KIND_CLEAVE: StringName = &"cleave"
const KIND_HEAL: StringName = &"heal"
const KIND_BUFF: StringName = &"buff"

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
			KIND_CLEAVE:
				def.power_mult = p.number("power_mult")
				def.targets = p.integer("targets")
			KIND_HEAL:
				def.heal_pct = p.number("heal_pct")
			KIND_BUFF:
				def.modifiers = p.modifiers("modifiers")
				def.duration_ms = p.integer("duration_ms")
			_:
				p.fail("unknown kind '%s'" % def.kind)
		r.absorb(p.ok)
	return def if r.ok else null


## True if the ability works with this setup id (empty `setups` = every setup).
func allows_setup(setup_id: StringName) -> bool:
	return setups.is_empty() or setups.has(setup_id)
