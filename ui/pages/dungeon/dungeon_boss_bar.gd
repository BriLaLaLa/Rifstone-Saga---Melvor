class_name DungeonBossBar
extends VBoxContainer
## Fixed band over the enemies for the whole final boss fight, intro included (docs/05_INTERFACES.md §7.q): "BOSS FINALE - Atto
## n/3" and under it the bar of the acts, one cell per act with the boss name from `state["stage"]["acts"]`: passed acts full,
## the act in progress highlighted, the ones to come dim. Presentation only: it draws `state["stage"]`.

const SEPARATION: int = 4
const ACT_SEPARATION: int = 6
const ACT_HEIGHT: int = 28
const HEADER_SIZE: int = 24
const PASSED_ALPHA: float = 0.4
const BORDER_WIDTH: int = 2
const CONTENT_MARGIN: float = 3.0

var _header: Label = null
var _acts_row: HBoxContainer = null
var _shown: String = ""


func _init() -> void:
	name = "BossBar"
	add_theme_constant_override("separation", SEPARATION)
	_header = Label.new()
	_header.name = "BossHeader"
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header.theme_type_variation = &"TitleLabel"
	_header.add_theme_font_size_override("font_size", HEADER_SIZE)
	_header.add_theme_color_override("font_color", UiStyle.GOLD)
	add_child(_header)
	_acts_row = HBoxContainer.new()
	_acts_row.name = "Acts"
	_acts_row.add_theme_constant_override("separation", ACT_SEPARATION)
	add_child(_acts_row)


## `stage` = `state["stage"]`. The cells are rebuilt only when the content changes.
func setup(stage: Dictionary) -> void:
	var index: int = int(stage.get("index", 1))
	var acts: Array = stage.get("acts", []) as Array
	var count: int = int(stage.get("count", acts.size()))
	_header.text = DungeonTexts.boss_header(index, count)
	var signature: String = "%d|%s" % [index, str(acts)]
	if signature == _shown:
		return
	_shown = signature
	for child: Node in _acts_row.get_children():
		_acts_row.remove_child(child)
		child.queue_free()
	for i: int in acts.size():
		_acts_row.add_child(_act_cell(i + 1, String((acts[i] as Dictionary).get("name", "")), index))


## State of the act cell number `act` (1-based): &"passed", &"current" or &"next", for tests.
func act_state(act: int) -> StringName:
	var cell: Node = _acts_row.get_node_or_null("Act_%d" % act)
	return StringName(cell.get_meta(&"state", &"")) if cell != null else &""


func act_count() -> int:
	return _acts_row.get_child_count()


func _act_cell(act: int, boss_name: String, current: int) -> Control:
	var state: StringName = &"passed" if act < current else (&"current" if act == current else &"next")
	var cell := PanelContainer.new()
	cell.name = "Act_%d" % act
	cell.set_meta(&"state", state)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.custom_minimum_size.y = ACT_HEIGHT
	var fill: Color = UiStyle.BG_FIELD
	var border: Color = UiStyle.COMBAT_ENEMY_BORDER
	var text_color: Color = UiStyle.TEXT_2
	match state:
		&"passed":
			fill = Color(UiStyle.GOLD, PASSED_ALPHA)
			border = UiStyle.GOLD
			text_color = UiStyle.TEXT
		&"current":
			fill = UiStyle.GOLD
			border = UiStyle.GOLD
			text_color = UiStyle.COMBAT_ENEMY_BG
	cell.add_theme_stylebox_override("panel", UiStyle.flat(fill, border, BORDER_WIDTH, CONTENT_MARGIN))
	var label := Label.new()
	label.name = "ActName"
	label.text = boss_name
	label.clip_text = true
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", text_color)
	cell.add_child(label)
	return cell
