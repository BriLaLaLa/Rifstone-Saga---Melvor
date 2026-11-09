extends GutTest
## CardStore (docs/05_INTERFACES.md §5.23): add/create/uids, the Deposit (one box per Card, can_add, card_rejected), lock,
## F-114 salvage, take, the Bank refusing Cards, tolerant save. Fixture Deposit: 60 boxes.

const DUST: StringName = &"rift_dust"

var _session: GameSession = null
var _changes: Array = []
var _rejected: Array[int] = []


func before_each() -> void:
	_session = TestFactory.session(11)
	add_child_autofree(_session)
	_changes = []
	_rejected = []
	_session.events.card_changed.connect(func(uid: int, change: StringName) -> void: _changes.append([uid, change]))
	_session.events.card_rejected.connect(func(grade: int) -> void: _rejected.append(grade))


func _card(grade: int, rarity: StringName = &"common") -> MapCard:
	return MapCardRoller.create(grade, rarity, _session.data, RngService.new(grade * 7 + 1))


func _fill_deposit() -> void:
	var free: int = _session.deposit.free_slots()
	_session.deposit.register_occupant(&"test_filler", func() -> int: return free)


# --- add / create ----------------------------------------------------------------------------------------------------

func test_uids_start_at_1_and_are_never_reused() -> void:
	var first: int = _session.cards.add(_card(1))
	var second: int = _session.cards.add(_card(2))
	assert_eq([first, second], [1, 2])
	assert_not_null(_session.cards.take(first))
	assert_eq(_session.cards.add(_card(3)), 3, "uid 1 is not reused")
	assert_eq(_changes, [[1, &"added"], [2, &"added"], [1, &"removed"], [3, &"added"]])


func test_add_stores_a_copy_and_getters_return_copies() -> void:
	var card: MapCard = _card(4, &"magic")
	var uid: int = _session.cards.add(card)
	card.rarity = &"rare"
	var stored: MapCard = _session.cards.get_card(uid)
	assert_eq(stored.rarity, &"magic")
	assert_eq(stored.uid, uid)
	stored.locked = true
	assert_false(_session.cards.get_card(uid).locked, "a copy")
	assert_null(_session.cards.get_card(999))
	assert_eq(_session.cards.cards().size(), 1)
	assert_true(_session.cards.has(uid))


func test_add_rejects_a_non_card_and_null() -> void:
	assert_eq(_session.cards.add(null), 0)
	var bogus := MapCard.new()
	bogus.base_id = &"test_log"
	assert_eq(_session.cards.add(bogus), 0)
	assert_eq(_session.cards.used(), 0)


func test_create_rolls_a_card_of_the_grade() -> void:
	var uid: int = _session.cards.create(6, &"rare")
	var card: MapCard = _session.cards.get_card(uid)
	assert_eq(card.grade, 6)
	assert_eq(card.base_id, &"fracture_card_6")
	assert_between(card.mods.size(), 3, 4)
	assert_eq(_session.cards.create(0, &"common"), 0, "no base for the grade")
	assert_eq(_session.cards.create(11, &"common"), 0)


# --- the Deposit -----------------------------------------------------------------------------------------------------

func test_one_deposit_box_per_card() -> void:
	var before: int = _session.deposit.used()
	_session.cards.add(_card(1))
	_session.cards.add(_card(2))
	assert_eq(_session.cards.used(), 2)
	assert_eq(_session.deposit.used(), before + 2)
	assert_eq(_session.bank.free_boxes(), _session.deposit.capacity() - before - 2)


func test_can_add_follows_the_deposit() -> void:
	assert_true(_session.cards.can_add())
	assert_true(_session.cards.can_add(_session.deposit.free_slots()))
	assert_false(_session.cards.can_add(_session.deposit.free_slots() + 1))
	assert_false(_session.cards.can_add(-1))


func test_full_deposit_rejects_with_card_rejected_and_rolls_nothing() -> void:
	_fill_deposit()
	var rng_before: Dictionary = _session.rng.to_save()
	assert_eq(_session.cards.add(_card(3)), 0)
	assert_eq(_session.cards.create(5, &"rare"), 0)
	assert_eq(_rejected, [3, 5])
	assert_eq(_session.cards.used(), 0)
	assert_eq(_session.rng.to_save(), rng_before, "a rejected create consumes no draw")


func test_deposit_changed_is_announced() -> void:
	var seen: Array[int] = []
	_session.events.deposit_changed.connect(func(used: int, _capacity: int) -> void: seen.append(used))
	var base: int = _session.deposit.used()
	_session.cards.add(_card(1))
	assert_eq(seen, [base + 1])


func test_the_bank_refuses_cards() -> void:
	var result: CommandResult = _session.bank.add(&"fracture_card_1", 1)
	assert_false(result.ok)
	assert_eq(result.reason, Reasons.NOT_STACKABLE)
	assert_eq(_session.bank.get_count(&"fracture_card_1"), 0)


# --- lock ------------------------------------------------------------------------------------------------------------

func test_set_locked() -> void:
	var uid: int = _session.cards.add(_card(1))
	assert_eq(_session.cards.set_locked(999, true).reason, Reasons.UNKNOWN_ID)
	assert_true(_session.cards.set_locked(uid, true).ok)
	assert_true(_session.cards.get_card(uid).locked)
	assert_true(_session.cards.set_locked(uid, true).ok, "same value: no event")
	assert_eq(_changes, [[uid, &"added"], [uid, &"updated"]])


# --- F-114 salvage -----------------------------------------------------------------------------------------------------

func test_salvage_examples() -> void:
	assert_eq(_session.cards.salvage_dust(3, &"rare"), 30, "F-114: grade 3 rare -> 30")
	assert_eq(_session.cards.salvage_dust(1, &"common"), 5, "grade 1 common -> 5")
	assert_eq(_session.cards.salvage_dust(4, &"magic"), 30, "grade 4 magic -> 30")


func test_salvage_pays_dust_and_removes_the_card() -> void:
	var uid: int = _session.cards.add(_card(3, &"rare"))
	var used_before: int = _session.deposit.used()
	assert_true(_session.cards.salvage(uid).ok)
	assert_eq(_session.bank.get_count(DUST), 30)
	assert_false(_session.cards.has(uid))
	assert_eq(_changes.back(), [uid, &"removed"])
	assert_eq(_session.deposit.used(), used_before, "the Card box is freed, the Dust takes one")


func test_salvage_errors() -> void:
	assert_eq(_session.cards.salvage(5).reason, Reasons.UNKNOWN_ID)
	var uid: int = _session.cards.add(_card(2))
	_session.cards.set_locked(uid, true)
	assert_eq(_session.cards.salvage(uid).reason, Reasons.ITEM_LOCKED)
	assert_true(_session.cards.has(uid))
	_session.cards.set_locked(uid, false)
	_fill_deposit()
	var result: CommandResult = _session.cards.salvage(uid)
	assert_eq(result.reason, Reasons.BANK_FULL, "no room for a new Dust stack")
	assert_true(_session.cards.has(uid), "nothing changed")
	assert_eq(_session.bank.get_count(DUST), 0)


func test_salvage_with_dust_already_in_the_bank_needs_no_box() -> void:
	TestFactory.give(_session, DUST, 1)
	var uid: int = _session.cards.add(_card(1))
	_fill_deposit()
	assert_true(_session.cards.salvage(uid).ok)
	assert_eq(_session.bank.get_count(DUST), 6)


# --- take ------------------------------------------------------------------------------------------------------------

func test_take_removes_and_returns_the_card() -> void:
	var uid: int = _session.cards.add(_card(7, &"magic"))
	var card: MapCard = _session.cards.take(uid)
	assert_eq(card.grade, 7)
	assert_false(_session.cards.has(uid))
	assert_null(_session.cards.take(uid))
