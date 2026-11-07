class_name CurrencyUse
extends RefCounted
## Effects of the Rift currencies on a piece (docs/01_GDD.md §26, M8-09). No state: the piece is changed in place,
## only after every check passed; the randomness comes from the given RngService (F-85 draws).

const TO_MAGIC: StringName = &"to_magic"
const TO_RARE: StringName = &"to_rare"
const REROLL: StringName = &"reroll"


## True when `item_id` is a currency item.
static func is_currency(item_id: StringName, data: GameData) -> bool:
	return data.has_item(item_id) and data.item(item_id).category == &"currency"


## True when `effect` can be applied to a piece of this rarity.
static func accepts(effect: StringName, rarity: StringName) -> bool:
	match effect:
		TO_MAGIC:
			return rarity == &"common"
		TO_RARE:
			return rarity == &"magic"
		REROLL:
			return rarity == &"magic" or rarity == &"rare"
	return false


## Spends one `currency_id` from the bank and applies its effect to `inst` (upgrade, sockets and locked are kept).
## Fails without any change: not_equippable (not a currency), item_locked, item_equipped, requirement_not_met
## (rarity does not fit), not_enough_items.
static func use(
	inst: ItemInstance, worn: bool, currency_id: StringName, bank: Bank, data: GameData, rng: RngService
) -> CommandResult:
	if not is_currency(currency_id, data):
		return CommandResult.fail(Reasons.NOT_EQUIPPABLE)
	if inst.locked:
		return CommandResult.fail(Reasons.ITEM_LOCKED)
	if worn:
		return CommandResult.fail(Reasons.ITEM_EQUIPPED)
	var effect: StringName = data.item(currency_id).currency_effect
	if not accepts(effect, inst.rarity) or not data.has_item(inst.base_id):
		return CommandResult.fail(Reasons.REQUIREMENT_NOT_MET)
	var removed: CommandResult = bank.remove(currency_id, 1)
	if not removed.ok:
		return removed
	var base: ItemDef = data.item(inst.base_id)
	match effect:
		TO_MAGIC:
			inst.rarity = &"magic"
			inst.affixes = ItemRoller.roll_affixes(base, &"magic", inst.ilvl, data, rng)
		TO_RARE:
			inst.rarity = &"rare"
			inst.affixes = ItemRoller.extend_affixes(base, &"rare", inst.ilvl, inst.affixes, data, rng)
		REROLL:
			inst.affixes = ItemRoller.roll_affixes(base, inst.rarity, inst.ilvl, data, rng)
	return CommandResult.success()
