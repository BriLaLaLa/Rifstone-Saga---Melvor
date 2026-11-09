class_name ScaledSink
extends LootSink
## F-120 `monolith_loot_mult`: a sink that multiplies the quantity of every stack by `mult` (round) before it reaches the
## sink it wraps. Pieces, Cards, chances and the quantity rolls pass through unchanged.

var _inner: LootSink
var _mult: float


func _init(inner: LootSink, mult: float) -> void:
	_inner = inner
	_mult = mult


func add(item_id: StringName, qty: int) -> bool:
	return _inner.add(item_id, int(round(float(qty) * _mult)))


func add_piece(inst: ItemInstance) -> void:
	_inner.add_piece(inst)


func drop_card(grade: int) -> void:
	_inner.drop_card(grade)


func drop_chance(base: ItemDef, chance_pct: float) -> float:
	return _inner.drop_chance(base, chance_pct)


func drop_qty(base: ItemDef, qty: int) -> int:
	return _inner.drop_qty(base, qty)
