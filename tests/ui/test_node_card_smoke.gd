extends GutTest
## Smoke test of NodeCard (M25-04, 05_INTERFACES_M25.md §7.p) on fake combat states: the nodes of the contract exist,
## `refresh` draws a worked node, a rich node and a skipped one (not learned, too hard). No game state, no real slot.

const SKILL: StringName = &"forestry"

var _session: GameSession
var _card: NodeCard


func before_each() -> void:
	_session = TestFactory.session(1234, TestFactory.real_data())
	_card = add_child_autofree(NodeCard.new()) as NodeCard


func after_each() -> void:
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func _state(node: Dictionary) -> Dictionary:
	var base: Dictionary = {"skill": SKILL, "action": &"cut_redbirch", "duration_ms": 10000, "elapsed_ms": 2500, "skipped": false,
			"skip_reason": &"", "color": &"yellow", "attempts": 3, "attempt": 1, "rich": false, "units": 4, "units_planned": 12,
			"last_attempt": {"units": 4, "color": &"yellow", "xp": 7}}
	base.merge(node, true)
	return {"state": &"node", "node": base}


func test_worked_node_shows_art_pips_bar_and_loot() -> void:
	_card.refresh(_state({}), _session.data)
	assert_true(_card.visible)
	assert_not_null(_card.find_child("NodeSprite", true, false))
	assert_not_null(_card.find_child("NodeParticles", true, false))
	assert_not_null(_card.find_child("AttemptPip_3", true, false))
	assert_null(_card.find_child("AttemptPip_4", true, false))
	assert_almost_eq((_card.find_child("TimeBar", true, false) as ProgressBar).value, 0.25, 0.0001)
	assert_eq((_card.find_child("LootList", true, false) as Control).get_child_count(), 1)
	assert_false((_card.find_child("RichBadge", true, false) as Control).visible)
	assert_false((_card.find_child("LockedLabel", true, false) as Control).visible)
	_card.on_attempt_done(SKILL, &"cut_redbirch", 1, 3, 4, 4, &"yellow")


func test_rich_node_shows_the_badge_and_more_pips() -> void:
	_card.refresh(_state({"rich": true, "attempts": 4}), _session.data)
	assert_true((_card.find_child("RichBadge", true, false) as Control).visible)
	assert_not_null(_card.find_child("AttemptPip_4", true, false))


func test_skipped_node_shows_the_locked_form() -> void:
	for reason: StringName in [Reasons.NOT_LEARNED, Reasons.TOO_HARD]:
		_card.refresh(_state({"skipped": true, "skip_reason": reason}), _session.data)
		assert_true((_card.find_child("LockedLabel", true, false) as Control).visible)
		assert_false((_card.find_child("NodeArt", true, false) as Control).visible)
	_card.refresh({"state": &"travel", "node": {}}, _session.data)
	assert_false(_card.visible, "hidden outside the node state")
