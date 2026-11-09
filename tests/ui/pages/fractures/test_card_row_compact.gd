extends GutTest
## CardRow compact (M14-09, docs/01_GDD.md §29): one line per modifier (name, risk and reward side by side) and the risk
## points over the cap of the grade in the card's sub line (F-123). Fixture session of the Fractures tests.

const SCENE: PackedScene = preload("res://ui/pages/fractures/fractures_page.tscn")

var _s: GameSession
var _page: FracturesPage


func before_each() -> void:
	_s = FractureUtil.session(5)
	FractureUtil.hero(_s)
	_page = SCENE.instantiate() as FracturesPage
	_page.page_id = &"fractures"
	add_child(_page)


func after_each() -> void:
	if is_instance_valid(_page):
		_page.free()
	if is_instance_valid(_s):
		_s.free()
	await wait_physics_frames(1)


func _row() -> CardRow:
	for child: Node in (_page.get_node("%CardsList") as Node).get_children():
		if child is CardRow and not child.is_queued_for_deletion():
			return child as CardRow
	return null


func test_a_modifier_is_one_horizontal_line_with_name_risk_and_reward() -> void:
	FractureUtil.card(_s, 2, [["sturdy", 5]])
	_page.bind(_s)
	var block: Node = _row().find_child("Mod_sturdy", true, false)
	assert_true(block is HBoxContainer, "name, risk and reward on the same row")
	for child_name: String in ["ModName", "Risk", "Reward"]:
		assert_not_null(block.find_child(child_name, true, false), child_name)
		assert_eq(block.find_child(child_name, true, false).get_parent(), block)


func test_each_modifier_takes_one_line() -> void:
	FractureUtil.card(_s, 3, [["sturdy", 2], ["pack_bonus", 2]])
	_page.bind(_s)
	var row: CardRow = _row()
	var mods: int = 0
	for node: Node in row.find_children("Mod_*", "HBoxContainer", true, false):
		mods += 1
	assert_eq(mods, MapCardRoller.effects(_s.cards.cards()[0], _s.data).size())
	assert_gt(mods, 0)


func test_card_is_lower_than_one_with_stacked_labels() -> void:
	FractureUtil.card(_s, 3, [["sturdy", 2], ["pack_bonus", 2]])
	_page.bind(_s)
	var row: CardRow = _row()
	row.size = Vector2(900, 10)
	await wait_physics_frames(2)
	var stacked_height: float = 0.0
	for node: Node in row.find_children("Mod_*", "HBoxContainer", true, false):
		var block: Control = node as Control
		stacked_height += block.get_combined_minimum_size().y * 3.0
	var info: Control = row.find_child("GradeLabel", true, false).get_parent() as Control
	var mods_height: float = 0.0
	for node: Node in row.find_children("Mod_*", "HBoxContainer", true, false):
		mods_height += (node as Control).get_combined_minimum_size().y
	assert_lt(mods_height, stacked_height, "one row per modifier instead of three")
	assert_not_null(info)


func test_sub_line_shows_the_risk_over_the_cap_of_the_grade() -> void:
	var uid: int = FractureUtil.card(_s, 2, [["sturdy", 5]])
	_page.bind(_s)
	var card: MapCard = _s.cards.get_card(uid)
	var expected: String = FractureTexts.risk_total_text(card, _s.data)
	assert_string_contains((_row().find_child("GradeLabel", true, false) as Label).text, expected)
	assert_string_contains(expected, NumberFormat.format_number(snappedf(MapCardRoller.risk_cap(2, _s.data), 0.1)))
	assert_string_contains(expected, NumberFormat.format_number(snappedf(
			MapCardRoller.total_risk_points(card.mods, _s.data), 0.1)))
