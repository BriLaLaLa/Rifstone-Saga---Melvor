extends GutTest
## M25-12 smoke: the Trainers page lists the Engraver among the productions ("drop dei mostri"), the Altar page says the
## Engraver is learned from the Trainers when it is not learned. Real data, TestFactory session (never a real slot).

const TRAINERS: PackedScene = preload("res://ui/pages/trainers/trainers_page.tscn")
const RIFT: PackedScene = preload("res://ui/pages/rift/rift_page.tscn")

var _session: GameSession
var _page: Page


func before_each() -> void:
	_session = TestFactory.session(1234, TestFactory.real_data())


func after_each() -> void:
	if is_instance_valid(_page):
		_page.free()
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func _open(scene: PackedScene, id: StringName) -> void:
	_page = scene.instantiate() as Page
	_page.page_id = id
	add_child(_page)
	_page.bind(_session)


func test_trainers_page_lists_the_engraver_with_drops_text() -> void:
	_open(TRAINERS, &"trainers")
	var row: Node = _page.find_child("Trainer%s" % String(RiftAltar.SKILL).to_pascal_case(), true, false)
	assert_not_null(row, "the Engraver is a production row")
	assert_eq((row.find_child("FedByLabel", true, false) as Label).text, TrainersTexts.FED_BY_DROPS_TEXT)


func test_altar_says_to_learn_the_engraver_when_not_learned() -> void:
	_session.wallet.add_gold(1000000)
	if _session.disciplines.is_learned(RiftAltar.SKILL):
		assert_true(_session.disciplines.unlearn(RiftAltar.SKILL).ok)
	_open(RIFT, &"rift")
	assert_string_contains((_page.find_child("IntroLabel", true, false) as Label).text, RiftTexts.NOT_LEARNED_TEXT)
	assert_eq((_page.find_child("CraftRunesButton", true, false) as Button).text, RiftTexts.LEARN_ENGRAVER_TEXT)
