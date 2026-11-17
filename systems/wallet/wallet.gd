class_name Wallet
extends RefCounted
## The player's money (docs/01_GDD.md §8, F-177): the only currency, an integer >= 0 in copper (the `gold` names are historical, Q167).
##
## Every change emits `gold_changed(new_amount, delta)` on the session EventBus. `new_game` and `from_save` set the
## state without signals: the UI reads it after `session_started`.

const SAVE_KEY: StringName = &"wallet"
const LOG_CATEGORY: String = "wallet"
const START_GOLD_KEY: String = "start.gold"

var _events: GameEvents
var _start_gold: int = 0
var _gold: int = 0


func _init(session: GameSession) -> void:
	assert(session != null, "Wallet needs a session")
	_events = session.events
	_start_gold = int(session.data.balance_value(START_GOLD_KEY))


func get_gold() -> int:
	return _gold


## Adds `amount` > 0 gold; any other amount is a programming error and changes nothing.
func add_gold(amount: int) -> void:
	if amount <= 0:
		push_error("Wallet.add_gold: amount must be > 0, got %d" % amount)
		return
	_gold += amount
	_events.gold_changed.emit(_gold, amount)


func spend(amount: int) -> CommandResult:
	if amount <= 0:
		return CommandResult.fail(Reasons.INVALID_AMOUNT)
	if amount > _gold:
		return CommandResult.fail(Reasons.NOT_ENOUGH_GOLD)
	_gold -= amount
	_events.gold_changed.emit(_gold, -amount)
	return CommandResult.success()


## docs/01_GDD.md §1.1: `start.gold` from balance.json.
func new_game() -> void:
	_gold = _start_gold


func to_save() -> Dictionary:
	return {"copper": _gold}


## A missing, non-integral or negative `copper` is reported and loads as 0.
func from_save(d: Dictionary) -> void:
	if d.has("gold"):
		Log.warn(LOG_CATEGORY, "unexpected key 'gold' in a v11 wallet: ignored")
	var value: Variant = d.get("copper")
	_gold = 0
	if (value is int or value is float) and float(value) == floorf(float(value)) and float(value) >= 0.0:
		_gold = int(value)
	else:
		Log.warn(LOG_CATEGORY, "invalid copper %s in save: loaded as 0" % str(value))
