class_name MilestoneDef
extends RefCounted
## One mastery milestone of a gathering action (`milestones` in data/actions/<skill>.json, docs/04_DATA_SCHEMA.md §6,
## F-103, F-108): `byproduct` (item), `resource` (modifiers, default scope `action:<id>`) or `trade` (modifiers, default
## scope `skill:<skill>`). `from_dict` returns null (after logging, see DefReader) if a field is missing or mistyped.

const TYPE_BYPRODUCT: StringName = &"byproduct"
const TYPE_RESOURCE: StringName = &"resource"
const TYPE_TRADE: StringName = &"trade"

var at: int = 0
var type: StringName = &""
var item: StringName = &""
var modifiers: Array[Modifier] = []


static func from_dict(d: Dictionary, action_id: StringName, skill_id: StringName) -> MilestoneDef:
	var r := DefReader.new(d, "milestone of action '%s'" % action_id)
	var def := MilestoneDef.new()
	def.at = r.integer("at")
	def.type = r.id("type")
	if def.type == TYPE_BYPRODUCT:
		def.item = r.id("item")
	elif def.type == TYPE_RESOURCE:
		def.modifiers = r.modifiers("modifiers", "action:%s" % action_id)
	elif def.type == TYPE_TRADE:
		def.modifiers = r.modifiers("modifiers", "skill:%s" % skill_id)
	else:
		r.fail("unknown type '%s'" % def.type)
	return def if r.ok else null
