extends GutTest
## Lesson "an object lives in one place" for the Fractures (docs/03_ARCHITECTURE.md §12, docs/05_INTERFACES.md §5.23): a Card
## leaves the Deposit once, when it is opened; every piece and Card of the bag ends in exactly one place (Armory / Deposit,
## the pending bag, or lost); nothing is created by a delivery and nothing is delivered twice. Fixtures with 3 groups.

const RUNS: int = 6
const GROUPS: int = 3

var _finished: Array = []
var _peak: Array = [0, 0, 0]
var _salvaged: int = 0


func _session(seed_value: int) -> GameSession:
	var s: GameSession = autofree(FractureUtil.session(seed_value, GROUPS))
	_finished = []
	_peak = [0, 0, 0]
	_salvaged = 0
	s.events.fracture_finished.connect(func(o: StringName, _g: int, _n: int, c: int, p: int) -> void: _finished.append([o, c, p]))
	s.events.fracture_bag_changed.connect(func(a: int, p: int, c: int) -> void: _peak = [maxi(a, _peak[0]), maxi(p, _peak[1]), maxi(c, _peak[2])])
	s.events.item_salvaged.connect(func(_u: int, _b: StringName, _auto: bool) -> void: _salvaged += 1)
	return s


func _fight(s: GameSession, uid: int) -> void:
	_peak = [0, 0, 0]
	_salvaged = 0
	assert_true(s.fractures.open(uid).ok)
	FractureUtil.run_until(s, func() -> bool: return not s.combat.in_fracture())


func _uids(s: GameSession) -> Array[int]:
	var result: Array[int] = []
	for inst: ItemInstance in s.armory.instances():
		result.append(inst.uid)
	return result


func test_opening_takes_the_card_out_of_the_deposit_exactly_once() -> void:
	var s: GameSession = _session(31)
	FractureUtil.hero(s)
	var uid: int = FractureUtil.card(s, 1)
	var other: int = FractureUtil.card(s, 2)
	assert_eq(s.cards.used(), 2)
	assert_true(s.fractures.open(uid).ok)
	assert_eq(s.cards.used(), 1, "one Card left the Deposit")
	assert_true(s.cards.has(other))
	assert_false(s.cards.has(uid))
	assert_false(s.fractures.open(uid).ok, "the same Card cannot be opened twice")
	assert_false(s.fractures.open(other).ok, "no second Fracture while one is in progress")
	assert_eq(s.cards.used(), 1)


func test_every_piece_and_card_of_a_won_bag_arrives_once() -> void:
	var s: GameSession = _session(32)
	FractureUtil.hero(s)
	var pieces_before: int = s.armory.used()
	var cards_before: int = 0
	var delivered_pieces: int = 0
	var delivered_cards: int = 0
	for i: int in RUNS:
		var uid: int = FractureUtil.card(s, 1 + i % 3)
		cards_before = s.cards.used() - 1
		_fight(s, uid)
		var done: Array = _finished[_finished.size() - 1]
		assert_eq(done[0], &"won")
		assert_eq(_peak[1], done[2], "the bag counted the same pieces it reports")
		assert_eq(_peak[2], done[1], "the bag counted the same Cards it reports")
		delivered_pieces += int(done[2])
		delivered_cards += int(done[1])
		assert_eq(s.cards.used(), cards_before + int(done[1]), "run %d: Cards in the Deposit" % i)
		for card: MapCard in s.cards.cards():
			assert_gt(card.uid, 0, "delivered Cards got a uid")
	assert_eq(s.armory.used() - pieces_before, delivered_pieces)
	var seen: Dictionary = {}
	for uid: int in _uids(s):
		assert_false(seen.has(uid), "piece uid %d appears once" % uid)
		seen[uid] = true
	var card_seen: Dictionary = {}
	for card: MapCard in s.cards.cards():
		assert_false(card_seen.has(card.uid), "Card uid %d appears once" % card.uid)
		card_seen[card.uid] = true


func test_a_lost_bag_creates_nothing() -> void:
	var s: GameSession = _session(33)
	FractureUtil.weakling(s)
	var pieces_before: int = s.armory.used()
	var bank_before: Dictionary = s.bank.to_save()
	for i: int in 3:
		_fight(s, FractureUtil.card(s, 1))
		assert_eq(_finished[_finished.size() - 1][0], &"died")
	assert_eq(s.armory.used(), pieces_before)
	assert_eq(s.cards.used(), 0)
	assert_eq(s.bank.to_save(), bank_before)
	assert_false(s.fractures.has_pending())


func test_the_pending_bag_is_delivered_once_and_only_once() -> void:
	var s: GameSession = _session(34)
	FractureUtil.hero(s)
	var room: Array[int] = [0]
	s.deposit.register_occupant(&"test:squeeze", func() -> int: return room[0])
	var uid: int = FractureUtil.card(s, 1)
	# Take every free box away: whatever the bag holds cannot enter.
	room[0] = 100000
	var pieces_before: int = s.armory.used()
	var cards_before: int = s.cards.used() - 1
	_fight(s, uid)
	var done: Array = _finished[_finished.size() - 1]
	assert_eq(done[0], &"won")
	var pending: Dictionary = s.fractures.pending()
	var waiting_pieces: int = int(pending.get("pieces", 0))
	var waiting_cards: int = int(pending.get("cards", 0))
	assert_eq(s.armory.used() - pieces_before + _salvaged, int(done[2]), "pieces: delivered + dismantled = bag (pieces never wait)")
	assert_eq(waiting_pieces, 0)
	assert_eq(s.cards.used() - cards_before + waiting_cards, int(done[1]), "Cards: delivered + waiting = bag")
	assert_true(s.fractures.has_pending() or int(done[1]) + int(done[2]) == 0 or waiting_pieces + waiting_cards == 0)
	room[0] = -100000
	var armory_after: int = s.armory.used()
	var cards_after: int = s.cards.used()
	var collected: CommandResult = s.fractures.collect()
	if waiting_pieces + waiting_cards + (pending.get("stacks", []) as Array).size() > 0:
		assert_true(collected.ok, "room again: the collection works")
	assert_false(s.fractures.has_pending())
	assert_eq(s.armory.used() - armory_after, waiting_pieces)
	assert_eq(s.cards.used() - cards_after, waiting_cards)
	assert_false(s.fractures.collect().ok, "a second collection finds nothing")
	assert_eq(s.armory.used() - pieces_before + _salvaged, int(done[2]), "in the end every piece is in the Armory once or dismantled once")
