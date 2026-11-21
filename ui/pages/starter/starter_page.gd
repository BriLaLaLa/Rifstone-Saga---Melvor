class_name StarterPage
extends Page
## «Primi passi» page (docs/01_GDD_M30.md §41.5, §41.8; docs/05_INTERFACES_M30.md §7.ab), route `starter`: the starter quests
## in groups (titles from the data), one `StarterRow` each. Riscuoti is the `starter.claim` command (one call per click);
## the reward arrives by Mail and the page says so, a refusal shows its reason. The rows are redrawn from
## `session.tutorial.starter` on `starter_quests_changed`, `starter_quest_completed` and on every signal that re-reads a
## measure (the keys of `TutorialMetrics.METRICS`). It keeps only references to its own nodes.

const ROW_SCRIPT: GDScript = preload("res://ui/pages/starter/starter_row.gd")

var _session: GameSession = null
var _rows: Array[StarterRow] = []
var _signals: Array[Signal] = []

@onready var _margin: MarginContainer = %Margin
@onready var _content: VBoxContainer = %Content
@onready var _title_label: Label = %TitleLabel
@onready var _count_label: Label = %CountLabel
@onready var _intro_label: Label = %IntroLabel
@onready var _message_label: Label = %MessageLabel
@onready var _groups: VBoxContainer = %Groups


func _ready() -> void:
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		_margin.add_theme_constant_override(side, UiStyle.STARTER_MARGIN)
	_content.add_theme_constant_override("separation", UiStyle.STARTER_SECTION_SEPARATION)
	_groups.add_theme_constant_override("separation", UiStyle.STARTER_SECTION_SEPARATION)
	_title_label.text = StarterTexts.TITLE_TEXT
	_intro_label.text = StarterTexts.INTRO_TEXT


func bind(session: GameSession) -> void:
	unbind()
	_session = session
	var events: GameEvents = _session.events
	_signals = [events.starter_quests_changed, events.starter_quest_completed]
	for metric: StringName in TutorialMetrics.METRICS:
		for signal_name: StringName in TutorialMetrics.METRICS[metric]:
			if events.has_signal(signal_name) and not _signals.has(Signal(events, signal_name)):
				_signals.append(Signal(events, signal_name))
	for sig: Signal in _signals:
		sig.connect(_on_changed)
	_build()
	_redraw()


func unbind() -> void:
	for sig: Signal in _signals:
		if sig.get_object() != null and is_instance_valid(sig.get_object()) and sig.is_connected(_on_changed):
			sig.disconnect(_on_changed)
	_signals.clear()
	_session = null


func _exit_tree() -> void:
	unbind()


## One title and the rows of each group, in the order of the data.
func _build() -> void:
	for child: Node in _groups.get_children():
		_groups.remove_child(child)
		child.queue_free()
	_rows.clear()
	var quests: Array[StarterQuestDef] = _session.tutorial.starter.quests()
	for group: Dictionary in _session.data.starter_groups():
		var box := VBoxContainer.new()
		box.name = "Group_%s" % group["id"]
		box.add_theme_constant_override("separation", UiStyle.STARTER_ROW_SEPARATION)
		_groups.add_child(box)
		var title := Label.new()
		title.name = "GroupTitle"
		title.text = String(group["title"]).to_upper()
		title.theme_type_variation = &"HeaderLabel"
		box.add_child(title)
		for def: StarterQuestDef in quests:
			if def.group != StringName(group["id"]):
				continue
			var row: StarterRow = ROW_SCRIPT.new() as StarterRow
			box.add_child(row)
			row.setup(def)
			row.claim_requested.connect(_on_claim_requested)
			_rows.append(row)


func _redraw() -> void:
	if _session == null:
		return
	var starter: StarterQuests = _session.tutorial.starter
	_count_label.text = StarterTexts.COUNT_TEXT % [starter.claimed_count(), starter.total()]
	for row: StarterRow in _rows:
		row.refresh(starter, _session.data)


func _on_claim_requested(quest_id: StringName) -> void:
	var result: CommandResult = _session.tutorial.starter.claim(quest_id)
	_message_label.visible = true
	_message_label.text = StarterTexts.CLAIMED_NOTICE if result.ok else StarterTexts.refused(result.reason)
	_message_label.add_theme_color_override("font_color", UiStyle.GOOD if result.ok else UiStyle.BAD)
	_redraw()


func _on_changed(_a: Variant = null, _b: Variant = null, _c: Variant = null, _d: Variant = null) -> void:
	_redraw()
