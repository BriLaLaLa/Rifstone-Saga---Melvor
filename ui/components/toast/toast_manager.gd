class_name ToastManager
extends Control
## Toast stack at the bottom right of the main screen (docs/01_GDD.md §13), at most `UiStyle.TOAST_MAX_VISIBLE`.
##
## Ported from the previous game's global loot notification layer: here it is a Control inside the screen that
## listens to the EventBus instead of being called by every system. Public API (docs/05_INTERFACES.md §7):
## `push(text, kind)`. It shows toasts for `notification_requested`, `bank_changed` (increases only, summed per
## item over `UiStyle.TOAST_GROUP_MS`), `level_up` and `action_stopped`. It never changes game state.
##
## Injection points (set them before adding the node to the tree):
## - `events`: the GameEvents to listen to; null means the `EventBus` autoload. Tests pass a fresh `GameEvents.new()`.
## - `time_source`: `() -> int` in milliseconds, used for grouping and toast lifetime; tests pass a fake clock and
##   drive `_process` with `gut.simulate`.
## - `name_resolver`: `(id: StringName) -> String`, display name of an item or skill id. Until GameData exists (M1-04)
##   the default shows the id itself; the main screen sets it to read names from the data.
##
## `bank_changed` toasts use the signed `delta` of each change: only positive deltas count, summed per item while
## the group window is open. Open groups are dropped on `session_ended`, so they never leak into another slot.

const TOAST_SCENE: PackedScene = preload("res://ui/components/toast/toast.tscn")
const KIND_INFO := &"info"
const KIND_SUCCESS := &"success"
const KIND_WARNING := &"warning"
## Stop reasons that the player caused, so they get no toast.
const SILENT_STOP_REASONS: Array[StringName] = [Reasons.STOPPED_BY_USER, Reasons.REPLACED]
## Italian text of each stop reason; other reasons use STOP_TEXT_DEFAULT.
const STOP_TEXTS: Dictionary[StringName, String] = {
	Reasons.MISSING_INPUTS: "materiali finiti",
	Reasons.BANK_FULL: "bank piena",
	Reasons.LEVEL_TOO_LOW: "livello troppo basso",
	Reasons.REQUIREMENT_NOT_MET: "requisito non soddisfatto",
	Reasons.NO_FOOD: "cibo finito",
	Reasons.PLAYER_DIED: "sei stato sconfitto",
}
const STOP_TEXT_DEFAULT := "interrotta"

## Event bus to listen to; null = the `EventBus` autoload.
var events: GameEvents = null
## `() -> int`, current time in milliseconds.
var time_source: Callable = Time.get_ticks_msec
## `(id: StringName) -> String`, display name of an item or skill.
var name_resolver: Callable = _default_name

var _stack: VBoxContainer
var _bound_events: GameEvents = null
var _active: Array[Toast] = []
var _expiry_ms: Dictionary[Toast, int] = {}
var _pending_texts: PackedStringArray = PackedStringArray()
var _pending_kinds: Array[StringName] = []
var _group_qty: Dictionary[StringName, int] = {}
var _group_start_ms: Dictionary[StringName, int] = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_stack = VBoxContainer.new()
	_stack.name = "Stack"
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.alignment = BoxContainer.ALIGNMENT_END
	_stack.add_theme_constant_override("separation", UiStyle.TOAST_STACK_SEPARATION)
	add_child(_stack)
	_stack.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE,
			UiStyle.TOAST_EDGE_MARGIN)
	_stack.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_stack.grow_vertical = Control.GROW_DIRECTION_BEGIN


func _enter_tree() -> void:
	_bound_events = events if events != null else EventBus
	_bound_events.notification_requested.connect(_on_events_notification_requested)
	_bound_events.bank_changed.connect(_on_events_bank_changed)
	_bound_events.level_up.connect(_on_events_level_up)
	_bound_events.action_stopped.connect(_on_events_action_stopped)
	_bound_events.session_ended.connect(_on_events_session_ended)


func _exit_tree() -> void:
	if not is_instance_valid(_bound_events):
		_bound_events = null
		return
	_bound_events.notification_requested.disconnect(_on_events_notification_requested)
	_bound_events.bank_changed.disconnect(_on_events_bank_changed)
	_bound_events.level_up.disconnect(_on_events_level_up)
	_bound_events.action_stopped.disconnect(_on_events_action_stopped)
	_bound_events.session_ended.disconnect(_on_events_session_ended)
	_bound_events = null


func _process(_delta: float) -> void:
	var now: int = _now()
	_flush_groups(now)
	_expire_toasts(now)


## Shows a toast now, or queues it while `UiStyle.TOAST_MAX_VISIBLE` toasts are on screen.
## `kind` is `&"info"`, `&"success"` or `&"warning"`.
func push(text: String, kind: StringName) -> void:
	if _active.size() < UiStyle.TOAST_MAX_VISIBLE:
		_spawn(text, kind)
		return
	_pending_texts.append(text)
	_pending_kinds.append(kind)


func _spawn(text: String, kind: StringName) -> void:
	var toast: Toast = TOAST_SCENE.instantiate() as Toast
	_stack.add_child(toast)
	toast.setup(text, kind)
	_active.append(toast)
	_expiry_ms[toast] = _now() + UiStyle.TOAST_LIFETIME_MS
	toast.dismissed.connect(_on_toast_dismissed.bind(toast), CONNECT_ONE_SHOT)


func _expire_toasts(now: int) -> void:
	for toast: Toast in _expiry_ms.keys():
		if now >= _expiry_ms[toast]:
			_expiry_ms.erase(toast)
			toast.dismiss()


func _flush_groups(now: int) -> void:
	for item_id: StringName in _group_qty.keys():
		if now - _group_start_ms[item_id] >= UiStyle.TOAST_GROUP_MS:
			var qty: int = _group_qty[item_id]
			_group_qty.erase(item_id)
			_group_start_ms.erase(item_id)
			push("+%s %s" % [_format_count(qty), _display_name(item_id)], KIND_SUCCESS)


func _on_toast_dismissed(toast: Toast) -> void:
	_active.erase(toast)
	_expiry_ms.erase(toast)
	if not _pending_texts.is_empty() and _active.size() < UiStyle.TOAST_MAX_VISIBLE:
		var text: String = _pending_texts[0]
		var kind: StringName = _pending_kinds[0]
		_pending_texts.remove_at(0)
		_pending_kinds.remove_at(0)
		_spawn(text, kind)


func _on_events_notification_requested(text: String, kind: StringName) -> void:
	push(text, kind)


func _on_events_bank_changed(item_id: StringName, _new_count: int, delta: int) -> void:
	if delta <= 0:
		return
	var now: int = _now()
	_flush_groups(now)
	if _group_qty.has(item_id):
		_group_qty[item_id] += delta
	else:
		_group_qty[item_id] = delta
		_group_start_ms[item_id] = now


func _on_events_level_up(skill_id: StringName, new_level: int) -> void:
	push("%s: livello %d" % [_display_name(skill_id), new_level], KIND_SUCCESS)


func _on_events_action_stopped(_lane: StringName, skill_id: StringName, reason: StringName) -> void:
	if SILENT_STOP_REASONS.has(reason):
		return
	var reason_text: String = STOP_TEXTS.get(reason, STOP_TEXT_DEFAULT)
	push("%s: azione fermata (%s)" % [_display_name(skill_id), reason_text], KIND_WARNING)


func _on_events_session_ended(_slot: int) -> void:
	_group_qty.clear()
	_group_start_ms.clear()


func _now() -> int:
	return time_source.call() as int


func _display_name(id: StringName) -> String:
	return name_resolver.call(id) as String


static func _default_name(id: StringName) -> String:
	return String(id)


## Item quantity of a toast, via NumberFormat (1250 -> "1.250").
static func _format_count(value: int) -> String:
	return NumberFormat.format_int(value)
