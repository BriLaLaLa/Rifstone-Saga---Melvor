extends GutTest
## Offline screens (M9-02): the progress overlay follows the signals of an injected GameEvents (only from min_ms),
## the summary view draws an OfflineSummary with names from the data. No real slot, no Game session.

const MIN_MS: int = 60000

var _session: GameSession
var _nodes: Array[Node] = []


func before_each() -> void:
	_session = TestFactory.session()


func after_each() -> void:
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func _overlay() -> OfflineOverlay:
	var overlay: OfflineOverlay = OfflineOverlay.SCENE.instantiate()
	overlay.events = _session.events
	overlay.min_ms = MIN_MS
	add_child(overlay)
	_nodes.append(overlay)
	return overlay


func test_overlay_hidden_below_min() -> void:
	var overlay: OfflineOverlay = _overlay()
	_session.events.offline_started.emit(MIN_MS - 1, false)
	assert_false(overlay.visible)


func test_overlay_follows_progress_and_closes() -> void:
	var overlay: OfflineOverlay = _overlay()
	assert_false(overlay.visible, "hidden until the simulation starts")
	_session.events.offline_started.emit(2 * 3600 * 1000, false)
	assert_true(overlay.visible)
	_session.events.offline_progress.emit(3600 * 1000, 2 * 3600 * 1000)
	assert_almost_eq((overlay.find_child("Bar", true, false) as ProgressBar).value, 0.5, 0.001)
	assert_eq((overlay.find_child("TimeLabel", true, false) as Label).text, "1 h 0 min / 2 h 0 min")
	_session.events.offline_completed.emit(OfflineSummary.new())
	assert_false(overlay.visible)


func test_overlay_disconnects_on_exit() -> void:
	var overlay: OfflineOverlay = _overlay()
	var before: int = _session.events.offline_started.get_connections().size()
	remove_child(overlay)
	assert_eq(_session.events.offline_started.get_connections().size(), before - 1)
	overlay.free()


func _view(summary: OfflineSummary) -> OfflineSummaryView:
	var view: OfflineSummaryView = OfflineSummaryView.open(self, summary, _session.data)
	_nodes.append(view)
	return view


func _text(view: OfflineSummaryView) -> String:
	return "\n".join(view.shown_lines())


func test_summary_empty() -> void:
	var summary: OfflineSummary = OfflineSummary.new()
	summary.elapsed_ms = 90000
	var text: String = _text(_view(summary))
	assert_true(text.contains("Tempo simulato: 1 min 30 s"), text)
	assert_true(text.contains(OfflineTexts.NOTHING_HAPPENED))


func test_summary_full() -> void:
	var item_id: StringName = _session.data.items()[0].id
	var item_name: String = _session.data.item(item_id).name
	var skill: SkillDef = _session.data.skills()[0]
	var summary: OfflineSummary = OfflineSummary.new()
	summary.elapsed_ms = 3600 * 1000
	summary.capped = true
	summary.xp = {skill.id: 1500, CharacterSystem.SAVE_KEY: 200}
	summary.levels = {skill.id: Vector2i(3, 5)}
	summary.items = {item_id: 42}
	summary.gold_delta = 10
	summary.deaths = 2
	summary.food_eaten = 7
	summary.pieces_stored = 3
	summary.pieces_dismantled = 5
	summary.pieces_rejected = 1
	summary.bank_rejected = {item_id: 4}
	summary.stop_reasons = [Reasons.NO_FOOD]
	summary.stop_times_ms = [11520000]
	var view: OfflineSummaryView = _view(summary)
	var text: String = _text(view)
	assert_true(text.contains(OfflineTexts.CAPPED_LINE))
	assert_true(text.contains("%s: +1.500 XP (livello 3 -> 5)" % skill.name), text)
	assert_true(text.contains("Personaggio: +200 XP"), text)
	assert_true(text.contains("%s x42" % item_name), text)
	assert_true(text.contains("%s x4 persi" % item_name), text)
	assert_true(text.contains("Morti: 2") and text.contains("Cibo mangiato: 7"), text)
	assert_true(text.contains("Pezzi conservati: 3") and text.contains("smantellati dal filtro: 5"), text)
	assert_true(text.contains("Armeria piena: 1"), text)
	assert_true(text.contains("Cibo finito: il combattimento si è fermato (dopo 3 h 12 min)"), text)


func test_summary_close_button() -> void:
	var view: OfflineSummaryView = _view(OfflineSummary.new())
	watch_signals(view)
	(view.find_child("CloseButton", true, false) as Button).pressed.emit()
	assert_signal_emitted(view, "closed")


func test_duration() -> void:
	assert_eq(OfflineTexts.duration(40000), "40 s")
	assert_eq(OfflineTexts.duration(125000), "2 min 5 s")
	assert_eq(OfflineTexts.duration(43200000), "12 h 0 min")
