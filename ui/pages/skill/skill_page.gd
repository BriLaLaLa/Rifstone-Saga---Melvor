class_name SkillPage
extends Page
## Page of a learned discipline or of the Engraver (docs/01_GDD_M24.md §35.7 and §35.11, docs/03_ARCHITECTURE.md §11),
## route `skill:<skill_id>`: header with icon, name, level and XP bar; one card per action of the data.
##
## A gathering discipline is read only (resources, level, the colour at the current level, mastery, the areas where it is
## found, the tool panel): the player gathers at the nodes of the combat cycle. An artisan page and the Engraver put the
## recipes in the production queue (`actions.enqueue`, `enqueue_blueprint`) and show the queue (ProductionQueuePanel).
## Every redraw reads the session; a refused command shows its reason under the header. Stop reasons of the runner
## become toasts (ToastManager), not here. It keeps no game state: the session reference and its nodes.
## The cards of recipes are redrawn on `bank_changed` (owned ingredients). The card list scrolls (88 recipes in Forgiatura).
## Skills with mastery have a "Maestria" button in the header that opens the MasteryPanel (M2-03), a child window of the
## page (created on the first press, freed with the page): bound to the session only while open.
## When its own discipline is unlearned the page asks for the Trainers page (`page_requested`).

signal page_requested(page_id: StringName)

const CARD_SCENE: PackedScene = preload("res://ui/pages/skill/action_card.tscn")
const RECIPE_CARD_SCENE: PackedScene = preload("res://ui/pages/skill/recipe_card.tscn")
const MASTERY_PANEL_SCENE: PackedScene = preload("res://ui/pages/mastery/mastery_panel.tscn")
const BLUEPRINT_SECTION_SCENE: PackedScene = preload("res://ui/pages/skill/blueprint_section.tscn")
const TOOL_PANEL_SCENE: PackedScene = preload("res://ui/pages/skill/tool_upgrade_panel.tscn")
const TOOL_SKILLS: Array[StringName] = [&"forestry", &"quarrying", &"angling"]
const LOG_CATEGORY: String = "ui"
const LEVEL_TEXT: String = "Livello %s"
## Italian text of each refusal of `actions.enqueue`; other reasons use REFUSED_TEXT_DEFAULT.
const REFUSED_TEXTS: Dictionary[StringName, String] = SkillHeader.REFUSED_TEXTS
const REFUSED_TEXT_DEFAULT: String = SkillHeader.REFUSED_TEXT_DEFAULT

var _session: GameSession = null
var _skill: SkillDef = null
var _cards: Dictionary[StringName, ActionCard] = {}
var _mastery_panel: MasteryPanel = null
## Thin bar under the XP bar: the skill's mastery pool against its cap (skills with mastery only).
var _pool_bar: ProgressBar = null
var _blueprints: BlueprintSection = null
var _tool_panel: ToolUpgradePanel = null
var _bench: ForgeBench = null
## The production queue of the artisan pages and the Engraver; the "Si trova in" line of a gathering page.
var _queue: ProductionQueuePanel = null
var _top: Control = null
var _tabs: SkillTabs = SkillTabs.new()
## Flow container of each Engraver section (presentation), by section id.
var _section_flows: Dictionary[StringName, HFlowContainer] = {}

@onready var _skill_icon: TextureRect = %SkillIcon
@onready var _name_label: Label = %NameLabel
@onready var _level_label: Label = %LevelLabel
@onready var _xp_bar: XpBar = %XpBar
@onready var _status_label: Label = %StatusLabel
@onready var _message_label: Label = %MessageLabel
@onready var _card_list: HFlowContainer = %Cards
@onready var _extras: VBoxContainer = %Extras
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
	_build_cards()
	_tabs.build(_skill.id, _extras, _cards, _session.data, _blueprints, _bench)
	var events: GameEvents = _session.events
	events.xp_gained.connect(_on_events_xp_gained)
	events.level_up.connect(_on_events_level_up)
	events.action_started.connect(_on_events_action_started)
	events.action_stopped.connect(_on_events_action_stopped)
	events.mastery_xp_gained.connect(_on_events_mastery_xp_gained)
	events.modifiers_changed.connect(_on_events_modifiers_changed)
	events.production_queue_changed.connect(_on_events_queue_changed)
	events.discipline_changed.connect(_on_events_discipline_changed)
	events.recipe_learned.connect(_on_events_recipe_learned)
	if _has_recipe_cards() or _blueprints != null or _tool_panel != null:
		events.bank_changed.connect(_on_events_bank_changed)
		events.armory_changed.connect(_on_events_extras_changed)
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
			[events.action_started, _on_events_action_started],
			[events.action_stopped, _on_events_action_stopped],
			[events.mastery_xp_gained, _on_events_mastery_xp_gained],
			[events.modifiers_changed, _on_events_modifiers_changed],
			[events.bank_changed, _on_events_bank_changed],
			[events.armory_changed, _on_events_extras_changed],
			[events.blueprint_crafted, _on_events_extras_changed],
			[events.gold_changed, _on_events_extras_changed],
			[events.production_queue_changed, _on_events_queue_changed],
			[events.discipline_changed, _on_events_discipline_changed],
			[events.recipe_learned, _on_events_recipe_learned],
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
	_tool_panel = null
	_bench = null


func _process(_delta: float) -> void:
	# Read-only: the progress of the queue head goes to the blueprint bar when the head is a blueprint craft.
	if _blueprints != null:
		_blueprints.set_progress(_session.actions.get_progress() if _running_action_id() == BlueprintCraft.ACTION else 0.0)


func _exit_tree() -> void:
	unbind()


func _build_cards() -> void:
	for child: Node in _card_list.get_children():
		_card_list.remove_child(child)
		child.queue_free()
	_cards.clear()
	for action: ActionDef in _session.data.actions_for_skill(_skill.id):
		if action.id == BlueprintCraft.ACTION:
			continue  # started from the BlueprintSection, not from a card
		var scene: PackedScene = RECIPE_CARD_SCENE if not action.inputs.is_empty() else CARD_SCENE
		var action_card: ActionCard = scene.instantiate() as ActionCard
		_card_parent(action).add_child(action_card)
		action_card.setup(action, _session.data)
		if action_card is RecipeCard:
			(action_card as RecipeCard).enqueue_requested.connect(_on_enqueue_requested)
		_cards[action.id] = action_card


## Where the card of `action` goes: the card list, or for the Engraver the flow of its section (inside `Extras`).
func _card_parent(action: ActionDef) -> Container:
	if _skill.id != EngraverSections.SKILL:
		return _card_list
	return EngraverSections.flow_for(_extras, _section_flows, action)


func _redraw() -> void:
	_redraw_header()
	for action_id: StringName in _cards:
		_cards[action_id].redraw(_session)
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


func _on_events_action_started(_lane: StringName, _skill_id: StringName, _action_id: StringName) -> void:
	_redraw()


func _on_events_action_stopped(_lane: StringName, _skill_id: StringName, _reason: StringName) -> void:
	_redraw()


func _on_events_queue_changed() -> void:
	_redraw_status()
	_redraw_extras()


## A recipe was discovered: the lock of its card goes away.
func _on_events_recipe_learned(_action_id: StringName) -> void:
	_redraw()


## The discipline of this page was unlearned: the page has nothing to show, the Trainers page is requested.
func _on_events_discipline_changed(skill_id: StringName, grade: int) -> void:
	if skill_id == _skill.id and grade <= 0:
		page_requested.emit(&"trainers")


func _on_events_mastery_xp_gained(skill_id: StringName, action_id: StringName, _amount: int) -> void:
	if skill_id == _skill.id:
		_redraw_pool_bar()
	if skill_id == _skill.id and _cards.has(action_id):
		_cards[action_id].redraw(_session)


func _on_events_modifiers_changed() -> void:
	_redraw()


func _on_events_bank_changed(_item_id: StringName, _new_count: int, _delta: int) -> void:
	_redraw_extras()
	for action_id: StringName in _cards:
		if _cards[action_id] is RecipeCard:
			_cards[action_id].redraw(_session)


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


func _has_recipe_cards() -> bool:
	for action_id: StringName in _cards:
		if _cards[action_id] is RecipeCard:
			return true
	return false


## M10: the blueprint section of the Forging page and the tool panel of the gathering skills, in `Extras`.
func _build_extras() -> void:
	for child: Node in _extras.get_children():
		_extras.remove_child(child)
		child.queue_free()
	_blueprints = null
	_tool_panel = null
	_bench = null
	_section_flows.clear()
	_tabs.clear()
	_clear_top()
	if _skill.category == &"gathering":
		_add_top(GatheringInfo.build_label(_session.data, _skill.id))
	else:  # artisan pages and the Engraver: the production queue on top
		_queue = ProductionQueuePanel.new()
		_queue.name = "ProductionQueue"
		_add_top(_queue)
		_queue.bind(_session)
		_queue.refused.connect(_show_refusal)
	if _skill.id == BlueprintCraft.SKILL:
		_blueprints = BLUEPRINT_SECTION_SCENE.instantiate() as BlueprintSection
		_extras.add_child(_blueprints)
		_blueprints.setup(_session.data)
		_blueprints.start_requested.connect(_on_blueprint_start_requested)
		_blueprints.stop_requested.connect(_on_blueprint_stop_requested)
		_bench = ForgeBench.new()
		_extras.add_child(_bench)
		_bench.bind(_session)
	elif TOOL_SKILLS.has(_skill.id):
		_tool_panel = TOOL_PANEL_SCENE.instantiate() as ToolUpgradePanel
		_extras.add_child(_tool_panel)
		_tool_panel.setup(_skill.id)
		_tool_panel.upgrade_requested.connect(_on_tool_upgrade_requested)


## The node above `Extras` (the queue or the "Si trova in" line): presentation, replaced at each bind.
func _add_top(node: Control) -> void:
	_top = node
	_extras.get_parent().add_child(node)
	_extras.get_parent().move_child(node, _extras.get_index())


func _clear_top() -> void:
	if _queue != null and is_instance_valid(_queue):
		_queue.unbind()
	if _top != null and is_instance_valid(_top):
		_top.get_parent().remove_child(_top)
		_top.queue_free()
	_top = null
	_queue = null


func _redraw_extras() -> void:
	if _blueprints != null:
		_blueprints.redraw(_session)
	if _tool_panel != null:
		_tool_panel.redraw(_session)


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
