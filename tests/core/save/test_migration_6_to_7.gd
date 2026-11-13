extends GutTest
## v6 -> v7 (M17-04, docs/05_INTERFACES.md §6): the ten narrow areas replace the four wide ones. The area that no longer exists becomes
## the area that contains the level of the character; the fight and the Monolith in progress restart without any loss.

const Step := preload("res://core/save/migrations/migration_6_to_7.gd")


## xp that gives exactly `level` (the curve of the real balance).
func _xp_of(level: int) -> int:
	var data: GameData = TestFactory.real_data()
	return data.character_xp_table().xp_for_level(level)


func _v6(area: String, level: int, state: String = "encounter") -> Dictionary:
	return {"format_version": 6, "player_name": "x", "modules": {
		"character": {"class": "rift_blade", "xp": _xp_of(level)},
		"combat": {"state": state, "area": area, "player_hp": 40, "player_timer_ms": 100, "hand": 1, "between_ms": 0,
			"enemies": [{"monster": "shard_wraith", "hp": 12, "timer_ms": 300}], "effects": {"x": 1},
			"loot": {"stacks": [{"item": "rift_shard", "qty": 4}], "pieces": []}, "kills": {"plains_boar": 7}, "deaths": 2,
			"food_eaten": 5, "stone": {"since": 33, "pending": true, "stone_id": "whisper_wood_stone_30"},
			"skip_stone_level": 10, "wave": {"fired": [75]}},
		"fractures": {"run": {"return_area": "gone_area", "group": 2}, "pending": {}}}}


func test_the_save_is_migrated_to_the_current_version() -> void:
	var out: Dictionary = SaveMigrator.migrate(_v6("redrock_plains", 1))
	assert_eq(out["format_version"], SaveMigrator.CURRENT_VERSION)
	assert_eq(SaveMigrator.CURRENT_VERSION, 7)


func test_a_missing_area_becomes_the_area_of_the_character_level() -> void:
	var cases: Dictionary = {1: "redrock_plains", 10: "redrock_plains", 11: "whisper_wood", 37: "cracked_mines", 41: "ash_marsh",
			65: "rift_threshold", 80: "black_glass_desert", 99: "rift_heart"}
	for level: int in cases:
		var out: Dictionary = Step.migrate(_v6("old_area_that_is_gone", level))
		assert_eq(out["modules"]["combat"]["area"], cases[level], "level %d" % level)


func test_an_area_that_still_exists_is_kept() -> void:
	var out: Dictionary = Step.migrate(_v6("rift_threshold", 5))
	assert_eq(out["modules"]["combat"]["area"], "rift_threshold")


func test_the_fight_and_the_stone_restart_and_nothing_is_lost() -> void:
	var v6: Dictionary = _v6("gone", 70)
	var combat: Dictionary = Step.migrate(v6)["modules"]["combat"]
	assert_eq(combat["state"], "between")
	assert_eq(combat["enemies"], [])
	assert_false(combat.has("wave"), "no Monolith fight in progress")
	assert_eq(combat["stone"], {"since": 0, "pending": false, "stone_id": ""})
	assert_eq(combat["loot"], v6["modules"]["combat"]["loot"], "the bag stays")
	assert_eq(combat["kills"], {"plains_boar": 7})
	assert_eq([combat["deaths"], combat["food_eaten"], combat["skip_stone_level"]], [2, 5, 10])
	assert_eq(v6["modules"]["combat"]["state"], "encounter", "the input is not changed")


func test_an_idle_engine_keeps_its_empty_area() -> void:
	var v6: Dictionary = _v6("", 20, "idle")
	var combat: Dictionary = Step.migrate(v6)["modules"]["combat"]
	assert_eq(combat["state"], "idle")
	assert_eq(combat["area"], "")


func test_the_area_to_come_back_to_after_a_fracture_is_migrated_too() -> void:
	var out: Dictionary = Step.migrate(_v6("gone", 52))
	assert_eq(out["modules"]["fractures"]["run"]["return_area"], "weeping_gorge")
	assert_eq(out["modules"]["fractures"]["run"]["group"], 2, "the Fracture itself stays")


func test_a_v6_session_save_loads_in_the_current_game() -> void:
	var s: GameSession = autofree(TestFactory.session_no_kit(1, TestFactory.real_data()))
	var saved: Dictionary = s.to_save(1)
	saved["format_version"] = 6
	((saved["modules"] as Dictionary)["combat"] as Dictionary)["area"] = "cracked_mines"  # exists: kept
	var migrated: Dictionary = SaveMigrator.migrate(saved)
	assert_eq(migrated["format_version"], 7)
	var other: GameSession = autofree(TestFactory.session_no_kit(2, TestFactory.real_data()))
	assert_true(other.from_save(migrated).ok)
