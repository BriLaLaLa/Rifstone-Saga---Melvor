extends GutTest
## M34-01 (docs/M34_DEPOSITO_E_SALTA.md §2-§3, docs/05_INTERFACES_M30.md §5.41): skip_tutorial on the real data and a real new game.

const Play := preload("res://tests/integration/test_tutorial_playthrough.gd")
const AREA: StringName = &"redrock_plains"
const TWELVE_H: int = 12 * 3_600_000


func _new() -> GameSession:
	return autofree(Play.new_game_session(7001))


## A session sitting at step `index` (as a load: no gift of the step, the mail holds the gift of step 0 only).
func _at(index: int) -> GameSession:
	var s: GameSession = _new()
	var step_id: StringName = s.data.tutorial_steps()[index].id
	s.tutorial.from_save({"completed": false, "step": String(step_id), "progress": 0, "since_ms": 0, "visited": [], "starter": {}})
	return s


func _mail_totals(s: GameSession) -> Dictionary:
	var totals: Dictionary = {}
	for m: Dictionary in s.mail.messages():
		var fields: Variant = m.get("fields", m)
		if fields is Dictionary:
			var money: int = int((fields as Dictionary).get("money", 0))
			if money > 0:
				totals["money"] = int(totals.get("money", 0)) + money
			for row: Variant in (fields as Dictionary).get("items", []):
				var key: String = str((row as Dictionary)["item"])
				totals[key] = int(totals.get(key, 0)) + int((row as Dictionary)["qty"])
	return totals


func _gifts_after(s: GameSession, index: int) -> Dictionary:
	var totals: Dictionary = {}
	var steps: Array[TutorialStepDef] = s.data.tutorial_steps()
	for i: int in range(index + 1, steps.size()):
		if steps[i].gift_money > 0:
			totals["money"] = int(totals.get("money", 0)) + steps[i].gift_money
		elif not steps[i].gift_items.is_empty():
			for q: ItemQty in steps[i].gift_items:
				totals[str(q.item_id)] = int(totals.get(str(q.item_id), 0)) + q.qty
	return totals


func _expected(before: Dictionary, add: Dictionary) -> Dictionary:
	var out: Dictionary = before.duplicate()
	for k: Variant in add:
		out[k] = int(out.get(k, 0)) + int(add[k])
	return out


func test_skip_completes_once_and_activates_the_starter() -> void:
	var s: GameSession = _new()
	var completed: Array[int] = [0]
	s.events.tutorial_completed.connect(func() -> void: completed[0] += 1)
	var r: CommandResult = s.tutorial.skip_tutorial()
	assert_true(r.ok)
	assert_true(s.tutorial.is_completed())
	assert_eq(completed[0], 1)
	assert_true(s.tutorial.starter.is_enabled())
	var mail_before: int = s.mail.count()
	var again: CommandResult = s.tutorial.skip_tutorial()
	assert_false(again.ok)
	assert_eq(again.reason, Reasons.TUTORIAL_INACTIVE)
	assert_eq(completed[0], 1)
	assert_eq(s.mail.count(), mail_before)


func test_skip_from_every_step_frees_the_combat() -> void:
	var n: int = Play.new_game_session(1).data.tutorial_steps().size()
	assert_eq(n, 22)
	for i: int in n:
		var s: GameSession = _at(i)
		assert_true(s.tutorial.skip_tutorial().ok, "step %d" % i)
		assert_false(s.combat.is_frozen(), "frozen %d" % i)
		assert_false(s.combat.is_force_node(), "node %d" % i)
		assert_true(s.combat.force_pack().is_empty(), "pack %d" % i)
		assert_false(s.combat.is_guarded(), "guarded %d" % i)
		s.free()


func test_gifts_of_the_following_steps_are_mailed_once() -> void:
	var n: int = Play.new_game_session(1).data.tutorial_steps().size()
	for i: int in [0, 3, 9, 15, n - 1]:
		var s: GameSession = _at(i)
		var before: Dictionary = _mail_totals(s)
		s.tutorial.skip_tutorial()
		var want: Dictionary = _expected(before, _gifts_after(s, i))
		assert_eq(_mail_totals(s), want, "step %d" % i)
		s.tutorial.skip_tutorial()
		assert_eq(_mail_totals(s), want, "second skip %d" % i)
		var twin: GameSession = autofree(Play.new_game_session(7001))
		twin.mail.from_save(s.mail.to_save())
		twin.tutorial.from_save(JSON.parse_string(JSON.stringify(s.tutorial.to_save())) as Dictionary)
		assert_eq(_mail_totals(twin), want, "reload %d" % i)
		s.free()
	var last: GameSession = _at(n - 1)
	var count: int = last.mail.count()
	last.tutorial.skip_tutorial()
	assert_eq(last.mail.count(), count, "no gift from the last step")


func test_save_keys_are_unchanged() -> void:
	var s: GameSession = _at(5)
	var keys_before: Array = s.tutorial.to_save().keys()
	s.tutorial.skip_tutorial()
	var saved: Dictionary = s.tutorial.to_save()
	assert_eq(saved.keys(), keys_before)
	assert_true(saved["completed"])
	var twin: GameSession = autofree(Play.new_game_session(7001))
	twin.tutorial.from_save(JSON.parse_string(JSON.stringify(saved)) as Dictionary)
	assert_true(twin.tutorial.is_completed())
	assert_eq(JSON.stringify(twin.tutorial.to_save()), JSON.stringify(saved))


func test_starter_quests_and_final_bonus_work_after_skip() -> void:
	var s: GameSession = _at(4)
	s.tutorial.skip_tutorial()
	var st: StarterQuests = s.tutorial.starter
	assert_gt(st.total(), 0)
	assert_false(st.is_final_available())
	assert_eq(st.can_claim_final().reason, Reasons.QUEST_INCOMPLETE)


func test_offline_12h_after_skip_equals_stepped_blocks() -> void:
	var a: GameSession = _new()
	a.tutorial.skip_tutorial()
	assert_true(a.combat.start(AREA).ok)
	a.advance(TWELVE_H)
	var c: GameSession = autofree(Play.new_game_session(7001))
	c.tutorial.skip_tutorial()
	assert_true(c.combat.start(AREA).ok)
	for i: int in TWELVE_H / 60_000:
		c.advance(60_000)
	assert_eq(JSON.stringify(a.to_save(0)), JSON.stringify(c.to_save(0)))
	assert_eq(JSON.stringify(a.combat.total_kills()), JSON.stringify(c.combat.total_kills()))
