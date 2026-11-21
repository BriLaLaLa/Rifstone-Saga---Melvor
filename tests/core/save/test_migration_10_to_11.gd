extends GutTest
## v10 -> v11 (M27-02, docs/05_INTERFACES_M27.md §6e, docs/02_FORMULAS_M27.md F-177): the wallet goes from gold to copper (x100),
## nothing else changes. Plus the real v10 slot written by the code of main before the change.

const Step := preload("res://core/save/migrations/migration_10_to_11.gd")
const SLOT_V10: String = "res://tests/fixtures/saves/slot_v10.json"


func _v10(wallet: Variant) -> Dictionary:
	var modules: Dictionary = {"bank": {"stacks": [{"item": "redbirch_log", "count": 5}]}, "village": {"levels": {"auction_house": 1}}}
	if wallet != null:
		modules["wallet"] = wallet
	return {"format_version": 10, "player_name": "x", "modules": modules}


func _copper(out: Dictionary) -> Variant:
	return ((out["modules"] as Dictionary)["wallet"] as Dictionary).get("copper")


func test_the_gold_becomes_copper_times_100() -> void:
	assert_eq(Step.V11_COPPER_PER_GOLD, 100)
	assert_eq(_copper(Step.migrate(_v10({"gold": 1250}))), 125000, "12g 50s")
	assert_eq(_copper(Step.migrate(_v10({"gold": 0}))), 0)
	assert_eq(_copper(Step.migrate(_v10({"gold": 1250.0}))), 125000)
	assert_typeof(_copper(Step.migrate(_v10({"gold": 1250.0}))), TYPE_INT)


func test_the_gold_key_is_removed() -> void:
	var wallet: Dictionary = Step.migrate(_v10({"gold": 7}))["modules"]["wallet"]
	assert_false(wallet.has("gold"))


func test_an_invalid_gold_is_dropped() -> void:
	for bad: Variant in ["x", -5, 2.5, null]:
		var wallet: Dictionary = Step.migrate(_v10({"gold": bad}))["modules"]["wallet"]
		assert_eq(wallet, {}, "gold %s" % str(bad))


func test_a_missing_wallet_stays_missing() -> void:
	assert_false((Step.migrate(_v10(null))["modules"] as Dictionary).has("wallet"))


func test_nothing_else_changes_and_the_input_is_untouched() -> void:
	var d: Dictionary = _v10({"gold": 3})
	var out: Dictionary = Step.migrate(d)
	var expected: Dictionary = d.duplicate(true)
	(expected["modules"] as Dictionary)["wallet"] = {"copper": 300}
	assert_eq(out, expected)
	assert_eq((d["modules"] as Dictionary)["wallet"], {"gold": 3})


func test_the_chain_from_v9_reaches_v11_with_the_wallet_in_copper() -> void:
	var v9: Dictionary = {"format_version": 9, "player_name": "x", "modules": {"wallet": {"gold": 40},
			"skills": {"forging": {"xp": 0}}, "actions": {"lanes": {}}}}
	var out: Dictionary = SaveMigrator.migrate(v9)
	assert_eq(out["format_version"], 12)
	assert_eq(_copper(out), 4000)
	assert_true((out["modules"] as Dictionary).has("disciplines"), "the v9 -> v10 step ran")


func _slot() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SLOT_V10))
	assert_true(parsed is Dictionary, "the v10 slot is readable")
	return parsed as Dictionary


func test_the_real_v10_slot_migrates_without_losses() -> void:
	var v10: Dictionary = _slot()
	assert_eq(int(v10["format_version"]), 10)
	var gold: int = int((v10["modules"] as Dictionary)["wallet"]["gold"])
	assert_gt(gold, 0)
	var out: Dictionary = SaveMigrator.migrate(v10)
	assert_eq(out["format_version"], 12)
	assert_eq(_copper(out), gold * 100)
	var rest: Dictionary = out.duplicate(true)
	var before: Dictionary = v10.duplicate(true)
	for d: Dictionary in [rest, before]:
		d.erase("format_version")
		(d["modules"] as Dictionary).erase("tutorial")  # added by the v11 -> v12 step (M30-02)
		(d["modules"] as Dictionary).erase("wallet")
	assert_eq(JSON.stringify(rest, "", true), JSON.stringify(before, "", true), "everything but the wallet is identical")


func test_the_real_v10_slot_loads_and_saves_identically() -> void:
	var migrated: Dictionary = SaveMigrator.migrate(_slot())
	var copper: int = int(_copper(migrated))
	var s: GameSession = autofree(TestFactory.session_no_kit(2711, TestFactory.real_data()))
	assert_true(s.from_save(migrated).ok)
	assert_eq(s.wallet.get_gold(), copper)
	var saved: Dictionary = s.to_save(int(migrated["saved_at_unix_ms"]))
	assert_eq(int((saved["modules"] as Dictionary)["wallet"]["copper"]), copper)
	var again: GameSession = autofree(TestFactory.session_no_kit(1, TestFactory.real_data()))
	assert_true(again.from_save(saved).ok)
	var saved_twice: Dictionary = again.to_save(int(migrated["saved_at_unix_ms"]))
	assert_eq(JSON.stringify(saved_twice, "", true), JSON.stringify(saved, "", true), "save -> load -> save is identical")
