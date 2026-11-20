class_name PlayerWard
extends RefCounted
## The Ward of the player (docs/01_GDD_M28.md §40.3, docs/02_FORMULAS_M28.md F-189, F-193): an amount of damage that is taken
## before the hp, for a time. One only: a new Ward keeps the bigger amount and the longer time. It runs down in every state of
## the combat (like the buffs, F-79) and ends with `reset`, `stop` and the death (`clear`). Saved in the slot (`combat.ward`).

const LOG_CATEGORY: String = "combat"

var amount: int = 0
var ms: int = 0


## F-189: `amount = max(amount, new_amount)`, `ms = max(ms, new_ms)`; nothing if either is not positive.
func grant(new_amount: int, new_ms: int) -> void:
	if new_amount <= 0 or new_ms <= 0:
		return
	amount = maxi(amount, new_amount)
	ms = maxi(ms, new_ms)


## F-193: takes up to `damage` from the Ward and returns the damage that is left for the hp (all of it without a Ward).
func absorb(damage: int) -> int:
	var taken: int = mini(amount, maxi(0, damage))
	amount -= taken
	if amount <= 0:
		clear()
	return damage - taken


## Time passes: the Ward ends at 0 ms.
func elapse(delta_ms: int) -> void:
	if not active():
		return
	ms -= delta_ms
	if ms <= 0:
		clear()


func clear() -> void:
	amount = 0
	ms = 0


func active() -> bool:
	return amount > 0 and ms > 0


## `ward` of the save and of `get_state()`: {"amount", "ms"}, {} without a Ward.
func to_save() -> Dictionary:
	return {"amount": amount, "ms": ms} if active() else {}


## Tolerant (F-185): a malformed value is dropped with a warning, a negative number is limited to 0; no time or no amount = none.
static func from_save(d: Variant) -> PlayerWard:
	var ward := PlayerWard.new()
	if d == null or (d is Dictionary and (d as Dictionary).is_empty()):
		return ward
	if not (d is Dictionary) or not _is_number((d as Dictionary).get("amount")) or not _is_number((d as Dictionary).get("ms")):
		Log.warn(LOG_CATEGORY, "saved Ward is malformed: dropped")
		return ward
	ward.grant(maxi(0, int((d as Dictionary)["amount"])), maxi(0, int((d as Dictionary)["ms"])))
	return ward


static func _is_number(value: Variant) -> bool:
	return value is int or value is float
