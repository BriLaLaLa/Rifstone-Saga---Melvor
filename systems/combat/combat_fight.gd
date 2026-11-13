class_name CombatFight
extends CombatState
## The fight mechanics under `CombatEngine` (docs/01_GDD.md §10, docs/05_INTERFACES.md §5.10): timers, attacks, kills and the end
## of an encounter. The values and the ways out of a Fracture or a dungeon are in `CombatState`; the public API, the commands and
## the save in `CombatEngine`. Randomness from `session.rng`. Helpers: EffectSet, AbilityRunner, RiftStone, FractureCombat,
## DungeonCombat (M22).


func _next_timer() -> int:
	if _dg.run != null:  # M22: the pause of a dungeon, `await` and the scene of a stage
		var held: int = _dg.held_timer(_state)
		if held >= 0:
			return held
	if _state == STATE_BETWEEN:
		return _between_ms
	var next: int = mini(mini(_player_timer_ms, _frac.next_pulse_ms()), _abilities.next_ms(_player_hp, player_stats().max_hp))
	next = mini(next, _frac.next_boss_ms())
	if _dg.fighting:
		next = mini(next, _dg.next_ability_ms(_encounter))
	for enemy: Encounter.Enemy in _encounter.enemies:
		if enemy.alive():
			next = mini(next, enemy.timer_ms)
	return next


func _consume(ms: int) -> void:
	if ms <= 0 or (_dg.run != null and _dg.hold(_state, ms)):
		return
	_abilities.tick(ms)
	if _state == STATE_BETWEEN:
		_between_ms -= ms
		return
	_player_timer_ms -= ms
	_frac.tick(ms)
	if _dg.fighting:
		_dg.tick(ms)
	for enemy: Encounter.Enemy in _encounter.enemies:
		if enemy.alive():
			enemy.timer_ms -= ms


# F-76: player base attack, then the enemies by position; whoever dies (or ends the encounter) stops the rest.
func _resolve_instant() -> void:
	if _state == STATE_INTRO:  # M22 (F-141): the scene is over, the stage fights
		_start_stage()
		return
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
		if in_encounter() and (_frac.ability_due(enemy) or (_dg.fighting and _dg.ability_due(enemy))):  # F-112: right after the base attack of the boss
			_boss_ability(i, enemy)
	if in_encounter() and _frac.active() and _frac.next_pulse_ms() <= 0:  # F-111 `pulse`, after the enemies
		var pulse: Dictionary = _frac.pulse_attack(player_stats())
		_session.events.combat_hit.emit(FractureCombat.PULSE_SOURCE, PLAYER, true, pulse["damage"], pulse["blocked"])
		_on_block(pulse)
		_hurt_player(FractureCombat.PULSE_SOURCE, pulse["damage"])


func _begin_encounter() -> void:
	_encounter = _frac.next_encounter() if _frac.active() else _area_encounter()  # F-50 / a miniboss / a pending stone (F-87)
	_state = STATE_RIFTSTONE if _encounter.has_stone() else STATE_ENCOUNTER
	if _frac.active() and _encounter.enemies.is_empty():  # no pack or no boss in the data: nothing to fight
		Log.error("combat", "Fracture grade %d has nothing to fight: counted as won" % _frac.run.grade)
		_end_fracture(&"won", Reasons.FRACTURE_WON, true)
		return
	_open_encounter()


# The timers and the effects of a fight that starts now (`_encounter` and `_state` are already set).
func _open_encounter() -> void:
	_player_timer_ms = player_stats(_hand).attack_interval_ms
	var ctx: EffectContext = _ctx()
	_fx.encounter_start(ctx)
	_player_timer_ms = ctx.player_timer_ms
	_session.events.encounter_started.emit(_encounter.monster_ids())


# F-139: the miniboss of the area if one waits (a pending Rift Stone goes first), else a pack or the stone (F-77, F-87).
func _area_encounter() -> Encounter:
	if _miniboss_pending and not _stone.pending:
		_miniboss_pending = false
		var pack: Array[MonsterDef] = Miniboss.pack(_session.data.area(_area_id), _session.rng, _session.data)
		if not pack.is_empty():
			return Encounter.of_defs(pack, _session.data)
	return _stone.next_encounter(_area_id)


# F-141: the scene of the stage is over: its monsters appear (the boss ability timer starts) and the stage begins.
func _start_stage() -> void:
	_encounter = _dg.stage_encounter()
	_state = STATE_ENCOUNTER
	_open_encounter()
	_session.events.dungeon_stage_started.emit(_dg.stage_index, _dg.stage.monster.id)


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


# F-112: the ability of the boss at `index` (of a Fracture or of a dungeon stage). A heavy strike hits like an attack; a summon
# announces the new positions.
func _boss_ability(index: int, enemy: Encounter.Enemy) -> void:
	var summoned: Array[int] = []
	var attack: Dictionary = _dg.use_ability(enemy, _encounter, player_stats(), summoned) if _dg.active() \
			else _frac.use_ability(enemy, _encounter, player_stats(), summoned)
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
	if _player_hp <= 0:  # death: only the loot bag is lost (inside a Fracture or a dungeon, the bag of the run instead)
		if not _frac.active() and not _dg.active():
			loot.lose_all()
		_deaths += 1
		_set_hp(me.max_hp)
		_session.events.player_died.emit()
		if _frac.active():
			_end_fracture(&"died", Reasons.PLAYER_DIED, true)
		elif _dg.active():
			_end_dungeon(&"died", Reasons.PLAYER_DIED, true)
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
	var dealt: int = _frac.absorb(enemy, damage)  # the shield of a boss takes it first (F-112)
	if _dg.fighting:
		dealt = _dg.absorb(enemy, dealt)
	enemy.hp = maxi(0, enemy.hp - dealt)
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
# In a Fracture or a dungeon the rewards go to the bag of the run (F-111, F-113, F-142), a summoned enemy gives none, and no
# stone is rolled (F-50).
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
	elif _dg.active():
		counts = _dg.reward(enemy, kill_ctx.card_mult)  # F-142: always false, the monsters of a dungeon are not kills of an area
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
		_cleared()


# The last enemy of the encounter is dead. In a dungeon the run waits for DungeonSystem; in an area the next encounter comes after
# `BETWEEN`, and after a normal one (not a stone, a Fracture or a miniboss) the miniboss of the area may be next (F-139).
func _cleared() -> void:
	if _dg.active():
		_dungeon_cleared()
		return
	var normal: bool = _state == STATE_ENCOUNTER and not _frac.active() and not _encounter.has_miniboss()
	_encounter = Encounter.new()
	_state = STATE_BETWEEN
	_between_ms = int(_session.data.balance_value("combat.respawn_ms"))
	if normal and not _stone.pending and not _miniboss_pending:
		_miniboss_pending = Miniboss.roll(_session.data.area(_area_id), _session.rng, _session.data)
	_session.events.encounter_cleared.emit()


# F-141: a room or a stage of the dungeon is beaten: the engine waits, then tells DungeonSystem (it acts at once). The signals
# come last: the state is already final when the system reacts (a new scene, a fork, the end of the run).
func _dungeon_cleared() -> void:
	var stage: int = _dg.stage_index if _dg.fighting else 0
	var layer: int = _dg.room_layer
	var kind: StringName = _dg.room_kind
	_dg.end_fight()
	_encounter = Encounter.new()
	_state = STATE_AWAIT
	_session.events.encounter_cleared.emit()
	if stage > 0:
		_session.events.dungeon_stage_cleared.emit(stage)
	else:
		_session.events.dungeon_room_cleared.emit(layer, kind)
