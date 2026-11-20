class_name ConditionApply
extends RefCounted
## The application of a condition to an enemy: one entry of the `apply` list of an ability or the parameters of `apply_on_hit`
## (docs/04_DATA_SCHEMA_M28.md §33.2, docs/02_FORMULAS_M28.md F-185). `pct` is 0 for a Stagger (it has none). `from_dict` returns
## null (after logging, see DefReader) if a field is missing or mistyped or the condition is unknown; ranges are the validator's job.

const BLEED: StringName = &"bleed"
const WEAKEN: StringName = &"weaken"
const EXPOSE: StringName = &"expose"
const STAGGER: StringName = &"stagger"
const ALL: Array[StringName] = [BLEED, WEAKEN, EXPOSE, STAGGER]

var condition: StringName = &""
var pct: float = 0.0
var ms: int = 0


static func from_dict(d: Dictionary) -> ConditionApply:
	var r := DefReader.new(d, "condition apply")
	var app := ConditionApply.new()
	app.condition = r.id("condition")
	if r.ok and not ALL.has(app.condition):
		r.fail("unknown condition '%s'" % app.condition)
	if app.condition != STAGGER:
		app.pct = r.number("pct")
	app.ms = r.integer("ms")
	return app if r.ok else null
