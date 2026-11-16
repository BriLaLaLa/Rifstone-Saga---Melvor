class_name ActionCard
extends PanelContainer
## Card of one action on the SkillPage (docs/01_GDD.md §4, docs/01_GDD_M24.md §35.7): icon, name, required level, base XP,
## current interval (F-03, read from `actions.current_interval_ms`), products, mastery level and bar. Read only (M24-06):
## a gathering card also shows the colour the node would have at the player's level (`NodeColorPreview`); the cards
## of recipes (RecipeCard) add the "Metti in coda" controls. `setup` draws the parts that come from the data; `redraw`
## reads everything else from the session. The card keeps no game state, only its ActionDef and its nodes.
## A card below the required level is drawn locked (requirement in red).

const ITEM_SLOT_SCENE: PackedScene = preload("res://ui/components/item_slot/item_slot.tscn")
const LEVEL_TEXT: String = "Livello %s"
const LOCKED_TEXT: String = "Richiede il livello %s"
const XP_TEXT: String = "%s XP"
const MASTERY_TEXT: String = "Liv. %s"
const NO_MASTERY_TEXT: String = "Nessuna"
const PRODUCT_OWNED_TEXT: String = "%s (ne hai %s)"
const COLOR_TEXT: String = "Colore ora: %s (%s%% XP)"

var _action: ActionDef = null
var _bonus_tag: MasteryBonusTag = null
## Name label of each product (a craft card shows how many the player owns next to it).
var _product_labels: Dictionary[StringName, Label] = {}
var _product_names: Dictionary[StringName, String] = {}
## Set by a craft card before `setup`: show "possiedi N" next to every product.
var _show_owned: bool = false
## Only on a gathering card: the colour of the node at the current level.
var _color_label: Label = null

@onready var _icon: TextureRect = %Icon
@onready var _name_label: Label = %NameLabel
@onready var _requirement_label: Label = %RequirementLabel
@onready var _xp_label: Label = %XpValue
@onready var _interval_label: Label = %IntervalValue
@onready var _products: HBoxContainer = %Products
@onready var _mastery_label: Label = %MasteryValue
@onready var _mastery_bar: XpBar = %MasteryBar


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
		_product_labels[item.id] = label
		_product_names[item.id] = item.name
	_mastery_bar.visible = action.mastery
	if action.mastery:
		_bonus_tag = MasteryBonusTag.new()  # M16-05: the mastery lines moved from above "Avvia" into this summary
		_icon.get_parent().add_child(_bonus_tag)
		_bonus_tag.setup(action, data)
	if action.inputs.is_empty() and data.skill(action.skill_id).category == &"gathering":
		_color_label = Label.new()  # the colour of the node at the player's level (F-154), filled by `redraw`
		_color_label.name = "ColorLabel"
		_color_label.visible = false
		_icon.get_parent().get_parent().add_child(_color_label)


## Reads level, interval, mastery and (gathering) the colour at the current level from `session`.
func redraw(session: GameSession) -> void:
	var unlocked: bool = session.skills.meets_requirements({_action.skill_id: _action.level})
	var level_text: String = NumberFormat.format_int(_action.level)
	_requirement_label.text = (LEVEL_TEXT if unlocked else LOCKED_TEXT) % level_text
	if unlocked:
		_requirement_label.remove_theme_color_override("font_color")
	else:
		_requirement_label.add_theme_color_override("font_color", UiStyle.BAD)
	_icon.modulate = Color.WHITE if unlocked else UiStyle.TEXT_DISABLED
	if _color_label != null:
		_redraw_color(session)
	_interval_label.text = seconds_text(session.actions.current_interval_ms(_action.id))
	if _action.mastery:
		_mastery_label.text = MASTERY_TEXT % NumberFormat.format_int(session.mastery.get_mastery_level(_action.id))
		_mastery_bar.set_xp(session.data.mastery_table(), session.mastery.get_mastery_xp(_action.id))
		if _bonus_tag != null:
			_bonus_tag.show_info(session.mastery.step_info(_action.skill_id, _action.id),
					session.mastery.get_mastery_level(_action.id))
	else:
		_mastery_label.text = NO_MASTERY_TEXT
	if _show_owned:
		for item_id: StringName in _product_labels:
			_product_labels[item_id].text = PRODUCT_OWNED_TEXT % [_product_names[item_id],
					NumberFormat.format_int(session.bank.get_count(item_id))]


func action_id() -> StringName:
	return _action.id if _action != null else &""


## Milliseconds as seconds with at least one decimal (NumberFormat.format_seconds): 3000 -> "3,0 s".
static func seconds_text(ms: int) -> String:
	return NumberFormat.format_seconds(ms)


## The colour of the node of this resource at the player's level, from the model (F-154), if it can be read.
func _redraw_color(session: GameSession) -> void:
	var preview: Dictionary = NodeColorPreview.of(session, _action)
	_color_label.visible = not preview.is_empty()
	if preview.is_empty():
		return
	var color_id: StringName = CombatTexts.color_id(preview)
	_color_label.text = COLOR_TEXT % [CombatTexts.NODE_COLOR_NAMES.get(color_id, CombatTexts.NODE_COLOR_UNKNOWN_TEXT),
			NumberFormat.format_number(float(preview.get("xp_pct", 0.0)))]
	_color_label.add_theme_color_override("font_color", CombatTexts.NODE_COLORS.get(color_id, UiStyle.TEXT))


