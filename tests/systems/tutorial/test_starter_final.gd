extends GutTest
## The final bonus of the starter quests (docs/M31_RITOCCHI_TUTORIAL.md §5) on the fixture quests: availability, the refusals in order,
## the delivery by Mail, the save (additive, no new version).

var _s: GameSession
var _q: StarterQuests


func before_each() -> void:
	_s = autofree(TestFactory.session(1234))
	_q = _s.tutorial.starter
	watch_signals(_s.events)


func _all_ids() -> Array:
	var ids: Array = []
	for def: StarterQuestDef in _q.quests():
		ids.append(String(def.id))
	return ids


func _load_starter(claimed: Array, final_claimed: Variant = null) -> void:
	var block: Dictionary = {"claimed": claimed, "progress": {}}
	if final_claimed != null:
		block["final_claimed"] = final_claimed
	_s.tutorial.from_save({"completed": true, "step": "", "visited": [], "starter": block})


func test_available_only_when_every_quest_is_claimed() -> void:
	assert_false(_q.is_final_available())
	_load_starter(_all_ids().slice(1))
	assert_false(_q.is_final_available())
	_load_starter(_all_ids())
	assert_true(_q.is_final_available())
	assert_false(_q.all_done(), "the box stays until the bonus is claimed")
	assert_not_null(_q.final_reward())


func test_claim_delivers_items_by_mail_and_xp() -> void:
	_load_starter(_all_ids())
	var xp_before: int = _s.character.get_xp()
	var mail_before: int = _s.mail.count()
	assert_true(_q.claim_final().ok)
	assert_eq(_s.mail.count(), mail_before + 1)
	var m: Dictionary = _s.mail.messages()[_s.mail.messages().size() - 1]
	assert_eq(m["kind"], &"starter_reward")
	assert_eq((m["items"] as Array).size(), _q.final_reward().reward_items.size())
	assert_gt(_s.character.get_xp(), xp_before)
	assert_true(_q.is_final_claimed())
	assert_false(_q.is_final_available())
	assert_true(_q.all_done())
	assert_signal_emitted(_s.events, "starter_quests_changed")
	assert_eq(_q.claim_final().reason, Reasons.ALREADY_CLAIMED)
	assert_eq(_s.mail.count(), mail_before + 1)


func test_refusals_in_order() -> void:
	var s: GameSession = autofree(TestFactory.session(1, null, false, true))
	assert_eq(s.tutorial.starter.can_claim_final().reason, Reasons.TUTORIAL_INACTIVE)
	assert_eq(s.tutorial.starter.claim_final().reason, Reasons.TUTORIAL_INACTIVE)
	_load_starter(_all_ids().slice(1))
	assert_eq(_q.can_claim_final().reason, Reasons.QUEST_INCOMPLETE)
	_load_starter(_all_ids(), true)
	assert_eq(_q.can_claim_final().reason, Reasons.ALREADY_CLAIMED, "already_claimed comes before quest_incomplete and mailbox_full")
	_load_starter(_all_ids())
	for i: int in _s.mail.capacity():
		_s.mail.post(&"auction_sold", {"item": &"test_twig", "qty": 1, "listing": i + 1, "money": 1})
	var xp_before: int = _s.character.get_xp()
	assert_eq(_q.claim_final().reason, Reasons.MAILBOX_FULL)
	assert_eq(_s.character.get_xp(), xp_before, "nothing changed")
	assert_false(_q.is_final_claimed())


func test_save_round_trip_and_old_slots() -> void:
	assert_false(_q.to_save()["final_claimed"], "always written")
	_load_starter(_all_ids())
	assert_true(_q.claim_final().ok)
	var saved: Dictionary = _s.tutorial.to_save()
	assert_true(saved["starter"]["final_claimed"])
	var twin: GameSession = autofree(TestFactory.session(1234))
	twin.tutorial.from_save(saved)
	assert_true(twin.tutorial.starter.is_final_claimed())
	_load_starter(_all_ids())  # a v12 slot from before M31: no key
	assert_false(_q.is_final_claimed())
	assert_true(_q.is_final_available(), "a 20/20 slot sees the bonus available")
	_load_starter(_all_ids(), "yes")
	assert_false(_q.is_final_claimed(), "not a boolean: not claimed")
