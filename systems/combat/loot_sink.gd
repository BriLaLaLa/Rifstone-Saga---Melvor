class_name LootSink
extends RefCounted
## Where the drops of a kill go (docs/05_INTERFACES.md §5.23). This base class is the neutral sink; `LootBag` (outside a
## Fracture) and `FractureSink` (inside one) override what differs. `KillRewards` only talks to this interface.


## F-120 `card_drop_mult`: the factor of the probability of the Card drops, set by the fight at every kill.
var card_mult: float = 1.0

## A stack of `item_id` (false = it was lost).
func add(_item_id: StringName, _qty: int) -> bool:
	return true


## A new piece (uid 0).
func add_piece(_inst: ItemInstance) -> void:
	pass


## A Card drop of `grade` (the rarity is rolled by the sink, F-109).
func drop_card(_grade: int) -> void:
	pass


## F-111: the probability of a drop of `base` (the data value, x `card_mult` for a Card, at most 100).
func drop_chance(base: ItemDef, chance_pct: float) -> float:
	if base.is_map() and card_mult != 1.0:
		return minf(100.0, chance_pct * card_mult)
	return chance_pct


## F-111: the quantity of a stack drop of `base` (the rolled value by default).
func drop_qty(_base: ItemDef, qty: int) -> int:
	return qty
