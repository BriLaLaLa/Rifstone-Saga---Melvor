class_name GuidePageDef
extends RefCounted
## A hand-written page of the Guide, from data/guide/*.json (docs/04_DATA_SCHEMA.md §19). `blocks` keep the file's
## shape (type, text, source, targets). `from_dict` returns null (after logging, see DefReader) if a field is missing
## or mistyped; `help_for` and `allow_digits` are optional.

var id: StringName = &""
var section: StringName = &""
var title: String = ""
var order: int = 0
var blocks: Array[Dictionary] = []
var help_for: PackedStringArray = []
var allow_digits: bool = false


static func from_dict(d: Dictionary) -> GuidePageDef:
	var r := DefReader.new(d, "guide page")
	var def := GuidePageDef.new()
	def.id = r.id("id")
	r.set_context("guide page '%s'" % def.id)
	def.section = r.id("section")
	def.title = r.text("title")
	def.order = r.integer("order")
	for block: Dictionary in r.dict_list("blocks"):
		def.blocks.append(block.duplicate(true))
	if d.has("help_for"):
		for route: StringName in r.id_list("help_for"):
			def.help_for.append(String(route))
	if d.has("allow_digits"):
		def.allow_digits = r.flag("allow_digits")
	return def if r.ok else null
