class_name MasteryNodeView
extends PanelContainer
## Card of one mastery node in the MasteryNodeTree (docs/01_GDD.md §6.3): name, modifiers (labels from
## `StatRegistry.info` through ItemTooltipLines), F-15 cost read from `mastery.node_cost`, state and Buy button.
##
## `setup` draws the parts that come from the data; `redraw` reads the rest from the session. The state is never
## stored: `state_of` derives it from `owns_node` and `can_buy_node(id).reason` at every redraw. Pressing Buy emits
## `buy_requested`; the panel sends `mastery.buy_node` and shows a refusal. The card keeps only its MasteryNodeDef.

signal buy_requested(node_id: StringName)

var _node: MasteryNodeDef = null

@onready var _content: Control = %Content
@onready var _name_label: Label = %NameLabel
@onready var _modifiers_label: RichTextLabel = %ModifiersLabel
@onready var _cost_label: Label = %CostLabel
@onready var _state_label: Label = %StateLabel
@onready var _buy_button: Button = %BuyButton


func _ready() -> void:
	custom_minimum_size = UiStyle.MASTERY_NODE_SIZE
	_buy_button.text = MasteryTexts.BUY_TEXT
	_buy_button.pressed.connect(_on_buy_button_pressed)


## Draws the data of `node` (call it once, after the card entered the tree).
func setup(node: MasteryNodeDef, data: GameData) -> void:
	_node = node
	name = String(node.id).to_pascal_case()
	_name_label.text = node.name
	tooltip_text = node.description
	_modifiers_label.text = "\n".join(ItemTooltipLines.modifier_lines(node.modifiers, data))


## Reads cost, ownership and buyability of the node from `session`.
func redraw(session: GameSession) -> void:
	var mastery: MasterySystem = session.mastery
	_cost_label.text = MasteryTexts.COST_TEXT % [NumberFormat.format_int(mastery.node_cost(_node.id)),
			NumberFormat.format_number(_node.cost_pct)]
	var state: StringName = state_of(session, _node.id)
	_state_label.text = MasteryTexts.state_text(state)
	if state == MasteryTexts.STATE_LOCKED:
		_state_label.text = MasteryTexts.REQUIRES_TEXT % ", ".join(_missing_names(session))
	_state_label.tooltip_text = _state_label.text
	_state_label.add_theme_color_override("font_color", _state_color(state))
	_buy_button.visible = state == MasteryTexts.STATE_BUYABLE or state == MasteryTexts.STATE_UNAFFORDABLE
	_buy_button.disabled = state != MasteryTexts.STATE_BUYABLE
	var locked: bool = state == MasteryTexts.STATE_LOCKED
	_content.modulate = Color(Color.WHITE, UiStyle.MASTERY_LOCKED_ALPHA) if locked else Color.WHITE
	if state == MasteryTexts.STATE_OWNED:
		_name_label.add_theme_color_override("font_color", UiStyle.GOOD)
	else:
		_name_label.remove_theme_color_override("font_color")


func node_id() -> StringName:
	return _node.id if _node != null else &""


## Position of the node in the tree (`pos` of the data, [col, row]).
func grid_pos() -> Vector2i:
	return _node.pos if _node != null else Vector2i.ZERO


## Ids of the nodes this one requires (from the data).
func required_ids() -> Array[StringName]:
	return _node.requires if _node != null else ([] as Array[StringName])


## State of a node read from the session: owned, buyable, locked (a prerequisite is missing) or unaffordable.
static func state_of(session: GameSession, id: StringName) -> StringName:
	if session.mastery.owns_node(id):
		return MasteryTexts.STATE_OWNED
	var check: CommandResult = session.mastery.can_buy_node(id)
	if check.ok:
		return MasteryTexts.STATE_BUYABLE
	if check.reason == Reasons.POOL_INSUFFICIENT:
		return MasteryTexts.STATE_UNAFFORDABLE
	return MasteryTexts.STATE_LOCKED


func _missing_names(session: GameSession) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for required: StringName in _node.requires:
		if session.mastery.owns_node(required):
			continue
		var def: MasteryNodeDef = session.data.mastery_node(required)
		names.append(def.name if def != null else String(required))
	return names


static func _state_color(state: StringName) -> Color:
	match state:
		MasteryTexts.STATE_OWNED:
			return UiStyle.GOOD
		MasteryTexts.STATE_BUYABLE:
			return UiStyle.GOLD_LIGHT
		MasteryTexts.STATE_UNAFFORDABLE:
			return UiStyle.BAD
	return UiStyle.TEXT_2


func _on_buy_button_pressed() -> void:
	if _node != null:
		buy_requested.emit(_node.id)
