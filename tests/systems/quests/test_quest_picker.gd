extends GutTest
## F-135 (docs/02_FORMULAS.md §5i): QuestPicker with the real quests: tier window, memory of the recent ones, cursor, requirements.

var _quests: Array[QuestDef]
var _params: Dictionary
var _none: Array[StringName] = []


func before_all() -> void:
	var data: GameData = TestFactory.real_data()
	_quests = data.quests()
	_params = data.balance_value("quest") as Dictionary


func _levels(level: int) -> Dictionary:
	var levels: Dictionary = {}
	for skill: String in ["forestry", "quarrying", "angling", "forging", "hearthcraft", "woodwright"]:
		levels[StringName(skill)] = level
	return levels


# Every candidate in the order the picker gives them (active grows, no memory).
func _all_candidates(level: int, skills: Dictionary) -> Array[StringName]:
	var active: Array[StringName] = []
	var cursor: int = 0
	while true:
		var choice: Dictionary = QuestPicker.pick(_quests, cursor, _none, active, level, skills, _params)
		if (choice["id"] as StringName) == &"":
			break
		active.append(choice["id"] as StringName)
		cursor = int(choice["cursor"])
	return active


func test_current_tier_from_character_level() -> void:
	var levels: Array = _params["tier_levels"]
	assert_eq(QuestPicker.current_tier(1, levels), 1)
	assert_eq(QuestPicker.current_tier(9, levels), 1)
	assert_eq(QuestPicker.current_tier(10, levels), 2)
	assert_eq(QuestPicker.current_tier(45, levels), 5)
	assert_eq(QuestPicker.current_tier(99, levels), 8)
	assert_eq(QuestPicker.current_tier(0, levels), 0)


func test_character_1_gets_only_tier_1_in_file_order() -> void:
	var picked: Array[StringName] = _all_candidates(1, _levels(1))
	assert_eq(picked.size(), 7)
	assert_eq(picked[0], &"kill_any_t1")
	assert_eq(picked[1], &"gather_forestry_t1")
	assert_eq(picked[2], &"gather_quarrying_t1")
	var first: Dictionary = QuestPicker.pick(_quests, 0, _none, _none, 1, _levels(1), _params)
	assert_eq(first["cursor"], 1, "cursor = index + 1")


func test_recent_memory_skips_then_is_ignored_when_alone() -> void:
	var active: Array[StringName] = [&"gather_forestry_t1", &"gather_quarrying_t1"]
	var recent: Array[StringName] = [&"kill_any_t1"]
	var choice: Dictionary = QuestPicker.pick(_quests, 0, recent, active, 1, _levels(1), _params)
	assert_eq(choice["id"], &"gather_angling_t1", "kill_any_t1 is in recent")
	var everything: Array[StringName] = []
	for id: StringName in _all_candidates(1, _levels(1)):
		if id != &"kill_any_t1":
			everything.append(id)
	var last: Dictionary = QuestPicker.pick(_quests, 0, recent, everything, 1, _levels(1), _params)
	assert_eq(last["id"], &"kill_any_t1", "the memory is ignored when nobody else qualifies")


func test_no_candidate_keeps_the_cursor() -> void:
	var all: Array[StringName] = _all_candidates(1, _levels(1))
	var choice: Dictionary = QuestPicker.pick(_quests, 5, _none, all, 1, _levels(1), _params)
	assert_eq(choice["id"], &"")
	assert_eq(choice["cursor"], 5)
	var empty: Array[QuestDef] = []
	assert_eq(QuestPicker.pick(empty, 3, _none, _none, 1, {}, _params)["cursor"], 3)


func test_window_and_skill_requirement_at_character_45() -> void:
	var skills: Dictionary = _levels(45)
	var picked: Array[StringName] = _all_candidates(45, skills)
	assert_false(picked.has(&"kill_any_t2"), "tier 2 < 5 - 2")
	assert_true(picked.has(&"kill_any_t3"))
	assert_true(picked.has(&"gather_forestry_t5"))
	assert_false(picked.has(&"kill_any_t6"), "character 45 is tier 5")
	skills[&"forestry"] = 44
	assert_false(_all_candidates(45, skills).has(&"gather_forestry_t5"), "Forestry 44 < 45")
