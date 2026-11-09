class_name BlueprintInfo
extends RefCounted
## The `blueprint` object of a `blueprint` item (docs/04_DATA_SCHEMA.md §5, §21): the equipment base it crafts, its
## grade (M14: the grade of the material, F-119), the component/material inputs and the rare components.
## M14: `rare_components` are two different `{item, qty}` (Q68). TRANSITIONAL until M14-05: the legacy `rare_component`
## (a single entry, old blueprints) is accepted and becomes the only element of `rare_components`; `rare_component`
## keeps pointing at it (null with the new form).
## `from_dict` returns null (after logging, see DefReader) if a field is missing or mistyped.

var base_id: StringName = &""
var grade: int = 0
var inputs: Array[ItemQty] = []
var rare_components: Array[ItemQty] = []
var rare_component: ItemQty = null  # TRANSITIONAL (M14-05 removes it)


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
	if r.has("rare_components"):
		for entry: Dictionary in r.dict_list("rare_components"):
			var rare: ItemQty = ItemQty.from_dict(entry)
			r.absorb(rare != null)
			if rare != null:
				def.rare_components.append(rare)
	elif r.is_dict("rare_component"):
		def.rare_component = ItemQty.from_dict(r.dict("rare_component"))
		r.absorb(def.rare_component != null)
		if def.rare_component != null:
			def.rare_components.append(def.rare_component)
	return def if r.ok else null
