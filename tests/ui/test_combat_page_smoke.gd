extends GutTest
## CombatPage (M5-05, GDR layout of M6-00c) with a TestFactory session (fixture data): area choice from the data, player
## column, target and queue from combat.get_state(), hit numbers and their clearing, loadout sections, equipment grid,
## eat and loot commands, everything disconnected by unbind. Character page values of F-70.

const SCENE: PackedScene = preload("res://ui/pages/combat/combat_page.tscn")
const CHARACTER_SCENE: PackedScene = preload("res://ui/pages/character/character_page.tscn")
const AREA_ID: StringName = &"test_area"
const FOOD_ID: StringName = &"test_ration"
const HELM: StringName = &"test_helm"
const OBSERVED: Array[StringName] = [&"combat_started", &"combat_stopped", &"encounter_started", &"encounter_cleared",
		&"player_hp_changed", &"monster_hp_changed", &"monster_killed", &"food_eaten", &"food_changed", &"bank_changed",
		&"loot_bag_changed", &"equipment_changed", &"combat_hit", &"player_died", &"character_level_up", &"traits_changed",
		&"character_xp_gained", &"gold_changed", &"ability_used", &"trait_triggered"]

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
	var option: OptionButton = _page.get_node("%AreaOption") as OptionButton
	assert_eq(option.item_count, _session.data.areas().size())
	assert_true(option.get_item_text(0).begins_with(_session.data.area(AREA_ID).name))
	assert_eq(_label("%AreaLabel").text, CombatTexts.NO_AREA_TEXT)
	assert_eq(_zone().queue_card(0), null)
	assert_false(_zone().target_card().visible)
	assert_true((_page.get_node("%StopButton") as Button).disabled)
	assert_eq(_player().shown_hp(), _session.combat.get_state()["player_max_hp"])


func test_area_choice_starts_combat_and_cards_follow_the_state() -> void:
	(_page.get_node("%AreaOption") as OptionButton).item_selected.emit(0)
	assert_true(_session.combat.is_active())
	assert_eq(_label("%AreaLabel").text, _session.data.area(AREA_ID).name)
	_page._process(0.0)
	var enemies: Array = _session.combat.get_state()["enemies"]
	assert_gt(enemies.size(), 0)
	for i: int in enemies.size():
		var card: EnemyCard = _zone().queue_card(i)
		assert_not_null(card, "card %d" % i)
		assert_eq(card.shown_hp(), enemies[i]["hp"])
	assert_eq(_zone().shown_index(), 0, "the first enemy is the target")
	assert_true(_zone().target_card().visible)
	assert_false(_zone().queue_card(0).visible, "the target is not repeated in the queue")
	assert_eq(_zone().target_card().shown_hp(), enemies[0]["hp"])
	assert_ne(_zone().target_card().shown_tag(), "", "style and triangle relation")
	assert_false((_page.get_node("%StopButton") as Button).disabled)


func test_stop_button_stops_combat() -> void:
	_session.combat.start(AREA_ID)
	(_page.get_node("%StopButton") as Button).pressed.emit()
	assert_false(_session.combat.is_active())
	assert_eq(_label("%AreaLabel").text, CombatTexts.NO_AREA_TEXT)


func test_combat_hit_shows_numbers_and_stop_clears_them() -> void:
	_session.combat.start(AREA_ID)
	_page._process(0.0)
	_session.events.combat_hit.emit(-1, 0, true, 7, false)
	var card: EnemyCard = _zone().queue_card(0)
	assert_eq(card.hit_text(), CombatTexts.HIT_TEXT % "7")
	assert_eq(_zone().target_card().hit_text(), CombatTexts.HIT_TEXT % "7", "also on the big card of the target")
	_session.events.combat_hit.emit(-1, 0, false, 0, false)
	assert_eq(card.hit_text(), CombatTexts.MISS_TEXT)
	_session.events.combat_hit.emit(0, -1, true, 0, true)
	assert_eq(_player().hit_text(), CombatTexts.BLOCKED_TEXT)
	assert_gt(card.floater_count(), 0)
	_session.combat.stop()
	assert_eq(card.floater_count(), 0, "no number stays after the end of the combat")
	assert_eq(_zone().target_card().floater_count(), 0)


func test_advancing_redraws_the_cards() -> void:
	_session.combat.start(AREA_ID)
	_session.advance(1000)
	_page._process(0.0)
	var enemies: Array = _session.combat.get_state()["enemies"]
	assert_eq(_zone().target_card().shown_hp(), enemies[_zone().shown_index()]["hp"])
	assert_gt(_player().shown_timer(), 0.0)


func test_loadout_sections_and_gear_grid_follow_the_model() -> void:
	var player: PlayerColumn = _player()
	assert_eq(player.ability_card_count(), (_session.data.balance_value(Loadout.ABILITY_LEVELS_KEY) as Array).size())
	assert_eq(player.trait_chip_count(), (_session.data.balance_value(Loadout.TRAIT_LEVELS_KEY) as Array).size())
	for slot: StringName in Equipment.SLOTS:
		assert_not_null(player.gear_cell(slot), "cell %s" % slot)
		assert_eq(player.gear_cell(slot).uid(), 0)
	var helm: int = TestFactory.give_piece(_session, HELM, &"magic")
	assert_true(_session.equipment.equip(helm).ok)
	assert_eq(player.gear_cell(&"head").uid(), helm, "the grid redraws on equipment_changed")
	assert_true(player.hint_text().contains(ItemTooltipLines.STYLE_NAMES[_session.equipment.style()]))


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


func test_log_summary_opens_and_lists_events() -> void:
	var button: Button = _page.get_node("%LogButton") as Button
	assert_true(button.text.begins_with("Registro"))
	_session.combat.start(AREA_ID)
	_session.events.combat_hit.emit(-1, 0, true, 5, false)
	button.pressed.emit()
	assert_true((_page.get_node("%LogScroll") as Control).visible)
	assert_true(_label("%LogLabel").text.contains("5"))
	button.pressed.emit()
	assert_false((_page.get_node("%LogScroll") as Control).visible)


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
	assert_eq((list.get_child(0) as Label).text, "%s: %s" % [_data_stat_name(&"accuracy_bonus"), NumberFormat.format_int(stats.accuracy)])
	assert_eq((list.get_child(3) as Label).text, "%s: %s" % [_data_stat_name(&"max_hp_flat"), NumberFormat.format_int(stats.max_hp)])
	page.free()


func test_defeat_message_is_cleared_by_a_new_start() -> void:
	_session.combat.start(AREA_ID)
	_session.events.player_died.emit()
	assert_true(_label("%MessageLabel").visible)
	assert_eq(_label("%MessageLabel").text, CombatTexts.DEFEAT_TEXT)
	_session.combat.stop(Reasons.PLAYER_DIED)
	assert_true(_session.combat.start(AREA_ID).ok, "restarted outside the page")
	assert_ne(_label("%MessageLabel").text, CombatTexts.DEFEAT_TEXT, "the defeat message goes away on the new start")
	assert_eq(_label("%MessageLabel").text, CombatTexts.NO_FOOD_WARNING, "no food: the warning of B2 takes its place")


func _label(path: String) -> Label:
	return _page.get_node(path) as Label


func _zone() -> EnemyZone:
	return _page.get_node("%EnemyZone") as EnemyZone


func _player() -> PlayerColumn:
	return _page.get_node("%PlayerColumn") as PlayerColumn


# The name of the stat in data/config/stats.json: the character page reuses it, it does not redefine it.
func _data_stat_name(stat: StringName) -> String:
	return str(_session.data.stats.info(stat)["name"])


func test_ability_used_and_trait_triggered_give_feedback() -> void:
	_session.character.add_xp(_session.data.character_xp_table().xp_for_level(10))
	_session.loadout.set_ability(0, &"test_strike")
	_session.loadout.set_trait(0, &"test_cleave")
	_session.combat.start(AREA_ID)
	var player: PlayerColumn = _player()
	_session.events.ability_used.emit(&"test_strike", [0])
	assert_true(player.is_flashing(&"test_strike"))
	assert_eq(player.entry_name(&"test_strike"), "Colpo di prova")
	_session.events.trait_triggered.emit(&"test_cleave")
	assert_true(player.is_flashing(&"test_cleave"))
	_page._on_log_pressed()
	var log_text: String = (_page.get_node("%LogLabel") as Label).text
	assert_string_contains(log_text, CombatTexts.LOG_ABILITY_TEXT % "Colpo di prova")
	assert_string_contains(log_text, CombatTexts.LOG_TRAIT_TEXT % "Fendente di prova")


func test_running_buff_shows_remaining_time() -> void:
	_session.equipment.equip(TestFactory.give_piece(_session, &"test_blade"))
	_session.loadout.set_ability(0, &"test_strike")
	var player: PlayerColumn = _player()
	player.tick({"player_hp": 1, "player_max_hp": 1, "player_interval_ms": 1000, "player_timer_ms": 0,
			"abilities": [{"id": &"test_strike", "timer_ms": 5000, "cooldown_ms": 8000, "enabled": true}],
			"buffs": {&"test_strike": 3000}})
	assert_eq(player.ability_state_text(0), CombatTexts.BUFF_ACTIVE_TEXT % "3,0")
