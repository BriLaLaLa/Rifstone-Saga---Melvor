class_name ArmoryKit
extends RefCounted
## The starting kit of docs/01_GDD.md §1.1: the pieces of `start.armory` and then the unique tools of `start.tools`,
## common, grade 1, without affixes (uid 0: `Armory.new_game` assigns 1…n in this order). Both lists are optional in
## balance.json until M10-04 adds them; `Equipment.new_game` wears the pieces whose `equip` is not empty.

const START_KEY: String = "start"
const LISTS: Array[String] = ["armory", "tools"]


## The `base` ids of the kit in order, with the slot they are worn in ("" = stays in the Armory; tools: their own slot).
static func entries(data: GameData) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var start: Dictionary = data.balance_value(START_KEY) as Dictionary
	for list_key: String in LISTS:
		for entry: Variant in start.get(list_key, []) as Array:
			var d: Dictionary = entry as Dictionary
			var base_id: StringName = StringName(str(d["base"]))
			if not data.has_item(base_id) or data.item(base_id).equip == null:
				Log.error("armory", "starting kit: '%s' is not an equipment or tool base" % base_id)
				continue
			var slot: StringName = data.item(base_id).equip.slot if list_key == "tools" else StringName(str(d["equip"]))
			result.append({"base": base_id, "slot": slot})
	return result


static func pieces(data: GameData) -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	for entry: Dictionary in entries(data):
		var inst := ItemInstance.new()
		inst.base_id = entry["base"]
		inst.rarity = &"common"
		inst.ilvl = 1
		result.append(inst)
	return result


## `start.food`: the item id of the food chosen at the start, &"" when absent.
static func food(data: GameData) -> StringName:
	return StringName(str((data.balance_value(START_KEY) as Dictionary).get("food", "")))
