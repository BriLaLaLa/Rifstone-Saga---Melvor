extends GutTest
## FracturesPage (M13-05, docs/05_INTERFACES.md §7.v) with a fixture session (three groups per Fracture): the Cards sorted by
## grade, their modifiers with risk and reward, "Apri" starts a Fracture, "Abbandona" asks a confirmation and loses the bag,
## lock / salvage / Crystals, pending loot and the refusals in Italian. The page keeps no data: it rereads the session.

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


func _bind() -> void:
	_page.bind(_s)


func _rows() -> Array[CardRow]:
	var rows: Array[CardRow] = []
	for child: Node in (_page.get_node("%CardsList") as Node).get_children():
		if child is CardRow and not child.is_queued_for_deletion():
			rows.append(child as CardRow)
	return rows


func _press(row: CardRow, button: String) -> void:
	(row.find_child(button, true, false) as Button).pressed.emit()


func _button(path: String) -> Button:
	return _page.get_node(path) as Button


func _message() -> Label:
	return _page.get_node("%MessageLabel") as Label


func test_no_cards_shows_the_hint() -> void:
	_bind()
	assert_eq(_rows().size(), 0)
	assert_true((_page.get_node("%NoCardsLabel") as Label).visible)
	assert_false((_page.get_node("%RunBox") as Control).visible)


func test_cards_sorted_by_grade_descending_then_uid() -> void:
	var low: int = FractureUtil.card(_s, 1)
	var high: int = FractureUtil.card(_s, 3)
	var low2: int = FractureUtil.card(_s, 1)
	_bind()
	var rows: Array[CardRow] = _rows()
	assert_eq(rows.size(), 3)
	assert_eq(rows[0].name, "Card%d" % high)
	assert_eq(rows[1].name, "Card%d" % low)
	assert_eq(rows[2].name, "Card%d" % low2)


func test_card_shows_modifiers_with_risk_and_reward_of_f109() -> void:
	FractureUtil.card(_s, 2, [["sturdy", 5]])
	_bind()
	var row: CardRow = _rows()[0]
	var risk: Label = row.find_child("Risk", true, false) as Label
	var reward: Label = row.find_child("Reward", true, false) as Label
	assert_not_null(risk)
	assert_true(risk.text.contains("PV dei mostri +"), risk.text)
	assert_true(reward.text.contains("Quantità del bottino +"), reward.text)
	var effect: Dictionary = MapCardRoller.effects(_s.cards.get_card(_s.cards.cards()[0].uid), _s.data)[0]
	assert_true(risk.text.contains(NumberFormat.format_int(roundi(float(effect["risk"])))))
	assert_true((row.find_child("GradeLabel", true, false) as Label).text.contains(
			str(_s.fractures.recommended_level(2))), "recommended level")


func test_open_starts_the_fracture_and_the_page_shows_it() -> void:
	var uid: int = FractureUtil.card(_s, 1, [["sturdy", 5]])
	_bind()
	_press(_rows()[0], "OpenButton")
	assert_true(_s.fractures.is_active())
	assert_false(_s.cards.has(uid), "the Card is consumed")
	assert_true((_page.get_node("%RunBox") as Control).visible)
	assert_false((_page.get_node("%CardsSection") as Control).visible)
	var group: Label = _page.find_child("GroupLabel", true, false) as Label
	assert_eq(group.text, FractureTexts.GROUP_TEXT % [1, 3])


func test_abandon_asks_and_loses_the_bag() -> void:
	FractureUtil.card(_s, 1)
	_bind()
	_press(_rows()[0], "OpenButton")
	_button("%AbandonButton").pressed.emit()
	await wait_physics_frames(1)
	var dialog: ConfirmDialog = _dialog()
	assert_not_null(dialog)
	dialog.canceled.emit()
	await wait_physics_frames(1)
	assert_true(_s.fractures.is_active(), "cancel keeps the Fracture")
	_button("%AbandonButton").pressed.emit()
	await wait_physics_frames(1)
	_dialog().confirmed.emit()
	await wait_physics_frames(1)
	assert_false(_s.fractures.is_active())
	assert_false(_s.combat.in_fracture())
	assert_true((_page.get_node("%CardsSection") as Control).visible)
	assert_false(_s.fractures.has_pending())


func test_lock_blocks_the_salvage_with_an_italian_reason() -> void:
	var uid: int = FractureUtil.card(_s, 1)
	_bind()
	_press(_rows()[0], "LockButton")
	assert_true(_s.cards.get_card(uid).locked)
	assert_eq((_rows()[0].find_child("LockButton", true, false) as Button).text, FractureTexts.UNLOCK_TEXT)
	_press(_rows()[0], "SalvageButton")
	assert_true(_message().visible)
	assert_eq(_message().text, FractureTexts.REFUSED[Reasons.ITEM_LOCKED])
	assert_true(_s.cards.has(uid))


func test_salvage_removes_the_card_and_tells_the_dust() -> void:
	var uid: int = FractureUtil.card(_s, 2)
	_bind()
	_press(_rows()[0], "SalvageButton")
	assert_false(_s.cards.has(uid))
	assert_eq(_rows().size(), 0)
	assert_true(_message().visible)
	assert_true(_message().text.begins_with("Carta smantellata"), _message().text)


func test_crystals_of_the_bank_can_be_used_on_a_card() -> void:
	var uid: int = FractureUtil.card(_s, 1, [], &"common")
	_bind()
	_press(_rows()[0], "CurrencyButton")
	assert_true((_page.get_node("%CrystalBox") as Control).visible)
	assert_not_null(_page.find_child("NoCrystals", true, false))
	TestFactory.give(_s, &"test_currency", 1)
	assert_not_null(_page.find_child("UseCrystalButton", true, false), "a Crystal in the bank can be used")
	(_page.find_child("UseCrystalButton", true, false) as Button).pressed.emit()
	assert_eq(_s.cards.get_card(uid).rarity, &"magic")
	assert_eq(_s.bank.get_count(&"test_currency"), 0)


func test_pending_loot_shows_the_collect_box() -> void:
	_bind()
	assert_false((_page.get_node("%PendingBox") as Control).visible)
	var bag := FractureBag.new()
	bag.add_stack(&"test_log", 3)
	_s.fractures.from_save({"run": {}, "pending": bag.to_save()})
	_s.events.fracture_bag_changed.emit(1, 0, 0)
	assert_true(_s.fractures.has_pending())
	assert_true((_page.get_node("%PendingBox") as Control).visible)
	assert_true(((_page.get_node("%PendingText") as Label).text).contains(FractureTexts.PENDING_TITLE_TEXT))
	_button("%CollectButton").pressed.emit()
	assert_false(_s.fractures.has_pending())
	assert_false((_page.get_node("%PendingBox") as Control).visible)
	assert_eq(_s.bank.get_count(&"test_log"), 3)


func test_open_is_refused_while_loot_is_pending_and_open_button_is_disabled() -> void:
	var uid: int = FractureUtil.card(_s, 1)
	var bag := FractureBag.new()
	bag.add_stack(&"test_log", 3)
	_s.fractures.from_save({"run": {}, "pending": bag.to_save()})
	_bind()
	assert_true((_rows()[0].find_child("OpenButton", true, false) as Button).disabled)
	_page.call("_on_open_requested", uid)
	assert_eq(_message().text, FractureTexts.REFUSED[Reasons.FRACTURE_BAG_PENDING])
	assert_true(_s.cards.has(uid))


func test_unbind_disconnects_everything() -> void:
	_bind()
	_page.unbind()
	FractureUtil.card(_s, 1)
	assert_eq(_rows().size(), 0, "no redraw after unbind")
	for sig: Signal in [_s.events.card_changed, _s.events.deposit_changed, _s.events.fracture_opened,
			_s.events.fracture_finished, _s.events.fracture_bag_changed, _s.events.bank_changed]:
		for connection: Dictionary in sig.get_connections():
			assert_ne((connection["callable"] as Callable).get_object(), _page)


func _dialog() -> ConfirmDialog:
	for child: Node in _page.get_children():
		if child is ConfirmDialog:
			return child as ConfirmDialog
	return null
