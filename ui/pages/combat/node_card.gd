class_name NodeCard
extends PanelContainer
## Card of the node being worked, in the Combat page in place of the target box (docs/01_GDD_M25.md §36.5,
## 05_INTERFACES_M25.md §7.p): animated art, resource, colour, "Ricco" badge, attempt pips, time bar, loot numbers
## that rise with a small tween on every attempt, XP of the last attempt; a locked form for a skipped node.
## `refresh(state, data)` reads `combat.get_state()["node"]` every frame: it computes no time and no yield.

const POP_SCALE: float = 1.25
const POP_SECONDS: float = 0.25
const COUNT_SECONDS: float = 0.4
const PIP_SIZE: Vector2 = Vector2(22, 10)
const BODY_SEPARATION: int = 12

var _art: NodeArt = null
var _title: Label = null
var _resource: Label = null
var _color: Label = null
var _rich: Label = null
var _pips: HBoxContainer = null
var _bar: ProgressBar = null
var _loot_title: Label = null
var _loot: VBoxContainer = null
var _loot_row: Label = null
var _xp: Label = null
var _locked: Label = null
var _pip_count: int = -1
var _shown_units: int = 0  ## the number on screen while the tween runs (presentation only)
var _count_tween: Tween = null


func _ready() -> void:
	theme_type_variation = &"HudPanel"
	var box := VBoxContainer.new()
	box.name = "NodeBox"
	add_child(box)
	_title = _add_label(box, "NodeTitle", &"HeaderLabel")
	var body := HBoxContainer.new()  # art on the left, numbers on the right: keeps the card short at 1280x720
	body.name = "NodeBody"
	body.add_theme_constant_override("separation", BODY_SEPARATION)
	box.add_child(body)
	_art = NodeArt.new()
	_art.name = "NodeArt"
	_art.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	body.add_child(_art)
	var info := VBoxContainer.new()
	info.name = "NodeInfo"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(info)
	_resource = _add_label(info, "ResourceLabel", &"")
	_color = _add_label(info, "ColorLabel", &"")
	_rich = _add_label(info, "RichBadge", &"")
	_rich.text = NodeCardTexts.RICH_TEXT
	_rich.add_theme_color_override("font_color", UiStyle.GOLD_LIGHT)
	_pips = HBoxContainer.new()
	_pips.name = "AttemptsRow"
	info.add_child(_pips)
	_loot_title = _add_label(info, "LootTitle", &"MutedLabel")
	_loot_title.text = NodeCardTexts.LOOT_TITLE_TEXT
	_loot = VBoxContainer.new()
	_loot.name = "LootList"
	info.add_child(_loot)
	_xp = _add_label(info, "XpLabel", &"MutedLabel")
	_bar = ProgressBar.new()
	_bar.name = "TimeBar"
	_bar.max_value = 1.0
	_bar.step = 0.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, UiStyle.COMBAT_BAR_HEIGHT)
	box.add_child(_bar)
	_locked = _add_label(box, "LockedLabel", &"")
	_locked.add_theme_color_override("font_color", UiStyle.BAD)
	_locked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	visible = false


## Redraws from `state` (`CombatEngine.get_state()`); hidden outside the `node` state.
func refresh(state: Dictionary, data: GameData) -> void:
	var node: Dictionary = state.get("node", {}) as Dictionary
	visible = state.get("state", &"") == CombatTexts.STATE_NODE and not node.is_empty()
	if not visible:
		return
	var skill_id: StringName = StringName(node.get("skill", &""))
	var skill: SkillDef = data.skill(skill_id)
	_title.text = NodeCardTexts.TITLE_TEXT % (skill.name if skill != null else "")
	var skipped: bool = bool(node.get("skipped", false))
	for control: Control in [_art, _resource, _color, _pips, _loot_title, _loot, _xp]:
		control.visible = not skipped
	_rich.visible = not skipped and bool(node.get("rich", false))
	_locked.visible = skipped
	var duration: int = int(node.get("duration_ms", 0))
	_bar.value = clampf(float(int(node.get("elapsed_ms", 0))) / float(duration), 0.0, 1.0) if duration > 0 else 0.0
	if skipped:
		_locked.text = _locked_text(StringName(node.get("skip_reason", &"")))
		return
	_art.set_skill(skill_id)
	var action: ActionDef = data.action(StringName(node.get("action", &"")))
	var action_name: String = action.name if action != null else ""
	_resource.text = NodeCardTexts.RESOURCE_TEXT % action_name
	var color_id: StringName = CombatTexts.color_id(node.get("color"))
	_color.text = CombatTexts.NODE_COLOR_TEXT % CombatTexts.NODE_COLOR_NAMES.get(color_id, CombatTexts.NODE_COLOR_UNKNOWN_TEXT)
	var tint: Color = CombatTexts.NODE_COLORS.get(color_id, UiStyle.TEXT)
	_color.add_theme_color_override("font_color", tint)
	_art.set_tint(tint)
	_refresh_pips(int(node.get("attempts", 0)), int(node.get("attempt", 0)))
	_refresh_loot(action_name, int(node.get("units", 0)))
	var last: Dictionary = node.get("last_attempt", {}) as Dictionary
	if last.is_empty():
		_xp.text = NodeCardTexts.XP_NONE_TEXT
	else:
		_xp.text = NodeCardTexts.XP_TEXT % NumberFormat.format_int(int(last.get("xp", 0)))


## Small effect on `node_attempt_done`: the loot row pops; the numbers themselves come from `get_state()`.
func on_attempt_done(_skill_id: StringName, _action_id: StringName, _attempt: int, _attempts: int, _units: int,
		_total_units: int, _color_id: StringName) -> void:
	if CombatFx.reduced() or not is_inside_tree() or _loot_row == null:
		return
	_loot_row.pivot_offset = _loot_row.size * 0.5
	var tween: Tween = create_tween()
	tween.tween_property(_loot_row, "scale", Vector2(POP_SCALE, POP_SCALE), POP_SECONDS * 0.5)
	tween.tween_property(_loot_row, "scale", Vector2.ONE, POP_SECONDS * 0.5)


func _refresh_pips(attempts: int, done: int) -> void:
	if attempts != _pip_count:
		for child: Node in _pips.get_children():
			_pips.remove_child(child)
			child.queue_free()
		for i: int in range(1, attempts + 1):
			var new_pip := ColorRect.new()
			new_pip.name = "AttemptPip_%d" % i
			new_pip.custom_minimum_size = PIP_SIZE
			_pips.add_child(new_pip)
		_pip_count = attempts
	for i: int in range(1, attempts + 1):
		var pip: ColorRect = _pips.get_node("AttemptPip_%d" % i) as ColorRect
		if i <= done:
			pip.color = UiStyle.GOOD
		elif i == done + 1:
			pip.color = UiStyle.GOLD_LIGHT
		else:
			pip.color = UiStyle.GOLD_FAINT


func _refresh_loot(item_name: String, units: int) -> void:
	if _loot_row == null:
		_loot_row = Label.new()
		_loot_row.name = "LootRow"
		_loot.add_child(_loot_row)
	if units == _shown_units and _loot_row.text != "":
		return
	if _count_tween != null:
		_count_tween.kill()
	if units <= _shown_units or CombatFx.reduced() or not is_inside_tree():  # new node or no motion: no count up
		_shown_units = units
		_loot_row.text = "%s: %s" % [item_name, NumberFormat.format_int(units)]
		return
	var from: int = _shown_units
	_shown_units = units
	_count_tween = create_tween()
	_count_tween.tween_method(func(v: float) -> void:
		_loot_row.text = "%s: %s" % [item_name, NumberFormat.format_int(roundi(v))], float(from), float(units), COUNT_SECONDS)


func _locked_text(reason: StringName) -> String:
	match reason:
		Reasons.NOT_LEARNED:
			return NodeCardTexts.LOCKED_NOT_LEARNED_TEXT
		Reasons.TOO_HARD:
			return NodeCardTexts.LOCKED_TOO_HARD_TEXT
	return NodeCardTexts.LOCKED_TEXT


func _add_label(parent: Node, node_name: String, variation: StringName) -> Label:
	var label := Label.new()
	label.name = node_name
	if variation != &"":
		label.theme_type_variation = variation
	parent.add_child(label)
	return label
