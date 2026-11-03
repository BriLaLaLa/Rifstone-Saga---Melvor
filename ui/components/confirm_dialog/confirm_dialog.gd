class_name ConfirmDialog
extends ConfirmationDialog
## Yes/no confirmation (docs/05_INTERFACES.md §7). `await ConfirmDialog.ask(parent, title, text)` is true only when
## the player presses the confirm button; Cancel, Esc and the close button give false.
##
## `ask` adds the dialog under `parent`, shows it centred (exclusive, so the screen below takes no input), waits for
## the answer and frees the dialog. Tests answer it by emitting `confirmed` or `canceled` on the ConfirmDialog child.

## Emitted once with the answer; internal to `ask`.
signal _answered(accepted: bool)

const OK_TEXT := "Conferma"
const CANCEL_TEXT := "Annulla"
## Initial size of the dialog (the text wraps inside it).
const DIALOG_SIZE := Vector2i(460, 0)

var _done: bool = false


func _init() -> void:
	ok_button_text = OK_TEXT
	cancel_button_text = CANCEL_TEXT
	dialog_autowrap = true
	exclusive = true
	confirmed.connect(_on_confirmed)
	canceled.connect(_on_canceled)


## Coroutine: shows the question under `parent` and returns the answer.
static func ask(parent: Node, title: String, text: String) -> bool:
	var dialog := ConfirmDialog.new()
	dialog.title = title
	dialog.dialog_text = text
	parent.add_child(dialog)
	dialog.popup_centered(DIALOG_SIZE)
	var accepted: bool = await dialog._answered
	dialog.queue_free()
	return accepted


func _answer(accepted: bool) -> void:
	if _done:
		return
	_done = true
	hide()
	_answered.emit(accepted)


func _on_confirmed() -> void:
	_answer(true)


func _on_canceled() -> void:
	_answer(false)
