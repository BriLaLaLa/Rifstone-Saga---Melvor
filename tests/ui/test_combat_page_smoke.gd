extends GutTest
## CombatPage (M5-05) with a TestFactory session (fixture data): areas from the data, cards from combat.get_state(),
## hit numbers, eat and loot commands, everything disconnected by unbind. Character page values of F-70.

const SCENE: PackedScene = preload("res://ui/pages/combat/combat_page.tscn")
const CHARACTER_SCENE: PackedScene = preload("res://ui/pages/character/character_page.tscn")
const AREA_ID: StringName = &"test_area"
const FOOD_ID: StringName = &"test_ration"
const OBSERVED: Array[StringName] = [&"combat_started", &"combat_stopped", &"encounter_started", &"encounter_cleared",
		&"player_hp_changed", &"monster_hp_changed", &"monster_killed", &"food_eaten", &"food_changed", &"bank_changed",
		&"loot_bag_changed", &"equipment_changed", &"combat_hit", &"player_died", &"character_level_up"]

var _session: GameSession
var _page: CombatPage


func before_each() -> void:
	_session = TestFactory.session()
	_page = SCENE.instantiate() as CombatPage
	_page.page_id = &"combat"
	add_child(_page)
	_page.bind(_session)


func after_each() -> void:
	if is_instance_valid(_page):
		_page.free()
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func test_idle_page_lists_areas_and_has_no_enemy_cards() -> void:
	var button: Button = _page.find_child("Area_%s" % AREA_ID, true, false) as Button
	assert_not_null(button)
	assert_true(button.text.begins_with(_session.data.area(AREA_ID).name))
	assert_eq(_label("%AreaLabel").text, CombatTexts.NO_AREA_TEXT)
	assert_eq(_page.find_child("Enemy_0", true, false), null)
	assert_true((_page.get_node("%StopButton") as Button).disabled)
	assert_eq((_page.get_node("%PlayerCard") as CombatantCard).shown_hp(), _session.combat.get_state()["player_max_hp"])


func test_area_button_starts_combat_and_cards_follow_the_state() -> void:
	(_page.find_child("Area_%s" % AREA_ID, true, false) as Button).pressed.emit()
	assert_true(_session.combat.is_active())
	assert_eq(_label("%AreaLabel").text, _session.data.area(AREA_ID).name)
	var enemies: Array = _session.combat.get_state()["enemies"]
	assert_gt(enemies.size(), 0)
	for i: int in enemies.size():
		var card: CombatantCard = _page.find_child("Enemy_%d" % i, true, false) as CombatantCard
		assert_not_null(card, "card %d" % i)
		assert_eq(card.shown_hp(), enemies[i]["hp"])
	assert_true((_page.find_child("Enemy_0", true, false) as CombatantCard).is_highlighted(), "target highlighted")
	assert_false((_page.get_node("%StopButton") as Button).disabled)


func test_stop_button_stops_combat() -> void:
	_session.combat.start(AREA_ID)
	(_page.get_node("%StopButton") as Button).pressed.emit()
	assert_false(_session.combat.is_active())
	assert_eq(_label("%AreaLabel").text, CombatTexts.NO_AREA_TEXT)


func test_combat_hit_shows_a_number_on_the_target() -> void:
	_session.combat.start(AREA_ID)
	_session.events.combat_hit.emit(-1, 0, true, 7, false)
	var card: CombatantCard = _page.find_child("Enemy_0", true, false) as CombatantCard
	assert_eq(card.hit_text(), CombatTexts.HIT_TEXT % "7")
	_session.events.combat_hit.emit(-1, 0, false, 0, false)
	assert_eq(card.hit_text(), CombatTexts.MISS_TEXT)
	_session.events.combat_hit.emit(0, -1, true, 0, true)
	assert_eq((_page.get_node("%PlayerCard") as CombatantCard).hit_text(), CombatTexts.BLOCKED_TEXT)


func test_advancing_redraws_the_cards() -> void:
	_session.combat.start(AREA_ID)
	_session.advance(1000)
	_page._process(0.0)
	var enemies: Array = _session.combat.get_state()["enemies"]
	var card: CombatantCard = _page.find_child("Enemy_0", true, false) as CombatantCard
	assert_eq(card.shown_hp(), enemies[0]["hp"])
	assert_gt((_page.get_node("%PlayerCard") as CombatantCard).shown_timer(), 0.0)


func test_eat_without_food_shows_the_reason() -> void:
	_session.combat.start(AREA_ID)
	(_page.get_node("%EatButton") as Button).pressed.emit()
	var message: Label = _label("%MessageLabel")
	assert_true(message.visible)
	assert_eq(message.text, CombatTexts.REASON_TEXTS[Reasons.NO_FOOD])


func test_food_line_follows_the_chosen_food() -> void:
	assert_eq(_label("%FoodLabel").text, CombatTexts.NO_FOOD_TEXT)
	TestFactory.give(_session, FOOD_ID, 3)
	_session.equipment.set_food(FOOD_ID)
	assert_eq(_label("%FoodLabel").text, CombatTexts.FOOD_TEXT % [_session.data.item(FOOD_ID).name, "3"])


func test_loot_bag_is_listed_and_collected() -> void:
	_session.combat.loot.add(&"test_log", 2)
	assert_eq(_page.get_node("%LootList").get_child_count(), 1)
	assert_false((_page.get_node("%CollectButton") as Button).disabled)
	(_page.get_node("%CollectButton") as Button).pressed.emit()
	assert_eq(_session.combat.loot.used(), 0)
	assert_true((_page.get_node("%CollectButton") as Button).disabled)


func test_unbind_disconnects_everything() -> void:
	var events: GameEvents = _session.events
	var before: Dictionary = {}
	_page.unbind()
	var baseline: GameSession = TestFactory.session()
	for signal_name: StringName in OBSERVED:
		before[signal_name] = baseline.events.get_signal_connection_list(signal_name).size()
	baseline.free()
	for signal_name: StringName in OBSERVED:
		assert_eq(events.get_signal_connection_list(signal_name).size(), before[signal_name], "%s disconnected" % signal_name)


func test_character_page_shows_the_base_values_of_f70() -> void:
	var page: CharacterPage = CHARACTER_SCENE.instantiate() as CharacterPage
	add_child(page)
	page.bind(_session)
	var stats: CombatantStats = CombatantStats.for_player(_session)
	assert_eq(page.get_node("%StatsTitle").text, CombatTexts.STATS_TITLE)
	var list: Node = page.get_node("%StatsList")
	assert_eq(list.get_child_count(), 4)
	assert_eq((list.get_child(0) as Label).text, CombatTexts.STAT_ACCURACY_TEXT % NumberFormat.format_int(stats.accuracy))
	assert_eq((list.get_child(3) as Label).text, CombatTexts.STAT_HP_TEXT % NumberFormat.format_int(stats.max_hp))
	page.free()


func _label(path: String) -> Label:
	return _page.get_node(path) as Label
