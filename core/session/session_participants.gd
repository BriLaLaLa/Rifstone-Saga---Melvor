class_name SessionParticipants
extends RefCounted
## The SaveParticipants joined to a GameSession, in join order: new game, save, load and modifier rebuild of each.
##
## Internal helper of GameSession (not an API for other modules): it keeps `game_session.gd` short.

const LOG_CATEGORY: String = "session"

var _participants: Array[_Participant] = []


# Registers a SaveParticipant (docs/05_INTERFACES.md: SAVE_KEY, new_game, to_save, from_save).
func join(key: StringName, new_game_fn: Callable, to_save_fn: Callable, from_save_fn: Callable,
		rebuild_fn: Callable = Callable()) -> void:
	for p: _Participant in _participants:
		assert(p.key != key, "duplicate SAVE_KEY '%s'" % key)
	var p: _Participant = _Participant.new()
	p.key = key
	p.new_game = new_game_fn
	p.to_save = to_save_fn
	p.from_save = from_save_fn
	p.rebuild = rebuild_fn
	p.system = to_save_fn.get_object()
	_participants.append(p)


func new_game() -> void:
	for p: _Participant in _participants:
		p.new_game.call()


# {SAVE_KEY: module block} of every participant.
func to_save() -> Dictionary:
	var modules: Dictionary = {}
	for p: _Participant in _participants:
		modules[String(p.key)] = p.to_save.call()
	return modules


# Missing or non-object modules start as a new game; unknown modules are reported and ignored.
func from_save(modules: Dictionary) -> void:
	var known: Dictionary[String, bool] = {}
	for p: _Participant in _participants:
		var key: String = String(p.key)
		known[key] = true
		var block: Variant = modules.get(key)
		if block is Dictionary:
			p.from_save.call(block)
		else:
			if block != null:
				Log.warn(LOG_CATEGORY, "module '%s' is not an object: new game state" % key)
			p.new_game.call()
	for key: Variant in modules:
		if not known.has(str(key)):
			Log.warn(LOG_CATEGORY, "unknown module '%s' ignored" % str(key))


# Calls each optional rebuild_modifiers; the caller wraps this in a modifier batch.
func rebuild() -> void:
	for p: _Participant in _participants:
		if p.rebuild.is_valid():
			p.rebuild.call()


# The four SaveParticipant callables of one system, plus its optional modifier rebuild.
class _Participant:
	extends RefCounted

	var key: StringName
	var new_game: Callable
	var to_save: Callable
	var from_save: Callable
	var rebuild: Callable
	var system: Object # Callables do not keep a RefCounted alive: the participant does.
