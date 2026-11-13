class_name CombatFight
extends RefCounted
## The fight mechanics under `CombatEngine` (docs/01_GDD.md §10, docs/05_INTERFACES.md §5.10): state, timers, attacks, kills and
## the end of a Fracture. Split from the engine for size: the public API, the commands and the save live in `CombatEngine`.
## Randomness from `session.rng`. Helpers: EffectSet, AbilityRunner, RiftStone, FractureCombat.

const STATE_IDLE: StringName = &"idle"
const STATE_ENCOUNTER: StringName = &"encounter"
const STATE_BETWEEN: StringName = &"between"
const STATE_RIFTSTONE: StringName = &"riftstone"  # M7
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
var _resume_area: StringName = &""  # M13: the area to go back to once the instant being resolved is over
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
	session.events.modifiers_changed.connect(_on_stats_source_changed)
	session.events.equipment_changed.connect(_on_loadout_changed.unbind(2))
	session.events.character_level_up.connect(_on_stats_source_changed.unbind(1))
	session.events.traits_changed.connect(_on_loadout_changed)

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
	if not to_area or run.return_area == &"":
		stop(reason)
		return
	_state = STATE_IDLE  # not announced: the area starts at once
	_encounter = Encounter.new()
	_resume_area = run.return_area


func _resume() -> void:
	if _resume_area == &"":
		return
	var area: StringName = _resume_area
	_resume_area = &""
	_abilities.reset()
	start(area)


func _next_timer() -> int:
	if _state == STATE_BETWEEN:
		return _between_ms
	var next: int = mini(mini(_player_timer_ms, _frac.next_pulse_ms()), _abilities.next_ms(_player_hp, player_stats().max_hp))
	next = mini(next, _frac.next_boss_ms())
	for enemy: Encounter.Enemy in _encounter.enemies:
		if enemy.alive():
			next = mini(next, enemy.timer_ms)
	return next


func _consume(ms: int) -> void:
	if ms <= 0:
		return
	_abilities.tick(ms)
	if _state == STATE_BETWEEN:
		_between_ms -= ms
		return
	_player_timer_ms -= ms
	_frac.tick(ms)
	for enemy: Encounter.Enemy in _encounter.enemies:
		if enemy.alive():
			enemy.timer_ms -= ms


# F-76: player base attack, then the enemies by position; whoever dies (or ends the encounter) stops the rest.
func _resolve_instant() -> void:
	if _state == STATE_BETWEEN:
		if _between_ms <= 0:
			_begin_encounter()
		return
	if _player_timer_ms <= 0:
		_player_attack()
	_use_abilities()
	for i: int in _encounter.enemies.size():
		if not in_encounter():
			return
		var enemy: Encounter.Enemy = _encounter.enemies[i]
		if enemy.alive() and enemy.timer_ms <= 0:
			_enemy_attack(i, enemy)
		if in_encounter() and _frac.ability_due(enemy):  # F-112: right after the base attack of the boss
			_boss_ability(i, enemy)
	if in_encounter() and _frac.active() and _frac.next_pulse_ms() <= 0:  # F-111 `pulse`, after the enemies
		var pulse: Dictionary = _frac.pulse_attack(player_stats())
		_session.events.combat_hit.emit(FractureCombat.PULSE_SOURCE, PLAYER, true, pulse["damage"], pulse["blocked"])
		_on_block(pulse)
		_hurt_player(FractureCombat.PULSE_SOURCE, pulse["damage"])


func _begin_encounter() -> void:
	_encounter = _frac.next_encounter() if _frac.active() else _stone.next_encounter(_area_id)  # F-50 / a pending stone (F-87)
	_state = STATE_RIFTSTONE if _encounter.has_stone() else STATE_ENCOUNTER
	if _frac.active() and _encounter.enemies.is_empty():  # no pack or no boss in the data: nothing to fight
		Log.error("combat", "Fracture grade %d has nothing to fight: counted as won" % _frac.run.grade)
		_end_fracture(&"won", Reasons.FRACTURE_WON, true)
		return
	_player_timer_ms = player_stats(_hand).attack_interval_ms
	var ctx: EffectContext = _ctx()
	_fx.encounter_start(ctx)
	_player_timer_ms = ctx.player_timer_ms
	_session.events.encounter_started.emit(_encounter.monster_ids())


# Base attack: effects may widen it (F-81) or change its damage. Rolls first (position order), then hand and timer, then outcomes.
func _player_attack() -> void:
	var first: int = _encounter.target(_fx.target_rule())
	if first < 0:
		return
	var ctx: EffectContext = _ctx()
	ctx.base_attack = true
	_fx.before_attack(ctx)
	var targets: Array[int] = [first]
	if ctx.attack_all:
		targets = _encounter.alive_indices()
	var attacks: Array[Dictionary] = []
	for index: int in targets:
		attacks.append(_base_roll(index, ctx))
	var setup: SetupDef = _session.equipment.setup_def()
	var dual: bool = setup != null and setup.alternate and _session.equipment.offhand_weapon() != null
	_struck_hand = _hand
	_hand = 1 if _hand == 0 and dual else 0
	_player_timer_ms = player_stats(_hand).attack_interval_ms
	_apply_hits(targets, attacks, ctx)


# One roll of the base attack against the enemy at `index` with the hand that strikes: the multipliers of the effects
# (F-81 low hp, F-120 execute) and the pierce (F-120 armor_pierce_pct).
func _base_roll(index: int, ctx: EffectContext) -> Dictionary:
	var enemy: Encounter.Enemy = _encounter.enemies[index]
	var mult: float = ctx.damage_mult * _fx.damage_mult_against(ctx, enemy.hp, enemy.stats.max_hp)
	return Encounter.roll_attack(player_stats(_hand), enemy.stats, 0.0, _session.rng, _session.data, mult, ctx.dr_mult)

# F-76/F-79: after the base attack, the abilities that are due, in slot order (each hits, heals or starts a buff).
func _use_abilities() -> void:
	while in_encounter():
		var use: AbilityRunner.Use = _abilities.take_due(_encounter, _player_hp, player_stats(), _fx.target_rule())
		if use == null:
			return
		_session.events.ability_used.emit(use.id, use.targets)
		_apply_hits(use.targets, use.attacks)
		_set_hp(mini(player_stats().max_hp, _player_hp + use.heal))


# The outcomes of the player's rolls, in target order: hit event, hp, leech, kill. `base` is the context of the base attack
# (null for an ability or an extra hit): only then F-120 double_hit_pct may add a second hit on the same target.
func _apply_hits(targets: Array[int], attacks: Array[Dictionary], base: EffectContext = null) -> void:
	for k: int in targets.size():
		if not in_encounter():
			return
		var damage: int = attacks[k]["damage"]
		_session.events.combat_hit.emit(PLAYER, targets[k], attacks[k]["hit"], damage, false)
		if damage > 0:
			_hurt_enemy(targets[k], damage)
			var ctx: EffectContext = _ctx()  # leech (F-81) and the like
			ctx.base_attack = base != null
			_fx.hit(ctx, damage)
			_set_hp(mini(ctx.player_max_hp, _player_hp + ctx.heal))
			if ctx.extra_hit and in_encounter() and _encounter.enemies[targets[k]].alive():
				_extra_hit(targets[k], base)


# F-120 double_hit_pct: a second base hit on the same target with the hand that struck (its rolls: F-23, F-22).
func _extra_hit(index: int, base: EffectContext) -> void:
	var hand: int = _hand
	_hand = _struck_hand
	var attack: Dictionary = _base_roll(index, base)
	_hand = hand
	_apply_hits([index], [attack])


func _enemy_attack(index: int, enemy: Encounter.Enemy) -> void:
	enemy.timer_ms = enemy.stats.attack_interval_ms
	var attack: Dictionary = Encounter.roll_enemy_attack(enemy, player_stats(), _session.rng, _session.data)
	_session.events.combat_hit.emit(index, PLAYER, attack["hit"], attack["damage"], attack["blocked"])
	_on_block(attack)
	_hurt_player(index, attack["damage"])


# F-112: the ability of the boss at `index`. A heavy strike hits like an attack; a summon announces the new positions.
func _boss_ability(index: int, enemy: Encounter.Enemy) -> void:
	var summoned: Array[int] = []
	var attack: Dictionary = _frac.use_ability(enemy, _encounter, player_stats(), summoned)
	if not attack.is_empty():
		_session.events.combat_hit.emit(index, PLAYER, attack["hit"], attack["damage"], attack["blocked"])
		_on_block(attack)
		_hurt_player(index, attack["damage"])
	for position: int in summoned:
		var fresh: Encounter.Enemy = _encounter.enemies[position]
		_session.events.monster_hp_changed.emit(position, fresh.hp, fresh.stats.max_hp)


# F-120 block_heal_pct: the attack was blocked (F-75).
func _on_block(attack: Dictionary) -> void:
	if attack["blocked"]:
		var ctx: EffectContext = _ctx()
		_fx.block(ctx)
		_set_hp(mini(ctx.player_max_hp, _player_hp + ctx.heal))

# The player takes `damage` from the enemy at `source` (or from the pulse of a Fracture): death, reflect, auto-eat.
func _hurt_player(source: int, damage: int) -> void:
	if damage <= 0:
		return
	var me: CombatantStats = player_stats()
	damage = _fx.damage_taken(_ctx(), damage)  # F-120 hit_cap_pct
	_set_hp(maxi(0, _player_hp - damage))
	if _player_hp <= 0:  # death: only the loot bag is lost (inside a Fracture, the bag of the Fracture instead)
		if not _frac.active():
			loot.lose_all()
		_deaths += 1
		_set_hp(me.max_hp)
		_session.events.player_died.emit()
		if _frac.active():
			_end_fracture(&"died", Reasons.PLAYER_DIED, true)
		else:
			stop(Reasons.PLAYER_DIED)
		return
	var ctx: EffectContext = _ctx()
	_fx.damaged(ctx, damage)
	if ctx.reflect_damage > 0 and source >= 0:
		_hurt_enemy(source, ctx.reflect_damage)
	if _fx.blocks_auto_eat(_ctx()):
		return
	var before: int = _food_count()
	_set_hp(AutoEat.after_hit(_session, _player_hp, me.max_hp))
	_food_eaten += before - _food_count()


func _hurt_enemy(index: int, damage: int) -> void:
	var enemy: Encounter.Enemy = _encounter.enemies[index]
	enemy.hp = maxi(0, enemy.hp - _frac.absorb(enemy, damage))  # the shield of a boss takes it first (F-112)
	_session.events.monster_hp_changed.emit(index, enemy.hp, enemy.stats.max_hp)
	if enemy.hp == 0:
		_kill(index, enemy)
	elif enemy.is_stone():
		_stone_waves(enemy)


# F-126: the thresholds that this hit took the stone under (the first hit included) each summon a wave, in descending order.
func _stone_waves(stone: Encounter.Enemy) -> void:
	var def: RiftStoneDef = _session.data.rift_stone(stone.def.id)
	for threshold: int in _stone.crossed(stone):
		var created: Array[int] = []
		for monster: MonsterDef in StoneFight.wave_defs(def, _session.data, _session.rng):
			var fresh := Encounter.Enemy.new(monster, _session.data)
			fresh.summoned = true
			_encounter.enemies.append(fresh)
			created.append(_encounter.enemies.size() - 1)
		for position: int in created:
			var fresh: Encounter.Enemy = _encounter.enemies[position]
			_session.events.monster_hp_changed.emit(position, fresh.hp, fresh.stats.max_hp)
		_session.events.rift_stone_wave.emit(def.id, threshold, created.size())


# Kill (05 §5.10): xp (F-28), then gold (F-31), drops in data order (F-32), shard (F-07); last enemy ends the encounter.
# In a Fracture the rewards go to its bag (F-111, F-113), a summoned enemy gives none, and no stone is rolled (F-50).
func _kill(index: int, enemy: Encounter.Enemy) -> void:
	var counts: bool = not enemy.is_stone()  # a stone, a boss and a summoned enemy are not kills of a monster of the data
	var kill_ctx: EffectContext = _ctx()  # F-81 on_kill_timer_cut, F-120 kill_heal_pct and card_drop_mult come first
	_fx.kill(kill_ctx)
	_player_timer_ms = kill_ctx.player_timer_ms
	_set_hp(mini(kill_ctx.player_max_hp, _player_hp + kill_ctx.heal))
	loot.card_mult = kill_ctx.card_mult
	if enemy.is_stone():
		var monolith: EffectContext = _ctx()  # F-120 monolith_loot_mult
		_fx.monolith(monolith)
		_stone.reward(loot, _session.data.rift_stone(enemy.def.id), monolith.loot_mult)
	elif _frac.active():
		counts = _frac.reward(enemy, kill_ctx.card_mult)
	elif enemy.summoned:  # M15 (F-126): the monsters called by a stone give no xp or gold and are no kills; V11: few drops
		counts = false
		KillRewards.grant_summoned(_session, loot, enemy.def, _area_id)
	else:
		KillRewards.grant(_session, loot, enemy.def, _area_id)
	if counts:
		_kills[enemy.def.id] = _kills.get(enemy.def.id, 0) + 1
	if counts and not _frac.active():
		_stone.on_kill(_area_id)
	_session.events.monster_killed.emit(index, enemy.def.id)
	var verdict: StringName = _frac.after_kill(enemy, _encounter)
	if verdict == FractureCombat.VERDICT_WON:
		_end_fracture(&"won", Reasons.FRACTURE_WON, true)
	elif verdict == FractureCombat.VERDICT_CLEARED:
		_encounter = Encounter.new()
		_state = STATE_BETWEEN
		_between_ms = int(_session.data.balance_value("combat.respawn_ms"))
		_session.events.encounter_cleared.emit()


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


