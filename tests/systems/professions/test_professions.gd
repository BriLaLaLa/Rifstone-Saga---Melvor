extends GutTest
## Professions (M26-03): the fraction per skill (F-168), origins and unlocks (F-169) on the fixtures, the save and skill_reset.
## Fixtures: test_craft has craft_plank (no colors), craft_tint (20/30/40), craft_scheme (discover, 25/35/45, sold as buy_recipe_craft_scheme).

const SKILL: StringName = &"test_craft"

var _s: GameSession = null


func before_each() -> void:
	_s = autofree(TestFactory.session())


func _plate(xp: int = 33) -> ActionDef:
	var a := ActionDef.new()
	a.id = &"plate"
	a.skill_id = SKILL
	a.xp = xp
	a.colors = {&"yellow": 20, &"green": 30, &"grey": 40}
	return a


func _cycles(action: ActionDef, level: int, count: int) -> Array[int]:
	TestFactory.set_level(_s, SKILL, level)
	var result: Array[int] = []
	for _i: int in count:
		result.append(_s.professions.craft_xp_base(action))
	return result


func test_yellow_level_25_gives_24_25_25_25_and_no_rest() -> void:
	assert_eq(_cycles(_plate(), 25, 4), [24, 25, 25, 25] as Array[int])
	assert_eq(_s.professions.frac(SKILL), 0)


func test_green_level_35_gives_8_8_8_9() -> void:
	assert_eq(_cycles(_plate(), 35, 4), [8, 8, 8, 9] as Array[int])
	assert_eq(_s.professions.frac(SKILL), 0)


func test_the_rest_grows_between_cycles() -> void:
	_cycles(_plate(), 35, 1)
	assert_eq(_s.professions.frac(SKILL), 250000)
	_cycles(_plate(), 35, 1)
	assert_eq(_s.professions.frac(SKILL), 500000)


func test_orange_gives_the_full_xp_every_cycle() -> void:
	assert_eq(_cycles(_plate(), 15, 3), [33, 33, 33] as Array[int])


func test_grey_gives_nothing_and_keeps_the_rest() -> void:
	_cycles(_plate(), 35, 1)
	assert_eq(_cycles(_plate(), 40, 2), [0, 0] as Array[int])
	assert_eq(_s.professions.frac(SKILL), 250000)


func test_small_xp_at_a_quarter_chance() -> void:
	assert_eq(_cycles(_plate(8), 35, 4), [2, 2, 2, 2] as Array[int])


func test_the_level_that_rises_between_cycles_is_used_by_the_next_one() -> void:
	var first: Array[int] = _cycles(_plate(), 25, 1)
	var second: Array[int] = _cycles(_plate(), 40, 1)
	assert_eq(first, [24] as Array[int])
	assert_eq(second, [0] as Array[int])
	assert_eq(_s.professions.frac(SKILL), 750000)


func test_recipe_without_colors_is_the_xp_of_today() -> void:
	var plain: ActionDef = _s.data.action(&"craft_plank")
	assert_eq(_cycles(plain, 25, 3), [8, 8, 8] as Array[int])
	assert_eq(_s.professions.frac(SKILL), 0)


func test_recipe_color() -> void:
	TestFactory.set_level(_s, SKILL, 25)
	assert_eq(_s.professions.recipe_color(&"craft_tint"), {"id": &"yellow", "chance_ppm": 750000})
	assert_eq(_s.professions.recipe_color(&"craft_plank"), {"id": &"", "chance_ppm": 1000000})
	assert_eq(_s.professions.recipe_color(&"nope"), {})
	assert_eq(_s.professions.recipe_color(&"gather_log"), {}, "a gathering action has no color")


func test_skill_reset_clears_the_rest() -> void:
	_cycles(_plate(), 35, 1)
	assert_gt(_s.professions.frac(SKILL), 0)
	_s.events.skill_reset.emit(SKILL)
	assert_eq(_s.professions.frac(SKILL), 0)


func test_save_has_only_the_fractions_above_zero_and_roundtrips() -> void:
	assert_eq(_s.professions.to_save(), {"frac": {}})
	_cycles(_plate(), 35, 1)
	var saved: Dictionary = _s.professions.to_save()
	assert_eq(saved, {"frac": {"test_craft": 250000}})
	_s.professions.new_game()
	assert_eq(_s.professions.frac(SKILL), 0)
	_s.professions.from_save(saved)
	assert_eq(_s.professions.to_save(), saved, "save, load, save is identical")


func test_from_save_is_tolerant() -> void:
	_s.professions.from_save({"frac": {"test_craft": 1000000, "nope": 5, "test_gather": 7}})
	assert_eq(_s.professions.to_save(), {"frac": {}}, "out of range, unknown and no colored recipes: dropped")
	_s.professions.from_save({"frac": {"test_craft": "x"}})
	assert_eq(_s.professions.frac(SKILL), 0)
	_s.professions.from_save({"frac": {"test_craft": 500000.0}})
	assert_eq(_s.professions.frac(SKILL), 500000)
	_s.professions.from_save({"frac": 3})
	assert_eq(_s.professions.to_save(), {"frac": {}})
	_s.professions.from_save({})
	assert_eq(_s.professions.to_save(), {"frac": {}})


func test_the_session_saves_the_module() -> void:
	_cycles(_plate(), 35, 1)
	var d: Dictionary = _s.to_save(0)
	assert_eq(d["modules"]["professions"], {"frac": {"test_craft": 250000}})


# --- F-169 ----------------------------------------------------------------------------------------------------------------

func test_recipe_source() -> void:
	assert_eq(_s.professions.recipe_source(&"craft_plank"), &"trainer")
	assert_eq(_s.professions.recipe_source(&"craft_scheme"), &"scheme")
	assert_eq(_s.professions.recipe_source(&"craft_secret"), &"drop")
	assert_eq(_s.professions.recipe_source(&"gather_log"), &"")
	assert_eq(_s.professions.recipe_source(&"nope"), &"")
	assert_eq(_s.professions.scheme_entry(&"craft_scheme"), &"buy_recipe_craft_scheme")
	assert_eq(_s.professions.scheme_entry(&"craft_secret"), &"")


func test_vendor() -> void:
	assert_eq(_s.professions.vendor(SKILL), &"fabbro")
	assert_eq(_s.professions.vendor(&"test_gather"), &"")
	assert_eq(_s.professions.vendor(&"nope"), &"")


func test_unlocks_are_by_level_then_kind() -> void:
	var rows: Array[Dictionary] = _s.professions.unlocks(SKILL)
	assert_eq(rows, [
		{"level": 1, "kind": &"trainer", "id": &"craft_plank"},
		{"level": 2, "kind": &"trainer", "id": &"craft_tint"},
		{"level": 5, "kind": &"scheme", "id": &"buy_recipe_craft_scheme"},
		{"level": 5, "kind": &"reagent", "id": &"buy_reagent_test_craft_1"},
	] as Array[Dictionary])
	assert_eq(_s.professions.unlocks(&"test_gather"), [] as Array[Dictionary])


func test_next_unlocks_are_above_the_current_level() -> void:
	TestFactory.set_level(_s, SKILL, 2)
	var rows: Array[Dictionary] = _s.professions.next_unlocks(SKILL, 1)
	assert_eq(rows.size(), 1)
	assert_eq(rows[0]["id"], &"buy_recipe_craft_scheme")
	assert_eq(_s.professions.next_unlocks(SKILL, 10).size(), 2)
	assert_eq(_s.professions.next_unlocks(SKILL, 0).size(), 0)
