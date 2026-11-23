class_name ToolHead
extends RefCounted
## One head of a unique tool (`equip.heads`, docs/04_DATA_SCHEMA_M35.md §35.1, F-197): `steps[i]` are the modifiers it gives at the
## i-th step of `tool_upgrade.head_steps` (scope `skill:<skill of the tool>`, set by the loader). `from_dict` returns null (after
## logging) on a bad field.

var id: StringName = &""
var name: String = ""
var description: String = ""
var steps: Array[Array] = []  # Array[Array[Modifier]], one list per head step


static func from_dict(d: Dictionary, scope: String) -> ToolHead:
	var r := DefReader.new(d, "tool head")
	var def := ToolHead.new()
	def.id = r.id("id")
	r.set_context("tool head '%s'" % def.id)
	def.name = r.text("name")
	def.description = r.text("description")
	var raw_steps: Variant = d.get("steps")
	if not raw_steps is Array:
		r.fail("'steps' is not a list")
		return null
	for entry: Variant in raw_steps as Array:
		var reader := DefReader.new({"modifiers": entry}, "tool head step")
		var list: Array[Modifier] = reader.modifiers("modifiers", scope, true)
		r.absorb(reader.ok)
		def.steps.append(list)
	return def if r.ok else null
