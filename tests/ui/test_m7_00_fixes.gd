extends GutTest
## M7-00 fixes from the visual test of M6: stacking of the floating numbers, width of the queue cards, singular/plural in
## the registry, final values on the equipment page (same lines as the character page), labels of the doll.

var _session: GameSession


func before_each() -> void:
	_session = TestFactory.session()


func after_each() -> void:
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


# --- Floating numbers --------------------------------------------------------------------------------------------

func test_free_y_keeps_a_distance_from_the_numbers_on_screen() -> void:
	var taken: Array[float] = []
	assert_eq(HitNumbers.free_y(taken, 10.0, 20.0), 10.0)
	taken = [10.0]
	assert_eq(HitNumbers.free_y(taken, 10.0, 20.0), 30.0)
	taken = [10.0, 30.0, 50.0]
	assert_eq(HitNumbers.free_y(taken, 10.0, 20.0), 70.0, "skips every taken line")
	taken = [-40.0]
	assert_eq(HitNumbers.free_y(taken, 10.0, 20.0), 10.0, "a number that already rose does not block")


func test_numbers_spawned_together_do_not_overlap() -> void:
	var holder := Control.new()
	holder.size = Vector2(100, 100)
	add_child_autofree(holder)
	var first: Label = HitNumbers.spawn(holder, "-5", Color.WHITE, false)
	var second: Label = HitNumbers.spawn(holder, "Mancato", Color.WHITE, false)
	var third: Label = HitNumbers.spawn(holder, "-9", Color.WHITE, true)
	assert_gte(second.position.y - first.position.y, first.size.y, "second below first")
	assert_gte(third.position.y - second.position.y, second.size.y, "third below second")
	HitNumbers.clear(holder)
	assert_eq(holder.get_child_count(), 0)


# --- Queue cards ---------------------------------------------------------------------------------------------------

func test_card_width_fills_the_row() -> void:
	assert_eq(EnemyZone.card_width(1000.0, 5, 104.0, 10.0), 192.0, "five cards share 1000 px")
	assert_eq(EnemyZone.card_width(1000.0, 2, 104.0, 10.0), 495.0, "never more columns than cards")
	assert_eq(EnemyZone.card_width(300.0, 5, 104.0, 10.0), 145.0, "two columns of 145")
	assert_eq(EnemyZone.card_width(50.0, 5, 104.0, 10.0), 104.0, "never below the minimum")
	assert_eq(EnemyZone.card_width(0.0, 5, 104.0, 10.0), 104.0, "not laid out yet")


# --- Singular and plural ---------------------------------------------------------------------------------------------

func test_log_summary_uses_singular_for_one() -> void:
	assert_eq(CombatTexts.log_summary(1, 1, 1, 1), "Registro: 1 colpo · 1 abilità · 1 parata · 1 cibo")
	assert_eq(CombatTexts.log_summary(0, 2, 12, 1500), "Registro: 0 colpi · 2 abilità · 12 parate · %s cibi" % NumberFormat.format_int(1500))


func test_yield_window_singular_minute() -> void:
	assert_eq(CombatTexts.yield_window_text(CombatYield.MS_PER_MINUTE), CombatTexts.YIELD_WINDOW_ONE_MINUTE_TEXT)
	assert_eq(CombatTexts.yield_window_text(3 * CombatYield.MS_PER_MINUTE), "ultimi 3 min")


# --- Equipment: final values ---------------------------------------------------------------------------------------

func test_equipment_stats_start_with_the_character_page_lines() -> void:
	var text: String = EquipmentStatsText.totals(_session)
	var lines: Array[String] = CombatTexts.final_stat_lines(_session)
	assert_eq(lines.size(), 4)
	for line: String in lines:
		assert_string_contains(text, line)
	assert_true(text.begins_with(lines[0]), "final values come first")


func test_equipment_stats_follow_the_equipment() -> void:
	var before: String = EquipmentStatsText.totals(_session)
	var uid: int = TestFactory.give_piece(_session, &"test_blade")
	assert_true(_session.equipment.equip(uid, &"weapon").ok)
	assert_ne(EquipmentStatsText.totals(_session), before)


# --- Doll labels -----------------------------------------------------------------------------------------------------

func test_doll_label_of_a_tool_is_the_skill_name() -> void:
	var skill: SkillDef = _session.data.skills()[0]
	assert_eq(EquipmentStatsText.doll_text(StringName("tool_" + skill.id), _session.data), skill.name)
	assert_eq(EquipmentStatsText.doll_text(&"head", _session.data), "Testa")


func test_slot_label_shrinks_to_fit() -> void:
	var view := EquipmentSlotView.new()
	add_child_autofree(view)
	view.size = Vector2(40, 40)
	view.setup(&"tool_forestry", "Selvicoltura molto lunga")
	assert_lt(view.label_font_size(), EquipmentSlotView.LABEL_FONT_SIZE)
	view.size = Vector2(400, 40)
	view.setup(&"head", "Testa")
	assert_eq(view.label_font_size(), EquipmentSlotView.LABEL_FONT_SIZE)
