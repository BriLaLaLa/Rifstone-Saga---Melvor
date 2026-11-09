class_name ActionCard
extends PanelContainer
## Card of one action on the SkillPage (docs/01_GDD.md §4): icon, name, required level, base XP, current interval
## (F-03, read from `actions.current_interval_ms`), products, mastery level and bar, cycle progress, Start/Stop.
##
## `setup` draws the parts that come from the data; `redraw` reads everything else from the session; the page calls
## `set_progress` every frame with `actions.get_progress`. Pressing the button emits `toggle_requested`: the page sends
## the command (start or stop) and shows a refusal. The card keeps no game state, only its ActionDef and its nodes.
## A card below the required level is drawn locked (button disabled, requirement in red); the running one has its
## name in light gold and a Stop button.

signal toggle_requested(action_id: StringName)

const ITEM_SLOT_SCENE: PackedScene = preload("res://ui/components/item_slot/item_slot.tscn")
const LANE_ACTION_KEY: String = "action"
const LEVEL_TEXT: String = "Livello %s"
const LOCKED_TEXT: String = "Richiede il livello %s"
const XP_TEXT: String = "%s XP"
const MASTERY_TEXT: String = "Liv. %s"
const NO_MASTERY_TEXT: String = "Nessuna"
const START_TEXT: String = "Avvia"
const STOP_TEXT: String = "Ferma"

var _action: ActionDef = null
var _step_row: MasteryStepRow = null

@onready var _icon: TextureRect = %Icon
@onready var _name_label: Label = %NameLabel
@onready var _requirement_label: Label = %RequirementLabel
@onready var _xp_label: Label = %XpValue
@onready var _interval_label: Label = %IntervalValue
@onready var _products: HBoxContainer = %Products
@onready var _mastery_label: Label = %MasteryValue
@onready var _mastery_bar: XpBar = %MasteryBar
@onready var _progress_bar: ActionProgressBar = %ProgressBar
@onready var _toggle_button: Button = %ToggleButton


func _ready() -> void:
	_toggle_button.pressed.connect(_on_toggle_button_pressed)


## Draws the data of `action` (call it once, after the card entered the tree).
func setup(action: ActionDef, data: GameData) -> void:
	_action = action
	name = String(action.id).to_pascal_case()
	_icon.texture = ItemSlotView.icon_of(action.icon)
	_name_label.text = action.name
	_name_label.tooltip_text = action.name
	_xp_label.text = XP_TEXT % NumberFormat.format_int(action.xp)
	for output: ItemQty in action.outputs:
		var item: ItemDef = data.item(output.item_id)
		if item == null:
			continue
		var slot: ItemSlotView = ITEM_SLOT_SCENE.instantiate() as ItemSlotView
		slot.name = "Product%s" % String(item.id).to_pascal_case()
		_products.add_child(slot)
		slot.set_item(item, output.qty)
		var label: Label = Label.new()
		label.name = "Product%sLabel" % String(item.id).to_pascal_case()
		label.text = item.name
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_products.add_child(label)
	_mastery_bar.visible = action.mastery
	if action.mastery:
		_step_row = MasteryStepRow.new()
		_step_row.name = "MasteryStepRow"
		_mastery_bar.add_sibling(_step_row)
		_step_row.setup(data)


## Reads level, interval, mastery and the running action from `session`.
func redraw(session: GameSession) -> void:
	var unlocked: bool = session.skills.meets_requirements({_action.skill_id: _action.level})
	var running_id: StringName = session.actions.get_lane().get(LANE_ACTION_KEY, &"")
	var running: bool = running_id == _action.id
	var level_text: String = NumberFormat.format_int(_action.level)
	_requirement_label.text = (LEVEL_TEXT if unlocked else LOCKED_TEXT) % level_text
	if unlocked:
		_requirement_label.remove_theme_color_override("font_color")
	else:
		_requirement_label.add_theme_color_override("font_color", UiStyle.BAD)
	_icon.modulate = Color.WHITE if unlocked else UiStyle.TEXT_DISABLED
	_interval_label.text = seconds_text(session.actions.current_interval_ms(_action.id))
	if _action.mastery:
		_mastery_label.text = MASTERY_TEXT % NumberFormat.format_int(session.mastery.get_mastery_level(_action.id))
		_mastery_bar.set_xp(session.data.mastery_table(), session.mastery.get_mastery_xp(_action.id))
		if _step_row != null:
			_step_row.show_info(session.mastery.step_info(_action.skill_id, _action.id))
	else:
		_mastery_label.text = NO_MASTERY_TEXT
	_toggle_button.text = STOP_TEXT if running else START_TEXT
	_toggle_button.disabled = not unlocked and not running
	if running:
		_name_label.add_theme_color_override("font_color", UiStyle.GOLD_LIGHT)
	else:
		_name_label.remove_theme_color_override("font_color")


## Draws the cycle progress read from the session (0..1).
func set_progress(progress: float) -> void:
	_progress_bar.set_progress(progress)


func action_id() -> StringName:
	return _action.id if _action != null else &""


## Milliseconds as seconds with at least one decimal (NumberFormat.format_seconds): 3000 -> "3,0 s".
static func seconds_text(ms: int) -> String:
	return NumberFormat.format_seconds(ms)


func _on_toggle_button_pressed() -> void:
	if _action != null:
		toggle_requested.emit(_action.id)
