class_name TrainersPage
extends Page
## Trainers page (docs/01_GDD_M24.md §35.3 and §35.11, 05_INTERFACES_M24.md §7.o), route `trainers`: two boxes, Raccolta
## and Produzione, each with "n/max posti" and one TrainerRow per discipline of the data (`data.disciplines(category)`).
## The player learns, trains and unlearns with the `Disciplines` commands (`learn`, `train`, `unlearn`); a refusal shows
## its reason in MessageLabel. Unlearning asks a confirmation that lists what is lost. The page redraws from the getters
## on `discipline_changed`, `gold_changed`, `level_up`, `character_level_up` and `skill_reset`. It keeps no game state.

const MARGIN: int = 16
const SECTION_SEPARATION: int = 12
const ROW_SEPARATION: int = 8
const CATEGORIES: Array[StringName] = [&"gathering", &"artisan"]

var _session: GameSession = null
var _rows: Dictionary[StringName, TrainerRow] = {}
var _titles: Dictionary[StringName, Label] = {}
var _connections: Array[Array] = []

@onready var _margin: MarginContainer = %Margin
@onready var _content: VBoxContainer = %Content
@onready var _title_label: Label = %TitleLabel
@onready var _gold_label: MoneyLabel = %GoldLabel
@onready var _message_label: Label = %MessageLabel
@onready var _gathering_title: Label = %GatheringTitle
@onready var _artisan_title: Label = %ArtisanTitle
@onready var _gathering_rows: VBoxContainer = %GatheringRows
@onready var _artisan_rows: VBoxContainer = %ArtisanRows


func _ready() -> void:
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		_margin.add_theme_constant_override(side, MARGIN)
	_content.add_theme_constant_override("separation", SECTION_SEPARATION)
	_gathering_rows.add_theme_constant_override("separation", ROW_SEPARATION)
	_artisan_rows.add_theme_constant_override("separation", ROW_SEPARATION)
	_title_label.text = TrainersTexts.TITLE_TEXT
	_message_label.add_theme_color_override("font_color", UiStyle.BAD)


func bind(session: GameSession) -> void:
	unbind()
	_session = session
	HelpButton.attach(_title_label.get_parent(), session.data, &"trainers")
	_build_rows()
	var events: GameEvents = session.events
	for pair: Array in [[events.discipline_changed, _on_discipline_changed], [events.gold_changed, _on_gold_changed],
			[events.level_up, _on_level_up], [events.character_level_up, _on_character_level_up],
			[events.skill_reset, _on_skill_reset]]:
		var source: Signal = pair[0]
		var handler: Callable = pair[1]
		source.connect(handler)
		_connections.append([source, handler])
	_refresh()


func unbind() -> void:
	for pair: Array in _connections:
		var source: Signal = pair[0]
		var handler: Callable = pair[1]
		if source.is_connected(handler):
			source.disconnect(handler)
	_connections.clear()
	_session = null


func _exit_tree() -> void:
	unbind()


func _build_rows() -> void:
	for container: VBoxContainer in [_gathering_rows, _artisan_rows]:
		for child: Node in container.get_children():
			container.remove_child(child)
			child.queue_free()
	_rows.clear()
	var containers: Dictionary[StringName, VBoxContainer] = {&"gathering": _gathering_rows, &"artisan": _artisan_rows}
	_titles = {&"gathering": _gathering_title, &"artisan": _artisan_title}
	for category: StringName in CATEGORIES:
		for skill_id: StringName in _session.data.disciplines(category):
			var skill: SkillDef = _session.data.skill(skill_id)
			var row: TrainerRow = TrainerRow.new()
			containers[category].add_child(row)
			row.setup(skill, _session.data.trainer(skill_id), _session.data)
			row.learn_requested.connect(_on_learn_requested)
			row.train_requested.connect(_on_train_requested)
			row.unlearn_requested.connect(_on_unlearn_requested)
			_rows[skill_id] = row


func _refresh() -> void:
	if _session == null:
		return
	_gold_label.caption = TrainersTexts.GOLD_CAPTION
	_gold_label.set_amount(_session.wallet.get_gold(), _session.data.currency())
	for category: StringName in _titles:
		var used: int = 0
		for skill_id: StringName in _session.disciplines.learned(category):
			if not _session.disciplines.is_free_slot(skill_id):
				used += 1
		_titles[category].text = TrainersTexts.title(category, used, used + _session.disciplines.free_slots(category))
	for row: TrainerRow in _rows.values():
		row.refresh(_session)


func _show_result(result: CommandResult) -> void:
	_message_label.visible = not result.ok
	_message_label.text = "" if result.ok else TrainersTexts.refused(result.reason)
	_refresh()


func _on_learn_requested(skill_id: StringName) -> void:
	if _session != null:
		_show_result(_session.disciplines.learn(skill_id))


func _on_train_requested(skill_id: StringName) -> void:
	if _session != null:
		_show_result(_session.disciplines.train(skill_id))


## Asks the confirmation (cost and what is lost, all read from the model), then sends `unlearn`.
func _on_unlearn_requested(skill_id: StringName) -> void:
	if _session == null:
		return
	var can: CommandResult = _session.disciplines.can_unlearn(skill_id)
	if not can.ok:
		_show_result(can)
		return
	var skill: SkillDef = _session.data.skill(skill_id)
	var text: String = TrainersTexts.UNLEARN_QUESTION % [skill.name,
			Money.text(_session.disciplines.unlearn_cost(skill_id), _session.data.currency()), _loss_text(skill_id)]
	var accepted: bool = await ConfirmDialog.ask(self, TrainersTexts.UNLEARN_TITLE % skill.name, text)
	if accepted and _session != null:
		_show_result(_session.disciplines.unlearn(skill_id))


## The list of what unlearning loses, read from the model.
func _loss_text(skill_id: StringName) -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append(TrainersTexts.LOSS_LEVEL % [NumberFormat.format_int(_session.skills.get_level(skill_id)),
			NumberFormat.format_int(_session.skills.get_xp(skill_id))])
	if _session.data.skill(skill_id).has_mastery:
		parts.append(TrainersTexts.LOSS_MASTERY % NumberFormat.format_int(_session.mastery.get_pool(skill_id)))
	var queued: int = 0
	for job: Dictionary in _session.actions.jobs():
		if StringName(job.get("skill", &"")) == skill_id:
			queued += 1
	if queued > 0:
		parts.append(TrainersTexts.LOSS_JOBS % queued)
	return TrainersTexts.LOSS_SEPARATOR.join(parts)


func _on_discipline_changed(_skill_id: StringName, _grade: int) -> void:
	_refresh()


func _on_gold_changed(_new_amount: int, _delta: int) -> void:
	_refresh()


func _on_level_up(_skill_id: StringName, _new_level: int) -> void:
	_refresh()


func _on_character_level_up(_new_level: int) -> void:
	_refresh()


func _on_skill_reset(_skill_id: StringName) -> void:
	_refresh()
