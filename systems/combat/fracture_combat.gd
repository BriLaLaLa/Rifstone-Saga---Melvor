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
	_session.events.fracture_boss_started.emit(boss.id)
	var scaled: Array[MonsterDef] = [FractureScaler.scale_monster(boss, run.grade, run.effects, data)]
	return Encounter.of_defs(scaled, data)


## Time passes during an encounter: the pulse timer runs.
func tick(ms: int) -> void:
	if run != null:
		pulse_ms = maxi(0, pulse_ms - ms)


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
	if enemy.def is ScaledMonsterDef and (enemy.def as ScaledMonsterDef).is_boss:
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
