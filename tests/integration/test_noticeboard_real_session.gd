extends GutTest
## NoticeboardPage bound to the real GameSession / Quests / GameData (docs/05_INTERFACES.md §5.28, §7.s): the QuestDef
## fields the row reads exist, a claim from the page pays, and the board survives a save and load.

const SCENE: PackedScene = preload("res://ui/pages/noticeboard/noticeboard_page.tscn")

var _session: GameSession
var _page: NoticeboardPage


func before_each() -> void:
	_session = TestFactory.session_no_kit(5, TestFactory.real_data())
	add_child(_session)
	_page = SCENE.instantiate()
	add_child(_page)
	_page.bind(_session)


func after_each() -> void:
	if is_instance_valid(_page):
		_page.free()
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func _board(level: int) -> void:
	var mod: Modifier = Modifier.from_dict({"stat": "quest_slots", "value": float(level), "scope": "global"})
	_session.modifiers.set_source(&"test:board", [mod])


func _row(slot: int) -> Node:
	return _page.find_child("Rows", true, false).get_child(slot)


func test_page_claims_a_real_quest_and_survives_save_load() -> void:
	assert_true(_page.find_child("NoBoardLabel", true, false).visible)
	_board(2)
	assert_eq(_page.find_child("Rows", true, false).get_child_count(), 2)
	var def: QuestDef = _session.data.quest(_session.quests.quest_at(0))
	assert_not_null(def)
	assert_eq((_row(0).find_child("NameLabel", true, false) as Label).text, def.name)
	for i: int in _session.quests.target_at(0):
		_session.events.monster_killed.emit(0, &"any")
	var button: Button = _row(0).find_child("ClaimButton", true, false) as Button
	assert_not_null(button)
	assert_false(button.disabled)
	var gold_before: int = _session.wallet.get_gold()
	button.pressed.emit()
	assert_eq(_session.quests.completed_total(), 1)
	assert_eq(_session.wallet.get_gold(), gold_before + def.reward_gold)
	var file: Dictionary = JSON.parse_string(JSON.stringify(_session.to_save(0))) as Dictionary
	assert_true(_session.from_save(file).ok)
	_board(2)
	assert_eq(_session.quests.completed_total(), 1)
	assert_ne(_session.quests.quest_at(0), &"")
