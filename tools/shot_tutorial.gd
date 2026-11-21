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
