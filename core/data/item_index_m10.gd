class_name ItemIndexM10
extends RefCounted
## Helper of GameData (internal; moved out of game_data.gd only for its size limit, behaviour unchanged).


## M10: the blueprints (by grade, then sort_order) with their index by base, and the unique tools by slot.
static func build(items: Array[ItemDef], blueprints: Array[ItemDef], by_base: Dictionary[StringName, ItemDef],
		unique_tools: Dictionary[StringName, ItemDef]) -> void:
	for def: ItemDef in items:
		if def.is_blueprint():
			blueprints.append(def)
			by_base[def.blueprint.base_id] = def
		elif def.category == &"tool" and def.equip != null and def.equip.unique:
			unique_tools[def.equip.slot] = def
	blueprints.sort_custom(func(a: ItemDef, b: ItemDef) -> bool:
		if a.blueprint.grade != b.blueprint.grade:
			return a.blueprint.grade < b.blueprint.grade
		return a.sort_order < b.sort_order)
