extends GutTest
## Smoke test of the piece tooltip (M35-A): built for a worn and a candidate piece, with the comparison only on the
## candidate, and the level badge shown on a cell. Real data, no exact texts.

var _session: GameSession


func before_each() -> void:
	_session = TestFactory.session(1234, TestFactory.real_data())


func after_each() -> void:
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func test_tooltip_is_built_and_compares_only_the_candidate() -> void:
	var worn: int = TestFactory.give_piece(_session, &"emberbronze_sword", &"magic", 12)
	_session.equipment.equip(worn)
	var candidate: int = TestFactory.give_piece(_session, &"emberbronze_sword", &"rare", 48)
	var tip_worn: String = PieceTooltip.build(_session, worn)
	var tip_candidate: String = PieceTooltip.build(_session, candidate)
	assert_ne(tip_worn, "")
	assert_false(tip_worn.contains(ArmoryTexts.COMPARISON_TITLE.substr(0, 8)), "worn piece: no comparison")
	assert_true(tip_candidate.contains(ArmoryTexts.COMPARISON_TITLE.substr(0, 8)), "candidate: comparison")
	assert_eq(PieceTooltip.build(_session, 999), "")


func test_level_badge_is_shown_and_hidden() -> void:
	var cell: PanelContainer = PanelContainer.new()
	add_child_autofree(cell)
	LevelBadge.show_on(cell, 42)
	assert_ne(LevelBadge.text_of(cell), "")
	LevelBadge.show_on(cell, 0)
	assert_eq(LevelBadge.text_of(cell), "")
