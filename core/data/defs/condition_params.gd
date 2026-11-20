class_name ConditionParams
extends RefCounted
## The `combat.conditions` section of balance.json (docs/04_DATA_SCHEMA_M28.md §33.1, docs/02_FORMULAS_M28.md F-186, F-188).
## `from_dict` returns null (after logging, see DefReader) if a key is missing or mistyped; ranges are the validator's job.

var tick_ms: int = 1000  # the Bleed clock (F-186)
var stagger_immunity_ms: int = 4000  # immunity after a Stagger (F-188)


static func from_dict(d: Dictionary) -> ConditionParams:
	var r := DefReader.new(d, "balance combat.conditions")
	var p := ConditionParams.new()
	p.tick_ms = r.integer("tick_ms")
	p.stagger_immunity_ms = r.integer("stagger_immunity_ms")
	return p if r.ok else null
