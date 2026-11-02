extends GutTest
## Modifier and ModifierContext: parsing from JSON, scope rules of F-05, scaling.


func test_make_sets_fields() -> void:
	var mod: Modifier = Modifier.make(&"skill_xp_pct", 5.0, &"skill", &"forestry")
	assert_eq(mod.stat, &"skill_xp_pct")
	assert_eq(mod.value, 5.0)
	assert_eq(mod.scope_kind, &"skill")
	assert_eq(mod.scope_id, &"forestry")


func test_make_defaults_to_global() -> void:
	var mod: Modifier = Modifier.make(&"bank_slots", 10.0)
	assert_eq(mod.scope_kind, &"global")
	assert_eq(mod.scope_id, &"")


func test_from_dict_schema_example() -> void:
	var mod: Modifier = Modifier.from_dict({"stat": "skill_interval_pct", "value": -5, "scope": "skill:forestry"})
	assert_not_null(mod)
	assert_eq(mod.stat, &"skill_interval_pct")
	assert_eq(mod.value, -5.0)
	assert_eq(mod.scope_kind, &"skill")
	assert_eq(mod.scope_id, &"forestry")


func test_from_dict_action_scope() -> void:
	var mod: Modifier = Modifier.from_dict({"stat": "double_item_chance", "value": 2.5, "scope": "action:cut_ashoak"})
	assert_eq(mod.scope_kind, &"action")
	assert_eq(mod.scope_id, &"cut_ashoak")
	assert_eq(mod.value, 2.5)


func test_from_dict_without_scope_is_global() -> void:
	var mod: Modifier = Modifier.from_dict({"stat": "bank_slots", "value": 4})
	assert_eq(mod.scope_kind, &"global")
	assert_eq(mod.scope_id, &"")


func test_from_dict_uses_default_scope_when_missing() -> void:
	var mod: Modifier = Modifier.from_dict({"stat": "preservation_chance", "value": 5}, "action:cut_ashoak")
	assert_eq(mod.scope_kind, &"action")
	assert_eq(mod.scope_id, &"cut_ashoak")


func test_from_dict_explicit_scope_beats_default() -> void:
	var mod: Modifier = Modifier.from_dict({"stat": "skill_xp_pct", "value": 1, "scope": "global"}, "skill:forestry")
	assert_eq(mod.scope_kind, &"global")


func test_from_dict_invalid_scope_returns_null() -> void:
	assert_null(Modifier.from_dict({"stat": "skill_xp_pct", "value": 1, "scope": "zone:plains"}))
	assert_null(Modifier.from_dict({"stat": "skill_xp_pct", "value": 1, "scope": "skill:"}))
	assert_null(Modifier.from_dict({"stat": "skill_xp_pct", "value": 1, "scope": ":forestry"}))
	assert_push_error(3)


func test_from_dict_missing_stat_or_value_returns_null() -> void:
	assert_null(Modifier.from_dict({"value": 1}))
	assert_null(Modifier.from_dict({"stat": "skill_xp_pct"}))
	assert_null(Modifier.from_dict({"stat": "skill_xp_pct", "value": "1"}))
	assert_push_error(3)


func test_global_applies_everywhere() -> void:
	var mod: Modifier = Modifier.make(&"skill_xp_pct", 1.0)
	assert_true(mod.applies_to(null))
	assert_true(mod.applies_to(ModifierContext.global_ctx()))
	assert_true(mod.applies_to(ModifierContext.for_skill(&"forestry")))
	assert_true(mod.applies_to(ModifierContext.for_action(&"forestry", &"cut_ashoak")))


func test_skill_scope_applies_only_to_that_skill() -> void:
	var mod: Modifier = Modifier.make(&"skill_xp_pct", 1.0, &"skill", &"forestry")
	assert_false(mod.applies_to(null))
	assert_false(mod.applies_to(ModifierContext.global_ctx()))
	assert_true(mod.applies_to(ModifierContext.for_skill(&"forestry")))
	assert_true(mod.applies_to(ModifierContext.for_action(&"forestry", &"cut_redbirch")))
	assert_false(mod.applies_to(ModifierContext.for_skill(&"quarrying")))


func test_action_scope_applies_only_to_that_action() -> void:
	var mod: Modifier = Modifier.make(&"skill_xp_pct", 1.0, &"action", &"cut_ashoak")
	assert_false(mod.applies_to(null))
	assert_false(mod.applies_to(ModifierContext.for_skill(&"forestry")))
	assert_true(mod.applies_to(ModifierContext.for_action(&"forestry", &"cut_ashoak")))
	assert_false(mod.applies_to(ModifierContext.for_action(&"forestry", &"cut_redbirch")))


func test_scaled_returns_copy() -> void:
	var mod: Modifier = Modifier.make(&"skill_xp_pct", 2.0, &"skill", &"forestry")
	var copy: Modifier = mod.scaled(3.0)
	assert_eq(copy.value, 6.0)
	assert_eq(copy.stat, &"skill_xp_pct")
	assert_eq(copy.scope_kind, &"skill")
	assert_eq(copy.scope_id, &"forestry")
	assert_eq(mod.value, 2.0, "the original is unchanged")


func test_context_factories() -> void:
	var g: ModifierContext = ModifierContext.global_ctx()
	assert_eq(g.skill_id, &"")
	assert_eq(g.action_id, &"")
	var s: ModifierContext = ModifierContext.for_skill(&"forestry")
	assert_eq(s.skill_id, &"forestry")
	assert_eq(s.action_id, &"")
	var a: ModifierContext = ModifierContext.for_action(&"forestry", &"cut_ashoak")
	assert_eq(a.skill_id, &"forestry")
	assert_eq(a.action_id, &"cut_ashoak")
