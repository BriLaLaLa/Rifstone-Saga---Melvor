extends GutTest
## TrainersPage (M24-06, 05_INTERFACES_M24.md §7.o) on a TestFactory session with the real data (never `Game.session`, never a
## real slot): one row per discipline in two boxes with "n/2 posti", Learn / Train commands refreshed on `discipline_changed`,
## a refusal shown in MessageLabel, and `unbind` leaves the event bus as it was.

const SCENE: PackedScene = preload("res://ui/pages/trainers/trainers_page.tscn")
## `TestFactory.session` has the first two disciplines of each category learned: these two are free.
const FREE: StringName = &"angling"
const LEARNED: StringName = &"forestry"

var _session: GameSession
var _page: TrainersPage


func before_each() -> void:
	_session = TestFactory.session(1234, TestFactory.real_data())
	_page = SCENE.instantiate() as TrainersPage
	_page.page_id = &"trainers"
	add_child(_page)
	_page.bind(_session)


func after_each() -> void:
	if is_instance_valid(_page):
		_page.free()
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func _row(skill_id: StringName) -> TrainerRow:
	return _page.find_child("Trainer%s" % String(skill_id).to_pascal_case(), true, false) as TrainerRow


func test_one_row_per_discipline_in_two_boxes() -> void:
	var gathering: Node = _page.get_node("%GatheringRows")
	var artisan: Node = _page.get_node("%ArtisanRows")
	assert_eq(gathering.get_child_count(), _session.data.disciplines(&"gathering").size())
	assert_eq(artisan.get_child_count(), _session.data.disciplines(&"artisan").size())
	assert_not_null(_row(LEARNED))
	assert_true((_row(LEARNED).find_child("TrainButton", true, false) as Button).visible, "learned: grade button")
	assert_false((_row(LEARNED).find_child("LearnButton", true, false) as Button).visible)
	assert_true((_row(FREE).find_child("LearnButton", true, false) as Button).visible, "not learned: Learn")


func test_places_are_full_so_learning_is_refused_and_shows_the_reason() -> void:
	assert_true((_row(FREE).find_child("LearnButton", true, false) as Button).disabled, "no free place: disabled")
	_page.get_node("%MessageLabel").visible = false
	var result: CommandResult = _session.disciplines.learn(FREE)
	assert_false(result.ok)
	(_row(FREE).find_child("LearnButton", true, false) as Button).disabled = false
	(_row(FREE).find_child("LearnButton", true, false) as Button).pressed.emit()
	assert_true((_page.get_node("%MessageLabel") as Label).visible, "the refusal is shown")


func test_unlearning_frees_a_place_and_redraws_on_the_event() -> void:
	var result: CommandResult = _session.disciplines.unlearn(LEARNED)
	if not result.ok:
		_session.wallet.add_gold(10000000)
		result = _session.disciplines.unlearn(LEARNED)
	assert_true(result.ok)
	assert_true((_row(LEARNED).find_child("LearnButton", true, false) as Button).visible, "redrawn on discipline_changed")
	assert_false((_row(FREE).find_child("LearnButton", true, false) as Button).disabled, "a place is free now")


func test_unbind_disconnects_everything() -> void:
	var before: int = _session.events.get_signal_connection_list(&"discipline_changed").size()
	_page.unbind()
	assert_eq(_session.events.get_signal_connection_list(&"discipline_changed").size(), before - 1)
	_page.unbind()
