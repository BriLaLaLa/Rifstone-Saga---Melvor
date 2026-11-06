extends GutTest
## LoadoutPanel in the CharacterPage (M6-05) with a TestFactory session (fixture class): one card per entry, the choice is
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


func _click(kind: StringName, id: StringName) -> void:
	var card: LoadoutCard = _panel.card(kind, id)
	assert_not_null(card, "no card %s" % id)
	card.chosen.emit(id)


func test_one_card_per_entry_of_the_class() -> void:
	var class_def: ClassDef = _session.character.class_def()
	assert_eq(_panel.card_count(LoadoutPanel.KIND_TRAIT), class_def.traits.size())
	assert_eq(_panel.card_count(LoadoutPanel.KIND_ABILITY), class_def.abilities.size())


func test_card_shows_name_description_and_unlock_level() -> void:
	var def: AbilityDef = _session.character.class_def().abilities[0]
	var card: LoadoutCard = _panel.card(LoadoutPanel.KIND_ABILITY, def.id)
	assert_eq(card.title_text(), def.name)
	assert_eq(card.description_text(), def.description)
	assert_string_contains(card.unlock_text(), str(def.unlock_level))


func test_summary_names_next_slot_level() -> void:
	var total: int = (_session.data.balance_value(Loadout.TRAIT_LEVELS_KEY) as Array).size()
	var next_level: int = int((_session.data.balance_value(Loadout.TRAIT_LEVELS_KEY) as Array)[_session.loadout.trait_slots()])
	assert_eq(_panel.summary_text(LoadoutPanel.KIND_TRAIT),
			LoadoutTexts.SLOTS_NEXT_TEXT % [_session.loadout.trait_slots(), total, next_level])


func test_click_is_a_command_and_redraws() -> void:
	_click(LoadoutPanel.KIND_TRAIT, &"test_cleave")
	assert_eq(_session.loadout.get_trait(0), &"test_cleave")
	assert_eq(_panel.card(LoadoutPanel.KIND_TRAIT, &"test_cleave").state_text(), LoadoutTexts.SLOT_CHOSEN_TEXT % 1)
	_click(LoadoutPanel.KIND_TRAIT, &"test_cleave")
	assert_eq(_session.loadout.get_trait(0), &"", "clicking a chosen card empties its slot")
	assert_eq(_panel.card(LoadoutPanel.KIND_TRAIT, &"test_cleave").state_text(), "")


func test_second_choice_takes_the_next_open_slot() -> void:
	_level_to(10)
	_click(LoadoutPanel.KIND_TRAIT, &"test_cleave")
	_click(LoadoutPanel.KIND_TRAIT, &"test_reflect")
	assert_eq(_session.loadout.get_trait(1), &"test_reflect")


func test_no_free_slot_gives_a_message_and_no_command() -> void:
	_click(LoadoutPanel.KIND_TRAIT, &"test_cleave")
	_click(LoadoutPanel.KIND_TRAIT, &"test_reflect")
	assert_eq(_panel.message_text(), LoadoutTexts.NO_FREE_SLOT_TEXT)
	assert_eq(_session.loadout.get_trait(0), &"test_cleave")


func test_entry_above_level_is_dimmed_and_refused_with_its_reason() -> void:
	var card: LoadoutCard = _panel.card(LoadoutPanel.KIND_ABILITY, &"test_mend")
	assert_lt(card.modulate.a, 1.0, "level 30 needed")
	_click(LoadoutPanel.KIND_ABILITY, &"test_mend")
	assert_eq(_panel.message_text(), LoadoutTexts.REASON_TEXTS[Reasons.LEVEL_TOO_LOW])
	assert_eq(_session.loadout.get_ability(0), &"")
	_click(LoadoutPanel.KIND_ABILITY, &"test_strike")
	assert_eq(_panel.message_text(), "", "a good choice clears the message")


func test_level_up_updates_the_summary() -> void:
	var before: String = _panel.summary_text(LoadoutPanel.KIND_TRAIT)
	_level_to(10)
	assert_ne(_panel.summary_text(LoadoutPanel.KIND_TRAIT), before)


func test_setup_note_for_entry_not_active() -> void:
	_click(LoadoutPanel.KIND_ABILITY, &"test_whirl")
	assert_string_contains(_panel.card(LoadoutPanel.KIND_ABILITY, &"test_whirl").state_text(), LoadoutTexts.NOT_FOR_SETUP_TEXT)


func test_encounter_shows_one_warning_per_section_and_blocks_clicks() -> void:
	assert_false(_panel.combat_note_visible(LoadoutPanel.KIND_ABILITY))
	_session.combat.start(AREA_ID)
	assert_true(_panel.combat_note_visible(LoadoutPanel.KIND_ABILITY))
	assert_true(_panel.combat_note_visible(LoadoutPanel.KIND_TRAIT))
	assert_false(_panel.card(LoadoutPanel.KIND_ABILITY, &"test_strike").is_clickable())
	_session.combat.stop()
	assert_false(_panel.combat_note_visible(LoadoutPanel.KIND_ABILITY))
	assert_true(_panel.card(LoadoutPanel.KIND_ABILITY, &"test_strike").is_clickable())


func test_unbind_disconnects_everything() -> void:
	_page.unbind()
	for event_name: StringName in OBSERVED:
		for connection: Dictionary in Signal(_session.events, event_name).get_connections():
			assert_ne((connection["callable"] as Callable).get_object(), _page, "%s still connected" % event_name)
