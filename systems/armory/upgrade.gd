class_name Upgrade
extends RefCounted
## F-86 refinement rules (docs/02_FORMULAS.md, docs/01_GDD.md §23): pure functions over the `upgrade` section of
## balance.json. No state: `Armory.upgrade` spends the materials and changes the piece.

const LEVELS_KEY: String = "upgrade.levels"
const DOWNGRADE_FROM_KEY: String = "upgrade.downgrade_from"
const SEAL_KEY: String = "upgrade.seal_item"
const INGOT_ITEMS_KEY: String = "upgrade.ingot_items"
const SHARD_ITEM: StringName = &"rift_shard"
const STAT: StringName = &"upgrade_success_pct"


## Highest refinement level (+N): one row of `upgrade.levels` per step.
static func max_level(data: GameData) -> int:
	return (data.balance_value(LEVELS_KEY) as Array).size()


## Row of the step `level` -> `level + 1` (level 0..max_level - 1): {success_pct, gold_per_grade, ingots, shards}.
static func row(level: int, data: GameData) -> Dictionary:
	return (data.balance_value(LEVELS_KEY) as Array)[level] as Dictionary


## F-86: `min(100, success_pct x (1 + bonus_pct / 100))`, `bonus_pct` = T(upgrade_success_pct).
static func chance_pct(level: int, bonus_pct: float, data: GameData) -> float:
	return minf(100.0, float(row(level, data)["success_pct"]) * (1.0 + bonus_pct / 100.0))


## Level after a failed attempt from `level`: one lower from `upgrade.downgrade_from` (the Seal prevents it).
static func failed_level(level: int, data: GameData) -> int:
	return level - 1 if level >= int(data.balance_value(DOWNGRADE_FROM_KEY)) else level


## Ingot item of a grade (1..8), `upgrade.ingot_items`; &"" for a grade out of range.
static func ingot_item(grade: int, data: GameData) -> StringName:
	var items: Array = data.balance_value(INGOT_ITEMS_KEY) as Array
	return StringName(str(items[grade - 1])) if grade >= 1 and grade <= items.size() else &""


static func seal_item(data: GameData) -> StringName:
	return StringName(str(data.balance_value(SEAL_KEY)))


## Cost of the step `level` -> `level + 1` for a piece of `grade`: {gold, ingot (item id), ingots, shards}.
static func cost(level: int, grade: int, data: GameData) -> Dictionary:
	var r: Dictionary = row(level, data)
	return {
		"gold": int(r["gold_per_grade"]) * grade,
		"ingot": ingot_item(grade, data),
		"ingots": int(r["ingots"]),
		"shards": int(r["shards"]),
	}


## F-86 refusals in order after `unknown_id`: upgrade_max, not_enough_gold, not_enough_items (ingots, shards and, when
## `use_seal` and the step can lose a level, the Seal).
static func check(inst: ItemInstance, use_seal: bool, wallet: Wallet, bank: Bank, data: GameData) -> CommandResult:
	if inst.upgrade >= max_level(data):
		return CommandResult.fail(Reasons.UPGRADE_MAX)
	var price: Dictionary = cost(inst.upgrade, material_grade(inst, data), data)
	if wallet.get_gold() < int(price["gold"]):
		return CommandResult.fail(Reasons.NOT_ENOUGH_GOLD)
	if not bank.has(price["ingot"], int(price["ingots"])) or not bank.has(SHARD_ITEM, int(price["shards"])) \
			or (seal_needed(inst, use_seal, data) and not bank.has(seal_item(data), 1)):
		return CommandResult.fail(Reasons.NOT_ENOUGH_ITEMS)
	return CommandResult.success()



## F-86 (M14): the grade of the cost is the grade of the material of the piece (1..8), not the piece grade (1..15).
static func material_grade(inst: ItemInstance, data: GameData) -> int:
	return data.material_grade(data.item(inst.base_id).equip.grade)


## True when the Seal is consumed by a failure: asked for and the step can lose a level.
static func seal_needed(inst: ItemInstance, use_seal: bool, data: GameData) -> bool:
	return use_seal and failed_level(inst.upgrade, data) < inst.upgrade


## Spends the cost of the step of `inst` (gold, ingots, shards); the checks have passed.
static func pay(inst: ItemInstance, wallet: Wallet, bank: Bank, data: GameData) -> void:
	var price: Dictionary = cost(inst.upgrade, material_grade(inst, data), data)
	if int(price["gold"]) > 0:
		wallet.spend(int(price["gold"]))
	spend(bank, price["ingot"], int(price["ingots"]))
	spend(bank, SHARD_ITEM, int(price["shards"]))


## Removes `qty` of `item_id` from the bank when positive.
static func spend(bank: Bank, item_id: StringName, qty: int) -> void:
	if qty > 0:
		bank.remove(item_id, qty)
