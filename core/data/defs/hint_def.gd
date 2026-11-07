class_name HintDef
extends RefCounted
## An entry of data/hints/hints.json (docs/04_DATA_SCHEMA.md §10). `trigger` is one of
## DataValidatorHints.TRIGGERS (checked by the validator). `from_dict` returns null (after logging, see DefReader)
## if a field is missing or mistyped.

var id: StringName = &""
var title: String = ""
var text: String = ""
var trigger: StringName = &""


static func from_dict(d: Dictionary) -> HintDef:
	var r := DefReader.new(d, "hint")
	var def := HintDef.new()
	def.id = r.id("id")
	r.set_context("hint '%s'" % def.id)
	def.title = r.text("title")
	def.text = r.text("text")
	def.trigger = r.id("trigger")
	return def if r.ok else null
