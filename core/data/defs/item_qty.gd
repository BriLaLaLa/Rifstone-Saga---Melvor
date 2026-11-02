class_name ItemQty
extends RefCounted
## An item with a quantity: `{"item": id, "qty": int}` (action inputs/outputs, shop item effects).
## `from_dict` returns null (after logging, see DefReader) if a field is missing or mistyped.

var item_id: StringName = &""
var qty: int = 0


static func from_dict(d: Dictionary) -> ItemQty:
	var r := DefReader.new(d, "item quantity")
	var def := ItemQty.new()
	def.item_id = r.id("item")
	def.qty = r.integer("qty")
	return def if r.ok else null
