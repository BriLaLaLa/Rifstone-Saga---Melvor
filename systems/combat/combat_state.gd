class_name CombatState
extends RefCounted
## The state of the combat engine and what is shared by its layers (docs/05_INTERFACES.md §5.10): the values, the way out of a
## Fracture or of a dungeon and the small helpers. `CombatFight` (mechanics) extends it and `CombatEngine` (commands, save) extends
## that. Split from `CombatFight` for size (M22-05). Randomness from `session.rng`.

const STATE_IDLE: StringName = &"idle"
const STATE_ENCOUNTER: StringName = &"encounter"
const STATE_BETWEEN: StringName = &"between"
const STATE_RIFTSTONE: StringName = &"riftstone"  # M7
const STATE_AWAIT: StringName = &"await"  # M22: between the rooms of a dungeon, nothing runs until DungeonSystem acts
const STATE_INTRO: StringName = &"intro"  # M22: the entrance scene of a boss stage, only its timer runs
const PLAYER: int = -1

var loot: LootBag
var advance_offset_ms: int = 0  # ms of the running `advance` already consumed (B3: dates an event in a block); 0 outside

var _session: GameSession
var _stone: RiftStone
var _state: StringName = STATE_IDLE
var _area_id: StringName = &""
var _encounter: Encounter = Encounter.new()
var _player_hp: int = 0
var _player_timer_ms: int = 0
var _hand: int = 0
var _struck_hand: int = 0  # the hand of the last base attack (F-120 double_hit_pct)
var _between_ms: int = 0
var _fx: EffectSet
var _abilities: AbilityRunner
var _frac: FractureCombat  # M13: the Fracture in progress, if any
var _dg: DungeonCombat  # M22: the dungeon run in progress, if any
var _resume_area: StringName = &""  # M13: the area to go back to once the instant being resolved is over
var _resolving: bool = false  # an instant is being resolved inside `advance`: the way back waits for its end
var _miniboss_pending: bool = false  # M22 (F-139): the next encounter of the area is its miniboss
var _kills: Dictionary[StringName, int] = {}
var _deaths: int = 0
var _food_eaten: int = 0
var _stop_log: Array[StringName] = []
var _stats: Array[CombatantStats] = [null, null]


func _init(session: GameSession) -> void:
	_session = session
	loot = LootBag.new(session)
	_stone = RiftStone.new(session)
	_fx = EffectSet.new(session)
	_abilities = AbilityRunner.new(session)
	_frac = FractureCombat.new(session)
	_dg = DungeonCombat.new(session)
	session.events.modifiers_changed.connect(_on_stats_source_changed)
	session.events.equipment_changed.connect(_on_loadout_changed.unbind(2))
	session.events.character_level_up.connect(_on_stats_source_changed.unbind(1))
	session.events.traits_changed.connect(_on_loadout_changed)
	session.events.dungeon_finished.connect(_on_dungeon_finished)


## Overridden by CombatEngine (the commands live there).
func start(_area: StringName) -> CommandResult:
	return CommandResult.fail(Reasons.UNKNOWN_ID)


func stop(_reason: StringName = Reasons.STOPPED_BY_USER) -> void:
	pass


func is_active() -> bool:
	return _state != STATE_IDLE


func in_encounter() -> bool:
	return _state == STATE_ENCOUNTER or _state == STATE_RIFTSTONE


## Stats of the player's hand (F-70, F-74), cached until something that feeds them changes.
func player_stats(hand: int = 0) -> CombatantStats:
	var index: int = clampi(hand, 0, 1)
	if _stats[index] == null:
		var stats: CombatantStats = CombatantStats.for_player(_session, index)
		_fx.modify_stats(stats)
		_stats[index] = stats
	return _stats[index]


# The end of a Fracture (win, death, abandon): fracture_finished, which makes FractureSystem deliver or lose the bag, and
# then the way back (05 §5.23). Back to the area is deferred to `_resume` so that the rest of the instant sees no fight.
func _end_fracture(outcome: StringName, reason: StringName, to_area: bool) -> void:
	var run: FractureRun = _frac.run
	var counts: Dictionary = run.bag.counts()
	_frac.end()
	_session.events.fracture_finished.emit(outcome, run.grade, run.groups_cleared, counts["cards"], counts["pieces"])
	_go_back(run.return_area if to_area else &"", reason)


# M22: a run that ends for the player (`died`, `fled`): dungeon_finished (DungeonSystem loses the bag), then the way back.
func _end_dungeon(outcome: StringName, reason: StringName, to_area: bool) -> void:
	var run: DungeonRun = _dg.run
	_dg.end()
	_session.events.dungeon_finished.emit(outcome, run.cleared, run.bag.pieces().size())
	_go_back(run.return_area if to_area else &"", reason)


# `DungeonSystem` ended the run (`won`, `left`) with the run still readable: back to its area, or stop (05 §5.29).
func _on_dungeon_finished(outcome: StringName, _rooms: int, _pieces: int) -> void:
	if not _dg.active() or (outcome != &"won" and outcome != &"left"):
		return
	var run: DungeonRun = _dg.run
	_dg.end()
	_go_back(run.return_area, Reasons.DUNGEON_WON)
	if not _resolving:
		_resume()


# Nothing to fight any more: stop for `reason` or, with an area, go idle unannounced and let `_resume` start the area.
func _go_back(area: StringName, reason: StringName) -> void:
	if area == &"":
		stop(reason)
		return
	_state = STATE_IDLE  # not announced: the area starts at once
	_encounter = Encounter.new()
	_resume_area = area


func _resume() -> void:
	if _resume_area == &"":
		return
	var area: StringName = _resume_area
	_resume_area = &""
	_abilities.reset()
	start(area)


## What the effect hooks see of the fight right now.
func _ctx() -> EffectContext:
	var ctx := EffectContext.new()
	ctx.player_hp = _player_hp
	ctx.player_max_hp = player_stats().max_hp
	ctx.player_timer_ms = _player_timer_ms
	ctx.rng = _session.rng
	return ctx


func _set_hp(hp: int) -> void:
	if hp == _player_hp:
		return
	_player_hp = hp
	_session.events.player_hp_changed.emit(hp, player_stats().max_hp)


func _food_count() -> int:
	var food: StringName = _session.equipment.get_food()
	return _session.bank.get_count(food) if food != &"" else 0


func _on_loadout_changed() -> void:
	_fx.invalidate()
	_on_stats_source_changed()


# Derived stats are stale: drop them; the current hp never exceeds the new maximum (docs/01_GDD.md §10.9).
func _on_stats_source_changed() -> void:
	_stats = [null, null]
	if _state != STATE_IDLE and _player_hp > player_stats().max_hp:
		_set_hp(player_stats().max_hp)
