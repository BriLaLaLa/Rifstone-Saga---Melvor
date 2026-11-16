extends GutTest
## v7 -> v8 (M24-03, docs/05_INTERFACES_M24.md §6b): helpers and Contracts go, the best disciplines are learned for free, the action lane
## becomes the production queue. Five v7 saves: gathering in progress, a recipe in progress, a project in progress, seven skills with xp,
## Contracts in the Bank and the loot bag.

const Step := preload("res://core/save/migrations/migration_7_to_8.gd")
const PFX: String = "con" + "tract_"
const SKILLS: Array[String] = ["forestry", "quarrying", "angling", "forging", "hearthcraft", "woodwright", "riftbinding"]


func _xp_of(level: int) -> int:
	return TestFactory.real_data().xp_table().xp_for_level(level)


func _v7(levels: Dictionary, lanes: Dictionary = {}) -> Dictionary:
	var skills: Dictionary = {}
	for id: String in SKILLS:
		skills[id] = {"xp": _xp_of(int(levels.get(id, 1))) if levels.has(id) else 0}
	return {"format_version": 7, "player_name": "x", "modules": {
		"skills": skills,
		"mastery": {"forestry": {"pool": 5, "actions": {"cut_redbirch": 10}, "nodes": []},
				"angling": {"pool": 7, "actions": {}, "nodes": []}, "forging": {"pool": 1, "actions": {}, "nodes": []}},
		"helpers": {"forestry": {"grade": "journeyman", "action": "cut_redbirch", "elapsed_ms": 4200}},
		"actions": {"lanes": lanes},
		"bank": {"stacks": [{"item": PFX + "forestry_master", "count": 2, "locked": false}, {"item": "redbirch_log", "count": 9, "locked": false}]}}}


func test_the_save_reaches_the_current_version() -> void:
	var out: Dictionary = SaveMigrator.migrate(_v7({}))
	assert_eq(out["format_version"], SaveMigrator.CURRENT_VERSION)
	assert_false((out["modules"] as Dictionary).has("helpers"))


## 1: gathering in progress -> no job; the two gathering skills with the most xp are learned, at the grade of their level.
func test_gathering_in_progress_and_the_grades_of_the_best_two() -> void:
	var lanes: Dictionary = {"main": {"skill": "forestry", "action": "cut_redbirch", "elapsed_ms": 1200}}
	var out: Dictionary = Step.migrate(_v7({"forestry": 27, "quarrying": 20, "angling": 61}, lanes))
	var m: Dictionary = out["modules"]
	assert_eq(m["disciplines"], {"learned": {"angling": 4, "forestry": 2}, "recipes": []}, "61 -> grade 4, 27 -> grade 2, quarrying out")
	assert_eq(m["actions"], {"jobs": [], "elapsed_ms": 0})
	assert_false((m["skills"] as Dictionary).has("quarrying"), "the discipline not learned loses its xp entry")
	assert_true((m["skills"] as Dictionary).has("forestry"))
	assert_false((m["mastery"] as Dictionary).has("quarrying"))


## 2: a recipe in progress keeps its skill first and becomes a repeating job with its elapsed time.
func test_a_recipe_in_progress_is_learned_first_and_becomes_a_repeating_job() -> void:
	var lanes: Dictionary = {"main": {"skill": "woodwright", "action": "carve_redbirch_grip", "elapsed_ms": 700}}
	var out: Dictionary = Step.migrate(_v7({"forging": 61, "hearthcraft": 40, "woodwright": 5}, lanes))
	var learned: Dictionary = out["modules"]["disciplines"]["learned"]
	assert_eq(learned, {"woodwright": 1, "forging": 4}, "the skill of the lane first, then by xp (cap 20 -> grade 1; 61 -> grade 4)")
	assert_eq(out["modules"]["actions"], {"jobs": [{"skill": "woodwright", "action": "carve_redbirch_grip", "remaining": 0,
			"repeat": true}], "elapsed_ms": 700})


## 3: a blueprint craft becomes a started project.
func test_a_project_in_progress_becomes_a_consumed_job() -> void:
	var lanes: Dictionary = {"main": {"skill": "forging", "action": "blueprint_craft", "elapsed_ms": 4000, "blueprint": "blueprint_sword_2",
			"chosen_affix": "keen", "duration_ms": 600000}}
	var out: Dictionary = Step.migrate(_v7({"forging": 99}, lanes))
	assert_eq(out["modules"]["disciplines"]["learned"], {"forging": 5})
	assert_eq(out["modules"]["actions"], {"jobs": [{"skill": "forging", "action": "blueprint_craft", "blueprint": "blueprint_sword_2",
			"chosen_affix": "keen", "duration_ms": 600000, "consumed": true}], "elapsed_ms": 4000})


## 4: seven skills with xp: two per category at most; the Incisore is untouched.
func test_seven_skills_with_xp() -> void:
	var levels: Dictionary = {}
	for id: String in SKILLS:
		levels[id] = 10
	levels["quarrying"] = 30
	levels["woodwright"] = 25
	var out: Dictionary = Step.migrate(_v7(levels))
	var learned: Dictionary = out["modules"]["disciplines"]["learned"]
	assert_eq(learned.size(), 4)
	assert_eq(learned["quarrying"], 2)
	assert_eq(learned["woodwright"], 2)
	assert_true(learned.has("forestry"), "ties by order: forestry before angling")
	assert_true(learned.has("forging"), "ties by order: forging before hearthcraft")
	assert_true((out["modules"]["skills"] as Dictionary).has("riftbinding"))
	assert_false(learned.has("riftbinding"))


## 5: the Contracts leave the Bank, the loot bag, the bags of the Fractures and the Dungeons, and the discoveries.
func test_the_contracts_are_removed_everywhere() -> void:
	var v7: Dictionary = _v7({"forestry": 10})
	var id: String = PFX + "angling_apprentice"
	var m: Dictionary = v7["modules"]
	m["combat"] = {"loot": {"stacks": [{"item": id, "qty": 1}, {"item": "boar_tusk", "qty": 2}], "pieces": []}}
	m["fractures"] = {"run": {"bag": {"stacks": [{"item": PFX + "quarrying_expert", "qty": 1}]}}, "pending": {"stacks": [{"item": id, "qty": 3}]}}
	m["dungeon"] = {"run": {"bag": {"stacks": [{"item": id, "qty": 1}, {"item": "rift_dust", "qty": 4}]}}, "pending": {"stacks": []}}
	m["discoveries"] = {"items": [id, "redbirch_log"]}
	var out: Dictionary = Step.migrate(v7)["modules"]
	assert_eq(out["bank"]["stacks"], [{"item": "redbirch_log", "count": 9, "locked": false}])
	assert_eq(out["combat"]["loot"]["stacks"], [{"item": "boar_tusk", "qty": 2}])
	assert_eq(out["fractures"]["run"]["bag"]["stacks"], [])
	assert_eq(out["fractures"]["pending"]["stacks"], [])
	assert_eq(out["dungeon"]["run"]["bag"]["stacks"], [{"item": "rift_dust", "qty": 4}])
	assert_eq(out["discoveries"]["items"], ["redbirch_log"])
	assert_eq(v7["modules"]["bank"]["stacks"].size(), 2, "the input is not changed")


func test_there_are_twelve_contract_ids() -> void:
	assert_eq(Step.contract_ids().size(), 12)


func test_a_migrated_save_loads_and_round_trips() -> void:
	var lanes: Dictionary = {"main": {"skill": "forging", "action": "smelt_emberbronze", "elapsed_ms": 500}}
	var out: Dictionary = SaveMigrator.migrate(_v7({"forging": 30, "forestry": 12}, lanes))
	out.merge({"slot": 1, "created_at_unix_ms": 0, "play_time_ms": 0, "rng": {"seed": 1, "state": "1"}}, false)
	var s: GameSession = autofree(TestFactory.session_no_kit(2, TestFactory.real_data()))
	assert_true(s.from_save(out).ok)
	assert_eq(s.disciplines.grade(&"forging"), 2)
	assert_true(s.actions.is_running())
	assert_eq(s.actions.current()["elapsed_ms"], 500)
	assert_eq(s.skills.get_level(&"forestry"), 12)
