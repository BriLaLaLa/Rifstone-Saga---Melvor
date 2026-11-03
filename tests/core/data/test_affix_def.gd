extends GutTest
## AffixDef and AffixTier: the examples of docs/04_DATA_SCHEMA.md §15.


func _parse(text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed is Dictionary, "test JSON must be an object")
	return parsed as Dictionary


func test_weapon_affix_example() -> void:
	var def: AffixDef = AffixDef.from_dict(_parse("""
		{"id": "keen", "name": "Affilato", "stat": "accuracy_bonus", "slots": ["weapon", "offhand"], "weight": 10,
		 "tiers": [{"min_ilvl": 1, "min": 3, "max": 6}, {"min_ilvl": 20, "min": 7, "max": 12},
		           {"min_ilvl": 45, "min": 13, "max": 20}]}"""))
	assert_not_null(def)
	assert_eq(def.id, &"keen")
	assert_eq(def.name, "Affilato")
	assert_eq(def.stat, &"accuracy_bonus")
	assert_eq(def.slots, [&"weapon", &"offhand"] as Array[StringName])
	assert_eq(def.weight, 10)
	assert_eq(typeof(def.weight), TYPE_INT)
	assert_eq(def.tiers.size(), 3)
	assert_eq(def.tiers[1].min_ilvl, 20)
	assert_eq(typeof(def.tiers[1].min_ilvl), TYPE_INT)
	assert_eq(def.tiers[1].min, 7.0)
	assert_eq(def.tiers[1].max, 12.0)
	assert_eq(def.tiers[1].step, 1.0, "step defaults to 1")


func test_tool_affix_example_with_negative_values() -> void:
	var def: AffixDef = AffixDef.from_dict(_parse("""
		{"id": "woodsman", "name": "del Boscaiolo", "stat": "skill_interval_pct", "slots": ["tool_forestry"],
		 "weight": 10, "tiers": [{"min_ilvl": 1, "min": -2, "max": -1}]}"""))
	assert_not_null(def)
	assert_eq(def.slots, [&"tool_forestry"] as Array[StringName])
	assert_eq(def.tiers[0].min, -2.0)
	assert_eq(def.tiers[0].max, -1.0)


func test_tier_with_step() -> void:
	var tier: AffixTier = AffixTier.from_dict(_parse("""{"min_ilvl": 30, "min": 6, "max": 10, "step": 2}"""))
	assert_not_null(tier)
	assert_eq(tier.step, 2.0)


func test_affix_missing_field_is_null() -> void:
	var d: Dictionary = _parse("""
		{"id": "keen", "name": "Affilato", "stat": "accuracy_bonus", "slots": ["weapon"], "tiers": []}""")
	assert_null(AffixDef.from_dict(d))
	assert_push_error(1)


func test_tier_with_a_fractional_ilvl_is_null() -> void:
	assert_null(AffixTier.from_dict(_parse("""{"min_ilvl": 1.5, "min": 1, "max": 2}""")))
	assert_push_error(1)


func test_affix_with_a_bad_tier_is_null() -> void:
	var d: Dictionary = _parse("""
		{"id": "keen", "name": "Affilato", "stat": "accuracy_bonus", "slots": ["weapon"], "weight": 10,
		 "tiers": [{"min_ilvl": 1, "min": 3}]}""")
	assert_null(AffixDef.from_dict(d))
	assert_push_error(1)
