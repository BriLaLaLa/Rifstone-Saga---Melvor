extends GutTest
## LoadoutPanel in the CharacterPage (M6-05) with a TestFactory session (fixture class): one row per slot, the choice is
## the command of Loadout, refusals show the reason, nothing changes in the model on a refusal, redraw on the signals.

const SCENE: PackedScene = preload("res://ui/pages/character/character_page.tscn")
const OBSERVED: Array[StringName] = [&"traits_changed", &"combat_started", &"combat_stopped", &"encounter_started",
		&"encounter_cleared"]
const AREA_ID: StringName = &"test_area"

var _session: GameSession
var _page: CharacterPage
var _panel: LoadoutPanel


func before_each() -> void:
	_session = TestFactory.session()
	_page = SCENE.instantiate() as CharacterPage
	_page.page_id = &"character"
	add_child(_page)
	_page.bind(_session)
	_panel = _page.get_node("%LoadoutPanel") as LoadoutPanel


func after_each() -> void:
	if is_instance_valid(_page):
		_page.free()
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func _level_to(level: int) -> void:
	_session.character.add_xp(_session.data.character_xp_table().xp_for_level(level))


func _pick(kind: StringName, slot: int, id: StringName) -> void:
	var option: OptionButton = _panel.option(kind, slot)
	for i: int in option.item_count:
		if option.get_item_metadata(i) == id:
			option.item_selected.emit(i)
			return
	fail_test("no entry %s" % id)


func test_one_row_per_slot_of_the_table() -> void:
	assert_eq(_panel.row_count(LoadoutPanel.KIND_TRAIT), (_session.data.balance_value(Loadout.TRAIT_LEVELS_KEY) as Array).size())
	assert_eq(_panel.row_count(LoadoutPanel.KIND_ABILITY), (_session.data.balance_value(Loadout.ABILITY_LEVELS_KEY) as Array).size())


func test_closed_slot_is_disabled_with_its_level() -> void:
	var option: OptionButton = _panel.option(LoadoutPanel.KIND_TRAIT, 3)
	assert_true(option.disabled)
	assert_eq(option.text, LoadoutTexts.SLOT_LOCKED_TEXT % 50)


func test_choice_is_a_command_and_redraws() -> void:
	_pick(LoadoutPanel.KIND_TRAIT, 0, &"test_cleave")
	assert_eq(_session.loadout.get_trait(0), &"test_cleave")
	assert_eq(_panel.option(LoadoutPanel.KIND_TRAIT, 0).selected, 1)
	assert_string_contains(_panel.note_text(LoadoutPanel.KIND_TRAIT, 0), "terzo attacco")
	_pick(LoadoutPanel.KIND_TRAIT, 0, &"")
	assert_eq(_session.loadout.get_trait(0), &"", "empty entry clears the slot")


func test_entry_above_level_is_disabled_and_other_slot_choice_marked() -> void:
	var option: OptionButton = _panel.option(LoadoutPanel.KIND_ABILITY, 0)
	var index: int = -1
	for i: int in option.item_count:
		if option.get_item_metadata(i) == &"test_mend":
			index = i
	assert_true(option.is_item_disabled(index), "level 30 needed")
	_pick(LoadoutPanel.KIND_ABILITY, 0, &"test_strike")
	var other: OptionButton = _panel.option(LoadoutPanel.KIND_ABILITY, 1)
	for i: int in other.item_count:
		if other.get_item_metadata(i) == &"test_strike":
			assert_true(other.is_item_disabled(i), "already used in slot 1")


func test_refused_choice_shows_reason_and_keeps_the_model() -> void:
	_panel.option(LoadoutPanel.KIND_TRAIT, 1).item_selected.emit(1)   # slot 2 opens at level 10
	assert_eq(_panel.message_text(), LoadoutTexts.REASON_TEXTS[Reasons.SLOT_LOCKED])
	assert_eq(_session.loadout.get_trait(1), &"")
	_pick(LoadoutPanel.KIND_TRAIT, 0, &"test_cleave")
	_level_to(10)
	_pick(LoadoutPanel.KIND_TRAIT, 1, &"test_reflect")
	assert_eq(_panel.message_text(), "", "a good choice clears the message")


func test_level_up_opens_the_slot() -> void:
	assert_true(_panel.option(LoadoutPanel.KIND_TRAIT, 1).disabled)
	_level_to(10)
	assert_false(_panel.option(LoadoutPanel.KIND_TRAIT, 1).disabled)


func test_setup_note_for_entry_not_active() -> void:
	_pick(LoadoutPanel.KIND_ABILITY, 0, &"test_whirl")
	assert_string_contains(_panel.note_text(LoadoutPanel.KIND_ABILITY, 0), LoadoutTexts.NOT_FOR_SETUP_TEXT)


func test_choice_is_blocked_during_an_encounter() -> void:
	_session.combat.start(AREA_ID)
	assert_true(_panel.option(LoadoutPanel.KIND_ABILITY, 0).disabled)
	assert_eq(_panel.note_text(LoadoutPanel.KIND_ABILITY, 0), LoadoutTexts.COMBAT_ACTIVE_TEXT)
	_session.combat.stop()
	assert_false(_panel.option(LoadoutPanel.KIND_ABILITY, 0).disabled)


func test_unbind_disconnects_everything() -> void:
	_page.unbind()
	for event_name: StringName in OBSERVED:
		for connection: Dictionary in Signal(_session.events, event_name).get_connections():
			assert_ne((connection["callable"] as Callable).get_object(), _page, "%s still connected" % event_name)
