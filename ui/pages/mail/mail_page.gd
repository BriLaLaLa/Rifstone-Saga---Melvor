class_name MailPage
extends Page
## Mail page (docs/01_GDD_M27.md §39.4, docs/05_INTERFACES_M27.md §5.40 and §7.o), route `mail`: the messages of the Auction House,
## newest first, on the left; the opened message with its attachment on the right. Opening a message is `mark_read`; **Ritira**
## and **Ritira tutto** are the `collect` / `collect_all` commands; a refusal (`can_collect`) is shown next to the button in Italian.
## Everything is read from `session.mail` on every redraw (`mail_changed`, `bank_changed`); the page keeps only the id of the
## message opened (presentation, not saved) and references to its own nodes.

const MARGIN: int = 16
const SECTION_SEPARATION: int = 12
const LIST_SEPARATION: int = 6

var _session: GameSession = null
var _selected: int = 0
var _redraw_queued: bool = false

@onready var _margin: MarginContainer = %Margin
@onready var _content: VBoxContainer = %Content
@onready var _body: HBoxContainer = %Body
@onready var _title_label: Label = %TitleLabel
@onready var _count_label: Label = %CountLabel
@onready var _reason_all_label: Label = %ReasonAllLabel
@onready var _collect_all_button: Button = %CollectAllButton
@onready var _rows: VBoxContainer = %Rows
@onready var _empty_label: Label = %EmptyLabel
@onready var _message_box: VBoxContainer = %Message
@onready var _subject_label: Label = %SubjectLabel
@onready var _sender_label: Label = %SenderLabel
@onready var _body_label: Label = %BodyLabel
@onready var _attachment_title: Label = %AttachmentTitle
@onready var _money_label: MoneyLabel = %MoneyLabel
@onready var _items_box: VBoxContainer = %ItemsBox
@onready var _collect_button: Button = %CollectButton
@onready var _reason_label: Label = %ReasonLabel


func _ready() -> void:
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		_margin.add_theme_constant_override(side, MARGIN)
	_content.add_theme_constant_override("separation", SECTION_SEPARATION)
	_body.add_theme_constant_override("separation", SECTION_SEPARATION)
	_rows.add_theme_constant_override("separation", LIST_SEPARATION)
	_title_label.text = MailTexts.TITLE_TEXT
	_empty_label.text = MailTexts.SELECT_TEXT
	_attachment_title.text = MailTexts.ATTACHMENT_TITLE
	_collect_button.text = MailTexts.COLLECT_TEXT
	_collect_all_button.text = MailTexts.COLLECT_ALL_TEXT
	_collect_button.pressed.connect(_on_collect_pressed)
	_collect_all_button.pressed.connect(_on_collect_all_pressed)


func bind(session: GameSession) -> void:
	unbind()
	_session = session
	session.events.mail_changed.connect(_on_changed)
	session.events.bank_changed.connect(_on_changed)
	_rebuild()


func unbind() -> void:
	if _session != null and is_instance_valid(_session):
		for sig: Signal in [_session.events.mail_changed, _session.events.bank_changed]:
			if sig.is_connected(_on_changed):
				sig.disconnect(_on_changed)
	_session = null


func _exit_tree() -> void:
	unbind()


## Any change redraws once, at the end of the frame (never inside the signal of the button that caused it).
func _on_changed(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	if _redraw_queued:
		return
	_redraw_queued = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_redraw_queued = false
	if _session == null or not is_inside_tree():
		return
	var mail: MailBox = _session.mail
	var messages: Array[Dictionary] = mail.messages()
	_count_label.text = MailTexts.UNREAD_TEXT % [NumberFormat.format_int(mail.unread()), NumberFormat.format_int(mail.count())]
	if mail.get_message(_selected).is_empty():
		_selected = 0
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	if messages.is_empty():
		var empty := Label.new()
		empty.text = MailTexts.EMPTY_TEXT
		empty.theme_type_variation = &"MutedLabel"
		_rows.add_child(empty)
	for message: Dictionary in messages:
		var id: int = message["id"]
		var composed: Dictionary = MailTexts.compose(message, _session.data)
		var row := MailRow.new()
		row.name = "Row_%d" % id
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_rows.add_child(row)
		row.setup(id, composed["subject"], composed["sender"], not (message["read"] as bool), id == _selected)
		row.row_clicked.connect(_on_row_clicked)
	_redraw_collect_all(messages)
	_redraw_detail()


func _redraw_collect_all(messages: Array[Dictionary]) -> void:
	var any_ok: bool = false
	var reason: StringName = &""
	for message: Dictionary in messages:
		var result: CommandResult = _session.mail.can_collect(message["id"] as int)
		if result.ok:
			any_ok = true
		elif reason == &"":
			reason = result.reason
	_collect_all_button.disabled = not any_ok
	_reason_all_label.visible = not any_ok and reason != &""
	_reason_all_label.text = MailTexts.refused(reason) if reason != &"" else ""


func _redraw_detail() -> void:
	var message: Dictionary = _session.mail.get_message(_selected)
	_empty_label.visible = message.is_empty()
	_message_box.visible = not message.is_empty()
	if message.is_empty():
		return
	var composed: Dictionary = MailTexts.compose(message, _session.data)
	_subject_label.text = composed["subject"]
	_sender_label.text = MailTexts.FROM_TEXT % composed["sender"]
	_body_label.text = composed["body"]
	var money: int = message["money"]
	_money_label.visible = money > 0
	if money > 0:
		_money_label.set_amount(money, _session.data.currency())
	for child: Node in _items_box.get_children():
		_items_box.remove_child(child)
		child.queue_free()
	for entry: Dictionary in (message["items"] as Array):
		var line := Label.new()
		line.text = MailTexts.ITEM_LINE_TEXT % [MailTexts.item_name(entry["item"] as StringName, _session.data),
				NumberFormat.format_int(int(entry["qty"]))]
		_items_box.add_child(line)
	var result: CommandResult = _session.mail.can_collect(_selected)
	_collect_button.disabled = not result.ok
	_reason_label.visible = not result.ok
	_reason_label.text = "" if result.ok else MailTexts.refused(result.reason)


func _on_row_clicked(message_id: int) -> void:
	if _session == null:
		return
	_selected = message_id
	_session.mail.mark_read(message_id)
	_on_changed()


func _on_collect_pressed() -> void:
	if _session == null or _selected == 0:
		return
	var result: CommandResult = _session.mail.collect(_selected)
	if not result.ok:
		_reason_label.visible = true
		_reason_label.text = MailTexts.refused(result.reason)
	_on_changed()


func _on_collect_all_pressed() -> void:
	if _session == null:
		return
	_session.mail.collect_all()
	_on_changed()
