class_name ToolUpgradePanel
extends PanelContainer
## Refinement panel of the unique tool of a gathering skill (docs/01_GDD.md §23.1, F-94; docs/05_INTERFACES.md §7.x):
## the tool with its "+N", the cost of the next step ("owned / required") and the minimum level of the craft read from
## `armory.tool_next_step`, the current effects from `modifiers.breakdown` in the skill context, and the button that
## asks for the refinement.
##
## Internal to SkillPage of the gathering skills. `setup(skill_id)` says which tool slot (`tool_<skill>`) it follows;
## `redraw` rereads everything from the session. No game state: only the skill id and the uid of the last redraw.
## The button emits `upgrade_requested`; the page sends
## `armory.upgrade_tool` and shows the refusal.

signal upgrade_requested(uid: int)

const SOURCE_PREFIX: String = "equipment:"
const LABEL_NAME_FMT: String = "Line_%d"

var _skill_id: StringName = &""
## Uid of the tool drawn by the last redraw (0 if none): what the button sends.
var _uid: int = 0

@onready var _title: Label = %PanelTitle
@onready var _name_label: Label = %ToolName
@onready var _next_label: Label = %NextTitle
@onready var _cost: VBoxContainer = %CostLines
@onready var _level_label: Label = %MinLevelLabel
@onready var _effects: VBoxContainer = %EffectLines
@onready var _upgrade_button: Button = %UpgradeButton


func _ready() -> void:
	_title.text = ToolUpgradeTexts.TITLE
	_upgrade_button.text = ToolUpgradeTexts.UPGRADE_TEXT
	_upgrade_button.pressed.connect(_on_upgrade_pressed)


## The skill whose tool this panel follows (`forestry`, `quarrying`, `angling`).
func setup(skill_id: StringName) -> void:
	_skill_id = skill_id


## Rereads the tool, the next step and the effects.
func redraw(session: GameSession) -> void:
	_uid = session.armory.tool_uid(StringName("%s%s" % [ToolUpgrade.SLOT_PREFIX, _skill_id]))
	var inst: ItemInstance = session.armory.get_instance(_uid) if _uid != 0 else null
	_clear(_cost)
	_clear(_effects)
	if inst == null:
		_name_label.text = ToolUpgradeTexts.NO_TOOL_TEXT
		_next_label.visible = false
		_level_label.visible = false
		_upgrade_button.visible = false
		return
	var base: ItemDef = session.data.item(inst.base_id)
	_name_label.text = ArmoryTexts.piece_name(inst, base)
	_name_label.add_theme_color_override("font_color", UiStyle.rarity_color(inst.rarity))
	_redraw_next(session, inst)
	_redraw_effects(session)


func _redraw_next(session: GameSession, inst: ItemInstance) -> void:
	var step: Dictionary = session.armory.tool_next_step(_uid)
	_upgrade_button.visible = not step.is_empty()
	_level_label.visible = not step.is_empty()
	_next_label.visible = true
	if step.is_empty():
		_next_label.text = ToolUpgradeTexts.MAX_TEXT
		return
	_next_label.text = ToolUpgradeTexts.NEXT_TITLE % [inst.upgrade, int(step["target"])]
	var plates: ItemQty = step["plates"]
	var handles: ItemQty = step["handles"]
	_add_line(_cost, _cost_line(session, plates.item_id, plates.qty), session.bank.get_count(plates.item_id) >= plates.qty)
	_add_line(_cost, _cost_line(session, handles.item_id, handles.qty),
			session.bank.get_count(handles.item_id) >= handles.qty)
	var gold: int = int(step["gold"])
	if gold > 0:
		_add_line(_cost, ToolUpgradeTexts.COST_LINE % [ToolUpgradeTexts.GOLD_NAME, NumberFormat.format_int(
				session.wallet.get_gold()), NumberFormat.format_int(gold)], session.wallet.get_gold() >= gold)
	var min_level: int = int(step["min_level"])
	_level_label.text = ToolUpgradeTexts.MIN_LEVEL_TEXT % NumberFormat.format_int(min_level)
	_level_label.add_theme_color_override("font_color",
			UiStyle.GOOD if session.skills.get_level(_skill_id) >= min_level else UiStyle.BAD)


## Current effects of the tool: the sources `equipment:tool_<skill>` of every registry stat in the skill context.
func _redraw_effects(session: GameSession) -> void:
	var source: StringName = StringName("%s%s%s" % [SOURCE_PREFIX, ToolUpgrade.SLOT_PREFIX, _skill_id])
	var ctx: ModifierContext = ModifierContext.for_skill(_skill_id)
	var shown: bool = false
	for stat: StringName in session.data.stats.ids():
		for entry: Dictionary in session.modifiers.breakdown(stat, ctx):
			if entry["source"] != source:
				continue
			var info: Dictionary = session.data.stats.info(stat)
			_add_line(_effects, "%s: %s" % [info["name"], ItemTooltipLines.format_stat(info["format"] as String,
					float(entry["value"]))], true)
			shown = true
	if not shown:
		_add_line(_effects, ToolUpgradeTexts.NO_EFFECT_TEXT, true)


func _cost_line(session: GameSession, item_id: StringName, required: int) -> String:
	var def: ItemDef = session.data.item(item_id) if session.data.has_item(item_id) else null
	return ToolUpgradeTexts.COST_LINE % [def.name if def != null else String(item_id),
			NumberFormat.format_int(session.bank.get_count(item_id)), NumberFormat.format_int(required)]


func _add_line(box: VBoxContainer, text: String, good: bool) -> void:
	var line: Label = Label.new()
	line.name = LABEL_NAME_FMT % box.get_child_count()
	line.text = text
	line.add_theme_color_override("font_color", UiStyle.TEXT if good else UiStyle.BAD)
	box.add_child(line)


func _clear(box: VBoxContainer) -> void:
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()


func _on_upgrade_pressed() -> void:
	if _uid != 0:
		upgrade_requested.emit(_uid)
