class_name NodePanel
extends PanelContainer
## Panel of the node being worked, in the Combat page (docs/01_GDD_M24.md §35.11, 05_INTERFACES_M24.md §7.o): the
## resource, the colour (text and `CombatTexts.NODE_COLORS`), the bar elapsed/duration and the units; for a skipped
## node the reason. `refresh(state, data)` reads `combat.get_state()["node"]` every frame: it computes no time.
## Visible only in the `node` state. No game state here.

var _title: Label = null
var _resource: Label = null
var _color: Label = null
var _units: Label = null
var _bar: ProgressBar = null
var _skipped: Label = null


func _ready() -> void:
	theme_type_variation = &"HudPanel"
	var box := VBoxContainer.new()
	box.name = "NodeBox"
	add_child(box)
	_title = _add_label(box, "NodeTitle", &"HeaderLabel")
	_resource = _add_label(box, "NodeResource", &"")
	_color = _add_label(box, "NodeColor", &"")
	_units = _add_label(box, "NodeUnits", &"MutedLabel")
	_bar = ProgressBar.new()
	_bar.name = "NodeBar"
	_bar.max_value = 1.0
	_bar.step = 0.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, UiStyle.COMBAT_BAR_HEIGHT)
	box.add_child(_bar)
	_skipped = _add_label(box, "NodeSkipped", &"")
	_skipped.add_theme_color_override("font_color", UiStyle.BAD)
	_skipped.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	visible = false


func refresh(state: Dictionary, data: GameData) -> void:
	var node: Dictionary = state.get("node", {}) as Dictionary
	visible = state.get("state", &"") == CombatTexts.STATE_NODE and not node.is_empty()
	if not visible:
		return
	var skill: SkillDef = data.skill(StringName(node.get("skill", &"")))
	_title.text = CombatTexts.NODE_TITLE_TEXT % (skill.name if skill != null else "")
	var skipped: bool = bool(node.get("skipped", false))
	_skipped.visible = skipped
	_resource.visible = not skipped
	_color.visible = not skipped
	_units.visible = not skipped
	var duration: int = int(node.get("duration_ms", 0))
	_bar.value = clampf(float(int(node.get("elapsed_ms", 0))) / float(duration), 0.0, 1.0) if duration > 0 else 0.0
	if skipped:
		return
	var action: ActionDef = data.action(StringName(node.get("action", &"")))
	_resource.text = CombatTexts.NODE_RESOURCE_TEXT % (action.name if action != null else "")
	var color_id: StringName = CombatTexts.color_id(node.get("color"))
	_color.text = CombatTexts.NODE_COLOR_TEXT % CombatTexts.NODE_COLOR_NAMES.get(color_id, CombatTexts.NODE_COLOR_UNKNOWN_TEXT)
	_color.add_theme_color_override("font_color", CombatTexts.NODE_COLORS.get(color_id, UiStyle.TEXT))
	_units.text = CombatTexts.NODE_UNITS_TEXT % NumberFormat.format_int(int(node.get("units", 0)))


func _add_label(parent: Node, node_name: String, variation: StringName) -> Label:
	var label := Label.new()
	label.name = node_name
	if variation != &"":
		label.theme_type_variation = variation
	parent.add_child(label)
	return label
