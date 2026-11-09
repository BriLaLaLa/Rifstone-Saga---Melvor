extends GutTest
## FractureTexts and the offline line of a Fracture (M13-05): the risk and reward lines with the values of the Card, the
## refusals in Italian for every reason of the page, the toasts and no text of the old timed Fracture.

const OLD_TEXTS: Array[String] = ["ogni 2-4 ore", "Frattura a tempo", "chiude tra"]

var _session: GameSession


func after_each() -> void:
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func test_risk_and_reward_lines_use_the_values_of_the_card() -> void:
	var effect: Dictionary = {"mod": &"sturdy", "risk_type": &"monster_hp_pct", "risk": 40.0,
			"reward_type": &"loot_qty_pct", "reward": 10.0}
	assert_eq(FractureTexts.risk_line(effect), "PV dei mostri +40%")
	assert_eq(FractureTexts.reward_line(effect), "Quantità del bottino +10%")
	assert_true(FractureTexts.effect_line(effect).contains("PV dei mostri +40%"))
	assert_true(FractureTexts.effect_line(effect).contains("Quantità del bottino +10%"))


func test_special_signs() -> void:
	assert_eq(MapEffectLabels.line(&"food_heal_pct", 40.0), "Cura del cibo -40%")
	assert_eq(MapEffectLabels.line(&"pack_bonus", 2.0), "Mostri in più in ogni gruppo +2")


func test_every_effect_type_of_the_data_has_a_label() -> void:
	var data: GameData = TestFactory.real_data()
	for def: MapModDef in data.map_mods():
		assert_true(MapEffectLabels.LABELS.has(def.risk.type), "risk %s" % def.risk.type)
		assert_true(MapEffectLabels.LABELS.has(def.reward.type), "reward %s" % def.reward.type)


func test_every_refusal_of_the_page_has_a_text() -> void:
	for reason: StringName in [Reasons.UNKNOWN_ID, Reasons.FRACTURE_ACTIVE, Reasons.FRACTURE_BAG_PENDING, Reasons.ITEM_LOCKED,
			Reasons.REQUIREMENT_NOT_MET, Reasons.NOT_ENOUGH_ITEMS, Reasons.BANK_FULL, Reasons.NO_FRACTURE]:
		assert_true(FractureTexts.REFUSED.has(reason), String(reason))
		assert_ne(FractureTexts.refusal(reason), FractureTexts.REFUSED_DEFAULT, String(reason))


func test_outcomes_and_toasts() -> void:
	assert_eq(FractureTexts.outcome_text(&"won"), "vinta")
	assert_eq(FractureTexts.outcome_text(&"died"), "persa")
	assert_eq(FractureTexts.outcome_text(&"abandoned"), "abbandonata")
	assert_eq(FractureTexts.toast_text(&"won", 1, 2), "Frattura vinta! 2 pezzi, 1 Carta")
	assert_eq(FractureTexts.toast_text(&"won", 0, 0), "Frattura vinta!")
	assert_eq(FractureTexts.toast_text(&"died", 3, 3), "Frattura persa: bottino perduto")
	assert_eq(FractureTexts.toast_text(&"abandoned", 0, 0), "Frattura abbandonata")
	assert_eq(FractureTexts.TOAST_REJECTED_TEXT, "Carta persa: Deposito pieno")


func test_offline_line_tells_the_fracture() -> void:
	var won: String = OfflineTexts.fracture_line({"grade": 3, "outcome": &"won", "groups": 30, "cards": 1, "pieces": 2})
	assert_true(won.contains("grado 3") and won.contains("vinta") and won.contains("30"), won)
	assert_true(won.contains("1 Carta") and won.contains("2 pezzi"), won)
	var lost: String = OfflineTexts.fracture_line({"grade": 2, "outcome": &"died", "groups": 7, "cards": 1, "pieces": 2})
	assert_true(lost.contains("persa"), lost)
	assert_false(lost.contains("Carta"), "a lost bag is not listed")


func test_offline_summary_view_lists_the_fractures() -> void:
	_session = TestFactory.session()
	var summary := OfflineSummary.new()
	summary.elapsed_ms = 600_000
	summary.fractures.append({"grade": 4, "outcome": &"abandoned", "groups": 5, "cards": 0, "pieces": 0})
	assert_false(summary.is_empty())
	var view: OfflineSummaryView = OfflineSummaryView.open(self, summary, _session.data)
	var text: String = "\n".join(view.shown_lines())
	assert_true(text.contains(OfflineTexts.SECTION_FRACTURES), text)
	assert_true(text.contains(OfflineTexts.fracture_line(summary.fractures[0])), text)
	view.free()


func test_no_old_texts() -> void:
	for path: String in ["res://ui/pages/fractures/fracture_texts.gd", "res://core/guide/map_effect_labels.gd",
			"res://data/guide/fratture.json"]:
		var source: String = FileAccess.get_file_as_string(path)
		for old: String in OLD_TEXTS:
			assert_false(source.contains(old), "%s: %s" % [path, old])
