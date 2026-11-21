class_name TutorialPanel
extends PanelContainer
## The card of the tutorial overlay (docs/05_INTERFACES_M30.md §7.ab): title, text, "Passo n di N", the event progress and
## the Avanti / Continua comunque buttons, or only the line "Vai a <pagina>" while the player must change page. It draws
## what the overlay gives it and keeps nothing else; the buttons only emit signals (the overlay sends the commands).

signal next_pressed
signal skip_pressed

var _title: Label
var _body: Label
var _step: Label
var _progress: Label
var _go_to: Label
var _reason: Label
var _next: Button
var _skip: Button
var _step_box: VBoxContainer


func _init() -> void:
	theme_type_variation = &"WindowPanel"
	custom_minimum_size = Vector2(UiStyle.TUTORIAL_PANEL_WIDTH, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UiStyle.TUTORIAL_PANEL_SEPARATION)
	add_child(box)
	_go_to = _label(box, "GoToLabel", &"HeaderLabel")
	_step_box = VBoxContainer.new()
	_step_box.name = "StepBox"
	_step_box.add_theme_constant_override("separation", UiStyle.TUTORIAL_PANEL_SEPARATION)
	box.add_child(_step_box)
	_title = _label(_step_box, "TitleLabel", &"HeaderLabel")
	_body = _label(_step_box, "BodyLabel", &"")
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size.x = UiStyle.TUTORIAL_PANEL_WIDTH - UiStyle.TUTORIAL_PANEL_TEXT_INSET  # an autowrap label needs a width
	_progress = _label(_step_box, "ProgressLabel", &"")
	_progress.add_theme_color_override("font_color", UiStyle.GOLD_LIGHT)
	_reason = _label(_step_box, "ReasonLabel", &"")
	_reason.add_theme_color_override("font_color", UiStyle.BAD)
	var row := HBoxContainer.new()
	_step_box.add_child(row)
	_step = _label(row, "StepLabel", &"MutedLabel")
	_step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next = _button(row, "NextButton", TutorialTexts.NEXT_TEXT, next_pressed)
	_skip = _button(row, "SkipButton", TutorialTexts.SKIP_TEXT, skip_pressed)
	_next.theme_type_variation = &"AccentButton"


## The card of a step: `progress` is shown only when `target_count` > 1.
func show_step(title: String, text: String, index: int, total: int, progress: int, target_count: int,
		can_next: bool, can_skip: bool) -> void:
	_go_to.visible = false
	_step_box.visible = true
	_title.text = title
	_body.text = text
	_step.text = TutorialTexts.STEP_TEXT % [index + 1, total]
	_progress.visible = target_count > 1
	_progress.text = TutorialTexts.PROGRESS_TEXT % [progress, target_count]
	_next.visible = can_next
	_skip.visible = can_skip
	_reason.visible = false
	reset_size()


## The card of the navigation state: only "Vai a <pagina>".
func show_navigation(page_name: String) -> void:
	_go_to.text = TutorialTexts.GO_TO_TEXT % page_name
	_go_to.visible = true
	_step_box.visible = false
	reset_size()


## Shows why Avanti / Continua comunque was refused.
func show_refused(text: String) -> void:
	_reason.text = text
	_reason.visible = true


func _label(parent: Node, node_name: String, variation: StringName) -> Label:
	var label := Label.new()
	label.name = node_name
	if variation != &"":
		label.theme_type_variation = variation
	parent.add_child(label)
	return label


func _button(parent: Node, node_name: String, text: String, request: Signal) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: request.emit())
	parent.add_child(button)
	return button
