class_name OfflineOverlay
extends Control
## Progress overlay of the offline simulation (docs/01_GDD.md §12): opens on `offline_started` (only from
## `offline.min_ms` of time away), follows `offline_progress`, hides itself on `offline_completed`. It blocks the
## input below it and holds no game state: it draws the numbers carried by the signals.
##
## Injection points (set before adding to the tree): `events` (null = the EventBus autoload), `min_ms` (-1 = read
## `offline.min_ms` from the data registry).

const SCENE: PackedScene = preload("res://ui/screens/offline/offline_overlay.tscn")
const MIN_KEY: String = "offline.min_ms"

var events: GameEvents = null
var min_ms: int = -1

var _events: GameEvents = null

@onready var _dim: ColorRect = %Dim
@onready var _title: Label = %TitleLabel
@onready var _time: Label = %TimeLabel
@onready var _bar: ProgressBar = %Bar


## Adds an overlay under `parent`, hidden until an offline simulation of enough length starts.
static func attach(parent: Node, source: GameEvents = null) -> OfflineOverlay:
	var overlay: OfflineOverlay = SCENE.instantiate()
	overlay.events = source
	parent.add_child(overlay)
	return overlay


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.color = UiStyle.OFFLINE_DIM
	_title.text = OfflineTexts.PROGRESS_TITLE
	UiStyle.style_bar(_bar, UiStyle.GOLD)
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.step = 0.0
	_bar.show_percentage = false
	_events = events if events != null else EventBus
	_events.offline_started.connect(_on_started)
	_events.offline_progress.connect(_on_progress)
	_events.offline_completed.connect(_on_completed)


func _exit_tree() -> void:
	if _events == null:
		return
	if _events.offline_started.is_connected(_on_started):
		_events.offline_started.disconnect(_on_started)
	if _events.offline_progress.is_connected(_on_progress):
		_events.offline_progress.disconnect(_on_progress)
	if _events.offline_completed.is_connected(_on_completed):
		_events.offline_completed.disconnect(_on_completed)
	_events = null


func _on_started(elapsed_ms: int, _capped: bool) -> void:
	var threshold: int = min_ms if min_ms >= 0 else int(DataRegistry.data.balance_value(MIN_KEY))
	if elapsed_ms < threshold:
		return
	_redraw(0, elapsed_ms)
	visible = true


func _on_progress(done_ms: int, total_ms: int) -> void:
	if visible:
		_redraw(done_ms, total_ms)


func _on_completed(_summary: OfflineSummary) -> void:
	visible = false


func _redraw(done_ms: int, total_ms: int) -> void:
	_bar.value = clampf(float(done_ms) / float(maxi(total_ms, 1)), 0.0, 1.0)
	_time.text = OfflineTexts.PROGRESS_TIME % [OfflineTexts.duration(done_ms), OfflineTexts.duration(total_ms)]
