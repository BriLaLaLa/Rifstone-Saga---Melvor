class_name Toast
extends PanelContainer
## One toast row (display only): a short text with an accent stripe on the right in the color of its kind.
##
## Ported from the previous game's loot notification. The lifecycle is driven by ToastManager: it calls `setup`
## after adding the toast to the tree and `dismiss` when the toast has to go; the toast fades in, fades out and
## frees itself. It holds no game data, only the text it was given.

## Emitted when the fade-out has finished, right before the toast frees itself.
signal dismissed

## Accent color of each toast kind (`notification_requested` kinds of docs/05_INTERFACES.md §3).
const KIND_COLORS: Dictionary[StringName, Color] = {
	&"info": UiStyle.GOLD,
	&"success": UiStyle.GOOD,
	&"warning": UiStyle.BAD,
}
const ACCENT_WIDTH: int = 3

var _is_dismissing: bool = false

@onready var _message_label: Label = %MessageLabel


## Sets text and kind; an unknown kind is logged and shown as `&"info"`.
func setup(text: String, kind: StringName) -> void:
	var accent: Color = KIND_COLORS.get(kind, UiStyle.GOLD)
	if not KIND_COLORS.has(kind):
		Log.warn("toast", "unknown toast kind '%s', shown as info" % kind)
	_message_label.text = text
	var sb: StyleBoxFlat = UiStyle.flat(UiStyle.BG, accent, 0, 0.0)
	sb.border_width_right = ACCENT_WIDTH
	add_theme_stylebox_override("panel", sb)
	modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, UiStyle.TOAST_FADE_IN_SEC).set_trans(Tween.TRANS_LINEAR)


## Fades the toast out, emits `dismissed` and frees it. Calling it twice has no effect.
func dismiss() -> void:
	if _is_dismissing:
		return
	_is_dismissing = true
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, UiStyle.TOAST_FADE_OUT_SEC).set_trans(Tween.TRANS_LINEAR)
	tween.finished.connect(_on_fade_out_finished)


func _on_fade_out_finished() -> void:
	dismissed.emit()
	queue_free()
