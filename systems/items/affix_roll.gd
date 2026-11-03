class_name AffixRoll
extends RefCounted
## One rolled affix on an item instance (docs/05_INTERFACES.md §5.17): affix id, tier (1-based) and rolled value.

var affix_id: StringName = &""
var tier: int = 1
var value: float = 0.0


static func make(affix_id: StringName, tier: int, value: float) -> AffixRoll:
	var roll := AffixRoll.new()
	roll.affix_id = affix_id
	roll.tier = tier
	roll.value = value
	return roll
