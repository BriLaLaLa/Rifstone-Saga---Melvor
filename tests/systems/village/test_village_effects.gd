extends GutTest
## F-132 (docs/02_FORMULAS.md §5h): the effect of a Village level, with the examples of the document. Every stat of
## the buildings is read from the ModifierService under the source `village:<id>`.

var _session: GameSession
var _village: Village


func before_each() -> void:
	_session = TestFactory.session_no_kit(11, TestFactory.real_data())
	add_child_autofree(_session)
	_village = _session.village


func _set_level(building: StringName, level: int) -> void:
	_session.village.from_save({"levels": {String(building): level}})
	_session.rebuild_modifiers()


func test_effect_at_is_linear() -> void:
	assert_eq(_village.effect_at(&"storehouse", 5), 20.0)
	assert_eq(_village.effect_at(&"sawmill", 8), -16.0)
	assert_eq(_village.effect_at(&"inn", 0), 0.0, "no effect below level 1")
	assert_eq(_village.effect_at(&"market", 3), 0.0, "a placeholder has no effect")
	assert_eq(_village.effect_at(&"nothing", 3), 0.0)


func test_storehouse_5_gives_20_deposit_slots() -> void:
	_set_level(&"storehouse", 5)
	assert_eq(_session.modifiers.total(&"deposit_slots"), 20.0)
	assert_true(_session.modifiers.has_source(&"village:storehouse"))


func test_inn_8_adds_to_the_equipment_food_healing() -> void:
	_set_level(&"inn", 8)
	assert_eq(_session.modifiers.total(&"food_healing_pct"), 24.0)
	_session.modifiers.set_source(&"test:gear", [Modifier.make(&"food_healing_pct", 10.0)] as Array[Modifier])
	assert_eq(_session.modifiers.total(&"food_healing_pct"), 34.0, "F-05: the sources add up")


func test_forge_4_only_helps_forging() -> void:
	_set_level(&"forge", 4)
	assert_eq(_session.modifiers.total(&"skill_xp_pct", ModifierContext.for_skill(&"forging")), 12.0)
	assert_eq(_session.modifiers.total(&"skill_xp_pct", ModifierContext.for_skill(&"forestry")), 0.0)


func test_sawmill_8_speeds_up_woodwright_only() -> void:
	_set_level(&"sawmill", 8)
	assert_eq(_session.modifiers.total(&"skill_interval_pct", ModifierContext.for_skill(&"woodwright")), -16.0)
	assert_eq(_session.modifiers.total(&"skill_interval_pct", ModifierContext.for_skill(&"forging")), 0.0)


func test_loot_shed_8_makes_the_loot_bag_28() -> void:
	_set_level(&"loot_shed", 8)
	assert_eq(_session.modifiers.total(&"loot_bag_slots"), 16.0)
	var bag: LootBag = LootBag.new(_session)
	assert_eq(bag.capacity(), 28, "F-33: 12 + 16")


func test_level_zero_has_no_source() -> void:
	assert_false(_session.modifiers.has_source(&"village:storehouse"))
	_set_level(&"storehouse", 2)
	assert_true(_session.modifiers.has_source(&"village:storehouse"))
	_session.village.new_game()
	_session.rebuild_modifiers()
	assert_false(_session.modifiers.has_source(&"village:storehouse"))


func test_every_building_stat_has_its_source_and_value() -> void:
	for id: StringName in _village.buildings():
		if not _village.is_buildable(id):
			continue
		var def: VillageBuildingDef = _session.data.village_building(id)
		_set_level(id, 3)
		var ctx: ModifierContext = ModifierContext.global_ctx()
		if def.effect_scope.begins_with("skill:"):
			ctx = ModifierContext.for_skill(StringName(def.effect_scope.get_slice(":", 1)))
		assert_eq(_session.modifiers.total(def.effect_stat, ctx), def.effect_per_level * 3.0, "%s (village:%s)" % [def.effect_stat, id])
		var found: bool = false
		for entry: Dictionary in _session.modifiers.breakdown(def.effect_stat, ctx):
			found = found or str(entry.get("source")) == "village:%s" % id
		assert_true(found, "breakdown of %s names the source village:%s" % [def.effect_stat, id])
