class_name NodeCard
extends PanelContainer
## Card of the node being worked, in the Combat page in place of the enemy zone (docs/01_GDD_M25.md §36.5,
## 05_INTERFACES_M25.md §7.p): a scene drawn by code, big animated art in the middle, big title with the "Ricco" badge,
## wide attempt pips and time bar, big loot number that rises with a small tween on every attempt, XP of the last
## attempt; a locked form (big grey icon of the discipline and the reason) for a skipped node.
## `refresh(state, data)` reads `combat.get_state()["node"]` every frame: it computes no time and no yield.

const POP_SCALE: float = 1.25
const POP_SECONDS: float = 0.25
const COUNT_SECONDS: float = 0.4
const PIP_HEIGHT: float = 18.0
const BAR_HEIGHT: float = 26.0
const BOX_SEPARATION: int = 10
const MARGIN: float = 24.0
const ART_HEIGHT_SHARE: float = 0.42  ## of the card height
const LOCKED_ICON_SIDE: float = 160.0
const TITLE_SIZE: int = 30
const RICH_SIZE: int = 28
const LOOT_SIZE: int = 40
const LOCKED_SIZE: int = 30

var _backdrop: NodeBackdrop = null
var _box: VBoxContainer = null
var _art: NodeArt = null
var _title: Label = null
var _rich: Label = null
var _locked_icon: TextureRect = null
var _pips: HBoxContainer = null
var _bar: ProgressBar = null
var _loot: VBoxContainer = null
var _loot_title: Label = null
var _loot_row: Label = null
var _xp: Label = null
var _locked: Label = null
var _pip_count: int = -1
var _shown_units: int = 0  ## the number on screen while the tween runs (presentation only)
var _count_tween: Tween = null


func _ready() -> void:
	add_theme_stylebox_override("panel", UiStyle.flat(Color.TRANSPARENT, UiStyle.COMBAT_ENEMY_BORDER,
			UiStyle.COMBAT_FRAME_WIDTH, 0.0))
	clip_contents = true
	_backdrop = NodeBackdrop.new()
	_backdrop.name = "NodeBackdrop"
	add_child(_backdrop)
	_box = VBoxContainer.new()
	_box.name = "NodeBox"
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", BOX_SEPARATION)
	var margin := MarginContainer.new()
	margin.name = "NodeMargin"
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, int(MARGIN))
	margin.add_child(_box)
	add_child(margin)
	_title = _add_label(_box, "NodeTitle", &"TitleLabel", TITLE_SIZE)
	_rich = _add_label(_box, "RichBadge", &"", RICH_SIZE)
	_rich.text = NodeCardTexts.RICH_TEXT
	_rich.add_theme_color_override("font_color", UiStyle.GOLD_LIGHT)
	_art = NodeArt.new()
	_art.name = "NodeArt"
	_art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_box.add_child(_art)
	_locked_icon = TextureRect.new()
	_locked_icon.name = "LockedIcon"
	_locked_icon.custom_minimum_size = Vector2(LOCKED_ICON_SIDE, LOCKED_ICON_SIDE)
	_locked_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_locked_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_locked_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_locked_icon.modulate = UiStyle.TEXT_DISABLED
	_box.add_child(_locked_icon)
	_pips = HBoxContainer.new()
	_pips.name = "AttemptsRow"
	_pips.add_theme_constant_override("separation", 6)
	_box.add_child(_pips)
	_bar = ProgressBar.new()
	_bar.name = "TimeBar"
	_bar.max_value = 1.0
	_bar.step = 0.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	_box.add_child(_bar)
	_loot_title = _add_label(_box, "LootTitle", &"MutedLabel", 0)
	_loot_title.text = NodeCardTexts.LOOT_TITLE_TEXT
	_loot = VBoxContainer.new()
	_loot.name = "LootList"
	_box.add_child(_loot)
	_xp = _add_label(_box, "XpLabel", &"MutedLabel", 0)
	_locked = _add_label(_box, "LockedLabel", &"", LOCKED_SIZE)
	_locked.add_theme_color_override("font_color", UiStyle.BAD)
	_locked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	visible = false
	resized.connect(_fit_art)


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
	for control: Control in [_art, _pips, _loot_title, _loot, _xp]:
		control.visible = not skipped
	_rich.visible = not skipped and bool(node.get("rich", false))
	_locked.visible = skipped
	_locked_icon.visible = skipped
	var duration: int = int(node.get("duration_ms", 0))
	_bar.value = clampf(float(int(node.get("elapsed_ms", 0))) / float(duration), 0.0, 1.0) if duration > 0 else 0.0
	_bar.visible = not skipped
	if skipped:
		_locked.text = _locked_text(StringName(node.get("skip_reason", &"")))
		_locked_icon.texture = ItemSlotView.icon_of(skill.icon) if skill != null else UiStyle.icon("missing")
		_backdrop.set_tint(Color.TRANSPARENT)
		return
	_fit_art()
	_art.set_skill(skill_id)
	var action: ActionDef = data.action(StringName(node.get("action", &"")))
	var action_name: String = action.name if action != null else ""
	var color_id: StringName = CombatTexts.color_id(node.get("color"))
	var tint: Color = CombatTexts.NODE_COLORS.get(color_id, UiStyle.TEXT)
	_art.set_tint(tint)
	_backdrop.set_tint(tint)
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


## The art takes a share of the card height (the zoom keeps the sprite proportional to the area).
func _fit_art() -> void:
	if _art == null or size.y <= 0.0:
		return
	_art.set_zoom(maxf(1.0, size.y * ART_HEIGHT_SHARE / NodeArt.ART_SIZE.y))

func _refresh_pips(attempts: int, done: int) -> void:
	if attempts != _pip_count:
		for child: Node in _pips.get_children():
			_pips.remove_child(child)
			child.queue_free()
		for i: int in range(1, attempts + 1):
			var new_pip := ColorRect.new()
			new_pip.name = "AttemptPip_%d" % i
			new_pip.custom_minimum_size = Vector2(0, PIP_HEIGHT)
			new_pip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
		_loot_row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_loot_row.add_theme_font_size_override("font_size", LOOT_SIZE)
		_loot_row.add_theme_color_override("font_color", UiStyle.GOLD_LIGHT)
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


func _add_label(parent: Node, node_name: String, variation: StringName, font_size: int) -> Label:
	var label := Label.new()
	label.name = node_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if variation != &"":
		label.theme_type_variation = variation
	if font_size > 0:
		label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label
