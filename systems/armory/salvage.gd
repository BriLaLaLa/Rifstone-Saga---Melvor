class_name Salvage
extends RefCounted
## F-88 salvage rules (docs/02_FORMULAS.md, docs/01_GDD.md §25): pure functions over the `salvage` and `upgrade`
## sections of balance.json. No state: `Armory.salvage` and `Armory.add_drop` destroy the piece and pay the yield.

const RATIO_KEY: String = "salvage.ingot_ratio"
const SHARDS_KEY: String = "salvage.shards_by_rarity"
const EPSILON: float = 1e-9


## Ingots of the recipe that makes each piece: base item id -> sum of the inputs that are `upgrade.ingot_items`.
## Pieces without a recipe (drops only, such as rings) are absent. The first recipe wins.
static func recipe_ingots(data: GameData) -> Dictionary[StringName, int]:
	var ingot_items: Array = data.balance_value(Upgrade.INGOT_ITEMS_KEY) as Array
	var result: Dictionary[StringName, int] = {}
	for skill: SkillDef in data.skills():
		for action: ActionDef in data.actions_for_skill(skill.id):
			var ingots: int = 0
			for input: ItemQty in action.inputs:
				if ingot_items.has(String(input.item_id)):
					ingots += input.qty
			for output: ItemQty in action.outputs:
				if not result.has(output.item_id):
					result[output.item_id] = ingots
	return result


## F-88: {"ingots": floor(recipe_ingots x ingot_ratio), "shards": shards_by_rarity[rarity] x grade + upgrade}.
static func amounts(grade: int, rarity: StringName, upgrade: int, recipe_ingots_qty: int, data: GameData) -> Dictionary:
	var by_rarity: Dictionary = data.balance_value(SHARDS_KEY) as Dictionary
	return {
		"ingots": floori(recipe_ingots_qty * float(data.balance_value(RATIO_KEY)) + EPSILON),
		"shards": int(by_rarity.get(String(rarity), 0)) * grade + upgrade,
	}


## Bank items paid for `inst`: ingots of its grade and Rift shards, only the positive quantities.
static func yields(inst: ItemInstance, recipes: Dictionary[StringName, int], data: GameData) -> Dictionary[StringName, int]:
	var grade: int = data.item(inst.base_id).equip.grade
	var a: Dictionary = amounts(grade, inst.rarity, inst.upgrade, recipes.get(inst.base_id, 0), data)
	var result: Dictionary[StringName, int] = {}
	if int(a["ingots"]) > 0:
		result[Upgrade.ingot_item(grade, data)] = int(a["ingots"])
	if int(a["shards"]) > 0:
		result[Upgrade.SHARD_ITEM] = int(a["shards"])
	return result
