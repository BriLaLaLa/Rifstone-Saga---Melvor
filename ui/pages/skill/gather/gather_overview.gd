class_name GatherOverview
extends VBoxContainer
## Overview tab of a gathering page (docs/01_GDD_M36.md §44.2, docs/05_INTERFACES_M36.md §7.ae): the zone where the player fights now with
## the resources of the discipline that appear there (name, nominal chance from `GameData.zones_of_action`, ball of the colour from
## `NodeColorPreview`, "non ancora lavorabile"), the tool in one line with the button to its tab, and the three hidden containers
## that M36B fills (StatsSection, ProgressSection, NeedsSection). Nothing is computed here. Nodes: ZoneNowSection, ToolLine,
## OpenToolButton, ZoneRow_<action_id>.

signal tool_tab_requested

var _skill_id: StringName = &""
var _zone_section: PanelContainer = null
var _zone_box: VBoxContainer = null
var _tool_label: Label = null


func setup(skill_id: StringName) -> void:
	_skill_id = skill_id
	name = "TabOverview"
	add_theme_constant_override("separation", 12)
	_zone_section = PanelContainer.new()
	_zone_section.name = "ZoneNowSection"
	_zone_section.theme_type_variation = &"HudPanel"
	_zone_box = VBoxContainer.new()
	_zone_box.add_theme_constant_override("separation", 4)
	_zone_section.add_child(_zone_box)
	add_child(_zone_section)
	var tool_panel: PanelContainer = PanelContainer.new()
	tool_panel.name = "ToolLine"
	tool_panel.theme_type_variation = &"HudPanel"
	var tool_row: HBoxContainer = HBoxContainer.new()
	tool_row.add_theme_constant_override("separation", 12)
	_tool_label = Label.new()
	_tool_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tool_label.clip_text = true
	tool_row.add_child(_tool_label)
	var open_button: Button = Button.new()
	open_button.name = "OpenToolButton"
	open_button.text = OverviewTexts.OPEN_TOOL_TEXT
	open_button.focus_mode = Control.FOCUS_NONE
	open_button.pressed.connect(tool_tab_requested.emit)
	tool_row.add_child(open_button)
	tool_panel.add_child(tool_row)
	add_child(tool_panel)
	for section: StringName in [&"StatsSection", &"ProgressSection", &"NeedsSection"]:  # reserved for M36B
		var reserved: VBoxContainer = VBoxContainer.new()
		reserved.name = section
		reserved.visible = false
		add_child(reserved)


func redraw(session: GameSession) -> void:
	_redraw_zone(session)
	var tool_name: String = ToolUpgradeTexts.tool_name(session, _skill_id)
	if tool_name.is_empty():
		_tool_label.text = ToolUpgradeTexts.NO_TOOL_TEXT
		return
	var parts: PackedStringArray = PackedStringArray([tool_name])
	var effects: PackedStringArray = ToolUpgradeTexts.effect_texts(session, _skill_id)
	if not effects.is_empty():
		parts.append(effects[0])
	_tool_label.text = OverviewTexts.TOOL_PREFIX % OverviewTexts.TOOL_EFFECT_SEPARATOR.join(parts)


func _redraw_zone(session: GameSession) -> void:
	for child: Node in _zone_box.get_children():
		_zone_box.remove_child(child)
		child.queue_free()
	var title: Label = Label.new()
	title.name = "ZoneTitle"
	title.theme_type_variation = &"HeaderLabel"
	_zone_box.add_child(title)
	var here: StringName = session.combat.area_id() if session.combat.is_active() else &""
	if not session.data.has_area(here):
		title.text = OverviewTexts.NO_ZONE_TEXT
		return
	title.text = OverviewTexts.ZONE_NOW_TEXT % session.data.area(here).name
	var shown: int = 0
	for action: ActionDef in session.data.actions_for_skill(_skill_id):
		for zone: Dictionary in session.data.zones_of_action(action.id):
			if StringName(zone["area"]) == here:
				_zone_box.add_child(_resource_row(session, action, int(zone["pct"])))
				shown += 1
				break
	if shown == 0:
		var none: Label = Label.new()
		none.name = "NoResources"
		none.text = OverviewTexts.NO_RESOURCES_TEXT
		none.theme_type_variation = &"MutedLabel"
		_zone_box.add_child(none)


func _resource_row(session: GameSession, action: ActionDef, pct: int) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "ZoneRow_%s" % action.id
	row.add_theme_constant_override("separation", 8)
	var preview: Dictionary = NodeColorPreview.of(session, action)
	var ball: Label = Label.new()
	ball.name = "Ball"
	ball.text = OverviewTexts.COLOR_BALL
	ball.visible = not preview.is_empty()
	if not preview.is_empty():
		ball.add_theme_color_override("font_color", CombatTexts.NODE_COLORS.get(CombatTexts.color_id(preview), UiStyle.TEXT))
	row.add_child(ball)
	var label: Label = Label.new()
	label.text = OverviewTexts.RESOURCE_LINE_TEXT % [action.name, pct]
	row.add_child(label)
	if not session.skills.meets_requirements({action.skill_id: action.level}):
		var locked: Label = Label.new()
		locked.name = "NotWorkable"
		locked.text = OverviewTexts.NOT_WORKABLE_TEXT
		locked.add_theme_color_override("font_color", UiStyle.BAD)
		row.add_child(locked)
	return row
