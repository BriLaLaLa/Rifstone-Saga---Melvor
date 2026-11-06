class_name RefineBox
extends VBoxContainer
## Refinement box of the piece panel (docs/01_GDD.md §23): the step "+N → +N+1", the success chance, the cost with
## what the player owns, the failure rule and, when a failure can lower the piece, the option to use the Warding Seal.
## Everything is read from `RefineTexts.refine_info` (Upgrade + session); the box only emits `refine_requested`, the
## page sends `armory.upgrade`. It keeps no game state: the checkbox is a presentation choice reset at every opening.

signal refine_requested(use_seal: bool)

const CONFIRM_TEXT: String = "Tenta la raffinazione"
const SEPARATION: int = 4

var _title: Label = null
var _chance: Label = null
var _costs: Label = null
var _fail: Label = null
var _seal: CheckBox = null
var _confirm: Button = null


func _ready() -> void:
	add_theme_constant_override("separation", SEPARATION)
	_title = _label(&"HeaderLabel")
	_chance = _label(&"")
	_costs = _label(&"")
	_fail = _label(&"MutedLabel")
	_seal = CheckBox.new()
	_seal.name = "SealCheck"
	_seal.focus_mode = Control.FOCUS_NONE
	add_child(_seal)
	_confirm = Button.new()
	_confirm.name = "ConfirmButton"
	_confirm.text = CONFIRM_TEXT
	_confirm.focus_mode = Control.FOCUS_NONE
	_confirm.custom_minimum_size.y = UiStyle.MENU_BUTTON_HEIGHT
	_confirm.pressed.connect(func() -> void: refine_requested.emit(_seal.visible and _seal.button_pressed))
	add_child(_confirm)
	visible = false


## Draws the step of `uid` as it is now; `reset_seal` unticks the Seal (a new opening).
func show_for(session: GameSession, uid: int, reset_seal: bool = false) -> void:
	var info: Dictionary = RefineTexts.refine_info(session, uid)
	if reset_seal:
		_seal.button_pressed = false
	if info["max"]:
		_title.text = RefineTexts.MAX_TEXT
		for node: Control in [_chance, _costs, _fail, _seal, _confirm]:
			node.visible = false
		return
	_title.text = info["title"]
	_chance.text = info["chance"]
	_costs.text = RefineTexts.COST_TITLE + "\n" + "\n".join(info["cost_lines"] as PackedStringArray)
	_fail.text = info["fail_text"]
	_seal.visible = info["seal_possible"]
	_seal.text = RefineTexts.SEAL_TEXT % [info["seal_name"], NumberFormat.format_int(int(info["seal_have"]))]
	if not _seal.visible:
		_seal.button_pressed = false
	for node: Control in [_chance, _costs, _fail, _confirm]:
		node.visible = true


func _label(variation: StringName) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if variation != &"":
		label.theme_type_variation = variation
	add_child(label)
	return label


## State of the box for tests.
func title_text() -> String:
	return _title.text


func chance_text() -> String:
	return _chance.text


func costs_text() -> String:
	return _costs.text


func seal_visible() -> bool:
	return _seal.visible


func confirm_button() -> Button:
	return _confirm
