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
const STATE_TRAVEL: StringName = &"travel"  # M24 (F-153): the journey to the next encounter of an area
const STATE_NODE: StringName = &"node"  # M24 (F-155): a gathering node is being worked or skipped
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
var _cy: CycleState  # M24: journey, node and node counters of the area cycle
var _ward: PlayerWard = PlayerWard.new()  # M28 (F-189): the Ward of the player
var _clock: BleedClock = BleedClock.new()  # M28 (F-186): the one clock of the Bleed of the encounter
var _travel_on_start: bool = false  # M24: the next `start` (the way back from a Fracture or a dungeon) begins with a journey
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
	_cy = CycleState.new(session)
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
	_travel_on_start = true  # the way back to the area begins with a journey (§35.1)
	start(area)
	_travel_on_start = false


## What the effect hooks see of the fight right now.
func _ctx() -> EffectContext:
	var ctx := EffectContext.new()
	ctx.player_hp = _player_hp
	ctx.player_max_hp = player_stats().max_hp
	ctx.player_timer_ms = _player_timer_ms
	ctx.rng = _session.rng
	return ctx


## M28 (F-185): the Ward and the Bleed clock end with the fight (a new combat, `stop`, a death).
func _clear_conditions() -> void:
	_ward.clear()
	_clock.reset()


## M28 (F-190): the context of a hit of the player on the enemy at `index` (`kind` = an `EffectContext.HIT_*`) as the effects see it.
func _hit_ctx(index: int, enemy: Encounter.Enemy, kind: StringName, primary: int = -1, ability_kind: StringName = &"") -> EffectContext:
	var ctx: EffectContext = _ctx()
	ctx.hit_kind = kind
	ctx.ability_kind = ability_kind
	ctx.target_index = index
	ctx.primary_index = primary
	ctx.target_hp = enemy.hp
	ctx.target_max_hp = enemy.stats.max_hp
	ctx.target_conditions = enemy.conditions
	ctx.alive_count = _encounter.alive_count()
	return ctx


## M28 (F-190): the factors of `M` that come from the effects and from the Expose of the target (1.0 for none).
func _hit_mult(index: int, kind: StringName, primary: int = -1, ability_kind: StringName = &"") -> float:
	var enemy: Encounter.Enemy = _encounter.enemies[index]
	var mult: float = _fx.hit_mult(_hit_ctx(index, enemy, kind, primary, ability_kind))
	var cond: EnemyConditions = enemy.conditions
	return mult * (1.0 + cond.expose_pct / 100.0) if cond.expose_ms > 0 else mult


## M28 (F-190, F-191): what `AbilityRunner` asks for: the `M` of an ability hit on `target_index`, or (-1) the factor of its amount.
func _ability_mult(def: AbilityDef, target_index: int) -> float:
	if target_index >= 0:
		return _hit_mult(target_index, EffectContext.HIT_ABILITY, -1, def.kind)
	var ctx: EffectContext = _ctx()
	ctx.ability_kind = def.kind
	return _fx.amount_mult(ctx)


## M28 (F-193): d1, the damage of the attack from the enemy at `source` (-1 or less: the pulse) after its Weaken (F-187) and the
## `damage_trade` of the effects (at least 1); `damage` itself, with no float step, when neither applies.
func _incoming_damage(source: int, damage: int) -> int:
	var taken: float = _fx.incoming_mult(_ctx())
	var weaken_pct: float = 0.0
	if source >= 0 and source < _encounter.enemies.size() and _encounter.enemies[source].conditions.weaken_ms > 0:
		weaken_pct = _encounter.enemies[source].conditions.weaken_pct
	if weaken_pct <= 0.0 and taken == 1.0:
		return damage
	return maxi(1, int(floor(float(damage) * (1.0 - weaken_pct / 100.0) * taken + CombatMath.EPSILON)))


## M28 (F-189): the Ward that an effect asks for in `ctx` (`ward_pct` of the maximum hp for `ward_ms`).
func _grant_ward(ctx: EffectContext) -> void:
	if ctx.ward_pct > 0.0 and ctx.ward_ms > 0:
		_ward.grant(int(floor(float(ctx.player_max_hp) * ctx.ward_pct / 100.0 + CombatMath.EPSILON)), ctx.ward_ms)


## M28 (F-185): applies `app` to the enemy at `index`, hit for `damage` and still alive; a Bleed starts the clock (F-186).
func _apply_condition(index: int, app: ConditionApply, damage: int) -> void:
	var enemy: Encounter.Enemy = _encounter.enemies[index]
	if enemy.immune_to(app.condition) or (app.condition == ConditionApply.STAGGER and _dg.fighting and _dg.is_chief(enemy)):
		return
	var params: ConditionParams = _session.data.conditions()
	enemy.timer_ms = enemy.conditions.apply(app, damage, enemy.timer_ms, true, params)
	if enemy.conditions.bleeds():
		_clock.start_if_idle(params)


func _any_bleeding() -> bool:
	for enemy: Encounter.Enemy in _encounter.enemies:
		if enemy.alive() and enemy.conditions.bleeds():
			return true
	return false


# The targets of an ability without repeats, in the order of the first hit (`ability_used`, 05_INTERFACES_M28.md §3f).
static func _distinct(targets: Array[int]) -> Array[int]:
	var out: Array[int] = []
	for index: int in targets:
		if not out.has(index):
			out.append(index)
	return out


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
