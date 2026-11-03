class_name GameSession
extends Node
## One open save slot: composition of the systems, nothing else (no game rules live here).
##
## Game creates it, adds it as its child and frees it with `free()` in end_session (no _process: GameClock drives it).
## Systems are RefCounted and keep a reference to the session; the session is not reference counted, so there are no
## cycles.
##
## Adding a system: its typed field, then in `_create_systems` one creation line and one `_join` line; a system with
## `advance` also adds `_tick(_PHASE_<X>, x.advance)`. Save, load, new game and rebuild follow the join order.

const LOG_CATEGORY: String = "session"
const GAME_VERSION_SETTING: String = "application/config/version"
const MODULES_KEY: String = "modules"
const RNG_KEY: String = "rng"
# Advance phases, in the fixed order of docs/01_GDD.md §2.
const _PHASE_FRACTURES: int = 0
const _PHASE_ACTIONS: int = 1
const _PHASE_COMBAT: int = 2
const _PHASE_COUNT: int = 3

var data: GameData
var events: GameEvents
var rng: RngService
var modifiers: ModifierService
var wallet: Wallet
var bank: Bank
var skills: SkillsSystem
var mastery: MasterySystem
var actions: ActionRunner
# The other system fields of docs/05_INTERFACES.md §5.3 are declared by the task that creates each system.
var slot: int = -1
var player_name: String = ""
var created_at_unix_ms: int = 0
var play_time_ms: int = 0

var _participants: SessionParticipants = SessionParticipants.new()
# phase -> advance(delta_ms) of the system in that phase; an empty Callable = no system.
var _steps: Array[Callable] = []


func _init(game_data: GameData, game_events: GameEvents, rng_seed: int) -> void:
	assert(game_data != null and game_data.is_valid(), "GameSession needs valid GameData")
	assert(game_events != null, "GameSession needs a GameEvents")
	data = game_data
	events = game_events
	_steps.resize(_PHASE_COUNT)
	rng = RngService.new(rng_seed)
	modifiers = ModifierService.new(data.stats, events)
	_create_systems()


## Initial state of a new game (docs/01_GDD.md §1.1) in every system, then the modifiers.
func new_game() -> void:
	play_time_ms = 0
	_participants.new_game()
	rebuild_modifiers()


## One fixed step: fractures, actions, combat (only the systems that exist), then play time.
func advance(delta_ms: int) -> void:
	for step: Callable in _steps:
		if step.is_valid():
			step.call(delta_ms)
	play_time_ms += delta_ms


## The complete slot file (docs/05_INTERFACES.md §6).
func to_save(now_unix_ms: int) -> Dictionary:
	return {
		SaveMigrator.FORMAT_VERSION_KEY: SaveMigrator.CURRENT_VERSION,
		"game_version": str(ProjectSettings.get_setting(GAME_VERSION_SETTING, "")),
		"slot": slot,
		"player_name": player_name,
		"created_at_unix_ms": created_at_unix_ms,
		"saved_at_unix_ms": now_unix_ms,
		"play_time_ms": play_time_ms,
		"total_level": total_level(),
		RNG_KEY: rng.to_save(),
		MODULES_KEY: _participants.to_save(),
	}


## Loads an already migrated slot file. A malformed header changes nothing (corrupted / version_unsupported).
## Missing modules start as a new game; unknown modules are reported and ignored. Then rebuilds the modifiers.
func from_save(d: Dictionary) -> CommandResult:
	var version: Variant = _int_field(d, SaveMigrator.FORMAT_VERSION_KEY)
	if version == null:
		return _load_failed(Reasons.CORRUPTED, "missing format_version")
	if version != SaveMigrator.CURRENT_VERSION:
		return _load_failed(Reasons.VERSION_UNSUPPORTED, "format_version %d not migrated" % version)
	var header: Dictionary = {}
	for key: String in ["slot", "created_at_unix_ms", "play_time_ms"]:
		header[key] = _int_field(d, key)
		if header[key] == null:
			return _load_failed(Reasons.CORRUPTED, "invalid '%s'" % key)
	var modules: Variant = d.get(MODULES_KEY, {})
	if not (d.get("player_name") is String and d.get(RNG_KEY) is Dictionary and modules is Dictionary):
		return _load_failed(Reasons.CORRUPTED, "invalid player_name, rng or modules")
	slot = header["slot"]
	created_at_unix_ms = header["created_at_unix_ms"]
	play_time_ms = header["play_time_ms"]
	player_name = d["player_name"]
	rng.from_save(d[RNG_KEY])
	_participants.from_save(modules)
	rebuild_modifiers()
	return CommandResult.success()


## Recomputes every modifier source from the systems' state, with a single modifiers_changed.
func rebuild_modifiers() -> void:
	modifiers.begin_batch()
	modifiers.clear_all()
	_participants.rebuild()
	modifiers.end_batch()


## Sum of the skill levels.
func total_level() -> int:
	return skills.total_level()


# Per system, in dependency order: `wallet = Wallet.new(self)` then
# `_join(Wallet.SAVE_KEY, wallet.new_game, wallet.to_save, wallet.from_save[, wallet.rebuild_modifiers])`.
func _create_systems() -> void:
	wallet = Wallet.new(self)
	_join(Wallet.SAVE_KEY, wallet.new_game, wallet.to_save, wallet.from_save)
	bank = Bank.new(self)
	_join(Bank.SAVE_KEY, bank.new_game, bank.to_save, bank.from_save)
	skills = SkillsSystem.new(self)
	_join(SkillsSystem.SAVE_KEY, skills.new_game, skills.to_save, skills.from_save)
	mastery = MasterySystem.new(self)
	_join(MasterySystem.SAVE_KEY, mastery.new_game, mastery.to_save, mastery.from_save, mastery.rebuild_modifiers)
	actions = ActionRunner.new(self)
	_join(ActionRunner.SAVE_KEY, actions.new_game, actions.to_save, actions.from_save)
	_tick(_PHASE_ACTIONS, actions.advance)


# Registers a SaveParticipant (docs/05_INTERFACES.md: SAVE_KEY, new_game, to_save, from_save).
func _join(key: StringName, new_game_fn: Callable, to_save_fn: Callable, from_save_fn: Callable,
		rebuild_fn: Callable = Callable()) -> void:
	_participants.join(key, new_game_fn, to_save_fn, from_save_fn, rebuild_fn)


# Registers the advance of the system that runs in `phase`.
func _tick(phase: int, advance_fn: Callable) -> void:
	assert(phase >= 0 and phase < _PHASE_COUNT, "unknown advance phase %d" % phase)
	assert(not _steps[phase].is_valid(), "advance phase %d already taken" % phase)
	_steps[phase] = advance_fn


# int from an int or an integral float (JSON); null when missing or not integral.
func _int_field(d: Dictionary, key: String) -> Variant:
	var v: Variant = d.get(key)
	if v is int:
		return v
	if v is float:
		var f: float = v
		if f == floorf(f):
			return int(f)
	return null


func _load_failed(reason: StringName, detail: String) -> CommandResult:
	Log.warn(LOG_CATEGORY, "load failed (%s): %s" % [reason, detail])
	return CommandResult.fail(reason)
