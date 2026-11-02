class_name ItemDef
extends RefCounted
## An item of data/items/*.json (docs/04_DATA_SCHEMA.md §5).
##
## Common fields are required. The optional sub-objects map to: `equip` -> `equip` (null when absent),
## `food.heal` -> `food_heal` (0 when there is no `food`), `infusion.modifiers`/`infusion.unique` ->
## `infusion_modifiers`/`infusion_unique` (empty/false when there is no `infusion`; `unique` defaults to false as in
## the schema). Whether the sub-objects match the category is DataValidator's job (M1-04).
## `from_dict` returns null (after logging, see DefReader) if a field is missing or mistyped.

var id: StringName = &""
var name: String = ""
var description: String = ""
var category: StringName = &""
var icon: String = ""
var value: int = 0
var sort_order: int = 0
var equip: EquipInfo = null
var food_heal: int = 0
var infusion_modifiers: Array[Modifier] = []
var infusion_unique: bool = false


static func from_dict(d: Dictionary) -> ItemDef:
	var r := DefReader.new(d, "item")
	var def := ItemDef.new()
	def.id = r.id("id")
	r.set_context("item '%s'" % def.id)
	def.name = r.text("name")
	def.description = r.text("description")
	def.category = r.id("category")
	def.icon = r.text("icon")
	def.value = r.integer("value")
	def.sort_order = r.integer("sort_order")
	if r.has("equip") and r.is_dict("equip"):
		def.equip = EquipInfo.from_dict(r.dict("equip"))
		r.absorb(def.equip != null)
	if r.has("food") and r.is_dict("food"):
		var food := DefReader.new(r.dict("food"), r.context() + " food")
		def.food_heal = food.integer("heal")
		r.absorb(food.ok)
	if r.has("infusion") and r.is_dict("infusion"):
		var infusion := DefReader.new(r.dict("infusion"), r.context() + " infusion")
		def.infusion_modifiers = infusion.modifiers("modifiers")
		if infusion.has("unique"):
			def.infusion_unique = infusion.flag("unique")
		r.absorb(infusion.ok)
	return def if r.ok else null


func is_equippable() -> bool:
	return equip != null


func is_food() -> bool:
	return food_heal > 0


func is_infusion() -> bool:
	return not infusion_modifiers.is_empty()
