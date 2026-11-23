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


func test_card_shows_one_line_effect_and_the_detail_for_the_tooltip() -> void:
	var def: AbilityDef = _session.character.class_def().abilities[0]
	var card: LoadoutCard = _panel.card(LoadoutPanel.KIND_ABILITY, def.id)
	assert_eq(card.title_text(), def.name)
	var full: String = LoadoutDescribe.ability_text(def, _session.data, _session.character.class_def())
	assert_eq(card.effect_text(), full.get_slice("\n", 0))
	assert_false(card.effect_text().contains("\n"), "one line")
	assert_string_contains(card.detail_text(), full)


func test_header_shows_occupied_and_open_slots() -> void:
	var section: LoadoutSection = _panel.section(LoadoutPanel.KIND_TRAIT)
	assert_eq(section.points_text(), "0 / %d" % _session.loadout.trait_slots())
	_click(LoadoutPanel.KIND_TRAIT, &"test_cleave")
	assert_eq(section.points_text(), "1 / %d" % _session.loadout.trait_slots())
	assert_gt(section.group_count(), 0)


func test_click_is_a_command_and_redraws() -> void:
	_click(LoadoutPanel.KIND_TRAIT, &"test_cleave")
	assert_eq(_session.loadout.get_trait(0), &"test_cleave")
	assert_eq(_panel.card(LoadoutPanel.KIND_TRAIT, &"test_cleave").state(), LoadoutCard.STATE_ACTIVE)
	_click(LoadoutPanel.KIND_TRAIT, &"test_cleave")
	assert_eq(_session.loadout.get_trait(0), &"", "clicking a chosen card empties its slot")
	assert_eq(_panel.card(LoadoutPanel.KIND_TRAIT, &"test_cleave").state(), LoadoutCard.STATE_AVAILABLE)


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
	assert_eq(card.state(), LoadoutCard.STATE_LOCKED, "level 30 needed")
	_click(LoadoutPanel.KIND_ABILITY, &"test_mend")
	assert_eq(_panel.message_text(), LoadoutTexts.REASON_TEXTS[Reasons.LEVEL_TOO_LOW])
	assert_eq(_session.loadout.get_ability(0), &"")
	_click(LoadoutPanel.KIND_ABILITY, &"test_strike")
	assert_eq(_panel.message_text(), "", "a good choice clears the message")


func test_level_up_updates_the_summary() -> void:
	var before: String = _panel.section(LoadoutPanel.KIND_TRAIT).points_text()
	_level_to(10)
	assert_ne(_panel.section(LoadoutPanel.KIND_TRAIT).points_text(), before)


func test_setup_note_for_entry_not_active() -> void:
	_click(LoadoutPanel.KIND_ABILITY, &"test_whirl")
	assert_eq(_panel.card(LoadoutPanel.KIND_ABILITY, &"test_whirl").state(), LoadoutCard.STATE_INACTIVE)


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


# --- M28-07: the real data, the real main screen and REAL mouse clicks (the toggle and a card) ---

const MAIN_SCENE: PackedScene = preload("res://ui/screens/main/main_screen.tscn")


func _real_screen() -> Array:
	var real: GameSession = TestFactory.session(77, TestFactory.real_data())
	TestFactory.set_character_level(real, 30)
	var screen: MainScreen = MAIN_SCENE.instantiate() as MainScreen
	screen.session = real
	add_child(screen)
	# the output panel of the GUT runner must not catch the clicks of the test
	for layer: Node in get_tree().root.find_children("GutLayer", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	(screen.find_child("PageHost", true, false) as PageHost).show_page(&"character")
	await wait_process_frames(3)
	var hint_card: HintCard = screen.find_child("HintCard", true, false) as HintCard
	while hint_card != null and hint_card.current_hint() != &"":  # the modal hints of a new game would catch the clicks
		hint_card.close_current()
	await wait_process_frames(2)
	return [real, screen]


func _visible_cards(panel: LoadoutPanel, kind: StringName, class_def: ClassDef) -> int:
	var count: int = 0
	for entry: Variant in (class_def.traits if kind == LoadoutPanel.KIND_TRAIT else class_def.abilities):
		if panel.card(kind, entry.id).visible:
			count += 1
	return count


## A real left click (motion, press, release) on the centre of `control`, scrolled into view first.
func _real_click(control: Control) -> void:
	var parent: Node = control.get_parent()
	while parent != null and not parent is ScrollContainer:
		parent = parent.get_parent()
	if parent != null:
		(parent as ScrollContainer).ensure_control_visible(control)
		await wait_process_frames(2)
	var at: Vector2 = control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	get_viewport().push_input(motion, true)
	await wait_process_frames(1)
	assert_eq(get_viewport().gui_get_hovered_control(), control, "the click lands on the control")
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.position = at
		event.global_position = at
		get_viewport().push_input(event, true)
		await wait_process_frames(1)
	await wait_process_frames(2)


func test_real_clicks_on_the_toggle_and_on_a_card() -> void:
	var made: Array = await _real_screen()
	var real: GameSession = made[0]
	var screen: MainScreen = made[1]
	var panel: LoadoutPanel = screen.find_child("LoadoutPanel", true, false) as LoadoutPanel
	var class_def: ClassDef = real.character.class_def()
	var toggle: CheckButton = panel.find_child("OnlyCurrentToggle", true, false) as CheckButton
	assert_not_null(toggle)
	assert_true(toggle.button_pressed, "on by default")
	var total: int = class_def.traits.size()
	var shown: int = _visible_cards(panel, LoadoutPanel.KIND_TRAIT, class_def)
	assert_gt(shown, 0)
	assert_lt(shown, total, "the entries of the other setups are hidden")
	await _real_click(toggle)
	assert_false(toggle.button_pressed)
	assert_eq(_visible_cards(panel, LoadoutPanel.KIND_TRAIT, class_def), total, "all the traits")
	await _real_click(toggle)
	assert_eq(_visible_cards(panel, LoadoutPanel.KIND_TRAIT, class_def), shown)
	# the cards are ordered by unlock level
	var cards: Array[LoadoutCard] = panel.section(LoadoutPanel.KIND_TRAIT).cards
	var levels: Array[int] = []
	for card: LoadoutCard in cards:
		for def: TraitDef in class_def.traits:
			if def.id == card.entry_id():
				levels.append(def.unlock_level)
	assert_eq(levels.size(), total)
	var sorted: Array[int] = levels.duplicate()
	sorted.sort()
	assert_eq(levels, sorted, "ordered by unlock level")
	# a click on a visible card chooses it (the command of Loadout), a second one empties the slot
	var first: LoadoutCard = null
	for card: LoadoutCard in cards:
		if first == null and card.is_visible_in_tree() and card.is_clickable():
			first = card
	assert_not_null(first)
	await _real_click(first)
	assert_eq(String(real.loadout.get_trait(0)), String(first.entry_id()))
	assert_eq(first.state(), LoadoutCard.STATE_ACTIVE)
	await _real_click(first)
	assert_eq(String(real.loadout.get_trait(0)), "")
	screen.free()
	real.free()


func test_chosen_card_stays_visible_when_filtered() -> void:
	var made: Array = await _real_screen()
	var real: GameSession = made[0]
	var screen: MainScreen = made[1]
	var panel: LoadoutPanel = screen.find_child("LoadoutPanel", true, false) as LoadoutPanel
	var class_def: ClassDef = real.character.class_def()
	var other: TraitDef = null
	for def: TraitDef in class_def.traits:
		if not def.allows_setup(real.equipment.setup()) and def.unlock_level <= real.character.get_level():
			other = def
	assert_not_null(other, "a trait of another setup")
	assert_false(panel.card(LoadoutPanel.KIND_TRAIT, other.id).visible)
	assert_true(real.loadout.set_trait(0, other.id).ok)
	panel.refresh()
	assert_true(panel.card(LoadoutPanel.KIND_TRAIT, other.id).visible, "a chosen entry is never hidden")
	screen.free()
	real.free()
