class_name Salvage
extends RefCounted
## F-95 salvage rules (docs/02_FORMULAS.md, docs/01_GDD.md §25): pure functions over the `salvage` section of
## balance.json and the blueprints. No state: `Armory.salvage` and `Armory.add_drop` destroy the piece and pay the yield.
## The yield of a piece is the components of the blueprint of its base (never the rare component) times
## `salvage.component_ratio`, plus Rift shards by rarity. M14: the grade is that of the material (`GameData.material_grade`);
## a Masterwork pays on its (x3) blueprint inputs, a legendary has no blueprint (shards only).

const RATIO_KEY: String = "salvage.component_ratio"
const SHARDS_KEY: String = "salvage.shards_by_rarity"
const EPSILON: float = 1e-9


## F-95: floor(qty x component_ratio) of one blueprint input.
static func component_amount(qty: int, data: GameData) -> int:
	return floori(qty * float(data.balance_value(RATIO_KEY)) + EPSILON)


## F-95: shards_by_rarity[rarity] x grade + upgrade; `grade` is the grade of the material (1..8, M14).
static func shards(grade: int, rarity: StringName, upgrade: int, data: GameData) -> int:
	var by_rarity: Dictionary = data.balance_value(SHARDS_KEY) as Dictionary
	return int(by_rarity.get(String(rarity), 0)) * grade + upgrade


## Components paid for the base: item id -> quantity, only the positive ones. Empty for a base without blueprint
## (rings, amulets).
static func components(base_id: StringName, data: GameData) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	var blueprint: ItemDef = data.blueprint_for_base(base_id)
	if blueprint == null:
		return result
	for input: ItemQty in blueprint.blueprint.inputs:
		var amount: int = component_amount(input.qty, data)
		if amount > 0:
			result[input.item_id] = result.get(input.item_id, 0) + amount
	return result


## Bank items paid for `inst`: components of its blueprint and Rift shards, only the positive quantities.
static func paid(inst: ItemInstance, data: GameData) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = components(inst.base_id, data)
	var amount: int = shards(data.material_grade(data.item(inst.base_id).equip.grade), inst.rarity, inst.upgrade, data)
	if amount > 0:
		result[Upgrade.SHARD_ITEM] = amount
	return result


## True when the bank has room for the stacks of `paid` that it does not hold yet.
static func fits(paid_items: Dictionary[StringName, int], bank: Bank) -> bool:
	var new_stacks: int = 0
	for item_id: StringName in paid_items:
		if bank.get_count(item_id) == 0:
			new_stacks += 1
	return new_stacks <= bank.free_boxes()


## Adds `paid` to the bank. Bank.add reports a full bank with bank_rejected, so a lost yield is never silent.
static func pay(paid_items: Dictionary[StringName, int], bank: Bank) -> void:
	for item_id: StringName in paid_items:
		bank.add(item_id, paid_items[item_id])
