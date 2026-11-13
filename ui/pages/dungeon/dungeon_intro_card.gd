class_name DungeonIntroCard
extends PanelContainer
## The entrance scene of a boss stage (docs/05_INTERFACES.md §7.q, docs/01_GDD.md §33.4): "Atto n", the title of the stage, its
## phrase and a bar that runs with `intro_left_ms`. Presentation only: it draws `state["stage"]` and keeps no game state.

const BAR_HEIGHT: int = 14
const TITLE_SIZE: int = 40
const QUOTE_SIZE: int = 20
const SEPARATION: int = 14

var _act_label: Label = null
var _title_label: Label = null
var _quote_label: Label = null
var _bar: ProgressBar = null


func _ready() -> void:
	add_theme_stylebox_override("panel", UiStyle.flat(UiStyle.COMBAT_ENEMY_BG, UiStyle.COMBAT_ENEMY_BORDER,
			UiStyle.COMBAT_FRAME_WIDTH * 2, 14.0))
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", SEPARATION)
	add_child(box)
	_act_label = _label("ActLabel", &"MutedLabel", 0)
	_title_label = _label("StageTitleLabel", &"TitleLabel", TITLE_SIZE)
	_quote_label = _label("QuoteLabel", &"", QUOTE_SIZE)
	_bar = ProgressBar.new()
	_bar.name = "IntroBar"
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.custom_minimum_size.y = BAR_HEIGHT
	for node: Control in [_act_label, _title_label, _quote_label, _bar]:
		box.add_child(node)


## `stage` = `state["stage"]`; `value` of the bar = how much of the scene has already run.
func show_stage(stage: Dictionary) -> void:
	_act_label.text = DungeonTexts.INTRO_STAGE_TEXT % int(stage.get("index", 1))
	_title_label.text = String(stage.get("title", ""))
	_quote_label.text = "\"%s\"" % String(stage.get("quote", ""))
	var total: int = maxi(1, int(stage.get("intro_ms", 1)))
	_bar.value = clampf(1.0 - float(stage.get("intro_left_ms", 0)) / float(total), 0.0, 1.0)


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
