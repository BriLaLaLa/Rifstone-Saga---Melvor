class_name ShopEntryDef
extends RefCounted
## An entry of data/shop/shop.json (docs/04_DATA_SCHEMA.md §9).
##
## `cost` has `gold` (-> `cost_gold`; M12: the price is always gold, no formulas); `effect` has `modifiers`
## (-> `effect_modifiers`, else empty) or `item` (-> `effect_item`, else null). Having neither is a conversion error;
## having both is left to DataValidator (M1-04). `requires` is required (it may be `{}`); its `entries`, `skills`,
## `character` (character level) and `total_level` are optional (empty / 0). Effect modifiers without `scope` are global.
## `from_dict` returns null (after logging, see DefReader) if a field is missing or mistyped.

var id: StringName = &""
var name: String = ""
var description: String = ""
var category: StringName = &""
var vendor: StringName = &""  # stall of the shop page (P-04): one of DataValidatorItems.SHOP_VENDORS
var cost_gold: int = 0
var max_purchases: int = 0
var req_entries: Array[StringName] = []
var req_skills: Dictionary[StringName, int] = {}
var req_total_level: int = 0
var req_character: int = 0  # character level, 0 = no requirement
var effect_modifiers: Array[Modifier] = []
var effect_item: ItemQty = null


static func from_dict(d: Dictionary) -> ShopEntryDef:
	var r := DefReader.new(d, "shop entry")
	var def := ShopEntryDef.new()
	def.id = r.id("id")
	r.set_context("shop entry '%s'" % def.id)
	def.name = r.text("name")
	def.description = r.text("description")
	def.category = r.id("category")
	def.vendor = r.id("vendor")
	def.max_purchases = r.integer("max_purchases")
	if r.is_dict("cost"):
		_read_cost(def, DefReader.new(r.dict("cost"), r.context() + " cost"), r)
	if r.is_dict("requires"):
		_read_requires(def, DefReader.new(r.dict("requires"), r.context() + " requires"), r)
	if r.is_dict("effect"):
		_read_effect(def, DefReader.new(r.dict("effect"), r.context() + " effect"), r)
	return def if r.ok else null


static func _read_cost(def: ShopEntryDef, cost: DefReader, parent: DefReader) -> void:
	if cost.has("gold"):
		def.cost_gold = cost.integer("gold")
	if not cost.has("gold"):
		cost.fail("needs 'gold' (M12: no cost formulas)")
	parent.absorb(cost.ok)


static func _read_requires(def: ShopEntryDef, requires: DefReader, parent: DefReader) -> void:
	if requires.has("entries"):
		def.req_entries = requires.id_list("entries")
	if requires.has("skills"):
		def.req_skills = requires.level_map("skills")
	if requires.has("total_level"):
		def.req_total_level = requires.integer("total_level")
	if requires.has("character"):
		def.req_character = requires.integer("character")
	parent.absorb(requires.ok)


static func _read_effect(def: ShopEntryDef, effect: DefReader, parent: DefReader) -> void:
	if effect.has("modifiers"):
		def.effect_modifiers = effect.modifiers("modifiers")
	if effect.has("item") and effect.is_dict("item"):
		def.effect_item = ItemQty.from_dict(effect.dict("item"))
		effect.absorb(def.effect_item != null)
	if not effect.has("modifiers") and not effect.has("item"):
		effect.fail("needs 'modifiers' or 'item'")
	parent.absorb(effect.ok)
