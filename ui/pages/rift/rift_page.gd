class_name RiftPage
extends Page
## Altar of the Rift page (docs/01_GDD.md §11, route `rift`), three columns in the order of the work: 1 pick a socket,
## 2 pick a rune of the Deposit, 3 see cost and result and confirm (or remove the rune, which destroys it, after a confirmation).
##
## Every redraw reads the session (`rift`, `bank`, `skills`, `data`). The page keeps the session reference, its nodes and
## three presentation choices (socket, rune, removal waiting for confirmation). Player actions are the commands
## `rift.socket` / `rift.clear_socket`; a refusal shows its reason in Italian and changes nothing.

var _session: GameSession = null
## Presentation state: the picked socket (-1 = none), the picked rune and the removal waiting for confirmation.
var _socket: int = -1
var _rune: StringName = &""
var _removing: bool = false

@onready var _margin: MarginContainer = %Margin
@onready var _title_label: Label = %TitleLabel
@onready var _intro_label: Label = %IntroLabel
@onready var _message_label: Label = %MessageLabel
@onready var _columns: HBoxContainer = %Columns
var _sockets_column: AltarSocketColumn = null
var _runes_column: AltarRuneColumn = null
var _confirm_column: AltarConfirmColumn = null


func _ready() -> void:
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		_margin.add_theme_constant_override(side, UiStyle.ARMORY_MARGIN)
	_title_label.text = RiftTexts.TITLE_TEXT
	_intro_label.text = RiftTexts.INTRO_TEXT
	_sockets_column = AltarSocketColumn.new()
	_runes_column = AltarRuneColumn.new()
	_confirm_column = AltarConfirmColumn.new()
	for column: AltarColumn in [_sockets_column, _runes_column, _confirm_column]:
		_columns.add_child(column)
	_sockets_column.socket_selected.connect(_on_socket_selected)
	_runes_column.rune_selected.connect(_on_rune_selected)
	_runes_column.craft_pressed.connect(_on_craft_runes_pressed)
	_confirm_column.socket_pressed.connect(_on_socket_confirmed)
	_confirm_column.remove_pressed.connect(_on_remove_pressed)
	_confirm_column.remove_confirmed.connect(_on_remove_confirmed)
	_confirm_column.remove_cancelled.connect(_on_remove_cancelled)


func bind(session: GameSession) -> void:
	unbind()
	_session = session
	HelpButton.attach(_title_label.get_parent(), session.data, &"rift", _title_label)
	_removing = false
	_rune = &""
	_socket = _next_free_socket()
	if _socket < 0 and session.rift.socket_total() > 0:
		_socket = 0
	_message_label.visible = false
	for sig: Signal in _signals(session.events):
		sig.connect(_redraw_from_event)
	_redraw()


func unbind() -> void:
	if _session != null and is_instance_valid(_session):
		for sig: Signal in _signals(_session.events):
			if sig.is_connected(_redraw_from_event):
				sig.disconnect(_redraw_from_event)
	_session = null


func _exit_tree() -> void:
	unbind()


func _signals(events: GameEvents) -> Array[Signal]:
	return [events.infusion_socketed, events.infusion_removed, events.bank_changed, events.level_up,
			events.discipline_changed, events.skill_reset]


func _redraw_from_event(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	_redraw()


func _redraw() -> void:
	if _session == null:
		return
	_intro_label.text = RiftTexts.INTRO_TEXT if _session.disciplines.is_learned(RiftAltar.SKILL) \
			else "%s\n%s" % [RiftTexts.INTRO_TEXT, RiftTexts.NOT_LEARNED_TEXT]
	_normalize()
	_sockets_column.refresh(_session, _socket)
	_runes_column.refresh(_session, _rune if _socket_is_free() else &"")
	_confirm_column.refresh(_session, _socket, _rune, _removing)


## Keeps the choices valid after the model changed: a rune no longer owned or no longer usable is dropped, and for a free
## socket the first usable rune is picked so the result is already on screen.
func _normalize() -> void:
	if _socket >= _session.rift.socket_total():
		_socket = -1
	if _removing and _session.rift.get_socket(_socket) == &"":
		_removing = false
	var usable: StringName = &""
	var keep: bool = false
	for entry: Dictionary in RiftTexts.owned(_session, &"infusion"):
		var id: StringName = (entry["item"] as ItemDef).id
		if RiftTexts.rune_block_reason(_session, id) != "":
			continue
		if usable == &"":
			usable = id
		if id == _rune:
			keep = true
	_rune = _rune if keep else usable


func _socket_is_free() -> bool:
	return _socket >= 0 and _session.rift.is_unlocked(_socket) and _session.rift.get_socket(_socket) == &""


func _next_free_socket() -> int:
	for i: int in _session.rift.socket_total():
		if _session.rift.is_unlocked(i) and _session.rift.get_socket(i) == &"":
			return i
	return -1


## Opens the Riftbinding skill page through the host (route `skill:riftbinding`), or the Trainers if it is not learned.
func _on_craft_runes_pressed() -> void:
	var node: Node = get_parent()
	while node != null and not node is PageHost:
		node = node.get_parent()
	if node == null:
		return
	if _session != null and not _session.disciplines.is_learned(RiftAltar.SKILL):
		(node as PageHost).show_page(&"trainers")
		return
	(node as PageHost).show_page(StringName("%s%s%s" % [PageHost.ROUTE_SKILL, PageHost.ROUTE_SEPARATOR,
			RiftAltar.SKILL]))


# --- Commands ---------------------------------------------------------------------------------------------------

func _on_socket_selected(index: int) -> void:
	_socket = index
	_removing = false
	_message_label.visible = false
	_redraw()


func _on_rune_selected(item_id: StringName) -> void:
	_rune = item_id
	_redraw()


func _on_socket_confirmed() -> void:
	if _session == null or _socket < 0 or _rune == &"":
		return
	var result: CommandResult = _session.rift.socket(_socket, _rune)
	if result.ok:
		_notify(RiftTexts.SOCKETED_TEXT % _session.data.item(_rune).name, true)
		var next: int = _next_free_socket()
		if next >= 0:
			_socket = next
	else:
		_notify(RiftTexts.refused(result.reason), false)
	_redraw()


func _on_remove_pressed() -> void:
	_removing = true
	_message_label.visible = false
	_redraw()


func _on_remove_cancelled() -> void:
	_removing = false
	_redraw()


func _on_remove_confirmed() -> void:
	if _session == null or _socket < 0:
		return
	var item_id: StringName = _session.rift.get_socket(_socket)
	_removing = false
	var result: CommandResult = _session.rift.clear_socket(_socket)
	if result.ok:
		_notify(RiftTexts.REMOVED_TEXT % _session.data.item(item_id).name, true)
	else:
		_notify(RiftTexts.refused(result.reason), false)
	_redraw()


func _notify(text: String, good: bool) -> void:
	_message_label.text = text
	_message_label.add_theme_color_override("font_color", UiStyle.GOOD if good else UiStyle.BAD)
	_message_label.visible = true
