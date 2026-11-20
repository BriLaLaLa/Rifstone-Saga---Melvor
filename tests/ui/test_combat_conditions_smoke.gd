extends GutTest
## M28-07 (docs/05_INTERFACES_M28.md §7.aa): the combat page draws the conditions of `get_state().enemies[i].conditions` as chips on the
## enemy cards, the Ward of `get_state().ward` above the HP bar and the numbers of the Bleed with their own colour. The state is the real
## engine's: a fight of the real data is saved, given conditions and a Ward in the save format (§6f) and loaded back. No exact texts.

const SCENE: PackedScene = preload("res://ui/pages/combat/combat_page.tscn")
const AREA_ID: StringName = &"redrock_plains"
const MAX_STEPS: int = 60

var _session: GameSession
var _page: CombatPage


func before_each() -> void:
	_session = TestFactory.session(21, TestFactory.real_data(), true)
	TestFactory.set_character_level(_session, 30)
	_session.combat.start(AREA_ID)
	var steps: int = 0
	while not _session.combat.in_encounter() and steps < MAX_STEPS:
		_session.combat.advance(1000)
		steps += 1
	var saved: Dictionary = _session.combat.to_save()
	var enemies: Array = saved["enemies"]
	enemies[0]["cond"] = {"bleed": {"left": 18, "ticks": 4}, "weaken": {"pct": 25.0, "ms": 2400}}
	if enemies.size() > 1:
		enemies[1]["cond"] = {"stagger_ms": 900, "expose": {"pct": 15.0, "ms": 1200}}
	saved["cond_clock_ms"] = 400
	saved["ward"] = {"amount": 35, "ms": 4200}
	_session.combat.from_save(saved)
	_page = SCENE.instantiate() as CombatPage
	_page.page_id = &"combat"
	add_child(_page)
	_page.bind(_session)
	_page._process(0.0)


func after_each() -> void:
	if is_instance_valid(_page):
		_page.free()
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func _zone() -> EnemyZone:
	return _page.get_node("%EnemyZone") as EnemyZone


func _player() -> PlayerColumn:
	return _page.get_node("%PlayerColumn") as PlayerColumn


func test_the_state_has_what_the_page_draws() -> void:
	var state: Dictionary = _session.combat.get_state()
	assert_true(_session.combat.in_encounter())
	assert_true((state["enemies"][0]["conditions"] as Dictionary).has("bleed"))
	assert_eq(int(state["ward"]["amount"]), 35)


func test_the_target_card_shows_the_chips_of_its_conditions() -> void:
	var strip: ConditionStrip = _zone().target_card().conditions_strip()
	assert_true(strip.visible)
	assert_eq(strip.shown_ids(), [ConditionTexts.BLEED, ConditionTexts.WEAKEN] as Array[StringName])
	assert_string_contains(strip.chip_label(ConditionTexts.BLEED), "18", "the damage still to come")
	assert_string_contains(strip.chip_label(ConditionTexts.WEAKEN), "25")


func test_a_queue_card_shows_stagger_and_expose() -> void:
	if (_session.combat.get_state()["enemies"] as Array).size() < 2:
		pending("the area gave a single enemy")
		return
	var strip: ConditionStrip = _zone().queue_card(1).conditions_strip()
	assert_eq(strip.shown_ids(), [ConditionTexts.EXPOSE, ConditionTexts.STAGGER] as Array[StringName])


func test_the_ward_is_drawn_above_the_hp_bar_and_goes_away() -> void:
	var ward: WardStrip = _player().find_child("WardStrip", true, false) as WardStrip
	assert_true(ward.visible)
	assert_string_contains(ward.shown_text(), "35")
	var hp_bar: Node = _player().find_child("HpBar", true, false)
	assert_lt(ward.get_index(), hp_bar.get_index(), "above the HP bar")
	var saved: Dictionary = _session.combat.to_save()
	saved["ward"] = {}
	_session.combat.from_save(saved)
	_page._process(0.0)
	assert_false(ward.visible)


func test_conditions_disappear_with_the_enemy_state() -> void:
	var saved: Dictionary = _session.combat.to_save()
	for enemy: Dictionary in saved["enemies"]:
		enemy.erase("cond")
	saved["cond_clock_ms"] = -1
	_session.combat.from_save(saved)
	_page._process(0.0)
	assert_false(_zone().target_card().conditions_strip().visible)


func test_a_bleed_tick_shows_a_number_with_the_colour_of_the_condition() -> void:
	var card: EnemyCard = _zone().target_card()
	var before: int = card.floater_count()
	_session.events.combat_condition_damage.emit(_zone().shown_index(), 7, ConditionApply.BLEED)
	assert_eq(card.floater_count(), before + 1)
	assert_string_contains(card.hit_text(), "7")
	var label: Label = card.find_child("HitNumber", true, false) as Label
	assert_eq(label.get_theme_color("font_color"), UiStyle.COMBAT_BLEED_COLOR)
