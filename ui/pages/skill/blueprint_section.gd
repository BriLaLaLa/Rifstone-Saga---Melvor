class_name BlueprintSection
extends VBoxContainer
## Blueprint section of the Forging page (docs/01_GDD.md §5.1, docs/05_INTERFACES.md §7.x): the blueprints in the bank,
## the requirements ("owned / required"), duration, XP and two-affix chance read from the systems, the choice of the affix
## from the Forging level `blueprint.choose_affix_level`, and Start / Stop for the craft in progress.
##
## Internal to SkillPage. `setup` builds one row per blueprint of the data (hidden unless owned or running); `redraw`
## rereads everything from the session; the page feeds the bar with `set_progress(actions.get_progress())`. The only
## state is presentation: the selected blueprint and the chosen affix. The buttons emit signals; the page sends
## `actions.start_blueprint` / `actions.stop` and shows the refusal.

signal start_requested(blueprint_id: StringName, chosen_affix: StringName)
signal stop_requested

const CHOICE_LEVEL_KEY: String = "blueprint.choose_affix_level"
const SKILL: StringName = BlueprintCraft.SKILL
const INTERVAL_STAT: StringName = &"skill_interval_pct"

var _data: GameData = null
var _session: GameSession = null  # last session given to `redraw`, to refresh after a local selection
var _rows: Dictionary[StringName, Button] = {}
## Presentation: the blueprint shown in the detail and the affix chosen for it ("" = random).
var _selected: StringName = &""
var _chosen_affix: StringName = &""
## What the affix list was built for (blueprint and grade level), to rebuild it only when it changes.
var _choice_key: String = ""

@onready var _title: Label = %SectionTitle
@onready var _empty_label: Label = %EmptyLabel
@onready var _list: HFlowContainer = %List
@onready var _detail: PanelContainer = %Detail
@onready var _detail_name: Label = %DetailName
@onready var _requirement_label: Label = %RequirementLabel
@onready var _inputs: VBoxContainer = %Inputs
@onready var _info_label: Label = %InfoLabel
@onready var _affix_row: HBoxContainer = %AffixRow
@onready var _affix_label: Label = %AffixLabel
@onready var _affix_choice: OptionButton = %AffixChoice
@onready var _affix_note: Label = %AffixNote
@onready var _status_label: Label = %StatusLabel
@onready var _progress_bar: ActionProgressBar = %ProgressBar
@onready var _start_button: Button = %StartButton
@onready var _stop_button: Button = %StopButton


func _ready() -> void:
	_title.text = BlueprintTexts.SECTION_TITLE
	_title.visible = false  # the sub-tab already names the section
	_empty_label.text = BlueprintTexts.EMPTY_TEXT
	_affix_label.text = BlueprintTexts.AFFIX_LABEL
	_start_button.text = BlueprintTexts.START_TEXT
	_stop_button.text = BlueprintTexts.STOP_TEXT
	_requirement_label.add_theme_color_override("font_color", UiStyle.BAD)
	_affix_choice.item_selected.connect(_on_affix_selected)
	_start_button.pressed.connect(_on_start_pressed)
	_stop_button.pressed.connect(func() -> void: stop_requested.emit())


## Builds one row per blueprint of the data (once).
func setup(data: GameData) -> void:
	_data = data
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_rows.clear()
	_selected = &""
	_chosen_affix = &""
	_choice_key = ""
	for blueprint: ItemDef in data.blueprints():
		var row: Button = Button.new()
		row.name = "Blueprint_%s" % blueprint.id
		row.toggle_mode = true
		row.focus_mode = Control.FOCUS_NONE
		row.visible = false
		row.pressed.connect(_on_row_pressed.bind(blueprint.id))
		_list.add_child(row)
		_rows[blueprint.id] = row


## Rereads the bank, the Forging level and the craft in progress.
func redraw(session: GameSession) -> void:
	if _data == null:
		return
	_session = session
	var state: Dictionary = session.actions.blueprint_state()
	var running: StringName = state.get("blueprint", &"")
	var any_shown: bool = false
	for blueprint_id: StringName in _rows:
		var def: ItemDef = _data.item(blueprint_id)
		var owned: int = session.bank.get_count(blueprint_id)
		var row: Button = _rows[blueprint_id]
		row.visible = owned > 0 or blueprint_id == running
		if blueprint_id == running and owned == 0:
			row.text = BlueprintTexts.RUNNING_ROW_TEXT % def.name
		else:
			row.text = BlueprintTexts.OWNED_TEXT % [def.name, NumberFormat.format_int(owned)]
		any_shown = any_shown or row.visible
	_empty_label.visible = not any_shown
	if _selected == &"" or not _rows.has(_selected) or not _rows[_selected].visible:
		select(running if running != &"" else _first_visible())
	_detail.visible = _selected != &""
	if _selected != &"":
		_redraw_detail(session, state)


## Selects the blueprint shown in the detail (&"" = none).
func select(blueprint_id: StringName) -> void:
	if blueprint_id != &"" and not _rows.has(blueprint_id):
		return
	if blueprint_id != _selected:
		_selected = blueprint_id
		_chosen_affix = &""
		_choice_key = ""
	for id: StringName in _rows:
		_rows[id].set_pressed_no_signal(id == _selected)


func selected() -> StringName:
	return _selected


## The affix that a Start would send now (&"" when random or when the choice is not available).
func chosen_affix() -> StringName:
	return _chosen_affix if _affix_choice.visible else &""


## Draws the cycle progress of the craft in progress (`actions.get_progress()`).
func set_progress(progress: float) -> void:
	_progress_bar.set_progress(progress)


func _first_visible() -> StringName:
	for blueprint_id: StringName in _rows:
		if _rows[blueprint_id].visible:
			return blueprint_id
	return &""


func _redraw_detail(session: GameSession, state: Dictionary) -> void:
	var blueprint: ItemDef = _data.item(_selected)
	var level: int = session.skills.get_level(SKILL)
	var required: int = BlueprintCraft.required_level(blueprint, _data)
	var running: StringName = state.get("blueprint", &"")
	var is_running: bool = running == _selected
	_detail_name.text = _data.item(blueprint.blueprint.base_id).name
	_requirement_label.text = BlueprintTexts.REQUIRES_LEVEL_TEXT % NumberFormat.format_int(required)
	_requirement_label.visible = level < required
	_redraw_inputs(session, blueprint, is_running)
	var ctx: ModifierContext = ModifierContext.for_action(SKILL, BlueprintCraft.ACTION)
	var duration_ms: int = BlueprintCraft.duration_ms(blueprint, session.modifiers.total(INTERVAL_STAT, ctx), _data)
	if is_running:
		duration_ms = int(state["duration_ms"])
	var rare: float = ItemRoller.blueprint_two_affix_chance(level, session.modifiers.total(BlueprintCraft.RARITY_STAT, ctx),
			_data)
	_info_label.text = BlueprintTexts.INFO_LINE % [BlueprintTexts.duration(duration_ms),
			NumberFormat.format_int(BlueprintCraft.xp(blueprint, _data)), BlueprintTexts.percent(rare)]
	_redraw_affix(blueprint, level, required, is_running)
	_status_label.visible = is_running
	_status_label.text = BlueprintTexts.RUNNING_TEXT
	if is_running and state.get("waiting", false):
		_status_label.text = BlueprintTexts.WAITING_TEXT
	_progress_bar.visible = is_running
	_start_button.visible = not is_running
	_start_button.disabled = session.bank.get_count(_selected) <= 0
	_stop_button.visible = running != &""


func _redraw_inputs(session: GameSession, blueprint: ItemDef, is_running: bool) -> void:
	for child: Node in _inputs.get_children():
		_inputs.remove_child(child)
		child.queue_free()
	_inputs.visible = not is_running
	if is_running:
		return
	var title: Label = Label.new()
	title.theme_type_variation = &"MutedLabel"
	title.text = BlueprintTexts.INPUTS_TITLE
	_inputs.add_child(title)
	for input: ItemQty in BlueprintCraft.inputs(blueprint):
		var have: int = session.bank.get_count(input.item_id)
		var line: Label = Label.new()
		line.name = "Input_%s" % input.item_id
		line.text = BlueprintTexts.INPUT_LINE % [_data.item(input.item_id).name, NumberFormat.format_int(have),
				NumberFormat.format_int(input.qty)]
		line.add_theme_color_override("font_color", UiStyle.GOOD if have >= input.qty else UiStyle.BAD)
		_inputs.add_child(line)


func _redraw_affix(blueprint: ItemDef, level: int, required: int, is_running: bool) -> void:
	var choice_level: int = int(_data.balance_value(CHOICE_LEVEL_KEY))
	var enabled: bool = level >= choice_level and not is_running
	_affix_row.visible = enabled
	_affix_choice.visible = enabled
	_affix_choice.disabled = not enabled
	_affix_note.visible = level < choice_level
	_affix_note.text = BlueprintTexts.AFFIX_LOCKED_TEXT % NumberFormat.format_int(choice_level)
	if not enabled:
		_chosen_affix = &""
		_choice_key = ""
		return
	var key: String = "%s:%s" % [_selected, required]
	if key == _choice_key:
		return
	_choice_key = key
	_affix_choice.clear()
	_affix_choice.add_item(BlueprintTexts.AFFIX_RANDOM_TEXT)
	_affix_choice.set_item_metadata(0, &"")
	var base: ItemDef = _data.item(blueprint.blueprint.base_id)
	for def: AffixDef in ItemRoller.chosen_affix_candidates(base, required, _data):
		_affix_choice.add_item(def.name)
		_affix_choice.set_item_metadata(_affix_choice.item_count - 1, def.id)
	_affix_choice.select(0)
	_chosen_affix = &""


func _on_row_pressed(blueprint_id: StringName) -> void:
	select(blueprint_id)
	if _session != null:
		redraw(_session)  # the detail (inputs, level, affix list) must follow the new selection at once


func _on_affix_selected(index: int) -> void:
	_chosen_affix = _affix_choice.get_item_metadata(index)


func _on_start_pressed() -> void:
	if _selected != &"":
		start_requested.emit(_selected, chosen_affix())
