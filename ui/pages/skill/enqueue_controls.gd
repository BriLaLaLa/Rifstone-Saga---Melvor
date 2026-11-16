class_name EnqueueControls
extends VBoxContainer
## The "Metti in coda" controls of a recipe card (docs/01_GDD_M24.md §35.11): a quantity (SpinBox with the shortcuts 1, 10
## and 100), the "Ripeti" check and the button. Pressing it emits `enqueue_requested`; the page sends `actions.enqueue`
## and shows a refusal. A locked recipe ("Da scoprire") disables everything. It keeps no game state: the quantity typed.

signal enqueue_requested(count: int, repeat: bool)

## Upper bound of the spin box: the model refuses a job that is too large (`invalid_amount`), the limit is not copied here.
const SPIN_MAX: float = 999999.0
const LINE_SEPARATION: int = 6

var _spin: SpinBox = null
var _repeat: CheckBox = null
var _button: Button = null
var _locked: Label = null
var _shortcuts: Array[Button] = []


func _ready() -> void:
	name = "EnqueueControls"
	add_theme_constant_override("separation", LINE_SEPARATION)
	_locked = Label.new()
	_locked.name = "LockedLabel"
	_locked.text = QueueTexts.LOCKED_TEXT
	_locked.tooltip_text = QueueTexts.LOCKED_TIP
	_locked.mouse_filter = Control.MOUSE_FILTER_STOP
	_locked.add_theme_color_override("font_color", UiStyle.GOLD_LIGHT)
	_locked.visible = false
	add_child(_locked)
	var line := HFlowContainer.new()  # wraps in a card of the minimum width
	line.name = "QuantityLine"
	line.add_theme_constant_override("h_separation", LINE_SEPARATION)
	add_child(line)
	_spin = SpinBox.new()
	_spin.name = "QuantitySpin"
	_spin.min_value = 1.0
	_spin.max_value = SPIN_MAX
	_spin.step = 1.0
	_spin.value = 1.0
	_spin.tooltip_text = QueueTexts.QUANTITY_TEXT
	line.add_child(_spin)
	for amount: int in QueueTexts.SHORTCUTS:
		var shortcut := Button.new()
		shortcut.name = "Shortcut%s" % amount
		shortcut.text = QueueTexts.SHORTCUT_TEXT % amount
		shortcut.focus_mode = Control.FOCUS_NONE
		shortcut.pressed.connect(func() -> void: _spin.value = float(amount))
		line.add_child(shortcut)
		_shortcuts.append(shortcut)
	_repeat = CheckBox.new()
	_repeat.name = "RepeatCheck"
	_repeat.text = QueueTexts.REPEAT_TEXT
	_repeat.focus_mode = Control.FOCUS_NONE
	_repeat.toggled.connect(func(on: bool) -> void: _spin.editable = not on)
	line.add_child(_repeat)
	_button = Button.new()
	_button.name = "EnqueueButton"
	_button.text = QueueTexts.ENQUEUE_TEXT
	_button.theme_type_variation = &"AccentButton"
	_button.custom_minimum_size = Vector2(0, 40)
	_button.focus_mode = Control.FOCUS_NONE
	_button.pressed.connect(func() -> void: enqueue_requested.emit(int(_spin.value), _repeat.button_pressed))
	add_child(_button)


## `usable`: the recipe can be put in the queue now (level reached); `known`: the recipe is discovered.
func set_state(known: bool, usable: bool) -> void:
	_locked.visible = not known
	var enabled: bool = known and usable
	_button.disabled = not enabled
	_spin.editable = enabled and not _repeat.button_pressed
	_repeat.disabled = not enabled
	for shortcut: Button in _shortcuts:
		shortcut.disabled = not enabled
