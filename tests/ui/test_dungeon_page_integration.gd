extends GutTest
## M22-12 integration: the Dungeon page on a real GameSession and the real DungeonSystem with the real data (M22-09 feedback):
## state()["stage"] carries count/monster/acts, the final boss band, the enemy grid (a Horde and summons are cells, never "xN")
## and the reveal banner (shown after dungeon_room_entered, never after a load).

const TICKET: StringName = &"dungeon_ticket_monkey_den"
const STEP_MS: int = 500
const STEP_LIMIT: int = 30000

var _s: GameSession
var _page: DungeonPage
var _last_kind: StringName = &""
var _entered: int = 0


func _new_session(seed_value: int) -> GameSession:
	var s: GameSession = TestFactory.session(seed_value, TestFactory.real_data())
	TestFactory.make_roomy(s)
	TestFactory.set_character_level(s, 55)
	s.modifiers.set_source(&"test:hero", [Modifier.make(&"power_bonus", 5000.0), Modifier.make(&"max_hp_flat", 100000.0)])
	return s


func _bind(s: GameSession) -> void:
	_page = (load("res://ui/pages/dungeon/dungeon_page.tscn") as PackedScene).instantiate() as DungeonPage
	_page.page_id = &"dungeon"
	add_child(_page)
	_page.bind(s)


func before_each() -> void:
	_s = _new_session(2211)
	_s.bank.add(TICKET, 1)
	_bind(_s)
	_s.events.dungeon_room_entered.connect(_on_entered)


func after_each() -> void:
	if is_instance_valid(_page):
		_page.free()
	if is_instance_valid(_s):
		_s.free()
	await wait_physics_frames(1)


func _on_entered(_layer: int, kind: StringName) -> void:
	_last_kind = kind
	_entered += 1


func _choices() -> Array[Button]:
	var result: Array[Button] = []
	for node: Node in _page.find_children("Choice_*", "Button", true, false):
		if not node.is_queued_for_deletion():
			result.append(node as Button)
	return result


func _banner() -> DungeonRevealBanner:
	return _page.find_child("RevealBanner", true, false) as DungeonRevealBanner


func _has_times_label(root: Node) -> bool:
	var rx: RegEx = RegEx.create_from_string("^x[0-9]+$")
	for node: Node in root.find_children("*", "Label", true, false):
		if rx.search((node as Label).text.strip_edges().to_lower()) != null:
			return true
	return false


func test_real_run_grid_boss_band_and_banner() -> void:
	var enter: Button = _page.find_child("EnterButton*", true, false) as Button
	enter.pressed.emit()
	assert_true(_s.dungeon.is_active())
	var fight: DungeonFightView = _page.find_child("FightView", true, false) as DungeonFightView
	var max_cells: int = 0
	var banners: int = 0
	var boss_acts: Dictionary = {}
	var steps: int = 0
	while _s.dungeon.is_active() and steps < STEP_LIMIT:
		_page.refresh()
		var state: Dictionary = _s.dungeon.state()
		var phase: StringName = state["phase"]
		if phase == &"await" or phase == &"event":
			var before: int = _entered
			for choice: Dictionary in state["choices"]:
				assert_false(choice.has("hint"), "no hint in a choice")
			var buttons: Array[Button] = _choices()
			buttons[0].pressed.emit()
			if _entered > before and _last_kind != &"entrance" and _last_kind != &"boss":
				banners += 1
				assert_true(_banner().is_showing(), "banner after entering a %s room" % _last_kind)
		else:
			if state.has("stage"):
				var stage: Dictionary = state["stage"]
				for key: String in ["count", "monster", "acts"]:
					assert_true(stage.has(key), "stage.%s" % key)
				assert_eq((stage["acts"] as Array).size(), int(stage["count"]))
				var header: String = DungeonTexts.boss_header(int(stage["index"]), int(stage["count"]))
				var found: bool = false
				for node: Node in _page.find_children("*", "Label", true, false):
					if (node as Label).text == header and (node as Label).is_visible_in_tree():
						found = true
				if int(stage["index"]) >= 1 and phase == &"fight":
					boss_acts[int(stage["index"])] = found
			if fight.is_visible_in_tree():
				max_cells = maxi(max_cells, fight.grid().cell_count())
				assert_false(_has_times_label(fight.grid()), "no xN label in the enemy grid")
			_s.advance(STEP_MS)
		steps += 1
	assert_gt(banners, 0, "at least one banner during the run")
	assert_gt(max_cells, 1, "the grid showed a group")
	assert_gt(boss_acts.size(), 0, "boss stages reached")
	for act: int in boss_acts:
		assert_true(boss_acts[act], "boss band header of act %d" % act)


func test_no_banner_after_a_load() -> void:
	assert_true(_s.dungeon.open(&"monkey_den").ok)
	for _i: int in 4000:
		var phase: StringName = _s.dungeon.state()["phase"]
		if phase == &"await" or phase == &"event":
			break
		_s.advance(STEP_MS)
	var twin: GameSession = _new_session(7)
	assert_true(twin.from_save(_s.to_save(0)).ok)
	_page.unbind()
	_page.free()
	_bind(twin)
	var old: GameSession = _s
	_s = twin
	old.free()
	assert_false(_banner().is_showing(), "no banner after the load")
