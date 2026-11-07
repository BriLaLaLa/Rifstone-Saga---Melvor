class_name LevelModifier
extends RefCounted
## One entry of `level_modifiers` of a skill (docs/04_DATA_SCHEMA.md §4, M10, F-93): the modifier value is
## `per_level` times the level of the skill. `from_dict` returns null (after logging) on a bad field.

var stat: StringName = &""
var per_level: float = 0.0


static func from_dict(d: Dictionary) -> LevelModifier:
	var r := DefReader.new(d, "level modifier")
	var def := LevelModifier.new()
	def.stat = r.id("stat")
	r.set_context("level modifier '%s'" % def.stat)
	def.per_level = r.number("per_level")
	return def if r.ok else null
