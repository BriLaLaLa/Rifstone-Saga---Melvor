class_name ToolExtra
extends RefCounted
## One entry of `equip.upgrade_extras` of a unique tool (docs/04_DATA_SCHEMA.md §5, M10): the modifiers that apply from
## refinement step `at` on (cumulative, F-94). `from_dict` returns null (after logging) on a bad field.

var at: int = 0
var modifiers: Array[Modifier] = []


static func from_dict(d: Dictionary) -> ToolExtra:
	var r := DefReader.new(d, "tool extra")
	var def := ToolExtra.new()
	def.at = r.integer("at")
	r.set_context("tool extra at %d" % def.at)
	def.modifiers = r.modifiers("modifiers")
	return def if r.ok else null
