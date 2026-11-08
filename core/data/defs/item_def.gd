class_name ItemDef
extends RefCounted
## An item of data/items/*.json (docs/04_DATA_SCHEMA.md §5).
##
## Common fields are required. The optional sub-objects map to: `equip` -> `equip` (null when absent),
## `food.heal` -> `food_heal` (0 when there is no `food`), `stone.modifiers` -> `stone_modifiers` and `currency.effect` ->
## `currency_effect` (M8; empty when absent), `blueprint` -> `blueprint` (M10; null when absent), `infusion.modifiers`/`infusion.unique` ->
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
var stone_modifiers: Array[Modifier] = []
var currency_effect: StringName = &""
var blueprint: BlueprintInfo = null  # M10: null unless category `blueprint`
var bag_slots: int = 0  # M12: `bag.slots` of a category `bag` item (F-100); 0 otherwise
var contract_skill: StringName = &""  # M12: `contract.skill` of a category `contract` item (a gathering skill)
var contract_grade: StringName = &""  # M12: `contract.grade` (an id of helper.grades)
var infusion_grade: int = 1  # M12: `infusion.grade` 1..5 (F-107), 1 when absent
var infusion_family: StringName = &""  # M12: `infusion.family` (the id of the grade I rune); the own id when absent


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
		if infusion.has("grade"):
			def.infusion_grade = infusion.integer("grade")
		def.infusion_family = infusion.id("family") if infusion.has("family") else def.id
		r.absorb(infusion.ok)
	if r.has("stone") and r.is_dict("stone"):
		var stone := DefReader.new(r.dict("stone"), r.context() + " stone")
		def.stone_modifiers = stone.modifiers("modifiers")
		r.absorb(stone.ok)
	if r.has("currency") and r.is_dict("currency"):
		var currency := DefReader.new(r.dict("currency"), r.context() + " currency")
		def.currency_effect = currency.id("effect")
		r.absorb(currency.ok)
	if r.has("blueprint") and r.is_dict("blueprint"):
		def.blueprint = BlueprintInfo.from_dict(r.dict("blueprint"))
		r.absorb(def.blueprint != null)
	if r.has("bag") and r.is_dict("bag"):
		var bag := DefReader.new(r.dict("bag"), r.context() + " bag")
		def.bag_slots = bag.integer("slots")
		r.absorb(bag.ok)
	if r.has("contract") and r.is_dict("contract"):
		var contract := DefReader.new(r.dict("contract"), r.context() + " contract")
		def.contract_skill = contract.id("skill")
		def.contract_grade = contract.id("grade")
		r.absorb(contract.ok)
	return def if r.ok else null


func is_equippable() -> bool:
	return equip != null


func is_food() -> bool:
	return food_heal > 0


func is_infusion() -> bool:
	return not infusion_modifiers.is_empty()


func is_stone() -> bool:
	return not stone_modifiers.is_empty()


func is_currency() -> bool:
	return currency_effect != &""


func is_blueprint() -> bool:
	return category == &"blueprint" and blueprint != null


func is_bag() -> bool:
	return category == &"bag" and bag_slots > 0


func is_contract() -> bool:
	return category == &"contract" and contract_skill != &""


func is_component() -> bool:
	return category == &"component"
