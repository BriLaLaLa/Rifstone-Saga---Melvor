extends GutTest
## HelpButton and tooltip lines (M11-05): every game route has a "?" that opens an existing Guide page, item tooltips
## list at most three sources/uses, the stat tooltip shows the description of stats.json.

const ROUTES: Array[StringName] = [&"bank", &"shop", &"equipment", &"character", &"combat", &"rift"]

var _session: GameSession
var _host: PageHost
var _nav: GuideNav


func before_each() -> void:
	_session = TestFactory.session(1234, TestFactory.real_data())
	_nav = GuideNav.new(_session.data)
	_host = PageHost.new()
	add_child(_host)
	_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_host.setup(_session)


func after_each() -> void:
	if is_instance_valid(_host):
		_host.free()
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func _game_routes() -> Array[StringName]:
	var routes: Array[StringName] = ROUTES.duplicate()
	for skill: SkillDef in _session.data.skills():
		var id: StringName = StringName("skill:%s" % skill.id)
		if _host.has_page(id):
			routes.append(id)
	return routes


func test_every_game_route_has_a_help_button_to_an_existing_page() -> void:
	var routes: Array[StringName] = _game_routes()
	assert_gt(routes.size(), ROUTES.size(), "skill routes are included")
	for route: StringName in routes:
		_host.show_page(route)
		await wait_physics_frames(1)
		var button: HelpButton = _host.find_child("HelpButton", true, false) as HelpButton
		assert_not_null(button, "help button of %s" % route)
		if button == null:
			continue
		assert_true(_nav.has_entry(button.guide_entry), "%s opens an existing page (%s)" % [route, button.guide_entry])
		assert_eq(button.text, "?")


func test_pressing_the_button_opens_the_guide_on_that_page() -> void:
	_host.show_page(&"shop")
	await wait_physics_frames(1)
	var button: HelpButton = _host.find_child("HelpButton", true, false) as HelpButton
	watch_signals(button)
	button.pressed.emit()
	assert_signal_emitted_with_parameters(button, "guide_requested", [button.guide_entry])
	assert_true(PageHost.is_guide_route(_host.current_page_id()))
	var guide: GuidePage = _host.find_child("Page", false, false) as GuidePage
	assert_not_null(guide)
	assert_eq(guide.current_entry(), button.guide_entry)


func test_rebinding_does_not_duplicate_the_button() -> void:
	_host.show_page(&"bank")
	await wait_physics_frames(1)
	var page: Node = _host.find_child("Page", false, false)
	(page as Page).bind(_session)
	var count: int = 0
	for node: Node in page.find_children("HelpButton", "", true, false):
		count += 1
	assert_eq(count, 1)


func test_unknown_route_gets_no_button() -> void:
	assert_eq(HelpButton.entry_for(_session.data, &"nowhere"), &"")


func test_item_tooltip_lines_have_at_most_three_entries() -> void:
	var seen: int = 0
	for item: ItemDef in _session.data.items():
		for line: String in ItemTooltipLines.guide_lines(item, _session.data):
			seen += 1
			var text: String = line.get_slice("]", 1).get_slice("[", 0)
			var entries: String = text.get_slice(": ", 1).trim_suffix(GuideIndex.ELLIPSIS)
			assert_lte(entries.split(GuideIndex.SEPARATOR).size(), 3, "%s: %s" % [item.id, line])
	assert_gt(seen, 0)


func test_item_tooltip_shows_only_uses_from_the_index() -> void:
	var index := GuideIndex.new(_session.data)
	var found: bool = false
	for item: ItemDef in _session.data.items():
		if index.sources_of(item.id).is_empty() or index.uses_of(item.id).is_empty():
			continue
		var text: String = "\n".join(ItemTooltipLines.guide_lines(item, _session.data))
		assert_false(text.contains("Si ottiene da"), "M14: sources live in the Guide behind the discoveries")
		assert_string_contains(text, "Serve a: ")
		found = true
		break
	assert_true(found)


func test_character_stat_tooltip_uses_the_stats_description() -> void:
	_host.show_page(&"character")
	await wait_physics_frames(1)
	var page: CharacterPage = _host.find_child("Page", false, false) as CharacterPage
	var line: Label = page.find_child("Stat0", true, false) as Label
	assert_not_null(line)
	line.mouse_entered.emit()
	var info: Dictionary = _session.data.stats.info(CombatTexts.STAT_NAME_SOURCES[&"accuracy"])
	assert_false((info["description"] as String).is_empty())
	assert_string_contains(_tooltip_text(), info["description"] as String)
	Tooltips.hide_tooltip()


func test_equipment_stats_summary_shows_descriptions() -> void:
	var text: String = EquipmentStatsText.summary(_session)
	var checked: int = 0
	for stat: StringName in _session.data.stats.ids():
		if _session.modifiers.breakdown(stat).is_empty():
			continue
		assert_string_contains(text, ItemTooltipLines.escape(str(_session.data.stats.info(stat)["description"])))
		checked += 1
	assert_gt(checked, 0)


func _tooltip_text() -> String:
	var labels: Array[Node] = Tooltips.find_children("*", "RichTextLabel", true, false)
	var parts: PackedStringArray = PackedStringArray()
	for label: Node in labels:
		parts.append((label as RichTextLabel).get_parsed_text())
	return " ".join(parts)
