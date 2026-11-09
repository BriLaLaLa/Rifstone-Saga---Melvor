extends GutTest
## BlueprintSection inside the SkillPage of Forging (M10-06) with a TestFactory session on the M10 fixtures (never a
## real slot): owned blueprints only, requirements "owned / required", affix choice from Forging level 50, start and
## stop commands with refusals worded in Italian, progress read from the session, layout at 1600x900 and 1280x720.

const BlueprintData := preload("res://tests/systems/actions/blueprint_data.gd")
const SCENE: PackedScene = preload("res://ui/pages/skill/skill_page.tscn")
const BP: StringName = &"bp_test_blade"
const BP_HIGH: StringName = &"bp_test_helm_high"
const PLATE: StringName = &"test_plate_1"
const HANDLE: StringName = &"test_handle_1"
const RARE: StringName = &"test_log"
const FORGING: StringName = &"forging"

var _session: GameSession
var _page: SkillPage
var _host: Control


func before_each() -> void:
	_session = TestFactory.session(1234, BlueprintData.data())


func after_each() -> void:
	if is_instance_valid(_page):
		_page.free()
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func test_only_owned_blueprints_are_listed() -> void:
	_open()
	assert_true(_section().get_node("%EmptyLabel").visible)
	TestFactory.give(_session, BP, 1)
	assert_true(_row(BP).visible)
	assert_false(_row(BP_HIGH).visible)
	assert_false(_section().get_node("%EmptyLabel").visible)
	assert_eq(_row(BP).text, BlueprintTexts.OWNED_TEXT % [_name(BP), "1"])


func test_requirements_show_owned_and_required() -> void:
	_open()
	TestFactory.give(_session, BP, 1)
	TestFactory.give(_session, PLATE, 2)
	var line: Label = _section().find_child("Input_%s" % PLATE, true, false) as Label
	assert_not_null(line)
	assert_true(line.text.ends_with("2 / 5"), line.text)
	assert_eq(line.get_theme_color("font_color"), UiStyle.BAD)
	TestFactory.give(_session, PLATE, 3)
	line = _section().find_child("Input_%s" % PLATE, true, false) as Label
	assert_true(line.text.ends_with("5 / 5"), line.text)
	assert_eq(line.get_theme_color("font_color"), UiStyle.GOOD)


func test_info_line_reads_duration_xp_and_rare_chance() -> void:
	_open()
	TestFactory.give(_session, BP, 1)
	var blueprint: ItemDef = _session.data.item(BP)
	var expected: String = BlueprintTexts.INFO_LINE % [BlueprintTexts.duration(BlueprintCraft.duration_ms(blueprint, 0.0,
			_session.data)), NumberFormat.format_int(BlueprintCraft.xp(blueprint, _session.data)),
			BlueprintTexts.percent(ItemRoller.blueprint_two_affix_chance(1, 0.0, _session.data))]
	assert_eq((_section().get_node("%InfoLabel") as Label).text, expected)


func test_affix_choice_only_from_level_50() -> void:
	_open()
	TestFactory.give(_session, BP, 1)
	var choice: OptionButton = _section().get_node("%AffixChoice") as OptionButton
	assert_false(choice.visible, "level 1")
	assert_true(_section().get_node("%AffixNote").visible)
	TestFactory.set_level(_session, FORGING, 50)
	_session.events.level_up.emit(FORGING, 50)
	assert_true(choice.visible)
	assert_false(choice.disabled)
	assert_gt(choice.item_count, 1, "random plus the candidates of the slot")
	var keen: int = -1
	for i: int in choice.item_count:
		if choice.get_item_metadata(i) == &"test_keen":
			keen = i
	assert_gt(keen, 0, "test_keen is a candidate for a weapon")
	choice.select(keen)
	choice.item_selected.emit(keen)
	assert_eq(_section().chosen_affix(), &"test_keen")


func test_start_and_stop_send_the_commands() -> void:
	_open()
	_give_all()
	_press("%StartButton")
	var state: Dictionary = _session.actions.blueprint_state()
	assert_eq(state.get("blueprint"), BP)
	assert_eq(_session.bank.get_count(BP), 0, "consumed at the start")
	assert_true(_section().get_node("%StopButton").visible)
	assert_false(_section().get_node("%StartButton").visible)
	_press("%StopButton")
	assert_true(_session.actions.blueprint_state().is_empty())
	assert_eq(_session.bank.get_count(BP), 1, "returned by the stop")


func test_refusal_is_shown_in_italian() -> void:
	_open()
	TestFactory.give(_session, BP, 1)
	_press("%StartButton")
	var message: Label = _page.get_node("%MessageLabel") as Label
	assert_true(message.visible)
	assert_eq(message.text, BlueprintTexts.REFUSED_TEXTS[Reasons.MISSING_INPUTS])
	assert_true(_session.actions.blueprint_state().is_empty())


func test_the_chosen_affix_reaches_the_command() -> void:
	TestFactory.set_level(_session, FORGING, 50)
	_open()
	_give_all()
	var choice: OptionButton = _section().get_node("%AffixChoice") as OptionButton
	for i: int in choice.item_count:
		if choice.get_item_metadata(i) == &"test_keen":
			choice.select(i)
			choice.item_selected.emit(i)
	_press("%StartButton")
	assert_eq(_session.actions.blueprint_state().get("chosen_affix"), &"test_keen")


func test_progress_bar_follows_the_session() -> void:
	_open()
	_give_all()
	_press("%StartButton")
	_session.advance(1000)
	await wait_process_frames(2)
	var bar: ActionProgressBar = _section().get_node("%ProgressBar") as ActionProgressBar
	assert_true(bar.visible)
	assert_almost_eq(bar.value, _session.actions.get_progress(), 0.001)
	assert_gt(bar.value, 0.0)


func test_blueprint_craft_has_no_card() -> void:
	_open()
	for child: Node in _page.get_node("%Cards").get_children():
		assert_ne((child as ActionCard).action_id(), BlueprintCraft.ACTION)


func test_unbind_disconnects_everything() -> void:
	var before: int = _session.events.armory_changed.get_connections().size()
	_open()
	assert_gt(_session.events.armory_changed.get_connections().size(), before)
	_page.unbind()
	assert_eq(_session.events.armory_changed.get_connections().size(), before)
	assert_eq(_session.events.blueprint_crafted.get_connections().size(), 0)


func test_layout_fits_at_both_resolutions() -> void:
	_open()
	_give_all()
	for size: Vector2 in [Vector2(1600, 900), Vector2(1280, 720)]:
		_host.size = size
		await wait_process_frames(2)
		var rect: Rect2 = Rect2(Vector2.ZERO, size)
		var detail: Control = _section().get_node("%Detail") as Control
		assert_true(detail.visible)
		assert_true(rect.encloses(Rect2(detail.get_global_rect().position - _page.global_position,
				Vector2(detail.size.x, 1.0))), "the detail starts inside the page at %s" % size)
		assert_lte(detail.get_global_rect().end.x, _page.get_global_rect().end.x + 0.5)


func _open() -> void:
	_page = SCENE.instantiate() as SkillPage
	_page.page_id = StringName(PageHost.ROUTE_SKILL + PageHost.ROUTE_SEPARATOR + FORGING)
	_host = autofree(Control.new())
	_host.size = Vector2(1600, 900)
	add_child(_host)
	_host.add_child(_page)
	_page.bind(_session)


func _section() -> BlueprintSection:
	return _page.get_node("%Extras").get_child(0) as BlueprintSection


func _row(blueprint_id: StringName) -> Button:
	return _section().find_child("Blueprint_%s" % blueprint_id, true, false) as Button


func _name(item_id: StringName) -> String:
	return _session.data.item(item_id).name


func _give_all() -> void:
	TestFactory.give(_session, BP, 1)
	TestFactory.give(_session, PLATE, 5)
	TestFactory.give(_session, HANDLE, 1)
	TestFactory.give(_session, RARE, 1)
	TestFactory.give(_session, &"test_plank", 1)  # M14-05: the second rare component of the M10 snapshot


func _press(path: String) -> void:
	(_section().get_node(path) as Button).pressed.emit()
