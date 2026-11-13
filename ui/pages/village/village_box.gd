class_name VillageBox
extends PanelContainer
## One building of the Village page (docs/01_GDD.md §30, docs/05_INTERFACES.md §7.t): name, level, current and next
## effect, cost with owned/required quantities, Woodwright requirement and the Costruisci/Migliora button.
## A placeholder (not buildable) is a grey box "In arrivo" without button. Everything shown is read from the village,
## the bank, the wallet and the data at every `refresh`; the box keeps only references to its own nodes.
## The `village` is used through the contract signatures of docs/05_INTERFACES.md §5.27 only.

signal upgrade_requested(building_id: StringName)

const SEPARATION: int = 6
const PLACEHOLDER_MODULATE := Color(1, 1, 1, 0.5)

var building_id: StringName = &""
var _def: Object = null
var _buildable: bool = false
var _level_label: Label = null
var _now_label: Label = null
var _next_label: Label = null
var _cost_box: VBoxContainer = null
var _requires_label: Label = null
var _button: Button = null
var _reason_label: Label = null
var _maxed_label: Label = null


## Builds the nodes of `def` (a VillageBuildingDef); the data of a building never changes while the page is open.
func setup(def: Object) -> void:
	_def = def
	building_id = def.get("id")
	_buildable = bool(def.get("buildable"))
	name = "Box_%s" % building_id
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", SEPARATION)
	add_child(column)
	_label(column, str(def.get("name")), &"HeaderLabel").name = "NameLabel"
	var description: Label = _label(column, str(def.get("description")), &"MutedLabel")
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not _buildable:
		modulate = PLACEHOLDER_MODULATE
		_label(column, VillageTexts.COMING_SOON_TEXT, &"HeaderLabel").name = "ComingSoonLabel"
		return
	_level_label = _label(column, "", &"")
	_level_label.name = "LevelLabel"
	_now_label = _label(column, "", &"")
	_now_label.name = "EffectNowLabel"
	_now_label.add_theme_color_override("font_color", UiStyle.GOLD_LIGHT)
	_next_label = _label(column, "", &"MutedLabel")
	_next_label.name = "EffectNextLabel"
	_cost_box = VBoxContainer.new()
	_cost_box.name = "CostBox"
	column.add_child(_cost_box)
	_requires_label = _label(column, "", &"")
	_requires_label.name = "RequiresLabel"
	_maxed_label = _label(column, VillageTexts.MAXED_TEXT, &"HeaderLabel")
	_maxed_label.name = "MaxedLabel"
	_button = Button.new()
	_button.name = "UpgradeButton"
	_button.theme_type_variation = &"AccentButton"
	_button.focus_mode = Control.FOCUS_NONE
	_button.pressed.connect(func() -> void: upgrade_requested.emit(building_id))
	column.add_child(_button)
	_reason_label = _label(column, "", &"")
	_reason_label.name = "ReasonLabel"
	_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reason_label.add_theme_color_override("font_color", UiStyle.BAD)


## Rereads everything from the session's modules; `village` is the session's Village (5.27).
func refresh(village: Object, session: GameSession) -> void:
	if not _buildable:
		return
	var level: int = village.level(building_id)
	var max_level: int = village.max_level()
	var maxed: bool = level >= max_level
	_level_label.text = VillageTexts.LEVEL_TEXT % [level, max_level]
	var fixed: bool = _def.get("effect_stat") == &""
	_now_label.text = VillageTexts.EFFECT_NOW_TEXT % _effect_text(village.effect_at(building_id, level), session)
	_next_label.visible = not maxed and not fixed
	_next_label.text = VillageTexts.EFFECT_NEXT_TEXT % _effect_text(
			village.effect_at(building_id, level + 1), session)
	_maxed_label.visible = maxed
	_button.visible = not maxed
	_cost_box.visible = not maxed
	_requires_label.visible = false
	_reason_label.visible = false
	if maxed:
		return
	_button.text = VillageTexts.BUILD_TEXT if level == 0 else VillageTexts.UPGRADE_TEXT
	_draw_cost(village.next_cost(building_id), session)
	var can: CommandResult = village.can_upgrade(building_id)
	_button.disabled = not can.ok
	var reason_text: String = "" if can.ok else VillageTexts.refused(can.reason)
	_button.tooltip_text = reason_text
	_reason_label.text = reason_text
	_reason_label.visible = not can.ok


func _effect_text(value: float, session: GameSession) -> String:
	var stat: StringName = _def.get("effect_stat")
	if stat == &"":
		return VillageTexts.FIXED_EFFECT_TEXT
	if not session.data.stats.has(stat):
		return NumberFormat.format_number(value)
	var info: Dictionary = session.data.stats.info(stat)
	return VillageTexts.EFFECT_LINE_TEXT % [str(info["name"]), ItemTooltipLines.format_stat(str(info["format"]), value)]


func _draw_cost(cost: Dictionary, session: GameSession) -> void:
	for child: Node in _cost_box.get_children():
		_cost_box.remove_child(child)
		child.queue_free()
	_label(_cost_box, VillageTexts.COST_TITLE_TEXT, &"HeaderLabel")
	var gold: int = int(cost.get("gold", 0))
	if gold > 0:
		_cost_line(VillageTexts.COST_GOLD_TEXT % [NumberFormat.format_int(session.wallet.get_gold()),
				NumberFormat.format_int(gold)], gold - session.wallet.get_gold())
	for row: Dictionary in cost.get("items", []):
		var item_id: StringName = row["item"]
		var qty: int = int(row["qty"])
		var owned: int = session.bank.get_count(item_id)
		var item_name: String = session.data.item(item_id).name if session.data.has_item(item_id) else String(item_id)
		_cost_line(VillageTexts.COST_ITEM_TEXT % [item_name, NumberFormat.format_int(owned),
				NumberFormat.format_int(qty)], qty - owned)
	var required: int = int(cost.get("requires_woodwright", 0))
	_requires_label.visible = required > 0
	_requires_label.text = VillageTexts.REQUIRES_WOODWRIGHT_TEXT % required
	var too_low: bool = required > 0 and session.skills.get_level(&"woodwright") < required
	_requires_label.add_theme_color_override("font_color", UiStyle.BAD if too_low else UiStyle.TEXT_2)


func _cost_line(text: String, missing: int) -> void:
	var line: Label = _label(_cost_box, text, &"")
	if missing > 0:
		line.text += VillageTexts.COST_MISSING_TEXT % NumberFormat.format_int(missing)
		line.add_theme_color_override("font_color", UiStyle.BAD)


func _label(parent: Node, text: String, variation: StringName) -> Label:
	var label: Label = Label.new()
	label.text = text
	if variation != &"":
		label.theme_type_variation = variation
	parent.add_child(label)
	return label
