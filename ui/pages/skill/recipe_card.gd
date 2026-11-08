class_name RecipeCard
extends ActionCard
## Card of one artisan recipe on the SkillPage (docs/01_GDD.md §5): everything the ActionCard shows plus the
## ingredients (owned / required, in red when short) and the preservation and double-product chances (F-08, F-06),
## read from `modifiers.total` with the action's context.
##
## The ingredient rows come from the recipe (any number of them); owned quantities come from `bank.get_count`. The start
## state comes from `ArtisanResolver.can_start` (read only): the button is disabled when the recipe cannot start, unless
## it is the running one (so it can be stopped). The card keeps no game state.

const INGREDIENT_ROW_PREFIX: String = "Ingredient"
const INGREDIENT_ROW_SEPARATION: int = 6
const OWNED_TEXT: String = "%s / %s"
const INGREDIENT_TEXT: String = "%s  %s"
const CHANCE_TEXT: String = "%s%%"

var _data: GameData = null
var _ingredient_labels: Dictionary[StringName, Label] = {}
var _needed: Dictionary[StringName, int] = {}
var _item_names: Dictionary[StringName, String] = {}
var _chance_label: Label = null
var _loss_label: Label = null

@onready var _ingredients: VBoxContainer = %Ingredients
@onready var _preservation_name: Label = %PreservationName
@onready var _preservation_value: Label = %PreservationValue
@onready var _double_name: Label = %DoubleName
@onready var _double_value: Label = %DoubleValue


## Draws the data of `action`: the base card plus one row per distinct ingredient.
func setup(action: ActionDef, data: GameData) -> void:
	super.setup(action, data)
	_data = data
	_preservation_name.text = String(data.stats.info(ArtisanResolver.PRESERVATION_STAT).get("name", ""))
	_double_name.text = String(data.stats.info(ArtisanResolver.DOUBLE_STAT).get("name", ""))
	for input: ItemQty in action.inputs:
		_needed[input.item_id] = _needed.get(input.item_id, 0) + input.qty
	for item_id: StringName in _needed:
		var item: ItemDef = data.item(item_id)
		if item == null:
			continue
		var row := HBoxContainer.new()
		row.name = INGREDIENT_ROW_PREFIX + String(item_id).to_pascal_case()
		row.add_theme_constant_override("separation", INGREDIENT_ROW_SEPARATION)
		_ingredients.add_child(row)
		var slot: ItemSlotView = ITEM_SLOT_SCENE.instantiate() as ItemSlotView
		slot.name = "Slot"
		row.add_child(slot)
		slot.set_item(item, _needed[item_id])
		var label := Label.new()
		label.name = "Text"
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(label)
		_ingredient_labels[item_id] = label
		_item_names[item_id] = item.name
		if action.skill_id == EngraverSections.SKILL:
			var source: String = EngraverSections.source_text(item_id, data)
			if not source.is_empty():
				_add_muted_line("Source%s" % String(item_id).to_pascal_case(), source)
	if action.kind == &"crystallize":
		_chance_label = _add_muted_line("ChanceLabel", "")
		_loss_label = _add_muted_line("LossLabel", "")


## Reads level, interval, mastery, owned ingredients, chances and the start state from `session`.
func redraw(session: GameSession) -> void:
	super.redraw(session)
	for item_id: StringName in _ingredient_labels:
		var owned: int = session.bank.get_count(item_id)
		var label: Label = _ingredient_labels[item_id]
		label.text = INGREDIENT_TEXT % [_item_names[item_id], OWNED_TEXT % [
			NumberFormat.format_int(owned), NumberFormat.format_int(_needed[item_id])]]
		if owned < _needed[item_id]:
			label.add_theme_color_override("font_color", UiStyle.BAD)
		else:
			label.remove_theme_color_override("font_color")
	var ctx: ModifierContext = ModifierContext.for_action(_action.skill_id, _action.id)
	_preservation_value.text = CHANCE_TEXT % NumberFormat.format_number(
			session.modifiers.total(ArtisanResolver.PRESERVATION_STAT, ctx))
	_double_value.text = CHANCE_TEXT % NumberFormat.format_number(
			session.modifiers.total(ArtisanResolver.DOUBLE_STAT, ctx))
	var running: bool = session.actions.get_lane().get(LANE_ACTION_KEY, &"") == _action.id
	if _chance_label != null:
		_chance_label.text = EngraverSections.chance_text(session, _action)
		_loss_label.text = EngraverSections.loss_text(session, _action)
	var can_start: CommandResult = ArtisanResolver.can_start(session, _action)
	if _action.kind == &"crystallize":
		can_start = EngraverResolver.can_start(session, _action)
	if not running and not can_start.ok:
		_toggle_button.disabled = true


## A muted wrapped line under the ingredients (source of an ingredient, chance and loss of a crystallization).
func _add_muted_line(node_name: String, text: String) -> Label:
	var line: Label = Label.new()
	line.name = node_name
	line.text = text
	line.theme_type_variation = &"MutedLabel"
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_ingredients.add_child(line)
	return line
