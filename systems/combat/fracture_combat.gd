class_name FractureCombat
extends RefCounted
## The part of `CombatEngine` that is specific to a Fracture (docs/05_INTERFACES.md §5.23, F-50, F-111, F-113): the run in
## progress, the pulse timer, the groups and the boss, the rewards of a kill and the extra save keys. It holds no flow
## of its own: the engine decides when to call it. Randomness from `session.rng`.

const NO_TIMER: int = 1 << 40
const PULSE_SOURCE: int = -2  # `combat_hit` attacker of the pulse: no enemy position (-1 is the player)
const PULSE_KEY: String = "fracture.pulse_ms"
const VERDICT_WON: StringName = &"won"
const VERDICT_CLEARED: StringName = &"cleared"

var run: FractureRun = null
var pulse_ms: int = 0  # time to the next pulse, runs only during an encounter
# State of the boss ability (M13-03); saved with the fight.
var boss_ability_ms: int = 0
var boss_shield: int = 0
var boss_shield_ms: int = 0

var _session: GameSession
var _sink: FractureSink = null


func _init(session: GameSession) -> void:
	_session = session


func active() -> bool:
	return run != null


## A Fracture starts (or is resumed from a save): a full pulse timer, no boss state.
func begin(new_run: FractureRun) -> void:
	run = new_run
	_sink = FractureSink.new(_session, run)
	pulse_ms = int(_session.data.balance_value(PULSE_KEY))
	boss_ability_ms = 0
	boss_shield = 0
	boss_shield_ms = 0


func end() -> void:
	run = null
	_sink = null
	pulse_ms = 0


func sink() -> LootSink:
	return _sink


## F-50: the next group, or the boss after the last one (`fracture_boss_started`). An empty encounter = nothing to fight.
func next_encounter() -> Encounter:
	var data: GameData = _session.data
	if run.groups_cleared < run.groups_total:
		return Encounter.of_defs(run.next_pack(_session.rng, data), data)
	var boss: BossDef = run.boss_def(data)
	if boss == null:
		return Encounter.new()
	run.boss_started = true
	boss_ability_ms = boss.ability.every_ms  # F-112: the first use is `every_ms` after the boss appears
	_session.events.fracture_boss_started.emit(boss.id)
	var scaled: Array[MonsterDef] = [FractureScaler.scale_monster(boss, run.grade, run.effects, data)]
	return Encounter.of_defs(scaled, data)


## Time passes during an encounter: the pulse timer runs.
func tick(ms: int) -> void:
	if run == null:
		return
	pulse_ms = maxi(0, pulse_ms - ms)
	if run.boss_started:
		boss_ability_ms = maxi(0, boss_ability_ms - ms)
		boss_shield_ms = maxi(0, boss_shield_ms - ms)
		if boss_shield_ms == 0:
			boss_shield = 0


## Time to the next use of the ability of the boss, `NO_TIMER` before the boss appears.
func next_boss_ms() -> int:
	return boss_ability_ms if run != null and run.boss_started else NO_TIMER


func ability_due(enemy: Encounter.Enemy) -> bool:
	return run != null and run.boss_started and enemy.alive() and boss_ability_ms <= 0 and is_boss(enemy)


func is_boss(enemy: Encounter.Enemy) -> bool:
	return enemy.def is ScaledMonsterDef and (enemy.def as ScaledMonsterDef).is_boss


## F-112: the ability of the boss is due. Restarts its timer. `heavy_strike` returns the attack to apply (`hit`, `blocked`,
## `damage`); `shield` (not renewed while one is up) and `summon` (into free or dead summoned slots) act at once and
## return `{}`. Returns the positions of the new enemies in `summoned`.
func use_ability(enemy: Encounter.Enemy, encounter: Encounter, me: CombatantStats, summoned: Array[int]) -> Dictionary:
	var data: GameData = _session.data
	var ability: BossAbilityDef = run.boss_def(data).ability
	boss_ability_ms = ability.every_ms
	match ability.type:
		BossAbilityDef.HEAVY_STRIKE:
			return BossAbility.heavy_strike(enemy.stats, me, ability, _session.rng, data)
		BossAbilityDef.SHIELD:
			if boss_shield <= 0:
				boss_shield = BossAbility.shield_amount(enemy.stats.max_hp, ability)
				boss_shield_ms = ability.duration_ms
		BossAbilityDef.SUMMON:
			_summon(ability, encounter, summoned)
	return {}


func _summon(ability: BossAbilityDef, encounter: Encounter, summoned: Array[int]) -> void:
	var data: GameData = _session.data
	var max_pack: int = int(data.balance_value("combat.max_pack_size"))
	var alive_summoned: int = 0
	for e: Encounter.Enemy in encounter.enemies:
		if e.summoned and e.alive():
			alive_summoned += 1
	var defs: Array[MonsterDef] = BossAbility.summon_defs(ability, alive_summoned, encounter.alive_count(), max_pack, run.grade,
			run.effects, data)
	for def: MonsterDef in defs:
		var fresh := Encounter.Enemy.new(def, data)
		fresh.summoned = true
		var slot: int = -1
		for i: int in encounter.enemies.size():  # a dead summoned enemy leaves its position free
			if encounter.enemies[i].summoned and not encounter.enemies[i].alive():
				slot = i
				break
		if slot < 0:
			encounter.enemies.append(fresh)
			slot = encounter.enemies.size() - 1
		else:
			encounter.enemies[slot] = fresh
		summoned.append(slot)


## The shield of the boss takes the damage first (F-112); returns what is left for the hp.
func absorb(enemy: Encounter.Enemy, damage: int) -> int:
	if run == null or boss_shield <= 0 or not is_boss(enemy):
		return damage
	var taken: int = mini(boss_shield, damage)
	boss_shield -= taken
	if boss_shield == 0:
		boss_shield_ms = 0
	return damage - taken


## What the kill of `enemy` did to the fight: `won` (the Fracture boss died), `cleared` (the group or encounter is beaten) or
## `` (it goes on). Outside a Fracture only `cleared` is possible.
func after_kill(enemy: Encounter.Enemy, encounter: Encounter) -> StringName:
	if run != null and enemy.def is ScaledMonsterDef and (enemy.def as ScaledMonsterDef).is_boss:
		return VERDICT_WON
	if encounter.alive_count() > 0:
		return &""
	if run != null and not run.boss_started:
		run.groups_cleared += 1
		_session.events.fracture_group_cleared.emit(run.groups_cleared, run.groups_total)
	return VERDICT_CLEARED


## The rewards of a killed enemy: xp, gold and drops into the Fracture bag, plus the Card of F-113. A summoned enemy gives
## nothing. True if it counts as a kill of a monster of the data (not summoned, not the boss).
func reward(enemy: Encounter.Enemy) -> bool:
	if enemy.summoned:
		return false
	KillRewards.grant(_session, _sink, enemy.def)
	if is_boss(enemy):  # F-115: the piece and the dust, then the Card of F-113 (no `card_chance_pct` on the boss)
		BossRewards.grant(_session, _sink, run, enemy.def)
		_roll_card(&"boss_pct", &"boss_delta", 0.0)
		return false
	_roll_card(&"monster_pct", &"monster_delta", _session.fractures.effect_total(FractureScaler.REWARD_CARD))
	return true


## F-113: `roll_pct(pct)`, then the grade offset by weight, then the rarity (F-109) and its modifiers.
func _roll_card(chance_key: StringName, delta_key: StringName, card_chance_pct: float) -> void:
	var pct: float = float(_session.data.balance_value("fracture.card_drop.%s" % chance_key)) * (1.0 + card_chance_pct / 100.0)
	if not _session.rng.roll_pct(pct):
		return
	var weights: Array[int] = []
	for weight: Variant in _session.data.balance_value("fracture.card_drop.%s" % delta_key) as Array:
		weights.append(int(weight))
	var grade: int = mini(10, run.grade + _session.rng.pick_weighted(weights))
	_sink.drop_card(grade)


## Time to the next pulse, `NO_TIMER` if the Card has no `pulse` risk.
func next_pulse_ms() -> int:
	return pulse_ms if _session.fractures.effect_total(FractureScaler.RISK_PULSE) > 0.0 else NO_TIMER


## F-111 `pulse`: damage `max(1, floor(max_hp x v/100))`; the roll is only the block (F-75). Restarts the timer.
func pulse_attack(me: CombatantStats) -> Dictionary:
	pulse_ms = int(_session.data.balance_value(PULSE_KEY))
	var v: float = _session.fractures.effect_total(FractureScaler.RISK_PULSE)
	var damage: int = maxi(1, floori(float(me.max_hp) * v / 100.0 + 1e-9))
	return Encounter.roll_pulse(damage, me, me.block_chance, _session.rng)


## `get_state()["fracture"]`.
func view() -> Dictionary:
	var boss: BossDef = run.boss_def(_session.data)
	return {"group": run.group, "groups": run.groups_total, "boss": run.boss_started,
		"boss_id": boss.id if run.boss_started and boss != null else &"", "boss_ability_ms": boss_ability_ms,
		"shield": boss_shield, "shield_ms": boss_shield_ms}


## `combat.fracture` of the save.
func to_save() -> Dictionary:
	return {"pulse_ms": pulse_ms, "boss": {"ability_ms": boss_ability_ms, "shield": boss_shield, "shield_ms": boss_shield_ms}}


## Tolerant: anything malformed counts as the start values.
func from_save(d: Dictionary) -> void:
	var pulse: Variant = d.get("pulse_ms")
	var boss: Variant = d.get("boss")
	pulse_ms = clampi(int(pulse), 0, int(_session.data.balance_value(PULSE_KEY))) \
			if pulse is int or pulse is float else pulse_ms
	if boss is Dictionary:
		boss_ability_ms = maxi(0, _int(boss, "ability_ms"))
		boss_shield = maxi(0, _int(boss, "shield"))
		boss_shield_ms = maxi(0, _int(boss, "shield_ms"))


static func _int(d: Dictionary, key: String) -> int:
	var v: Variant = d.get(key)
	return int(v) if v is int or v is float else 0
