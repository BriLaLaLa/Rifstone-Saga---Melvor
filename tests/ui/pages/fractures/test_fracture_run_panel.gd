extends GutTest
## FractureRunPanel (M13-05): hidden outside a Fracture; inside, the grade, "Gruppo N/3", the boss, the active modifiers with
## their risk and reward and the Fracture bag, all read from `fractures.state()` at each `redraw`.

var _s: GameSession
var _panel: FractureRunPanel


func before_each() -> void:
	_s = FractureUtil.session(9)
	FractureUtil.hero(_s)
	_panel = FractureRunPanel.new()
	add_child(_panel)


func after_each() -> void:
	if is_instance_valid(_panel):
		_panel.free()
	if is_instance_valid(_s):
		_s.free()
	await wait_physics_frames(1)


func _label(node_name: String) -> Label:
	return _panel.find_child(node_name, true, false) as Label


func test_hidden_and_empty_outside_a_fracture() -> void:
	_panel.redraw(_s)
	assert_false(_panel.visible)
	assert_eq(_panel.get_child_count(), 0)


func test_shows_grade_group_modifiers_and_empty_bag() -> void:
	var uid: int = FractureUtil.card(_s, 2, [["sturdy", 5]])
	assert_true(_s.fractures.open(uid).ok)
	_panel.redraw(_s)
	assert_true(_panel.visible)
	assert_eq(_label("TitleLabel").text, FractureTexts.RUN_TITLE_TEXT % 2)
	assert_eq(_label("GroupLabel").text, FractureTexts.GROUP_TEXT % [1, 3])
	assert_eq(_label("BossLabel").text, FractureTexts.BOSS_TEXT)
	var mod: Label = _label("Mod_sturdy")
	assert_not_null(mod)
	assert_true(mod.text.begins_with(_s.data.map_mod(&"sturdy").name), mod.text)
	assert_true(mod.text.contains("PV dei mostri +"), mod.text)
	assert_eq(_label("BagText").text, FractureTexts.BAG_EMPTY_TEXT)


func test_without_modifiers_says_so() -> void:
	assert_true(_s.fractures.open(FractureUtil.card(_s, 1, [], &"common")).ok)
	_panel.redraw(_s)
	assert_not_null(_label("NoMods"))


func test_progress_and_boss_follow_the_run() -> void:
	assert_true(_s.fractures.open(FractureUtil.card(_s, 1)).ok)
	FractureUtil.run_until(_s, func() -> bool: return _s.fractures.state().get("boss", false) as bool)
	_panel.redraw(_s)
	var boss: BossDef = _s.fractures.run().boss_def(_s.data)
	assert_eq(_label("BossLabel").text, FractureTexts.BOSS_NAMED_TEXT % boss.name)
	var bar: ProgressBar = _panel.find_child("GroupBar", true, false) as ProgressBar
	assert_eq(bar.value, bar.max_value, "the bar is full at the boss")


func test_bag_text_counts_what_was_collected() -> void:
	assert_true(_s.fractures.open(FractureUtil.card(_s, 1)).ok)
	_s.fractures.run().bag.add_stack(&"test_log", 4)  # stands in for the loot of a kill (the engine fills it in play)
	_panel.redraw(_s)
	assert_eq(_label("BagText").text, "1 tipo di oggetto")
	_s.fractures.run().bag.add_stack(&"test_twig", 1)
	_panel.redraw(_s)
	assert_eq(_label("BagText").text, "2 tipi di oggetti")
