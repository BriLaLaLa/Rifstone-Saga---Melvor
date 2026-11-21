extends Node
## Dev tool (M30-04): PNGs of the tutorial overlay and of the Primi passi pages, on a TestFactory session (never a real slot).
## Needs a window (NOT --headless); always run it under a timeout:
##   timeout 120 Godot --path . --resolution 1280x720 res://tools/shot_tutorial.tscn -- <out_dir> <w>x<h>
## Shots: welcome, go_to (navigation state), step_page (page target), step_target (control target), valve, sidebar_widget,
## starter_page (with something to claim).

const SCENE: String = "res://ui/screens/main/main_screen.tscn"

var _out: String = "user://shots_tutorial"


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	if args.size() > 1:
		var parts: PackedStringArray = args[1].split("x")
		get_tree().root.size = Vector2i(int(parts[0]), int(parts[1]))
	_run()


func _run() -> void:
	if args_mode() == "real":
		await _run_real()
		get_tree().quit(0)
		return
	await _shot(&"welcome", {})
	await _shot(&"go_to", {}, &"", false, true)
	await _shot(&"step_page", {"completed": false, "step": "character", "visited": [], "since_ms": 0}, &"character")
	await _shot(&"step_target", {"completed": false, "step": "combat_start", "visited": ["character"], "since_ms": 0})
	await _shot(&"valve", {"completed": false, "step": "combat_start", "visited": ["character"], "since_ms": 0}, &"", true)
	await _shot(&"finish", {"completed": false, "step": "finish", "visited": ["character", "combat"], "since_ms": 0})
	await _shot_done(&"starter_page", true)
	await _shot_done(&"sidebar_widget", false)
	print_rich("shots in ", ProjectSettings.globalize_path(_out))
	get_tree().quit(0)


func args_mode() -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	return args[2] if args.size() > 2 else ""


## A main screen on a new tutorial game loaded at `step` (a tutorial save); `page` is shown first, `stuck` skips the valve time.
func _shot(shot: StringName, step: Dictionary, page: StringName = &"", stuck: bool = false, acknowledge: bool = false) -> void:
	var session: GameSession = TestFactory.session(1234, TestFactory.real_data(), true, true)
	if not step.is_empty():
		session.tutorial.from_save(step)
	if stuck:
		session.play_time_ms += session.data.tutorial_stuck_ms()
	var screen: MainScreen = await _open(session)
	if acknowledge:  # the first step done: the second one needs another page
		session.tutorial.acknowledge()
	if page != &"":
		(screen.find_child("PageHost", true, false) as PageHost).show_page(page)
	await _frames(6)
	_save(shot)
	screen.free()
	session.free()
	await _frames(2)


## A main screen on a completed tutorial with a level that makes quests claimable; the starter page or the sidebar.
func _shot_done(shot: StringName, page: bool) -> void:
	var session: GameSession = TestFactory.session(1234, TestFactory.real_data(), true)
	TestFactory.set_character_level(session, 3)
	var screen: MainScreen = await _open(session)
	if page:
		(screen.find_child("PageHost", true, false) as PageHost).show_page(&"starter")
	await _frames(6)
	_save(shot)
	screen.free()
	session.free()
	await _frames(2)


func _open(session: GameSession) -> MainScreen:
	var screen: MainScreen = (load(SCENE) as PackedScene).instantiate() as MainScreen
	screen.session = session
	get_tree().root.add_child.call_deferred(screen)
	await _frames(4)
	return screen


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame


func _save(shot: StringName) -> void:
	var image: Image = get_tree().root.get_texture().get_image()
	image.save_png("%s/%s.png" % [ProjectSettings.globalize_path(_out), String(shot)])


# --- M30-05: the real new game (nothing learned, the Armory kit) at every step; the targets of §34.4 resolved on the real pages ---
# Third argument "real": prints `TARGET <n> <id> <target> OK|MISS` for the 21 steps and saves step01, step03, step04, step11, step17,
# chain_widget and chain_starter. A real new game, as the title screen makes it (no `learn_all`).

const SHOT_STEPS: Array[int] = [1, 3, 4, 11, 17]


func _real_session() -> GameSession:
	var events: GameEvents = GameEvents.new()
	var session: GameSession = GameSession.new(TestFactory.real_data(), events, 3060)
	session.add_child(events)
	session.new_game()
	return session


## The route to show for a step ("skill" needs a discipline: the first one learned).
func _route_of(step: TutorialStepDef) -> StringName:
	return &"skill:forestry" if step.page == &"skill" else step.page


func _run_real() -> void:
	var steps: Array[TutorialStepDef] = TestFactory.real_data().tutorial_steps()
	for i: int in steps.size():
		var step: TutorialStepDef = steps[i]
		var session: GameSession = _real_session()
		var visited: Array = []
		for j: int in i + 1:
			if steps[j].page != &"":
				visited.append(String(steps[j].page))
		session.tutorial.from_save({"completed": false, "step": String(step.id), "visited": visited, "since_ms": 0})
		if i > 10:  # after the Trainers step the player has learned the Woodcutter
			session.disciplines.learn(&"forestry")
		if step.id == &"mail":
			session.mail.post(&"tutorial_gift", {"money": 3000})
		var screen: MainScreen = await _open(session)
		if step.page == &"combat" and step.id != &"combat_start":
			session.combat.start(&"redrock_plains")
		if step.page != &"":
			(screen.find_child("PageHost", true, false) as PageHost).show_page(_route_of(step))
		await _frames(8)
		var found: Control = TutorialTargets.resolve(step.target, screen)
		print_rich("TARGET %d %s %s %s" % [i + 1, step.id, step.target if step.target != "" else "-", "OK" if found != null else ("MISS" if step.target != "" else "none")])
		if SHOT_STEPS.has(i + 1):
			_save(StringName("step%02d" % (i + 1)))
		screen.free()
		session.free()
		await _frames(2)
	# the widget in the middle of the chain: tutorial done, level 10, one claimed and one still to claim (the dot)
	var done: GameSession = _real_session()
	done.tutorial.from_save({"completed": true, "step": "", "visited": []})
	done.hints.from_save({"seen": ["first_level_ten", "first_shard", "first_defeat"]})  # no modal card over the shot
	TestFactory.set_character_level(done, 10)
	done.tutorial.starter.claim(&"level_3")
	var screen2: MainScreen = await _open(done)
	await _frames(6)
	_save(&"chain_widget")
	(screen2.find_child("PageHost", true, false) as PageHost).show_page(&"starter")
	await _frames(8)
	_save(&"chain_starter")
	var groups: int = screen2.find_children("*", "", true, false).filter(func(n: Node) -> bool: return String(n.name).begins_with("Group_")).size()
	print_rich("STARTER groups-named-nodes ", groups, " claimed ", done.tutorial.starter.claimed_count(), " of ", done.tutorial.starter.total())
	screen2.free()
	done.free()
	print_rich("real shots in ", ProjectSettings.globalize_path(_out))
