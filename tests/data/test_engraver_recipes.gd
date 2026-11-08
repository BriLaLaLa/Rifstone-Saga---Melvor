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


func test_real_recipes_of_the_engraver_follow_8_7() -> void:
	var data: GameData = TestFactory.real_data()
	assert_true(data.is_valid())
	var by_prefix: Dictionary = {}
	for a: ActionDef in data.actions_for_skill(&"riftbinding"):
		assert_false(String(a.id).begins_with("bind_"), "the old binding recipes are gone: %s" % a.id)
		var prefix: String = String(a.id).get_slice("_", 0)
		by_prefix[prefix] = int(by_prefix.get(prefix, 0)) + 1
	assert_eq(by_prefix, {"make": 1, "fuse": 8, "crystallize": 3, "engrave": 9, "upgrade": 36})
	var slab: ActionDef = data.action(&"make_rune_slab")
	assert_eq([slab.level, slab.interval_ms, slab.xp], [1, 3000, 6])
	assert_eq([slab.inputs[0].item_id, slab.inputs[0].qty, slab.inputs[1].item_id, slab.inputs[1].qty],
			[&"emberbronze_ore", 2, &"rift_shard", 1])
	assert_eq(slab.outputs[0].item_id, &"rune_slab")


func test_real_crystallize_fuse_and_engrave_recipes() -> void:
	var data: GameData = TestFactory.real_data()
	var crystals: Array = [[&"crystallize_spark", 5, 10, 25, 3000, &"currency_spark"],
			[&"crystallize_flux", 25, 25, 80, 4000, &"currency_flux"], [&"crystallize_crown", 45, 50, 160, 5000, &"currency_crown"]]
	for row: Array in crystals:
		var a: ActionDef = data.action(row[0] as StringName)
		assert_eq(a.kind, &"crystallize")
		assert_eq([a.level, a.inputs[0].item_id, a.inputs[0].qty, a.xp, a.interval_ms, a.outputs[0].item_id, a.outputs[0].qty, a.mastery],
				[row[1], &"rift_dust", row[2], row[3], row[4], row[5], 1, true], str(row[0]))
	for family: String in ["ember", "eye", "shade", "root"]:
		var stone: ActionDef = data.action(StringName("fuse_%s_stone" % family))
		assert_eq([stone.level, stone.xp, stone.interval_ms, stone.inputs[0].item_id, stone.inputs[0].qty, stone.outputs[0].item_id],
				[10, 20, 3000, StringName("stone_%s_chip" % family), 3, StringName("stone_%s_stone" % family)])
		var heart: ActionDef = data.action(StringName("fuse_%s_heart" % family))
		assert_eq([heart.level, heart.xp, heart.interval_ms, heart.inputs[0].item_id, heart.inputs[0].qty, heart.outputs[0].item_id],
				[40, 60, 4000, StringName("stone_%s_stone" % family), 3, StringName("stone_%s_heart" % family)])
	var engrave: ActionDef = data.action(&"engrave_stoneskin")
	assert_eq([engrave.level, engrave.xp, engrave.interval_ms], [45, 200, 5000])
	assert_eq([engrave.inputs[0].item_id, engrave.inputs[0].qty, engrave.inputs[1].item_id, engrave.inputs[1].qty, engrave.outputs[0].item_id],
			[&"rune_slab", 1, &"troll_moss", 3, &"inf_stoneskin"])


func test_real_upgrade_recipes_follow_f106() -> void:
	var data: GameData = TestFactory.real_data()
	var swift: ActionDef = data.action(&"upgrade_swift_hands_3")
	assert_eq([swift.level, swift.xp, swift.interval_ms, swift.inputs[0].item_id, swift.inputs[0].qty, swift.outputs[0].item_id],
			[11, 120, 4000, &"inf_swift_hands_2", 3, &"inf_swift_hands_3"], "level I + 5 x (N), XP x grade")
	assert_eq(data.action(&"upgrade_bulwark_5").level, 99, "capped at 99")
	assert_eq(data.action(&"upgrade_bulwark_2").inputs[0].item_id, &"inf_bulwark", "grade II is made from grade I")
	for a: ActionDef in data.actions_for_skill(&"riftbinding"):
		assert_false(String(a.id).ends_with("_6"), "grade V has no upgrade: %s" % a.id)


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
