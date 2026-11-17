class_name RecipeDetail
extends VBoxContainer
## Right panel of a production page: the recipe picked in the RecipeList. Large name and icon, the required level, one
## compact line of statistics (XP, time, mastery, preservation, double product), the "Reagenti" box (owned / needed, red
## when short), the "Prodotto" box and the "Metti in coda" controls. Everything is read from the session at each `redraw`
## (owned quantities, interval F-03, mastery, chances F-08 / F-06 through `modifiers.total`); it keeps only the picked
## ActionDef and its nodes. The player's command goes out as `enqueue_requested`; the page sends `actions.enqueue`.

signal enqueue_requested(action_id: StringName, count: int, repeat: bool)

const ITEM_SLOT_SCENE: PackedScene = preload("res://ui/components/item_slot/item_slot.tscn")
const XP_BAR_SCENE: PackedScene = preload("res://ui/components/progress/xp_bar.tscn")
const BIG_ICON_SIDE: float = 64.0
const SEPARATION: int = 10
const BOX_SEPARATION: int = 6

var _action: ActionDef = null
var _data: GameData = null
var _icon: TextureRect = null
var _name_label: Label = null
var _level_label: Label = null
var _stats_label: Label = null
var _bonus_tag: MasteryBonusTag = null
var _mastery_bar: XpBar = null
var _box: VBoxContainer = null
var _hint: Label = null
var _reagent_labels: Dictionary[StringName, Label] = {}
var _source_labels: Dictionary[StringName, Label] = {}
var _needed: Dictionary[StringName, int] = {}
var _item_names: Dictionary[StringName, String] = {}
var _product_labels: Dictionary[StringName, Label] = {}
var _product_names: Dictionary[StringName, String] = {}
var _chance_label: Label = null
var _loss_label: Label = null
var _controls: EnqueueControls = null


func _ready() -> void:
	add_theme_constant_override("separation", SEPARATION)
	_hint = Label.new()
	_hint.name = "HintLabel"
	_hint.text = ProfessionTexts.PICK_RECIPE_TEXT
	_hint.theme_type_variation = &"MutedLabel"
	add_child(_hint)
	_box = VBoxContainer.new()
	_box.name = "DetailBox"
	_box.add_theme_constant_override("separation", SEPARATION)
	_box.visible = false
	add_child(_box)


## The id of the recipe shown; `&""` when none.
func action_id() -> StringName:
	return _action.id if _action != null else &""


## Shows `action` (rebuilds the reagent and product boxes from the data).
func show_action(action: ActionDef, data: GameData) -> void:
	_action = action
	_data = data
	_hint.visible = false
	_box.visible = true
	for child: Node in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	_reagent_labels.clear()
	_source_labels.clear()
	_needed.clear()
	_item_names.clear()
	_product_labels.clear()
	_product_names.clear()
	_chance_label = null
	_loss_label = null
	_bonus_tag = null
	_mastery_bar = null
	_build_title(action)
	_build_stats(action, data)
	_build_reagents(action, data)
	_build_products(action, data)
	_controls = EnqueueControls.new()
	_box.add_child(_controls)
	_controls.enqueue_requested.connect(func(count: int, repeat: bool) -> void:
		enqueue_requested.emit(action.id, count, repeat))


func clear() -> void:
	_action = null
	_hint.visible = true
	_box.visible = false


## Reads the owned quantities, the interval, the mastery, the chances and the start state from `session`.
func redraw(session: GameSession) -> void:
	if _action == null:
		return
	var unlocked: bool = session.skills.meets_requirements({_action.skill_id: _action.level})
	var level_text: String = NumberFormat.format_int(_action.level)
	_level_label.text = (ProfessionTexts.LEVEL_OK_TEXT if unlocked else ProfessionTexts.LEVEL_NEEDED_TEXT) % level_text
	_level_label.add_theme_color_override("font_color", UiStyle.TEXT_2 if unlocked else UiStyle.BAD)
	_icon.modulate = Color.WHITE if unlocked else UiStyle.TEXT_DISABLED
	_stats_label.text = _stats_text(session)
	if _action.mastery and _mastery_bar != null:
		_mastery_bar.set_xp(session.data.mastery_table(), session.mastery.get_mastery_xp(_action.id))
		if _bonus_tag != null:
			_bonus_tag.show_info(session.mastery.step_info(_action.skill_id, _action.id),
					session.mastery.get_mastery_level(_action.id))
	for item_id: StringName in _reagent_labels:
		var owned: int = session.bank.get_count(item_id)
		var label: Label = _reagent_labels[item_id]
		label.text = ProfessionTexts.REAGENT_TEXT % [_item_names[item_id], NumberFormat.format_int(owned),
				NumberFormat.format_int(_needed[item_id])]
		if owned < _needed[item_id]:
			label.add_theme_color_override("font_color", UiStyle.BAD)
		else:
			label.remove_theme_color_override("font_color")
	for item_id: StringName in _source_labels:
		var source: String = EngraverSections.source_text(item_id, session.data, session.discoveries)
		_source_labels[item_id].text = source
		_source_labels[item_id].visible = not source.is_empty()
	for item_id: StringName in _product_labels:
		_product_labels[item_id].text = ProfessionTexts.PRODUCT_TEXT % [_product_names[item_id],
				NumberFormat.format_int(session.bank.get_count(item_id))]
	if _chance_label != null:
		_chance_label.text = EngraverSections.chance_text(session, _action)
		_loss_label.text = EngraverSections.loss_text(session, _action)
	_controls.set_state(session.disciplines.knows_recipe(_action.id), unlocked)


func _stats_text(session: GameSession) -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append(ProfessionTexts.XP_TEXT % NumberFormat.format_int(_action.xp))
	parts.append(NumberFormat.format_seconds(session.actions.current_interval_ms(_action.id)))
	if _action.mastery:
		parts.append(ProfessionTexts.MASTERY_STAT_TEXT % NumberFormat.format_int(session.mastery.get_mastery_level(_action.id)))
	else:
		parts.append(ProfessionTexts.NO_MASTERY_TEXT)
	var ctx: ModifierContext = ModifierContext.for_action(_action.skill_id, _action.id)
	for stat: StringName in [ArtisanResolver.PRESERVATION_STAT, ArtisanResolver.DOUBLE_STAT]:
		parts.append(ProfessionTexts.STAT_PAIR_TEXT % [String(session.data.stats.info(stat).get("name", "")),
				ProfessionTexts.CHANCE_TEXT % NumberFormat.format_number(session.modifiers.total(stat, ctx))])
	return ProfessionTexts.STAT_SEPARATOR.join(parts)


func _build_title(action: ActionDef) -> void:
	var head := HBoxContainer.new()
	head.name = "Head"
	head.add_theme_constant_override("separation", SEPARATION)
	_box.add_child(head)
	_icon = TextureRect.new()
	_icon.name = "Icon"
	_icon.custom_minimum_size = Vector2(BIG_ICON_SIDE, BIG_ICON_SIDE)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture = ItemSlotView.icon_of(action.icon)
	head.add_child(_icon)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(names)
	_name_label = _label(names, "NameLabel", action.name, &"TitleLabel")
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_level_label = _label(names, "LevelLabel", "", &"MutedLabel")


func _build_stats(action: ActionDef, data: GameData) -> void:
	var line := HBoxContainer.new()
	line.name = "StatsLine"
	line.add_theme_constant_override("separation", SEPARATION)
	_box.add_child(line)
	_stats_label = _label(line, "StatsLabel", "", &"")
	_stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if action.mastery:
		_bonus_tag = MasteryBonusTag.new()
		line.add_child(_bonus_tag)
		_bonus_tag.setup(action, data)
		_mastery_bar = XP_BAR_SCENE.instantiate() as XpBar
		_mastery_bar.name = "MasteryBar"
		_box.add_child(_mastery_bar)


func _build_reagents(action: ActionDef, data: GameData) -> void:
	var box: VBoxContainer = _section(ProfessionTexts.REAGENTS_TITLE, "Reagents")
	for input: ItemQty in action.inputs:
		_needed[input.item_id] = _needed.get(input.item_id, 0) + input.qty
	if _needed.is_empty():
		_label(box, "NoReagents", ProfessionTexts.NO_REAGENTS_TEXT, &"MutedLabel")
	for item_id: StringName in _needed:
		var item: ItemDef = data.item(item_id)
		if item == null:
			continue
		var row := HBoxContainer.new()
		row.name = "Ingredient%s" % String(item_id).to_pascal_case()
		row.add_theme_constant_override("separation", SEPARATION)
		box.add_child(row)
		var slot: ItemSlotView = ITEM_SLOT_SCENE.instantiate() as ItemSlotView
		slot.name = "Slot"
		row.add_child(slot)
		slot.set_item(item, _needed[item_id])
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(column)
		_reagent_labels[item_id] = _label(column, "Text", "", &"")
		_item_names[item_id] = item.name
		if action.skill_id == EngraverSections.SKILL:
			_source_labels[item_id] = _label(column, "Source%s" % String(item_id).to_pascal_case(), "", &"MutedLabel")
	if action.kind == &"crystallize":
		_chance_label = _label(box, "ChanceLabel", "", &"MutedLabel")
		_loss_label = _label(box, "LossLabel", "", &"MutedLabel")


func _build_products(action: ActionDef, data: GameData) -> void:
	var box: VBoxContainer = _section(ProfessionTexts.PRODUCT_TITLE, "Products")
	for output: ItemQty in action.outputs:
		var item: ItemDef = data.item(output.item_id)
		if item == null:
			continue
		var row := HBoxContainer.new()
		row.name = "Product%s" % String(item.id).to_pascal_case()
		row.add_theme_constant_override("separation", SEPARATION)
		box.add_child(row)
		var slot: ItemSlotView = ITEM_SLOT_SCENE.instantiate() as ItemSlotView
		row.add_child(slot)
		slot.set_item(item, output.qty)
		var label: Label = _label(row, "Text", "", &"")
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_product_labels[item.id] = label
		_product_names[item.id] = item.name


## A titled framed box in the detail; returns the VBox to fill.
func _section(title: String, node_name: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.name = node_name + "Panel"
	panel.theme_type_variation = &"HudPanel"
	_box.add_child(panel)
	var box := VBoxContainer.new()
	box.name = node_name
	box.add_theme_constant_override("separation", BOX_SEPARATION)
	panel.add_child(box)
	_label(box, "Title", title, &"HeaderLabel")
	return box


func _label(parent: Node, node_name: String, text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	if variation != &"":
		label.theme_type_variation = variation
	parent.add_child(label)
	return label
