class_name TrainerRow
extends PanelContainer
## Row of one discipline on the Trainers page (docs/01_GDD_M24.md §35.11): the Trainer (from the data), state, grade and
## cap, level, cost and requirements, `fed_by`, and the buttons Learn / Train / Unlearn. `setup` draws what comes from
## the data; `refresh(session)` reads everything else from `Disciplines`, `SkillsSystem` and `GameData`. Pressing a
## button only emits a request: the page sends the command. No game state here.

signal learn_requested(skill_id: StringName)
signal train_requested(skill_id: StringName)
signal unlearn_requested(skill_id: StringName)

const ICON_SIDE: float = 48.0
const INFO_MIN_WIDTH: float = 360.0

var _skill: SkillDef = null
var _trainer: TrainerDef = null
var _icon: TextureRect = null
var _title: Label = null
var _status: Label = null
var _level: Label = null
var _cost: Label = null
var _hint: Label = null
var _fed: Label = null
var _learn: Button = null
var _train: Button = null
var _unlearn: Button = null


func _ready() -> void:
	theme_type_variation = &"HudPanel"
	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	_icon = TextureRect.new()
	_icon.name = "Icon"
	_icon.custom_minimum_size = Vector2(ICON_SIDE, ICON_SIDE)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_icon)
	var info := VBoxContainer.new()
	info.name = "Info"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.custom_minimum_size = Vector2(INFO_MIN_WIDTH, 0)
	row.add_child(info)
	_title = _label(info, "TitleLabel", &"HeaderLabel")
	_title.mouse_filter = Control.MOUSE_FILTER_PASS
	_status = _label(info, "StatusLabel", &"")
	_level = _label(info, "LevelLabel", &"")
	_cost = _label(info, "CostLabel", &"MutedLabel")
	_hint = _label(info, "HintLabel", &"MutedLabel")
	_fed = _label(info, "FedByLabel", &"MutedLabel")
	var buttons := VBoxContainer.new()
	buttons.name = "Buttons"
	row.add_child(buttons)
	_learn = _button(buttons, "LearnButton", TrainersTexts.LEARN_TEXT, learn_requested)
	_train = _button(buttons, "TrainButton", TrainersTexts.TRAIN_TEXT, train_requested)
	_unlearn = _button(buttons, "UnlearnButton", TrainersTexts.UNLEARN_TEXT, unlearn_requested)
	_draw_static()


## Draws the data of `skill` and of its Trainer (call it once, after the row entered the tree).
func setup(skill: SkillDef, trainer: TrainerDef, data: GameData) -> void:
	_skill = skill
	_trainer = trainer
	name = "Trainer%s" % String(skill.id).to_pascal_case()
	if _icon != null:
		_draw_static()
	if _fed != null:
		var names: PackedStringArray = PackedStringArray()
		if trainer != null:
			for source_id: StringName in trainer.fed_by:
				var source: SkillDef = data.skill(source_id)
				names.append(source.name if source != null else String(source_id))
		_fed.visible = not names.is_empty()
		_fed.text = TrainersTexts.FED_BY_TEXT % ", ".join(names)


func skill_id() -> StringName:
	return _skill.id if _skill != null else &""


## Reads state, costs, requirements and the three commands' availability from `session`.
func refresh(session: GameSession) -> void:
	if _skill == null or _status == null:
		return
	var disciplines: Disciplines = session.disciplines
	var data: GameData = session.data
	var id: StringName = _skill.id
	var grade: int = disciplines.grade(id)
	var learned: bool = grade > 0
	var cap: int = disciplines.level_cap(id)
	_learn.visible = not learned
	_train.visible = learned
	_unlearn.visible = learned
	var hint: StringName = &""
	if not learned:
		_status.text = TrainersTexts.NOT_LEARNED_TEXT
		var first: TrainerGradeDef = data.trainer_grade(1)
		_level.text = TrainersTexts.LEVEL_UNLEARNED_TEXT % NumberFormat.format_int(first.cap if first != null else 0)
		var gold: int = disciplines.next_grade_cost(id)
		_cost.text = TrainersTexts.COST_FREE_TEXT if gold <= 0 else TrainersTexts.COST_LEARN_TEXT % NumberFormat.format_int(gold)
		var can: CommandResult = disciplines.can_learn(id)
		_learn.disabled = not can.ok
		hint = can.reason if not can.ok else &""
	else:
		var grade_def: TrainerGradeDef = data.trainer_grade(grade)
		_status.text = TrainersTexts.GRADE_TEXT % [grade_def.name if grade_def != null else "", NumberFormat.format_int(cap)]
		_level.text = TrainersTexts.LEVEL_TEXT % [NumberFormat.format_int(session.skills.get_level(id)),
				NumberFormat.format_int(cap)]
		var next_def: TrainerGradeDef = data.trainer_grade(grade + 1)
		var cost: int = disciplines.next_grade_cost(id)
		if next_def == null or cost < 0:
			_cost.text = TrainersTexts.MAX_GRADE_TEXT
		else:
			_cost.text = TrainersTexts.COST_TRAIN_TEXT % [next_def.name, NumberFormat.format_int(next_def.cap),
					NumberFormat.format_int(next_def.character_level), NumberFormat.format_int(cost)]
		var can_train: CommandResult = disciplines.can_train(id)
		_train.disabled = not can_train.ok
		hint = can_train.reason if not can_train.ok and can_train.reason != Reasons.MAX_GRADE else &""
		var can_unlearn: CommandResult = disciplines.can_unlearn(id)
		_unlearn.disabled = not can_unlearn.ok
		_unlearn.tooltip_text = "" if can_unlearn.ok else TrainersTexts.refused(can_unlearn.reason)
	_hint.visible = hint != &""
	_hint.text = TrainersTexts.refused(hint) if hint != &"" else ""


func _draw_static() -> void:
	if _skill == null or _icon == null:
		return
	_icon.texture = ItemSlotView.icon_of(_skill.icon)
	_icon.modulate = _skill.color
	_title.text = TrainersTexts.TRAINER_TEXT % [_trainer.title, _trainer.name] if _trainer != null else _skill.name
	_title.tooltip_text = _trainer.description if _trainer != null else ""


func _label(parent: Node, node_name: String, variation: StringName) -> Label:
	var label := Label.new()
	label.name = node_name
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if variation != &"":
		label.theme_type_variation = variation
	parent.add_child(label)
	return label


func _button(parent: Node, node_name: String, text: String, request: Signal) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: request.emit(_skill.id))
	parent.add_child(button)
	return button
