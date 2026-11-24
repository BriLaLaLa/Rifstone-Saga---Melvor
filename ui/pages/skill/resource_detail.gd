class_name ResourceDetail
extends VBoxContainer
## The detail opened by a click on a ResourceRow (docs/01_GDD_M36.md §44.2, docs/05_INTERFACES_M36.md §7.ae): every zone of the resource
## with its nominal percentage (tooltip: the effective one) and a "Vai" button, "Serve a", the sell price, the mastery with the bonus
## tag and one line "Prossimo bonus". Everything is read from the model (`zones_of_action`, `resource_odds`, `GuideIndex`); the zone
## buttons only emit `zone_requested`. No state besides the nodes.

signal zone_requested(area_id: StringName)

var _action: ActionDef = null
var _zones: VBoxContainer = null
var _mastery: Label = null
var _next: Label = null
var _bonus_tag: MasteryBonusTag = null


func setup(action: ActionDef, data: GameData, uses_text: String, price_text: String) -> void:
	_action = action
	name = "DetailBox_%s" % action.id
	add_theme_constant_override("separation", 4)
	_zones = VBoxContainer.new()
	_zones.name = "Zones_%s" % action.id
	add_child(_zones)
	_label(uses_text)
	_label(price_text)
	var mastery_row: HBoxContainer = HBoxContainer.new()
	mastery_row.add_theme_constant_override("separation", 8)
	_mastery = Label.new()
	mastery_row.add_child(_mastery)
	if action.mastery:
		_bonus_tag = MasteryBonusTag.new()
		mastery_row.add_child(_bonus_tag)
		_bonus_tag.setup(action, data)
	add_child(mastery_row)
	_next = _label("")


## Rereads the mastery (the nodes stay, also while the detail is closed).
func redraw_mastery(session: GameSession) -> void:
	if not _action.mastery:
		_mastery.text = ResourceTexts.NO_MASTERY_TEXT
		_next.visible = false
		return
	var level: int = session.mastery.get_mastery_level(_action.id)
	var info: Dictionary = session.mastery.step_info(_action.skill_id, _action.id)
	_mastery.text = ResourceTexts.MASTERY_TEXT % NumberFormat.format_int(level)
	var next: Dictionary = info.get("next", {}) as Dictionary
	_next.visible = not next.is_empty()
	_next.text = ResourceTexts.NEXT_BONUS_TEXT % str(next.get("text", "")) if not next.is_empty() else ""
	_bonus_tag.show_info(info, level)


## Rebuilds one line per zone (order and percentages from `zones_of_action`); the zone of the current fight is marked and its button disabled.
func redraw_zones(session: GameSession) -> void:
	for child: Node in _zones.get_children():
		_zones.remove_child(child)
		child.queue_free()
	var here: StringName = session.combat.area_id() if session.combat.is_active() else &""
	var level: int = session.skills.get_level(_action.skill_id)
	var unlocked: bool = session.skills.meets_requirements({_action.skill_id: _action.level})
	for zone: Dictionary in session.data.zones_of_action(_action.id):
		var area_id: StringName = StringName(zone["area"])
		var area_name: String = session.data.area(area_id).name
		var line: HBoxContainer = HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		var label: Label = Label.new()
		label.custom_minimum_size.x = 220
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.tooltip_text = _where_tip(session, area_id, area_name, level)
		label.text = (ResourceTexts.WHERE_HERE_TEXT if area_id == here else ResourceTexts.WHERE_LINE_TEXT) % [area_name, int(zone["pct"])]
		if area_id == here:
			label.add_theme_color_override("font_color", UiStyle.GOLD_LIGHT)
		line.add_child(label)
		var go: Button = Button.new()
		go.name = "GoButton_%s_%s" % [_action.id, area_id]
		go.text = ResourceTexts.GO_TEXT
		go.focus_mode = Control.FOCUS_NONE
		go.disabled = area_id == here
		if area_id == here:
			go.tooltip_text = ResourceTexts.GO_HERE_TIP
		elif not unlocked:
			go.tooltip_text = ResourceTexts.GO_LOCKED_TIP % NumberFormat.format_int(_action.level)
		go.pressed.connect(func() -> void: zone_requested.emit(area_id))
		line.add_child(go)
		_zones.add_child(line)
	if _zones.get_child_count() == 0:
		var none: Label = Label.new()
		none.text = ResourceTexts.WHERE_NONE_TEXT
		_zones.add_child(none)


func _where_tip(session: GameSession, area_id: StringName, area_name: String, level: int) -> String:
	for odds: Dictionary in EncounterCycle.resource_odds(session.data, area_id, _action.skill_id, level):
		if (odds["action"] as ActionDef).id == _action.id:
			if not bool(odds["workable"]):
				return ResourceTexts.WHERE_TIP_LOCKED_TEXT % area_name
			return ResourceTexts.WHERE_TIP_TEXT % [area_name, NumberFormat.format_number(float(odds["pct_effective"]))]
	return area_name


func _label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)
	return label
