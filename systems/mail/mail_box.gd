class_name MailBox
extends RefCounted
## The Mail (docs/02_FORMULAS_M27.md F-183, docs/05_INTERFACES_M27.md §5.40): the messages of the Auction House with their
## attachment (money or items). Nothing reaches the wallet or the bank until the player collects it (`collect`).
##
## `post` always delivers (the capacity is checked by the commands that create mail, through `is_full`); sales of the same listing
## (`auction_sold`) or of the same item (`auction_sale`) merge into one message. `mail_changed(unread, total)` follows every change
## except `new_game` and `from_save`.

const SAVE_KEY: StringName = &"mail"
const LOG_CATEGORY: String = "mail"
const CAPACITY_KEY: String = "mail.capacity"
const KINDS: Array[StringName] = [&"auction_sold", &"auction_sale", &"auction_expired", &"auction_cancelled", &"tutorial_gift", &"starter_reward"]  # M30-02: the last two never merge

var _session: GameSession
var _events: GameEvents
var _next_id: int = 1
var _messages: Array[Dictionary] = []  # id ascending
var _collected: int = 0  # messages collected in the whole game (M30-02), saved as `collected`


func _init(session: GameSession) -> void:
	assert(session != null, "MailBox needs a session")
	_session = session
	_events = session.events


## Copies, newest first (`id` descending).
func messages() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i: int in range(_messages.size() - 1, -1, -1):
		result.append(_copy(_messages[i]))
	return result


## A copy of the message; `{}` if there is none.
func get_message(message_id: int) -> Dictionary:
	var index: int = _index_of(message_id)
	return _copy(_messages[index]) if index >= 0 else {}


func count() -> int:
	return _messages.size()


func unread() -> int:
	var n: int = 0
	for m: Dictionary in _messages:
		if not (m["read"] as bool):
			n += 1
	return n


func capacity() -> int:
	return int(_session.data.balance_value(CAPACITY_KEY))


## M30-02: how many messages the player has collected (`collect`, `collect_all`) in the whole game.
func collected_total() -> int:
	return _collected


func is_full() -> bool:
	return count() >= capacity()


## F-183 delivery: `fields` = {"item", "qty", "price"?, "listing"?, "money"? | "items"?}. Merges when the rules allow it and returns the
## id of the message; an unknown kind, a negative `money` or `money` together with `items` is an error (0, nothing delivered).
func post(kind: StringName, fields: Dictionary) -> int:
	var money: int = int(fields.get("money", 0))
	var items: Array[Dictionary] = []
	items.assign(fields.get("items", []) as Array)
	if not KINDS.has(kind) or money < 0 or (money > 0 and not items.is_empty()):
		push_error("MailBox.post: invalid message '%s' %s" % [kind, fields])
		return 0
	var merge_into: int = _merge_target(kind, fields) if items.is_empty() else -1
	var message_id: int
	if merge_into >= 0:
		var m: Dictionary = _messages[merge_into]
		m["money"] = int(m["money"]) + money
		m["qty"] = int(m["qty"]) + int(fields.get("qty", 0))
		m["read"] = false
		message_id = int(m["id"])
	else:
		message_id = _next_id
		_next_id += 1
		_messages.append({"id": message_id, "kind": kind, "item": StringName(fields.get("item", &"")), "qty": int(fields.get("qty", 0)),
				"price": int(fields.get("price", 0)), "listing": int(fields.get("listing", 0)), "money": money,
				"items": _copy_items(items), "read": false})
	_notify()
	return message_id


func mark_read(message_id: int) -> CommandResult:
	var index: int = _index_of(message_id)
	if index < 0:
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	if not (_messages[index]["read"] as bool):
		_messages[index]["read"] = true
		_notify()
	return CommandResult.success()


func can_collect(message_id: int) -> CommandResult:
	var index: int = _index_of(message_id)
	if index < 0:
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	var new_types: int = 0
	var seen: Dictionary[StringName, bool] = {}
	for entry: Dictionary in (_messages[index]["items"] as Array[Dictionary]):
		var item_id: StringName = entry["item"]
		if not _session.bank.can_add(item_id):
			return CommandResult.fail(Reasons.BANK_FULL)
		if not seen.has(item_id) and _session.bank.get_count(item_id) == 0:
			new_types += 1
		seen[item_id] = true
	if new_types > 0 and not _session.deposit.has_room(new_types):
		return CommandResult.fail(Reasons.BANK_FULL)
	return CommandResult.success()


## Money to the wallet, items to the bank, then the message goes away; `bank_full` leaves everything as it was.
func collect(message_id: int) -> CommandResult:
	var result: CommandResult = _collect(message_id)
	if result.ok:
		_notify()
	return result


## F-183: every collectable message, oldest first; returns how many were collected (one `mail_changed` for all).
func collect_all() -> int:
	var ids: Array[int] = []
	for m: Dictionary in _messages:
		ids.append(int(m["id"]))
	var collected: int = 0
	for message_id: int in ids:
		if _collect(message_id).ok:
			collected += 1
	if collected > 0:
		_notify()
	return collected


func new_game() -> void:
	_messages.clear()
	_next_id = 1
	_collected = 0


func to_save() -> Dictionary:
	var list: Array[Dictionary] = []
	for m: Dictionary in _messages:
		var saved: Dictionary = _copy(m)
		saved["kind"] = String(m["kind"])
		saved["item"] = String(m["item"])
		for entry: Dictionary in (saved["items"] as Array[Dictionary]):
			entry["item"] = String(entry["item"])
		list.append(saved)
	return {"next_id": _next_id, "messages": list, "collected": _collected}


## Tolerant (docs/05_INTERFACES_M27.md §5.40): a bad message is dropped with a warning, `next_id` is at least the highest id + 1.
func from_save(d: Dictionary) -> void:
	new_game()
	var raw: Variant = d.get("messages", [])
	var max_id: int = 0
	var seen: Dictionary[int, bool] = {}
	for entry: Variant in (raw as Array if raw is Array else []):
		var m: Dictionary = _read_message(entry, seen)
		if m.is_empty():
			continue
		seen[int(m["id"])] = true
		max_id = maxi(max_id, int(m["id"]))
		_messages.append(m)
	_messages.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["id"]) < int(b["id"]))
	_next_id = maxi(maxi(_whole(d.get("next_id"), 1), 1), max_id + 1)
	_collected = maxi(_whole(d.get("collected", 0), 0), 0)
	if d.has("collected") and _whole(d["collected"], -1) < 0:
		Log.warn(LOG_CATEGORY, "'collected' is not a whole number >= 0: 0")


# The index of the message that `post` should grow, -1 for a new one (F-183 "Consegna").
func _merge_target(kind: StringName, fields: Dictionary) -> int:
	if kind != &"auction_sold" and kind != &"auction_sale":
		return -1
	for i: int in _messages.size():
		var m: Dictionary = _messages[i]
		if m["kind"] != kind or not (m["items"] as Array).is_empty():
			continue
		if kind == &"auction_sold" and int(m["listing"]) == int(fields.get("listing", 0)) and int(m["listing"]) > 0:
			return i
		if kind == &"auction_sale" and m["item"] == StringName(fields.get("item", &"")):
			return i
	return -1


func _collect(message_id: int) -> CommandResult:
	var can: CommandResult = can_collect(message_id)
	if not can.ok:
		return can
	var index: int = _index_of(message_id)
	var m: Dictionary = _messages[index]
	for entry: Dictionary in (m["items"] as Array[Dictionary]):
		_session.bank.add(entry["item"], int(entry["qty"]))
	if int(m["money"]) > 0:
		_session.wallet.add_gold(int(m["money"]))
	_messages.remove_at(index)
	_collected += 1
	return CommandResult.success()


func _notify() -> void:
	_events.mail_changed.emit(unread(), count())


func _index_of(message_id: int) -> int:
	for i: int in _messages.size():
		if int(_messages[i]["id"]) == message_id:
			return i
	return -1


func _read_message(entry: Variant, seen: Dictionary[int, bool]) -> Dictionary:
	if not entry is Dictionary:
		Log.warn(LOG_CATEGORY, "mail entry is not an object: dropped")
		return {}
	var e: Dictionary = entry as Dictionary
	var message_id: int = _whole(e.get("id"), 0)
	var kind: StringName = StringName(str(e.get("kind", "")))
	var money: int = _whole(e.get("money", 0), -1)
	if message_id < 1 or seen.has(message_id) or not KINDS.has(kind) or money < 0:
		Log.warn(LOG_CATEGORY, "invalid mail message %s: dropped" % str(e.get("id")))
		return {}
	var items: Array[Dictionary] = []
	for raw_item: Variant in (e.get("items", []) as Array if e.get("items", []) is Array else []):
		var row: Dictionary = raw_item as Dictionary if raw_item is Dictionary else {}
		var item_id: StringName = StringName(str(row.get("item", "")))
		var qty: int = _whole(row.get("qty"), 0)
		if not _session.data.has_item(item_id) or qty < 1:
			Log.warn(LOG_CATEGORY, "mail message %d has an invalid attachment: dropped" % message_id)
			return {}
		items.append({"item": item_id, "qty": qty})
	if money > 0 and not items.is_empty():
		Log.warn(LOG_CATEGORY, "mail message %d has money and items: dropped" % message_id)
		return {}
	return {"id": message_id, "kind": kind, "item": StringName(str(e.get("item", ""))), "qty": maxi(_whole(e.get("qty", 0), 0), 0),
			"price": maxi(_whole(e.get("price", 0), 0), 0), "listing": maxi(_whole(e.get("listing", 0), 0), 0), "money": money,
			"items": items, "read": e.get("read", false) == true}


# An int from an int or an integral float; `fallback` otherwise.
static func _whole(v: Variant, fallback: int) -> int:
	if v is int:
		return v
	if v is float and float(v) == floorf(float(v)):
		return int(v)
	return fallback


static func _copy_items(items: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in items:
		result.append({"item": StringName(entry["item"]), "qty": int(entry["qty"])})
	return result


static func _copy(m: Dictionary) -> Dictionary:
	var c: Dictionary = m.duplicate()
	c["items"] = _copy_items(m["items"] as Array[Dictionary])
	return c
