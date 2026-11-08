extends "res://tests/data/engraver_data_base.gd"
## Validator rules of the Engraver (docs/04_DATA_SCHEMA.md §3, §6; F-104, F-105, F-106): the `engraver` and `rune`
## balance sections, `kind: crystallize`, the quantities of `fuse_*` (engraver.merge_ratio) and `upgrade_*`
## (rune.upgrade_ratio). Fixture actions of riftbinding: 0 crystallize_test, 1 fuse_test_stone, 2 upgrade_inf_test_2.


func test_fixtures_are_valid_and_parsed() -> void:
	assert_eq(V.validate(raw()), PackedStringArray())
	var data: GameData = TestFactory.fixture_data()
	assert_eq(data.action(&"crystallize_test").kind, &"crystallize")
	assert_eq(data.action(&"fuse_test_stone").kind, &"craft", "default kind")
	assert_eq(float(data.action(&"fuse_test_stone").inputs[0].qty), data.balance_value("engraver.merge_ratio"))
	assert_eq(float(data.action(&"upgrade_inf_test_2").inputs[0].qty), data.balance_value("rune.upgrade_ratio"))


func test_real_data_recipes_arrive_with_m12_05() -> void:
	assert_true(TestFactory.real_data().is_valid())
	pending("M12-05: the real Engraver recipes (slab, fuse_*, crystallize_*, engrave_*, upgrade_*) replace bind_*")


func test_balance_values_are_the_formula_values() -> void:
	var data: GameData = TestFactory.real_data()
	assert_eq(data.balance_value("engraver.crystal_chance_min_pct"), 40.0)
	assert_eq(data.balance_value("engraver.crystal_chance_max_pct"), 90.0)
	assert_eq(data.balance_value("engraver.crystal_fail_loss_pct"), 50.0)
	assert_eq(data.balance_value("engraver.merge_ratio"), 3.0)
	assert_eq(data.balance_value("rune.upgrade_ratio"), 3.0)
	assert_eq(data.balance_value("rune.grade_mult"), [1.0, 2.0, 3.0, 4.0, 5.0])


func test_fuse_quantity_must_be_the_merge_ratio() -> void:
	var r: Dictionary = raw()
	((action(r, 1)["inputs"] as Array)[0] as Dictionary)["qty"] = 4
	expect(r, [ACTIONS, "fuse_test_stone", "qty 4", "engraver.merge_ratio = 3"])
	r = raw()
	balance(r, "engraver")["merge_ratio"] = 4
	expect(r, [ACTIONS, "fuse_test_stone", "qty 3", "engraver.merge_ratio = 4"])


func test_upgrade_quantity_must_be_the_upgrade_ratio() -> void:
	var r: Dictionary = raw()
	((action(r, 2)["inputs"] as Array)[0] as Dictionary)["qty"] = 2
	expect(r, [ACTIONS, "upgrade_inf_test_2", "qty 2", "rune.upgrade_ratio = 3"])


func test_ratios_need_at_least_two() -> void:
	var r: Dictionary = raw()
	balance(r, "engraver")["merge_ratio"] = 1
	expect(r, [V.BALANCE, "engraver.merge_ratio"])
	r = raw()
	balance(r, "rune")["upgrade_ratio"] = 1
	expect(r, [V.BALANCE, "rune.upgrade_ratio"])


func test_chance_range_and_loss_rules() -> void:
	var r: Dictionary = raw()
	balance(r, "engraver")["crystal_chance_min_pct"] = 95
	expect(r, [V.BALANCE, "crystal_chance_min_pct", "<= 'crystal_chance_max_pct'"])
	r = raw()
	balance(r, "engraver")["crystal_fail_loss_pct"] = 101
	expect(r, [V.BALANCE, "engraver", "crystal_fail_loss_pct"])
	r = raw()
	balance(r, "engraver")["crystal_chance_max_pct"] = 101
	expect(r, [V.BALANCE, "engraver", "crystal_chance_max_pct"])


func test_grade_mult_rules() -> void:
	var r: Dictionary = raw()
	balance(r, "rune")["grade_mult"] = [1, 2, 3, 4]
	expect(r, [V.BALANCE, "rune.grade_mult", "exactly 5"])
	r = raw()
	balance(r, "rune")["grade_mult"] = [1, 2, 2, 4, 5]
	expect(r, [V.BALANCE, "rune.grade_mult", "increasing"])
	r = raw()
	balance(r, "rune")["grade_mult"] = [2, 3, 4, 5, 6]
	expect(r, [V.BALANCE, "rune.grade_mult", "start with 1"])


func test_engraver_keys_are_required() -> void:
	var r: Dictionary = raw()
	V.file_of(r, "balance", V.BALANCE).erase("engraver")
	expect(r, [V.BALANCE, "missing key 'engraver.merge_ratio'"])


func test_crystallize_rules() -> void:
	var r: Dictionary = raw()
	((action(r, 0)["inputs"] as Array)[0] as Dictionary)["item"] = "test_twig"
	expect(r, [ACTIONS, "crystallize_test", "exactly one input", "rift_dust"])
	r = raw()
	action(r, 0)["inputs"] = [{"item": "rift_dust", "qty": 50}, {"item": "test_twig", "qty": 1}]
	expect(r, [ACTIONS, "crystallize_test", "exactly one input"])
	r = raw()
	((action(r, 0)["outputs"] as Array)[0] as Dictionary)["item"] = "test_stone"
	expect(r, [ACTIONS, "crystallize_test", "1 currency"])
	r = raw()
	((action(r, 0)["outputs"] as Array)[0] as Dictionary)["qty"] = 2
	expect(r, [ACTIONS, "crystallize_test", "1 currency"])
	r = raw()
	action(r, 0)["mastery"] = false
	expect(r, [ACTIONS, "crystallize_test", "'mastery': true"])


func test_kind_rules() -> void:
	var r: Dictionary = raw()
	action(r, 0)["kind"] = "smelt"
	expect(r, [ACTIONS, "crystallize_test", "field 'kind' must be one of"])
	r = raw()
	V.entry_of(r, "actions", "test_craft.json", "actions", 0)["kind"] = "crystallize"
	expect(r, ["test_craft.json", "craft_plank", "allowed only for the actions of 'riftbinding'"])
