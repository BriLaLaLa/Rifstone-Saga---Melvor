class_name HeadSection
extends VBoxContainer
## "Teste" section of the ToolUpgradePanel (docs/01_GDD_M35.md §42.2, docs/05_INTERFACES_M35.md §7.ac): one row per head step
## (`ToolUpgrade.head_steps`, +3/+6/+9) with the two heads of the tool as buttons, the cost of choosing ("gratis" the first time,
## `armory.tool_head_cost` for a change) and a warning while a reached step has no head. Everything is read from the session at each
## `redraw`; the only state is the head awaiting its confirmation (a change that costs gold needs a second press) and the last uid.
## A press emits `head_chosen`; the page sends `armory.choose_tool_head` and shows the refusal.
## Nodes: HeadRow_<step>, HeadButton_<step>_<head_id>, HeadWarning.

signal head_chosen(uid: int, step: int, head_id: StringName)

const ROW_NAME_FMT: String = "HeadRow_%d"
const BUTTON_NAME_FMT: String = "HeadButton_%d_%s"
const BUTTON_MIN_SIZE: Vector2 = Vector2(0, 52)

var _uid: int = 0
var _session: GameSession = null
## "<step>:<head_id>" of the paid change waiting for its second press; "" if none.
var _armed: String = ""
var _title: Label = null
var _warning: Label = null
var _rows: VBoxContainer = null


func _init() -> void:
	name = "HeadSection"
	add_theme_constant_override("separation", 4)
	_title = Label.new()
	_title.name = "HeadTitle"
	_title.theme_type_variation = &"HeaderLabel"
	_title.text = ResourceTexts.HEADS_TITLE
	add_child(_title)
	_warning = Label.new()
	_warning.name = "HeadWarning"
	_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warning.add_theme_color_override("font_color", UiStyle.GOLD)
	add_child(_warning)
	_rows = VBoxContainer.new()
	_rows.name = "HeadRows"
	_rows.add_theme_constant_override("separation", 4)
	add_child(_rows)


## Rereads the tool `uid` (0 = none: the section hides).
func redraw(session: GameSession, uid: int) -> void:
	if uid != _uid:
		_armed = ""
	_uid = uid
	_session = session
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var inst: ItemInstance = session.armory.get_instance(uid) if uid != 0 else null
	var def: ItemDef = session.data.item(inst.base_id) if inst != null else null
	var steps: Array[int] = ToolUpgrade.head_steps(session.data)
	var heads: Array[StringName] = session.armory.tool_heads(uid)
	visible = def != null and def.equip != null and def.equip.heads.size() > 0 and heads.size() == steps.size()
	if not visible:
		return
	var missing: bool = false
	for i: int in steps.size():
		if inst.upgrade >= steps[i] and heads[i] == &"":
			missing = true
		_rows.add_child(_build_row(session, def, inst, steps[i], heads[i]))
	var next_head: int = int(session.armory.tool_next_step(uid).get("head_step", 0))
	_warning.visible = missing or next_head > 0
	_warning.text = ResourceTexts.HEAD_CHOOSE_WARNING if missing else ResourceTexts.HEAD_NEXT_WARNING


func _build_row(session: GameSession, def: ItemDef, inst: ItemInstance, step: int, chosen: StringName) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = ROW_NAME_FMT % step
	row.add_theme_constant_override("separation", 6)
	var step_label: Label = Label.new()
	step_label.text = ResourceTexts.HEAD_STEP_TEXT % step
	step_label.custom_minimum_size.x = 36
	row.add_child(step_label)
	var locked: bool = inst.upgrade < step
	var index: int = ToolUpgrade.head_steps(session.data).find(step)
	for head: ToolHead in def.equip.heads:
		var button: Button = Button.new()
		button.name = BUTTON_NAME_FMT % [step, head.id]
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = BUTTON_MIN_SIZE
		button.clip_text = true
		button.tooltip_text = head.description
		var effect: String = _effect_text(session, head, index)
		var cost: int = session.armory.tool_head_cost(inst.uid, step)
		var armed: bool = _armed == "%d:%s" % [step, head.id]
		button.text = ResourceTexts.HEAD_BUTTON_FMT % [head.name, effect]
		if head.id == chosen:
			button.add_theme_color_override("font_color", UiStyle.GOLD)
			button.add_theme_stylebox_override("normal", button.get_theme_stylebox("pressed"))
		button.disabled = locked
		if armed:
			button.text = ResourceTexts.HEAD_BUTTON_FMT % [head.name, ResourceTexts.HEAD_CONFIRM_TEXT % Money.text(cost, session.data.currency())]
		button.pressed.connect(_on_head_pressed.bind(step, head.id, cost))
		row.add_child(button)
	var info: Label = Label.new()
	info.name = "HeadInfo"
	info.theme_type_variation = &"MutedLabel"
	info.custom_minimum_size.x = 110
	if locked:
		info.text = ResourceTexts.HEAD_LOCKED_TEXT % step
	elif chosen == &"":
		info.text = ResourceTexts.HEAD_FREE_TEXT
	else:
		info.text = ResourceTexts.HEAD_CHANGE_TEXT % Money.text(session.armory.tool_head_cost(inst.uid, step), session.data.currency())
	row.add_child(info)
	return row


## The effect of the head at its step `index`, worded from the registry of stats (the values are the ones of the data).
func _effect_text(session: GameSession, head: ToolHead, index: int) -> String:
	var parts: PackedStringArray = PackedStringArray()
	if index >= 0 and index < head.steps.size():
		for modifier: Modifier in head.steps[index] as Array[Modifier]:
			var info: Dictionary = session.data.stats.info(modifier.stat)
			parts.append("%s %s" % [ItemTooltipLines.format_stat(info["format"] as String, modifier.value), info["name"]])
	return ", ".join(parts)


## A press: a free choice goes out at once; a paid change arms the button first (second press confirms).
func _on_head_pressed(step: int, head_id: StringName, cost: int) -> void:
	if _uid == 0 or _session == null:
		return
	var key: String = "%d:%s" % [step, head_id]
	if cost > 0 and _armed != key:
		_armed = key
		redraw(_session, _uid)
		return
	_armed = ""
	head_chosen.emit(_uid, step, head_id)
