extends GutTest
## TutorialMetrics (docs/05_INTERFACES_M30.md §5.42): each measure read from the model, and the signals that make it worth rereading.


func test_the_closed_list() -> void:
	var names: Array[String] = []
	for key: StringName in TutorialMetrics.METRICS:
		names.append(String(key))
	names.sort()
	assert_eq(names, ["character_level", "disciplines_learned", "kills_total", "mail_collected", "page_visited", "quests_completed", "village_levels"])
	var signals: Dictionary = TutorialConditions.script_signals()
	for metric: StringName in TutorialMetrics.METRICS:
		for sig: StringName in (TutorialMetrics.METRICS[metric] as Array):
			assert_true(signals.has(sig), "%s -> %s" % [metric, sig])


func test_character_level_and_kills() -> void:
	var s: GameSession = autofree(TestFactory.session())
	assert_eq(TutorialMetrics.value(s, &"character_level"), s.character.get_level())
	TestFactory.set_character_level(s, 3)
	assert_eq(TutorialMetrics.value(s, &"character_level"), 3)
	assert_eq(TutorialMetrics.value(s, &"kills_total"), 0)
	var saved: Dictionary = s.combat.to_save()
	saved["kills"] = {"test_monster_a": 4, "test_monster_b": 3}
	s.combat.from_save(saved)
	assert_eq(TutorialMetrics.value(s, &"kills_total"), 7)


func test_disciplines_learned_by_category() -> void:
	var s: GameSession = autofree(TestFactory.session(7, TestFactory.real_data()))
	var gathering: int = TutorialMetrics.value(s, &"disciplines_learned", &"gathering")
	var artisan: int = TutorialMetrics.value(s, &"disciplines_learned", &"artisan")
	assert_eq(TutorialMetrics.value(s, &"disciplines_learned"), gathering + artisan)
	assert_eq(gathering, s.disciplines.learned(&"gathering").size())
	assert_eq(artisan, s.disciplines.learned(&"artisan").size())


func test_mail_village_quests_and_page_visited() -> void:
	var s: GameSession = autofree(TestFactory.session(7, TestFactory.real_data()))
	assert_eq(TutorialMetrics.value(s, &"mail_collected"), 0)
	var id: int = s.mail.post(&"starter_reward", {"money": 5})
	s.mail.collect(id)
	assert_eq(TutorialMetrics.value(s, &"mail_collected"), 1)
	var total: int = 0
	for b: VillageBuildingDef in s.data.village_buildings():
		total += s.village.level(b.id)
	assert_eq(TutorialMetrics.value(s, &"village_levels"), total)
	assert_eq(TutorialMetrics.value(s, &"village_levels", &"auction_house"), s.village.level(&"auction_house"))
	assert_eq(TutorialMetrics.value(s, &"quests_completed"), s.quests.completed_total())
	assert_eq(TutorialMetrics.value(s, &"page_visited", &"guide"), 0)
	s.tutorial.notify_page_opened(&"guide")
	assert_eq(TutorialMetrics.value(s, &"page_visited", &"guide"), 1)
	assert_eq(TutorialMetrics.value(s, &"page_visited", &"bank"), 0)
