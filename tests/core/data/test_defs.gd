extends GutTest
## Def classes for skills, actions and mastery: every example of docs/04_DATA_SCHEMA.md §4, §6, §7 becomes a
## Def with the right values, and malformed fields give null plus one logged error instead of a default.
## Items, combat and shop Defs are in test_item_defs.gd. Examples are parsed from JSON text, so numbers arrive
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


# --- §4 skills.json --------------------------------------------------------------------------------------------

func test_skill_schema_example() -> void:
	var skill: SkillDef = SkillDef.from_dict(_parse("""
		{"id": "forestry", "name": "Selvicoltura", "category": "gathering", "order": 1,
		 "icon": "res://assets/icons/skills/forestry.png", "color": "#7fbf6a",
		 "description": "Abbatti alberi per ottenere legni.",
		 "has_mastery": true}"""))
	assert_not_null(skill)
	assert_eq(skill.id, &"forestry")
	assert_eq(skill.name, "Selvicoltura")
	assert_eq(skill.description, "Abbatti alberi per ottenere legni.")
	assert_eq(skill.category, &"gathering")
	assert_eq(skill.order, 1)
	assert_eq(typeof(skill.order), TYPE_INT)
	assert_eq(skill.icon, "res://assets/icons/skills/forestry.png")
	assert_eq(skill.color, Color.html("#7fbf6a"))
	assert_true(skill.has_mastery)




func test_skill_bad_color_is_null() -> void:
	var skill: SkillDef = SkillDef.from_dict(_parse("""
		{"id": "blade", "name": "Lama", "category": "combat", "order": 5, "icon": "", "color": "red-ish",
		 "description": "", "has_mastery": false}"""))
	assert_null(skill)
	assert_push_error(1)

# --- §6 actions ------------------------------------------------------------------------------------------------

func test_action_gathering_example() -> void:
	var action: ActionDef = ActionDef.from_dict(_parse("""
		{"id": "cut_redbirch", "name": "Betulla rossa", "level": 1, "interval_ms": 3000, "xp": 10,
		 "mastery": true, "inputs": [], "outputs": [{"item": "redbirch_log", "qty": 1}]}"""), &"forestry")
	assert_not_null(action)
	assert_eq(action.id, &"cut_redbirch")
	assert_eq(action.skill_id, &"forestry")
	assert_eq(action.name, "Betulla rossa")
	assert_eq(action.level, 1)
	assert_eq(action.interval_ms, 3000)
	assert_eq(typeof(action.interval_ms), TYPE_INT)
	assert_eq(action.xp, 10)
	assert_true(action.mastery)
	assert_eq(action.icon, "")
	assert_eq(action.inputs.size(), 0)
	assert_false(action.is_artisan())
	assert_eq(action.outputs.size(), 1)
	assert_eq(action.outputs[0].item_id, &"redbirch_log")
	assert_eq(action.outputs[0].qty, 1)


func test_action_artisan_example() -> void:
	var action: ActionDef = ActionDef.from_dict(_parse("""
		{"id": "smelt_emberbronze", "name": "Fondere bronzo di brace", "level": 1, "interval_ms": 2000, "xp": 8,
		 "mastery": true, "inputs": [{"item": "emberbronze_ore", "qty": 2}],
		 "outputs": [{"item": "emberbronze_ingot", "qty": 1}]}"""), &"forging")
	assert_not_null(action)
	assert_eq(action.skill_id, &"forging")
	assert_eq(action.interval_ms, 2000)
	assert_eq(action.xp, 8)
	assert_true(action.is_artisan())
	assert_eq(action.inputs[0].item_id, &"emberbronze_ore")
	assert_eq(action.inputs[0].qty, 2)
	assert_eq(action.outputs[0].item_id, &"emberbronze_ingot")


func test_action_optional_icon_is_read() -> void:
	var action: ActionDef = ActionDef.from_dict(_parse("""
		{"id": "cut_redbirch", "name": "A", "level": 1, "interval_ms": 3000, "xp": 10, "mastery": true,
		 "icon": "res://a.png", "inputs": [], "outputs": [{"item": "redbirch_log", "qty": 1}]}"""), &"forestry")
	assert_eq(action.icon, "res://a.png")


func test_action_without_skill_id_is_null() -> void:
	assert_null(ActionDef.from_dict(_parse("""
		{"id": "cut_redbirch", "name": "A", "level": 1, "interval_ms": 3000, "xp": 10, "mastery": true,
		 "inputs": [], "outputs": [{"item": "redbirch_log", "qty": 1}]}""")))
	assert_push_error(1)


func test_action_bad_output_is_null() -> void:
	assert_null(ActionDef.from_dict(_parse("""
		{"id": "cut_redbirch", "name": "A", "level": 1, "interval_ms": 3000, "xp": 10, "mastery": true,
		 "inputs": [], "outputs": [{"item": "redbirch_log"}]}"""), &"forestry"))
	assert_push_error(1)


# --- §7 mastery nodes ------------------------------------------------------------------------------------------

func test_mastery_node_example() -> void:
	var node: MasteryNodeDef = MasteryNodeDef.from_dict(_parse("""
		{"id": "forestry_n1_quick_axe", "name": "Colpo sicuro", "description": "Azioni di Selvicoltura più rapide.",
		 "cost_pct": 5, "requires": [], "pos": [0, 0],
		 "modifiers": [{"stat": "skill_interval_pct", "value": -3, "scope": "skill:forestry"}]}"""), &"forestry")
	assert_not_null(node)
	assert_eq(node.id, &"forestry_n1_quick_axe")
	assert_eq(node.skill_id, &"forestry")
	assert_eq(node.name, "Colpo sicuro")
	assert_eq(node.description, "Azioni di Selvicoltura più rapide.")
	assert_eq(node.cost_pct, 5.0)
	assert_eq(node.requires.size(), 0)
	assert_eq(node.pos, Vector2i(0, 0))
	_assert_modifier(node.modifiers[0], &"skill_interval_pct", -3.0, &"skill", &"forestry")


func test_mastery_node_default_scope_is_its_skill() -> void:
	var node: MasteryNodeDef = MasteryNodeDef.from_dict(_parse("""
		{"id": "forestry_n2", "name": "N", "description": "", "cost_pct": 7.5, "requires": ["forestry_n1_quick_axe"],
		 "pos": [2, 3], "modifiers": [{"stat": "skill_xp_pct", "value": 4}]}"""), &"forestry")
	assert_eq(node.cost_pct, 7.5)
	assert_eq(node.requires, [&"forestry_n1_quick_axe"] as Array[StringName])
	assert_eq(node.pos, Vector2i(2, 3))
	_assert_modifier(node.modifiers[0], &"skill_xp_pct", 4.0, &"skill", &"forestry")


func test_mastery_node_bad_pos_is_null() -> void:
	assert_null(MasteryNodeDef.from_dict(_parse("""
		{"id": "forestry_n2", "name": "N", "description": "", "cost_pct": 5, "requires": [],
		 "pos": [1], "modifiers": []}"""), &"forestry"))
	assert_push_error(1)


func test_mastery_node_without_skill_id_is_null() -> void:
	assert_null(MasteryNodeDef.from_dict(_parse("""
		{"id": "forestry_n2", "name": "N", "description": "", "cost_pct": 5, "requires": [],
		 "pos": [1, 1], "modifiers": []}""")))
	assert_push_error(1)


func test_area_def_rift_stone_chance_optional() -> void:
	var d: Dictionary = {"id": "a", "name": "A", "description": "d", "order": 1, "requirements": {}, "packs": []}
	assert_eq(AreaDef.from_dict(d).rift_stone_chance_pct, -1.0, "absent = negative = global default")
	d["rift_stone_chance_pct"] = 3.5
	assert_eq(AreaDef.from_dict(d).rift_stone_chance_pct, 3.5)
