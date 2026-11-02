extends GutTest
## Def classes for items, combat and shop: every example of docs/04_DATA_SCHEMA.md §5, §8, §9 becomes a Def
## with the right values, and malformed fields give null plus one logged error instead of a default.
## Skills, actions and mastery Defs are in test_defs.gd. Examples are parsed from JSON text, so numbers arrive
## as float exactly as in the real files.


func _parse(text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed is Dictionary, "test JSON must be an object")
	return parsed as Dictionary


func _assert_modifier(mod: Modifier, stat: StringName, value: float, kind: StringName, id: StringName) -> void:
	assert_eq(mod.stat, stat)
	assert_eq(mod.value, value)
	assert_eq(mod.scope_kind, kind)
	assert_eq(mod.scope_id, id)


# --- §5 items --------------------------------------------------------------------------------------------------

func test_item_material_example() -> void:
	var item: ItemDef = ItemDef.from_dict(_parse("""
		{"id": "redbirch_log", "name": "Legno di betulla rossa", "category": "material",
		 "icon": "res://assets/icons/items/redbirch_log.png", "value": 1, "sort_order": 10,
		 "description": "Legno chiaro venato di rosso, comune nelle Pianure di Roccarossa."}"""))
	assert_not_null(item)
	assert_eq(item.id, &"redbirch_log")
	assert_eq(item.name, "Legno di betulla rossa")
	assert_eq(item.description, "Legno chiaro venato di rosso, comune nelle Pianure di Roccarossa.")
	assert_eq(item.category, &"material")
	assert_eq(item.icon, "res://assets/icons/items/redbirch_log.png")
	assert_eq(item.value, 1)
	assert_eq(item.sort_order, 10)
	assert_null(item.equip)
	assert_eq(item.food_heal, 0)
	assert_eq(item.infusion_modifiers.size(), 0)
	assert_false(item.infusion_unique)
	assert_false(item.is_equippable())
	assert_false(item.is_food())
	assert_false(item.is_infusion())


func test_item_weapon_example() -> void:
	var item: ItemDef = ItemDef.from_dict(_parse("""
		{"id": "emberbronze_blade", "name": "Lama di bronzo di brace", "category": "equipment",
		 "icon": "res://assets/icons/items/emberbronze_blade.png", "value": 12, "sort_order": 100,
		 "description": "Una lama corta, ancora tiepida di forgia.",
		 "equip": {"slot": "weapon", "requirements": {"blade": 1},
		           "modifiers": [{"stat": "accuracy_bonus", "value": 8}, {"stat": "power_bonus", "value": 6}],
		           "weapon": {"style": "blade", "attack_interval_ms": 2400, "two_handed": false}}}"""))
	assert_not_null(item)
	assert_eq(item.id, &"emberbronze_blade")
	assert_eq(item.category, &"equipment")
	assert_eq(item.value, 12)
	assert_eq(item.sort_order, 100)
	assert_true(item.is_equippable())
	assert_eq(item.equip.slot, &"weapon")
	assert_eq(item.equip.requirements, {&"blade": 1})
	assert_eq(item.equip.modifiers.size(), 2)
	_assert_modifier(item.equip.modifiers[0], &"accuracy_bonus", 8.0, &"global", &"")
	_assert_modifier(item.equip.modifiers[1], &"power_bonus", 6.0, &"global", &"")
	assert_not_null(item.equip.weapon)
	assert_eq(item.equip.weapon.style, &"blade")
	assert_eq(item.equip.weapon.attack_interval_ms, 2400)
	assert_false(item.equip.weapon.two_handed)


func test_item_tool_example() -> void:
	var item: ItemDef = ItemDef.from_dict(_parse("""
		{"id": "emberbronze_hatchet", "name": "Accetta di bronzo di brace", "category": "tool",
		 "icon": "res://assets/icons/items/emberbronze_hatchet.png", "value": 10, "sort_order": 10,
		 "description": "Taglia più in fretta.",
		 "equip": {"slot": "tool_forestry", "requirements": {"forestry": 1},
		           "modifiers": [{"stat": "skill_interval_pct", "value": -5, "scope": "skill:forestry"}]}}"""))
	assert_not_null(item)
	assert_eq(item.category, &"tool")
	assert_eq(item.equip.slot, &"tool_forestry")
	assert_eq(item.equip.requirements, {&"forestry": 1})
	_assert_modifier(item.equip.modifiers[0], &"skill_interval_pct", -5.0, &"skill", &"forestry")
	assert_null(item.equip.weapon)


func test_item_food_example() -> void:
	var item: ItemDef = ItemDef.from_dict(_parse("""
		{"id": "seared_brookfin", "name": "Pinnarivo scottato", "category": "food", "value": 2, "sort_order": 10,
		 "icon": "res://assets/icons/items/seared_brookfin.png", "description": "Cura 20 punti vita.",
		 "food": {"heal": 20}}"""))
	assert_not_null(item)
	assert_eq(item.category, &"food")
	assert_eq(item.food_heal, 20)
	assert_true(item.is_food())
	assert_false(item.is_equippable())


func test_item_infusion_example() -> void:
	var item: ItemDef = ItemDef.from_dict(_parse("""
		{"id": "inf_swift_hands", "name": "Infusione delle mani rapide", "category": "infusion", "value": 0,
		 "sort_order": 10, "icon": "res://assets/icons/items/inf_swift_hands.png",
		 "description": "Tutte le azioni sono un poco più rapide.",
		 "infusion": {"modifiers": [{"stat": "skill_interval_pct", "value": -3}], "unique": false}}"""))
	assert_not_null(item)
	assert_eq(item.value, 0)
	assert_true(item.is_infusion())
	assert_false(item.infusion_unique)
	assert_eq(item.infusion_modifiers.size(), 1)
	_assert_modifier(item.infusion_modifiers[0], &"skill_interval_pct", -3.0, &"global", &"")


func test_item_infusion_unique_defaults_to_false_and_reads_true() -> void:
	var base: String = """{"id": "inf_x", "name": "X", "category": "infusion", "value": 0, "sort_order": 1,
		"icon": "", "description": "", "infusion": {"modifiers": [{"stat": "bank_slots", "value": 1}]%s}}"""
	assert_false(ItemDef.from_dict(_parse(base % "")).infusion_unique)
	assert_true(ItemDef.from_dict(_parse(base % ", \"unique\": true")).infusion_unique)


func test_item_missing_field_is_null() -> void:
	assert_null(ItemDef.from_dict(_parse("""
		{"id": "redbirch_log", "name": "Legno", "category": "material", "icon": "", "sort_order": 10,
		 "description": ""}""")))
	assert_push_error("missing field 'value'")


func test_item_fractional_int_is_null() -> void:
	assert_null(ItemDef.from_dict(_parse("""
		{"id": "redbirch_log", "name": "Legno", "category": "material", "icon": "", "value": 1.5,
		 "sort_order": 10, "description": ""}""")))
	assert_push_error(1)


func test_item_bad_modifier_in_equip_is_null() -> void:
	assert_null(ItemDef.from_dict(_parse("""
		{"id": "bad_blade", "name": "Lama", "category": "equipment", "icon": "", "value": 1, "sort_order": 1,
		 "description": "", "equip": {"slot": "weapon", "requirements": {},
		 "modifiers": [{"stat": "power_bonus", "value": 1, "scope": "zone:x"}]}}""")))
	assert_push_error(1)


func test_item_wrong_type_for_food_is_null() -> void:
	assert_null(ItemDef.from_dict(_parse("""
		{"id": "bad_food", "name": "Cibo", "category": "food", "icon": "", "value": 1, "sort_order": 1,
		 "description": "", "food": 20}""")))
	assert_push_error(1)


func test_item_qty_converts_types() -> void:
	var qty: ItemQty = ItemQty.from_dict(_parse("""{"item": "novice_hatchet", "qty": 1}"""))
	assert_eq(qty.item_id, &"novice_hatchet")
	assert_eq(typeof(qty.item_id), TYPE_STRING_NAME)
	assert_eq(qty.qty, 1)
	assert_eq(typeof(qty.qty), TYPE_INT)


# --- §8 areas and monsters -------------------------------------------------------------------------------------

func test_area_example() -> void:
	var area: AreaDef = AreaDef.from_dict(_parse("""
		{"id": "redrock_plains", "name": "Pianure di Roccarossa", "order": 1,
		 "description": "Campi battuti dal vento ai piedi delle rocce rosse.",
		 "requirements": {}, "monsters": ["plains_boar", "ember_rat", "redrock_raider"]}"""))
	assert_not_null(area)
	assert_eq(area.id, &"redrock_plains")
	assert_eq(area.name, "Pianure di Roccarossa")
	assert_eq(area.description, "Campi battuti dal vento ai piedi delle rocce rosse.")
	assert_eq(area.order, 1)
	assert_eq(area.requirements.size(), 0)
	assert_eq(area.monster_ids, [&"plains_boar", &"ember_rat", &"redrock_raider"] as Array[StringName])


func test_area_requirements_are_typed() -> void:
	var area: AreaDef = AreaDef.from_dict(_parse("""
		{"id": "a", "name": "A", "order": 2, "description": "", "requirements": {"blade": 20, "vitality": 15},
		 "monsters": ["m"]}"""))
	assert_eq(area.requirements[&"blade"], 20)
	assert_eq(typeof(area.requirements[&"vitality"]), TYPE_INT)


func test_area_monsters_not_strings_is_null() -> void:
	assert_null(AreaDef.from_dict(_parse("""
		{"id": "a", "name": "A", "order": 2, "description": "", "requirements": {}, "monsters": [3]}""")))
	assert_push_error(1)


func test_monster_example() -> void:
	var monster: MonsterDef = MonsterDef.from_dict(_parse("""
		{"id": "plains_boar", "name": "Cinghiale delle pianure", "icon": "res://assets/icons/monsters/plains_boar.png",
		 "description": "Testardo e affamato.",
		 "hp": 20, "style": "blade", "attack_interval_ms": 2800,
		 "attack_level": 1, "power_level": 1, "defence_level": 1,
		 "accuracy_bonus": 0, "power_bonus": 0, "evasion_bonus": 0, "damage_reduction": 0,
		 "gold": [1, 4], "rift_shard_chance": 0.5,
		 "drops": [{"item": "boar_tusk", "chance_pct": 25, "qty": [1, 1]}]}"""))
	assert_not_null(monster)
	assert_eq(monster.id, &"plains_boar")
	assert_eq(monster.name, "Cinghiale delle pianure")
	assert_eq(monster.icon, "res://assets/icons/monsters/plains_boar.png")
	assert_eq(monster.description, "Testardo e affamato.")
	assert_eq(monster.hp, 20)
	assert_eq(monster.style, &"blade")
	assert_eq(monster.attack_interval_ms, 2800)
	assert_eq(monster.attack_level, 1)
	assert_eq(monster.power_level, 1)
	assert_eq(monster.defence_level, 1)
	assert_eq(monster.accuracy_bonus, 0)
	assert_eq(monster.power_bonus, 0)
	assert_eq(monster.evasion_bonus, 0)
	assert_eq(monster.damage_reduction, 0.0)
	assert_eq(monster.gold_min, 1)
	assert_eq(monster.gold_max, 4)
	assert_eq(monster.rift_shard_chance, 0.5)
	assert_eq(monster.drops.size(), 1)
	var drop: DropEntry = monster.drops[0]
	assert_eq(drop.item_id, &"boar_tusk")
	assert_eq(drop.chance_pct, 25.0)
	assert_eq(drop.qty_min, 1)
	assert_eq(drop.qty_max, 1)


func test_monster_bad_gold_is_null() -> void:
	var d: Dictionary = _parse("""
		{"id": "m", "name": "M", "icon": "", "description": "", "hp": 20, "style": "blade",
		 "attack_interval_ms": 2800, "attack_level": 1, "power_level": 1, "defence_level": 1,
		 "accuracy_bonus": 0, "power_bonus": 0, "evasion_bonus": 0, "damage_reduction": 0,
		 "gold": 4, "rift_shard_chance": 0.5, "drops": []}""")
	assert_null(MonsterDef.from_dict(d))
	assert_push_error(1)


# --- §9 shop ---------------------------------------------------------------------------------------------------

func test_shop_bank_slot_example() -> void:
	var entry: ShopEntryDef = ShopEntryDef.from_dict(_parse("""
		{"id": "bank_slot", "name": "Casella della bank", "category": "bank",
		 "description": "Una casella in più nella bank.",
		 "cost": {"formula": "bank_slot"}, "max_purchases": 150,
		 "requires": {}, "effect": {"modifiers": [{"stat": "bank_slots", "value": 1}]}}"""))
	assert_not_null(entry)
	assert_eq(entry.id, &"bank_slot")
	assert_eq(entry.name, "Casella della bank")
	assert_eq(entry.description, "Una casella in più nella bank.")
	assert_eq(entry.category, &"bank")
	assert_eq(entry.cost_gold, 0)
	assert_eq(entry.cost_formula, &"bank_slot")
	assert_eq(entry.max_purchases, 150)
	assert_eq(entry.req_entries.size(), 0)
	assert_eq(entry.req_skills.size(), 0)
	assert_eq(entry.req_total_level, 0)
	assert_eq(entry.effect_modifiers.size(), 1)
	_assert_modifier(entry.effect_modifiers[0], &"bank_slots", 1.0, &"global", &"")
	assert_null(entry.effect_item)


func test_shop_auto_eat_example() -> void:
	var entry: ShopEntryDef = ShopEntryDef.from_dict(_parse("""
		{"id": "auto_eat_2", "name": "Razioni da campo II", "category": "combat",
		 "description": "Mangia prima e più a lungo.",
		 "cost": {"gold": 25000}, "max_purchases": 1,
		 "requires": {"entries": ["auto_eat_1"], "skills": {"vitality": 25}},
		 "effect": {"modifiers": [{"stat": "auto_eat_tier", "value": 1}]}}"""))
	assert_not_null(entry)
	assert_eq(entry.category, &"combat")
	assert_eq(entry.cost_gold, 25000)
	assert_eq(typeof(entry.cost_gold), TYPE_INT)
	assert_eq(entry.cost_formula, &"")
	assert_eq(entry.max_purchases, 1)
	assert_eq(entry.req_entries, [&"auto_eat_1"] as Array[StringName])
	assert_eq(entry.req_skills, {&"vitality": 25})
	assert_eq(entry.req_total_level, 0)
	_assert_modifier(entry.effect_modifiers[0], &"auto_eat_tier", 1.0, &"global", &"")
	assert_null(entry.effect_item)


func test_shop_item_example() -> void:
	var entry: ShopEntryDef = ShopEntryDef.from_dict(_parse("""
		{"id": "novice_hatchet", "name": "Accetta del novizio", "category": "tools",
		 "description": "Un'accetta semplice.", "cost": {"gold": 150}, "max_purchases": 0,
		 "requires": {}, "effect": {"item": {"item": "novice_hatchet", "qty": 1}}}"""))
	assert_not_null(entry)
	assert_eq(entry.category, &"tools")
	assert_eq(entry.cost_gold, 150)
	assert_eq(entry.max_purchases, 0)
	assert_eq(entry.effect_modifiers.size(), 0)
	assert_not_null(entry.effect_item)
	assert_eq(entry.effect_item.item_id, &"novice_hatchet")
	assert_eq(entry.effect_item.qty, 1)


func test_shop_total_level_requirement() -> void:
	var entry: ShopEntryDef = ShopEntryDef.from_dict(_parse("""
		{"id": "e", "name": "E", "category": "combat", "description": "", "cost": {"gold": 10},
		 "max_purchases": 1, "requires": {"total_level": 120}, "effect": {"modifiers": []}}"""))
	assert_eq(entry.req_total_level, 120)


func test_shop_cost_without_gold_or_formula_is_null() -> void:
	assert_null(ShopEntryDef.from_dict(_parse("""
		{"id": "e", "name": "E", "category": "combat", "description": "", "cost": {},
		 "max_purchases": 1, "requires": {}, "effect": {"modifiers": []}}""")))
	assert_push_error("needs 'gold' or 'formula'")


func test_shop_effect_without_modifiers_or_item_is_null() -> void:
	assert_null(ShopEntryDef.from_dict(_parse("""
		{"id": "e", "name": "E", "category": "combat", "description": "", "cost": {"gold": 1},
		 "max_purchases": 1, "requires": {}, "effect": {}}""")))
	assert_push_error("needs 'modifiers' or 'item'")


func test_shop_missing_requires_is_null() -> void:
	assert_null(ShopEntryDef.from_dict(_parse("""
		{"id": "e", "name": "E", "category": "combat", "description": "", "cost": {"gold": 1},
		 "max_purchases": 1, "effect": {"modifiers": []}}""")))
	assert_push_error("missing field 'requires'")
