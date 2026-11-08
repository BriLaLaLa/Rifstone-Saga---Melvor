class_name HelperRow
extends HBoxContainer
## Helper row of a gathering skill page (docs/05_INTERFACES.md §7.w, docs/01_GDD.md §6.4): "Aiutante: <grado> — lavora:
## <risorsa>", the cycle bar, [Cambia] [Ferma] and [Assumi]; without a helper "Aiutante: nessuno"; "In attesa: Deposito
## pieno" while `helpers.is_blocked`.
##
## Every `redraw` reads the session (grade, action, interval, owned contracts, available resources); the bar is read from
## `helpers.get_progress` every frame, no time is computed here. The buttons only emit the requests: the page sends
## the commands (`helpers.set_action`, `stop`, `hire`) and shows a refusal. No game state: skill id and nodes.

signal change_requested(skill_id: StringName, action_id: StringName)
signal stop_requested(skill_id: StringName)
signal hire_requested(contract_item_id: StringName)

var _skill_id: StringName = &""
## Reference of the last `redraw`, read every frame for the bar; cleared by `unbind`.
var _session_ref: GameSession = null
var _label: Label = null
var _interval_label: Label = null
var _bar: ActionProgressBar = null
var _blocked_label: Label = null
var _change_button: Button = null
var _stop_button: Button = null
var _hire_button: Button = null
var _change_menu: PopupMenu = null
var _hire_menu: PopupMenu = null
var _change_ids: Array[StringName] = []
var _hire_ids: Array[StringName] = []


func _ready() -> void:
	name = "HelperRow"
	add_theme_constant_override("separation", UiStyle.HELPER_ROW_SEPARATION)
	_label = _add_label("HelperLabel")
	_bar = ActionProgressBar.new()
	_bar.name = "HelperBar"
	_bar.custom_minimum_size = Vector2(UiStyle.HELPER_BAR_WIDTH, 0)
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_bar)
	_interval_label = _add_label("IntervalLabel")
	_blocked_label = _add_label("BlockedLabel")
	_blocked_label.text = HelperTexts.BLOCKED_TEXT
	_blocked_label.add_theme_color_override("font_color", UiStyle.BAD)
	_change_button = _add_button("ChangeButton", HelperTexts.CHANGE_TEXT, _on_change_pressed)
	_stop_button = _add_button("StopButton", HelperTexts.STOP_TEXT, _on_stop_pressed)
	_hire_button = _add_button("HireButton", HelperTexts.HIRE_TEXT, _on_hire_pressed)
	_change_menu = _add_menu("ChangeMenu", _on_change_menu_id)
	_hire_menu = _add_menu("HireMenu", _on_hire_menu_id)
	set_process(false)


func setup(skill_id: StringName) -> void:
	_skill_id = skill_id


## Reads the helper of the skill from `session` and draws it.
func redraw(session: GameSession) -> void:
	_session_ref = session
	set_process(true)
	var grade: StringName = session.helpers.get_grade(_skill_id)
	var action_id: StringName = session.helpers.get_action(_skill_id)
	if grade == &"":
		_label.text = HelperTexts.NONE_TEXT
	else:
		_label.text = HelperTexts.HELPER_TEXT % HelperGradeNames.name_of(grade)
		if action_id == &"":
			_label.text += HelperTexts.IDLE_TEXT
		else:
			_label.text += HelperTexts.WORKING_TEXT % _resource_name(session, action_id)
	var working: bool = grade != &"" and action_id != &""
	_bar.visible = working
	_interval_label.visible = working
	if working:
		_interval_label.text = HelperTexts.INTERVAL_TEXT % NumberFormat.format_seconds(session.helpers.interval_ms(_skill_id))
	_blocked_label.visible = working and session.helpers.is_blocked(_skill_id)
	_change_button.visible = grade != &""
	_stop_button.visible = working
	_hire_button.visible = not _contracts(session).is_empty()


func unbind() -> void:
	_session_ref = null
	set_process(false)


func _process(_delta: float) -> void:
	if _session_ref != null:
		_bar.set_progress(_session_ref.helpers.get_progress(_skill_id))


## Name of the resource of an action: the name of its first product (never the name of the action).
func _resource_name(session: GameSession, action_id: StringName) -> String:
	var action: ActionDef = session.data.action(action_id)
	if action == null or action.outputs.is_empty():
		return String(action_id)
	var item: ItemDef = session.data.item(action.outputs[0].item_id)
	return item.name if item != null else action.name


## Contracts of this skill in the Deposit, in the bank's order.
func _contracts(session: GameSession) -> Array[StringName]:
	var ids: Array[StringName] = []
	for stack: Dictionary in session.bank.stacks():
		var item: ItemDef = session.data.item(stack["item"] as StringName)
		if item != null and item.is_contract() and item.contract_skill == _skill_id:
			ids.append(item.id)
	return ids


func _on_change_pressed() -> void:
	if _session_ref == null:
		return
	_change_menu.clear()
	_change_ids = _session_ref.helpers.available_actions(_skill_id)
	for index: int in _change_ids.size():
		_change_menu.add_item(_resource_name(_session_ref, _change_ids[index]), index)
	_popup_under(_change_menu, _change_button)


func _on_hire_pressed() -> void:
	if _session_ref == null:
		return
	_hire_menu.clear()
	_hire_ids = _contracts(_session_ref)
	for index: int in _hire_ids.size():
		_hire_menu.add_item(_session_ref.data.item(_hire_ids[index]).name, index)
	_popup_under(_hire_menu, _hire_button)


func _on_stop_pressed() -> void:
	stop_requested.emit(_skill_id)


func _on_change_menu_id(id: int) -> void:
	if id >= 0 and id < _change_ids.size():
		change_requested.emit(_skill_id, _change_ids[id])


func _on_hire_menu_id(id: int) -> void:
	if id >= 0 and id < _hire_ids.size():
		hire_requested.emit(_hire_ids[id])


func _popup_under(menu: PopupMenu, button: Control) -> void:
	if menu.item_count == 0:
		return
	menu.position = Vector2i(button.get_screen_position() + Vector2(0, button.size.y))
	menu.popup()


func _add_label(label_name: String) -> Label:
	var label: Label = Label.new()
	label.name = label_name
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(label)
	return label


func _add_button(button_name: String, text: String, on_pressed: Callable) -> Button:
	var button: Button = Button.new()
	button.name = button_name
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(on_pressed)
	add_child(button)
	return button


func _add_menu(menu_name: String, on_id: Callable) -> PopupMenu:
	var menu: PopupMenu = PopupMenu.new()
	menu.name = menu_name
	menu.id_pressed.connect(on_id)
	add_child(menu)
	return menu
