class_name DungeonIntroCard
extends PanelContainer
## The entrance banner of a boss act (docs/05_INTERFACES.md §7.q, docs/01_GDD.md §33.4): "ATTO n/3", the name of the boss, the
## title of the stage, its phrase and a bar that runs with `intro_left_ms`. The last act is stronger (gold frame, bigger text).
## Presentation only: it draws `state["stage"]` and keeps no game state.

const BAR_HEIGHT: int = 14
const TITLE_SIZE: int = 40
const FINAL_TITLE_SIZE: int = 52
const QUOTE_SIZE: int = 20
const SEPARATION: int = 14
const FRAME_WIDTH: int = 2
const FINAL_FRAME_WIDTH: int = 5

var _act_label: Label = null
var _name_label: Label = null
var _title_label: Label = null
var _quote_label: Label = null
var _bar: ProgressBar = null
var _final: bool = false


func _ready() -> void:
	_apply_frame(false)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", SEPARATION)
	add_child(box)
	_act_label = _label("ActLabel", &"HeaderLabel", 0)
	_name_label = _label("BossNameLabel", &"TitleLabel", TITLE_SIZE)
	_title_label = _label("StageTitleLabel", &"MutedLabel", 0)
	_quote_label = _label("QuoteLabel", &"", QUOTE_SIZE)
	_bar = ProgressBar.new()
	_bar.name = "IntroBar"
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.custom_minimum_size.y = BAR_HEIGHT
	for node: Control in [_act_label, _name_label, _title_label, _quote_label, _bar]:
		box.add_child(node)


## `stage` = `state["stage"]`; `value` of the bar = how much of the scene has already run.
func show_stage(stage: Dictionary) -> void:
	var index: int = int(stage.get("index", 1))
	var count: int = int(stage.get("count", 1))
	var acts: Array = stage.get("acts", []) as Array
	var boss_name: String = String((acts[index - 1] as Dictionary).get("name", "")) if index >= 1 and index <= acts.size() else ""
	var is_final: bool = index >= count
	if is_final != _final:
		_apply_frame(is_final)
	_act_label.text = DungeonTexts.act_text(index, count)
	_name_label.text = boss_name if boss_name != "" else String(stage.get("title", ""))
	_name_label.add_theme_font_size_override("font_size", FINAL_TITLE_SIZE if is_final else TITLE_SIZE)
	_title_label.text = String(stage.get("title", ""))
	_title_label.visible = boss_name != ""
	_quote_label.text = "\"%s\"" % String(stage.get("quote", ""))
	var total: int = maxi(1, int(stage.get("intro_ms", 1)))
	_bar.value = clampf(1.0 - float(stage.get("intro_left_ms", 0)) / float(total), 0.0, 1.0)


## True while the strong look of the last act is on, for tests.
func is_final_look() -> bool:
	return _final


func _apply_frame(is_final: bool) -> void:
	_final = is_final
	var border: Color = UiStyle.GOLD if is_final else UiStyle.COMBAT_ENEMY_BORDER
	add_theme_stylebox_override("panel", UiStyle.flat(UiStyle.COMBAT_ENEMY_BG, border,
			FINAL_FRAME_WIDTH if is_final else FRAME_WIDTH, 14.0))


func _label(node_name: String, variation: StringName, font_size: int) -> Label:
	var label := Label.new()
	label.name = node_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if variation != &"":
		label.theme_type_variation = variation
	if font_size > 0:
		label.add_theme_font_size_override("font_size", font_size)
	return label
