class_name DropEntry
extends RefCounted
## One drop of a monster (docs/04_DATA_SCHEMA.md §8): `{"item": id, "chance_pct": float, "qty": [min, max]}`.
## `from_dict` returns null (after logging, see DefReader) if a field is missing or mistyped.

var item_id: StringName = &""
var chance_pct: float = 0.0
var qty_min: int = 0
var qty_max: int = 0


static func from_dict(d: Dictionary) -> DropEntry:
	var r := DefReader.new(d, "drop")
	var def := DropEntry.new()
	def.item_id = r.id("item")
	r.set_context("drop '%s'" % def.item_id)
	def.chance_pct = r.number("chance_pct")
	var qty: Vector2i = r.int_pair("qty")
	def.qty_min = qty.x
	def.qty_max = qty.y
	return def if r.ok else null
