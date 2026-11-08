extends GutTest
## M12-06: toasts of the mastery milestones and of a blocked helper, and the layout of the new pages at 1600x900 and
## 1280x720 (Deposit with the bag slots, a gathering page with the helper row, the Engraver page).

const BANK_SCENE: PackedScene = preload("res://ui/pages/bank/bank_page.tscn")
const SKILL_SCENE: PackedScene = preload("res://ui/pages/skill/skill_page.tscn")
const SIZES: Array[Vector2] = [Vector2(1600, 900), Vector2(1280, 720)]

var _events: GameEvents
var _manager: ToastManager
var _session: GameSession
var _host: Control


func before_each() -> void:
	_events = GameEvents.new()
	_manager = ToastManager.new()
	_manager.events = _events
	_manager.name_resolver = func(id: StringName) -> String: return "skill %s" % id
	_manager.action_resolver = func(id: StringName) -> String: return "res %s" % id
	add_child(_manager)


func after_each() -> void:
	_manager.free()
	_events.free()
	if is_instance_valid(_host):
		_host.free()
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func test_milestone_toast_names_the_resource_and_the_step() -> void:
	_events.mastery_milestone_reached.emit(&"forestry", &"cut_redbirch", 25)
	assert_eq(_texts(), PackedStringArray(["Traguardo di maestria: res cut_redbirch (25)"]))


func test_blocked_helper_toast_names_the_trade_and_the_generic_one_is_dropped() -> void:
	_events.helper_blocked.emit(&"forestry", true)
	_events.notification_requested.emit(HelperSystem.BLOCKED_TEXT, &"warning")
	assert_eq(_texts(), PackedStringArray(["L'aiutante del skill forestry è fermo: Deposito pieno"]))
	_events.helper_blocked.emit(&"forestry", false)
	assert_eq(_texts().size(), 1, "no toast when it restarts")


func test_new_pages_fit_at_both_resolutions() -> void:
	_session = TestFactory.session(1234, TestFactory.real_data())
	TestFactory.give(_session, &"bag_canvas", 1)
	assert_true(_session.bank.equip_bag(0, &"bag_canvas").ok)
	for scene: PackedScene in [BANK_SCENE, SKILL_SCENE]:
		for skill_id: StringName in ([&"forestry", &"riftbinding"] if scene == SKILL_SCENE else [&""]):
			for size: Vector2 in SIZES:
				_host = Control.new()
				_host.size = size
				add_child(_host)
				var page: Page = scene.instantiate() as Page
				if skill_id != &"":
					page.page_id = StringName(PageHost.ROUTE_SKILL + PageHost.ROUTE_SEPARATOR + skill_id)
				page.set_anchors_preset(Control.PRESET_FULL_RECT)
				_host.add_child(page)
				page.bind(_session)
				await wait_process_frames(2)
				var rect: Rect2 = _host.get_global_rect()
				assert_lte((page.get_child(0) as Control).get_combined_minimum_size().x, size.x, "content fits %s at %s" % [skill_id, size])
				for node: Node in page.find_children("*", "Control", true, false):
					var control: Control = node as Control
					if control.is_visible_in_tree() and (control is Label or control is Button):
						assert_lte(control.get_global_rect().position.x, rect.end.x, "%s starts inside at %s" % [control.name, size])
				page.unbind()
				_host.free()
				_host = null


func _texts() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for child: Node in _manager.get_node("Stack").get_children():
		var toast: Toast = child as Toast
		if toast != null and not toast.is_queued_for_deletion():
			out.append((toast.get_node("%MessageLabel") as Label).text)
	return out
