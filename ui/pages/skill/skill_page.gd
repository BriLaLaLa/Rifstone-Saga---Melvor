class_name SkillPage
extends Page
## Page of a learned discipline or of the Engraver (docs/01_GDD_M24.md §35.7 and §35.11, docs/03_ARCHITECTURE.md §11),
## route `skill:<skill_id>`: header with icon, name, level and XP bar. A gathering discipline is read only (ResourceTable of its
## resources and the tool in the tabs of the GatherBody; the player gathers at the nodes of the combat cycle); an artisan
## page and the Engraver put recipes in the production queue. Every redraw reads the session; a refused command shows its reason under
## the header (stop reasons become toasts). No game state. An unlearned discipline asks for the Trainers page (`page_requested`).

signal page_requested(page_id: StringName)

const MASTERY_PANEL_SCENE: PackedScene = preload("res://ui/pages/mastery/mastery_panel.tscn")
const BLUEPRINT_SECTION_SCENE: PackedScene = preload("res://ui/pages/skill/blueprint_section.tscn")
const LOG_CATEGORY: String = "ui"
const LEVEL_TEXT: String = "Livello %s"
## Italian text of each refusal of `actions.enqueue`; other reasons use REFUSED_TEXT_DEFAULT.
const REFUSED_TEXTS: Dictionary[StringName, String] = SkillHeader.REFUSED_TEXTS
const REFUSED_TEXT_DEFAULT: String = SkillHeader.REFUSED_TEXT_DEFAULT

var _session: GameSession = null
var _skill: SkillDef = null
var _gather: GatherBody = null
var _mastery_panel: MasteryPanel = null
## Thin bar under the XP bar: the skill's mastery pool against its cap (skills with mastery only).
var _pool_bar: ProgressBar = null
var _blueprints: BlueprintSection = null
var _bench: ForgeBench = null
## The production queue of the artisan pages and the Engraver; the "Si trova in" line of a gathering page.
var _queue: ProductionQueuePanel = null
var _top: Control = null
## Body of a production page (recipe list and detail); null on a gathering page.
var _view: ProfessionView = null

@onready var _skill_icon: TextureRect = %SkillIcon
@onready var _name_label: Label = %NameLabel
@onready var _level_label: Label = %LevelLabel
@onready var _xp_bar: XpBar = %XpBar
@onready var _status_label: Label = %StatusLabel
@onready var _message_label: Label = %MessageLabel
@onready var _card_list: HFlowContainer = %Cards
@onready var _extras: VBoxContainer = %Extras
@onready var _content: VBoxContainer = %Content
@onready var _scroll: ScrollContainer = %Scroll
@onready var _mastery_button: Button = %MasteryButton


func _ready() -> void:
	set_process(false)
	_message_label.add_theme_color_override("font_color", UiStyle.BAD)
	_message_label.visible = false
	_mastery_button.pressed.connect(_on_mastery_button_pressed)


## Reads the skill of `page_id` (`skill:<id>`), builds its cards and follows the session's events.
func bind(session: GameSession) -> void:
	unbind()
	var skill: SkillDef = session.data.skill(PageHost.argument_of(page_id))
	if skill == null:
		Log.warn(LOG_CATEGORY, "skill page '%s': unknown skill" % page_id)
		return
	_session = session
	HelpButton.attach(_name_label.get_parent(), session.data, page_id)
	_skill = skill
	_skill_icon.texture = ItemSlotView.icon_of(skill.icon)
	_skill_icon.modulate = skill.color
	_name_label.text = skill.name
	_mastery_button.visible = skill.has_mastery
	_build_pool_bar()
	_build_extras()
	var events: GameEvents = _session.events
	events.xp_gained.connect(_on_events_xp_gained)
	events.level_up.connect(_on_events_level_up)
	events.action_started.connect(_redraw.unbind(3))
	events.action_stopped.connect(_redraw.unbind(3))
	events.mastery_xp_gained.connect(_on_events_mastery_xp_gained)
	events.modifiers_changed.connect(_redraw)
	events.production_queue_changed.connect(_on_events_queue_changed)
	events.discipline_changed.connect(_on_events_discipline_changed)
	events.recipe_learned.connect(_redraw.unbind(1))
	if _view != null or _blueprints != null or _gather != null:
		events.bank_changed.connect(_on_events_bank_changed)
		events.armory_changed.connect(_on_events_extras_changed)
		events.combat_started.connect(_on_events_combat_started)
		events.combat_stopped.connect(_on_events_combat_started)
		events.blueprint_crafted.connect(_on_events_extras_changed)
		events.gold_changed.connect(_on_events_extras_changed)
	_redraw()
	set_process(true)


## Disconnects every event connected in `bind`.
func unbind() -> void:
	set_process(false)
	if _session != null and is_instance_valid(_session):
		var events: GameEvents = _session.events
		for connection: Array in [
			[events.xp_gained, _on_events_xp_gained],
			[events.level_up, _on_events_level_up],
			[events.action_started, _redraw.unbind(3)],
			[events.action_stopped, _redraw.unbind(3)],
			[events.mastery_xp_gained, _on_events_mastery_xp_gained],
			[events.modifiers_changed, _redraw],
			[events.bank_changed, _on_events_bank_changed],
			[events.armory_changed, _on_events_extras_changed],
			[events.combat_started, _on_events_combat_started],
			[events.combat_stopped, _on_events_combat_started],
			[events.blueprint_crafted, _on_events_extras_changed],
			[events.gold_changed, _on_events_extras_changed],
			[events.production_queue_changed, _on_events_queue_changed],
			[events.discipline_changed, _on_events_discipline_changed],
			[events.recipe_learned, _redraw.unbind(1)],
		]:
			var event: Signal = connection[0]
			var handler: Callable = connection[1]
			if event.is_connected(handler):
				event.disconnect(handler)
	if _bench != null and is_instance_valid(_bench):
		_bench.unbind()
	if _mastery_panel != null and is_instance_valid(_mastery_panel):
		_mastery_panel.close_window()
	if _queue != null and is_instance_valid(_queue):
		_queue.unbind()
	_queue = null
	_top = null
	_session = null
	_skill = null
	_blueprints = null
	if _gather != null and is_instance_valid(_gather):
		_gather.forget_session()
	_gather = null
	if _view != null and is_instance_valid(_view):
		_view.forget_session()
	_bench = null


func _process(_delta: float) -> void:
	# Read-only: the progress of the queue head goes to the blueprint bar when the head is a blueprint craft.
	if _blueprints != null:
		_blueprints.set_progress(_session.actions.get_progress() if _running_action_id() == BlueprintCraft.ACTION else 0.0)


func _exit_tree() -> void:
	unbind()


func _is_gathering() -> bool:
	return _skill.category == &"gathering"


func _redraw() -> void:
	_redraw_header()
	_redraw_extras()


func _redraw_header() -> void:
	_level_label.text = LEVEL_TEXT % NumberFormat.format_int(_session.skills.get_level(_skill.id))
	_xp_bar.set_xp(_session.data.xp_table(), _session.skills.get_xp(_skill.id))
	_redraw_pool_bar()
	_redraw_status()


func _redraw_status() -> void:
	_status_label.text = SkillHeader.status_text(_session, _skill.id)


func _running_action_id() -> StringName:
	return SkillHeader.running_action_id(_session)


func _show_refusal(reason: StringName) -> void:
	_message_label.text = REFUSED_TEXTS.get(reason, REFUSED_TEXT_DEFAULT)
	_message_label.visible = true


func _hide_refusal() -> void:
	_message_label.text = ""
	_message_label.visible = false


## "Metti in coda" of a recipe card: the command answers, a refusal shows its reason.
func _on_enqueue_requested(action_id: StringName, count: int, repeat: bool) -> void:
	if _session == null:
		return
	var result: CommandResult = _session.actions.enqueue(_skill.id, action_id, count, repeat)
	if result.ok:
		_hide_refusal()
	else:
		_show_refusal(result.reason)


func _on_events_xp_gained(skill_id: StringName, _amount: int) -> void:
	if skill_id == _skill.id:
		_redraw_header()


func _on_events_level_up(skill_id: StringName, _new_level: int) -> void:
	if skill_id == _skill.id:
		_redraw()


func _on_events_queue_changed() -> void:
	_redraw_status()
	_redraw_extras()


## The discipline of this page was unlearned: the page has nothing to show, the Trainers page is requested.
func _on_events_discipline_changed(skill_id: StringName, grade: int) -> void:
	if skill_id == _skill.id and grade <= 0:
		page_requested.emit(&"trainers")


func _on_events_mastery_xp_gained(skill_id: StringName, _action_id: StringName, _amount: int) -> void:
	if skill_id == _skill.id:
		_redraw_pool_bar()
		if _gather != null:
			_gather.redraw(_session)


## The player entered or left a zone: the highlighted zone of "Si trova in" changes.
func _on_events_combat_started(_area_or_reason: StringName) -> void:
	_redraw_extras.call_deferred()  # the engine is still idle while the signal fires


func _on_events_bank_changed(_item_id: StringName, _new_count: int, _delta: int) -> void:
	_redraw_extras()


## Opens the mastery window of the skill (bound to the session while open) or closes it.
func _on_mastery_button_pressed() -> void:
	if _session == null or not _skill.has_mastery:
		return
	if _mastery_panel != null and _mastery_panel.visible:
		_mastery_panel.close_window()
		return
	if _mastery_panel == null:
		_mastery_panel = MASTERY_PANEL_SCENE.instantiate() as MasteryPanel
		_mastery_panel.title = MasteryTexts.WINDOW_TITLE % _skill.name
		add_child(_mastery_panel)
	_mastery_panel.bind(_session, _skill.id)
	_mastery_panel.open_window()


## M36: a gathering page is its GatherBody (tabs Panoramica, Risorse, Attrezzo) in `Extras`; a production page gets its ProfessionView and the queue strip.
func _build_extras() -> void:
	for child: Node in _extras.get_children():
		_extras.remove_child(child)
		child.queue_free()
	_blueprints = null
	_bench = null
	_gather = null
	_clear_top()
	_card_list.visible = false
	_scroll.visible = _is_gathering()
	if _is_gathering():
		_gather = GatherBody.new()
		_extras.add_child(_gather)
		_gather.setup(_session, _skill.id)
		_gather.go_to_area_requested.connect(_on_go_to_area_requested)
		_gather.tool_upgrade_requested.connect(_on_tool_upgrade_requested)
		_gather.tool_head_chosen.connect(_on_tool_head_chosen)
		return
	_build_production()


## The recipe list and detail (with the blueprint and bench pages of the Forging) and the queue strip at the bottom.
func _build_production() -> void:
	var pages: Dictionary[StringName, Control] = {}
	if _skill.id == BlueprintCraft.SKILL:
		_blueprints = BLUEPRINT_SECTION_SCENE.instantiate() as BlueprintSection
		_bench = ForgeBench.new()
		_bench.name = "ForgeBench"
		pages[ForgeTabs.TAB_BLUEPRINTS] = _blueprints
		pages[ForgeTabs.TAB_BENCH] = _bench
	_view = ProfessionView.new()
	_view.name = "ProfessionView"
	_content.add_child(_view)
	_content.move_child(_view, _scroll.get_index())
	_view.setup(_session.data, _skill.id, pages)
	_view.enqueue_requested.connect(_on_enqueue_requested)
	if _blueprints != null:
		_blueprints.setup(_session.data)
		_blueprints.start_requested.connect(_on_blueprint_start_requested)
		_blueprints.stop_requested.connect(_on_blueprint_stop_requested)
		_bench.bind(_session)
	_queue = ProductionQueuePanel.new()
	_queue.name = "ProductionQueue"
	_add_top(_queue)
	_queue.bind(_session)
	_queue.refused.connect(_show_refusal)


## The queue strip at the bottom of a production page.
func _add_top(node: Control) -> void:
	_top = node
	_content.add_child(node)


func _clear_top() -> void:
	if _queue != null and is_instance_valid(_queue):
		_queue.unbind()
	if _top != null and is_instance_valid(_top):
		_top.get_parent().remove_child(_top)
		_top.queue_free()
	if _view != null and is_instance_valid(_view):
		_view.get_parent().remove_child(_view)
		_view.queue_free()
	_top = null
	_queue = null
	_view = null


func _redraw_extras() -> void:
	if _view != null:
		_view.redraw(_session)
	if _blueprints != null:
		_blueprints.redraw(_session)
	if _gather != null:
		_gather.redraw(_session)


func _on_events_extras_changed(_a: Variant, _b: Variant) -> void:
	_redraw_extras()


func _on_blueprint_start_requested(blueprint_id: StringName, chosen_affix: StringName) -> void:
	if _session == null:
		return
	var result: CommandResult = _session.actions.enqueue_blueprint(blueprint_id, chosen_affix)
	if result.ok:
		_hide_refusal()
	else:
		_show_refusal_text(BlueprintTexts.refused(result.reason))


func _on_blueprint_stop_requested() -> void:
	if _session != null:
		_session.actions.cancel(0)
		_hide_refusal()


func _on_tool_upgrade_requested(uid: int) -> void:
	if _session == null:
		return
	var result: CommandResult = _session.armory.upgrade_tool(uid)
	if result.ok:
		_hide_refusal()
	else:
		_show_refusal_text(ToolUpgradeTexts.refused(result.reason))
	_redraw_extras()


func _show_refusal_text(text: String) -> void:
	_message_label.text = text
	_message_label.visible = true


func _build_pool_bar() -> void:
	if _pool_bar == null and _skill.has_mastery:
		_pool_bar = SkillHeader.build_pool_bar(_xp_bar)


func _redraw_pool_bar() -> void:
	if _pool_bar != null:
		SkillHeader.redraw_pool_bar(_pool_bar, _session, _skill.id)


## "Vai" of a zone: the combat starts there (the same command as the map); a refusal shows its reason under the header.
func _on_go_to_area_requested(area_id: StringName) -> void:
	if _session == null:
		return
	var result: CommandResult = _session.combat.start(area_id)
	if result.ok:
		_hide_refusal()
	else:
		_show_refusal_text(CombatTexts.REASON_TEXTS.get(result.reason, CombatTexts.REASON_TEXT_DEFAULT))


func _on_tool_head_chosen(uid: int, step: int, head_id: StringName) -> void:
	if _session == null:
		return
	_report(_session.armory.choose_tool_head(uid, step, head_id))
	_redraw_extras()


func _report(result: CommandResult) -> void:
	if result.ok:
		_hide_refusal()
	else:
		_show_refusal_text(ToolUpgradeTexts.refused(result.reason))
