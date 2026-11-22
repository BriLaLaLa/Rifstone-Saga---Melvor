class_name TutorialPanel
extends PanelContainer
## The card of the tutorial overlay (docs/05_INTERFACES_M30.md §7.ab): title, text, "Passo n di N", the event progress and
## the Avanti / Continua comunque buttons, or only the line "Vai a <pagina>" while the player must change page. It draws
## what the overlay gives it and keeps nothing else; the buttons only emit signals (the overlay sends the commands).

signal next_pressed
signal skip_pressed
## The player confirmed "Salta tutorial" (the overlay sends the command).
signal skip_tutorial_confirmed

var _title: Label
var _body: Label
var _step: Label
var _progress: Label
var _go_to: Label
var _reason: Label
var _next: Button
var _skip: Button
var _step_box: VBoxContainer
var _skip_tutorial: Button
var _confirm_box: VBoxContainer
## Presentation only: the confirmation question is on screen.
var _confirming: bool = false


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
	_skip_tutorial = _action(box, "SkipTutorialButton", TutorialTexts.SKIP_TUTORIAL_TEXT, _ask_skip_tutorial)
	_skip_tutorial.size_flags_horizontal = Control.SIZE_SHRINK_END
	_confirm_box = VBoxContainer.new()
	_confirm_box.name = "ConfirmBox"
	_confirm_box.visible = false
	_confirm_box.add_theme_constant_override("separation", UiStyle.TUTORIAL_PANEL_SEPARATION)
	box.add_child(_confirm_box)
	var question: Label = _label(_confirm_box, "ConfirmLabel", &"")
	question.text = TutorialTexts.SKIP_CONFIRM_TEXT
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question.custom_minimum_size.x = UiStyle.TUTORIAL_PANEL_WIDTH - UiStyle.TUTORIAL_PANEL_TEXT_INSET
	var answers := HBoxContainer.new()
	answers.alignment = BoxContainer.ALIGNMENT_END
	_confirm_box.add_child(answers)
	_action(answers, "ConfirmNoButton", TutorialTexts.NO_TEXT, _decline_skip_tutorial)
	_action(answers, "ConfirmYesButton", TutorialTexts.YES_TEXT, skip_tutorial_confirmed.emit).theme_type_variation = &"AccentButton"


## The card of a step: `progress` is shown only when `target_count` > 1, with `progress_text` ("%d ... %d", from the data) when
## given; `ack_text` is the label of the confirm button ("" = the default).
func show_step(title: String, text: String, index: int, total: int, progress: int, target_count: int,
		can_next: bool, can_skip: bool, progress_text: String = "", ack_text: String = "") -> void:
	_showing_navigation = false
	_go_to.visible = false
	_step_box.visible = true
	_title.text = title
	_body.text = text
	_step.text = TutorialTexts.STEP_TEXT % [index + 1, total]
	_progress.visible = target_count > 1
	_progress.text = (progress_text if not progress_text.is_empty() else TutorialTexts.PROGRESS_TEXT) % [progress, target_count]
	_next.text = ack_text if not ack_text.is_empty() else TutorialTexts.NEXT_TEXT
	_next.visible = can_next
	_skip.visible = can_skip
	_reason.visible = false
	if _confirming:
		_apply_confirm()
		return
	reset_size()


## The card of the navigation state: only "Vai a <pagina>".
func show_navigation(page_name: String) -> void:
	_showing_navigation = true
	_go_to.text = TutorialTexts.GO_TO_TEXT % page_name
	_go_to.visible = true
	_step_box.visible = false
	if _confirming:
		_apply_confirm()
		return
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


## Opens the confirmation in place of the card; "No" or a redraw of another step does not change it until answered.
func _ask_skip_tutorial() -> void:
	_confirming = true
	_apply_confirm()


func _decline_skip_tutorial() -> void:
	_confirming = false
	_apply_confirm()
	_restore_content.call_deferred()


## Content shown by the last `show_step` / `show_navigation`, re-applied when the question is closed.
var _showing_navigation: bool = false


func _restore_content() -> void:
	_go_to.visible = _showing_navigation
	_step_box.visible = not _showing_navigation
	reset_size()


func _apply_confirm() -> void:
	_confirm_box.visible = _confirming
	_skip_tutorial.visible = not _confirming
	if _confirming:
		_go_to.visible = false
		_step_box.visible = false
	reset_size()


func _action(parent: Node, node_name: String, text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button
