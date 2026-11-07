class_name BlueprintInfo
extends RefCounted
## The `blueprint` object of a `blueprint` item (docs/04_DATA_SCHEMA.md §5, M10): the equipment base it crafts, its
## grade, the component/material inputs and the rare component. All fields are required.
## `from_dict` returns null (after logging, see DefReader) if a field is missing or mistyped.

var base_id: StringName = &""
var grade: int = 0
var inputs: Array[ItemQty] = []
var rare_component: ItemQty = null


static func from_dict(d: Dictionary) -> BlueprintInfo:
	var r := DefReader.new(d, "blueprint")
	var def := BlueprintInfo.new()
	def.base_id = r.id("base")
	r.set_context("blueprint '%s'" % def.base_id)
	def.grade = r.integer("grade")
	for entry: Dictionary in r.dict_list("inputs"):
		var item: ItemQty = ItemQty.from_dict(entry)
		r.absorb(item != null)
		if item != null:
			def.inputs.append(item)
	if r.is_dict("rare_component"):
		def.rare_component = ItemQty.from_dict(r.dict("rare_component"))
		r.absorb(def.rare_component != null)
	return def if r.ok else null
