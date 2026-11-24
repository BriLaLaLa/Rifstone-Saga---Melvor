class_name FoldableSection
extends VBoxContainer
## A section with a title button that folds and unfolds its content (docs/05_INTERFACES_M36.md §7.ae): collapsed at the start, the
## state is a view setting (not saved). The content keeps its own visibility inside the body, so a content that hides itself still works.
## Nodes: FoldButton, FoldBody.

signal toggled(collapsed: bool)

const OPEN_PREFIX: String = "- "
const CLOSED_PREFIX: String = "+ "

var _title: String = ""
var _collapsed: bool = true
var _button: Button = null
var _body: VBoxContainer = null


func setup(title: String, content: Control) -> void:
	_title = title
	_button = Button.new()
	_button.name = "FoldButton"
	_button.focus_mode = Control.FOCUS_NONE
	_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_button.pressed.connect(toggle)
	add_child(_button)
	_body = VBoxContainer.new()
	_body.name = "FoldBody"
	_body.add_child(content)
	add_child(_body)
	set_collapsed(true)


func is_collapsed() -> bool:
	return _collapsed


func toggle() -> void:
	set_collapsed(not _collapsed)


func set_collapsed(collapsed: bool) -> void:
	_collapsed = collapsed
	_body.visible = not collapsed
	_button.text = (CLOSED_PREFIX if collapsed else OPEN_PREFIX) + _title
	toggled.emit(collapsed)
