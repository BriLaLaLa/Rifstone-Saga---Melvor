class_name ConditionKit
extends RefCounted
## Test helpers of M28-03: a scripted random source, a fake effect that drives every new hook of the engine (the real types arrive
## with M28-05, so these tests use no data of the game), and a session in a controlled fight on the fixture data.

const MONSTER_A: String = "test_monster_a"  # 20 hp, blade, no reduction, interval 2800
const MONSTER_B: String = "test_monster_b"  # 60 hp, arcana, interval 2400


## Hits always (`randf` = 0), draws the scripted integers in order (then the lower bound), never rolls a percentage in the player's
## favour. `calls` counts every draw.
class ScriptRng extends RngService:
	var ints: Array[int] = []
	var calls: int = 0

	func _init() -> void:
		super(1)

	func randf() -> float:
		calls += 1
		return 0.0

	func randi_range(from: int, _to: int) -> int:
		calls += 1
		return ints.pop_front() if not ints.is_empty() else from

	func roll_pct(_chance_pct: float) -> bool:
		calls += 1
		return false


## One effect with a field for every new hook. The hooks it sees are written to `seen` as {"hook", ...ctx fields}.
class Fake extends TraitEffect:
	var hit: float = 1.0  # hit_mult
	var incoming: float = 1.0  # incoming_mult
	var amount: float = 1.0  # amount_mult
	var timer: float = 1.0  # base_timer_mult
	var counter: float = 0.0  # on_block and on_evade: counter_mult
	var ward_pct: float = 0.0  # on_kill and on_block: the Ward
	var ward_ms: int = 0
	var cut_ms: int = 0  # on_kill: kill_cooldown_cut
	var applies: Array[ConditionApply] = []  # on_hit
	var seen: Array[Dictionary] = []

	func _init(id: StringName = &"fake") -> void:
		super(id, {})

	func hit_mult(ctx: EffectContext) -> float:
		seen.append({"hook": "hit_mult", "kind": ctx.hit_kind, "target": ctx.target_index, "primary": ctx.primary_index,
			"alive": ctx.alive_count, "ability_kind": ctx.ability_kind})
		return hit

	func incoming_mult(_ctx: EffectContext) -> float:
		return incoming

	func amount_mult(ctx: EffectContext) -> float:
		seen.append({"hook": "amount_mult", "ability_kind": ctx.ability_kind})
		return amount

	func base_timer_mult(_ctx: EffectContext) -> float:
		return timer

	func on_hit(ctx: EffectContext, damage: int) -> void:
		seen.append({"hook": "on_hit", "kind": ctx.hit_kind, "target": ctx.target_index, "damage": damage, "ctx_damage": ctx.damage,
			"hp": ctx.target_hp, "base": ctx.base_attack})
		ctx.applies.append_array(applies)

	func on_block(ctx: EffectContext) -> void:
		seen.append({"hook": "on_block", "source": ctx.source_index})
		ctx.counter_mult = maxf(ctx.counter_mult, counter)
		_ward(ctx)

	func on_evade(ctx: EffectContext) -> void:
		seen.append({"hook": "on_evade", "source": ctx.source_index})
		ctx.counter_mult = maxf(ctx.counter_mult, counter)

	func on_kill(ctx: EffectContext) -> void:
		seen.append({"hook": "on_kill", "target": ctx.target_index})
		ctx.cooldown_cut_ms += cut_ms
		_ward(ctx)

	func on_ability(ctx: EffectContext) -> void:
		seen.append({"hook": "on_ability", "ability_kind": ctx.ability_kind})

	func on_damaged(ctx: EffectContext, damage: int) -> void:
		seen.append({"hook": "on_damaged", "damage": damage, "source": ctx.source_index})

	func _ward(ctx: EffectContext) -> void:
		if ward_pct > ctx.ward_pct:
			ctx.ward_pct = ward_pct
			ctx.ward_ms = ward_ms

	func hooks(name: String) -> Array[Dictionary]:
		var out: Array[Dictionary] = []
		for entry: Dictionary in seen:
			if entry["hook"] == name:
				out.append(entry)
		return out


## A session in a fight of `test_area` (the save of `EffectKit.fight`), a player with `max_hp_extra` more hp and a scripted random
## source. The player's own timer is far away unless given.
static func session(enemies: Array, player_timer_ms: int = 100000, max_hp_extra: int = 100000, player_hp: int = -1) -> GameSession:
	var s: GameSession = base(max_hp_extra)
	begin(s, enemies, player_timer_ms, 60 + max_hp_extra if player_hp < 0 else player_hp)
	return s


## The session of `session` before the fight (the loadout can only be changed outside of one).
static func base(max_hp_extra: int = 100000) -> GameSession:
	var s: GameSession = TestFactory.session(1)
	s.modifiers.set_source(&"test:sturdy", [Modifier.make(&"max_hp_flat", float(max_hp_extra))] as Array[Modifier])
	s.rng = ScriptRng.new()
	return s


static func begin(s: GameSession, enemies: Array, player_timer_ms: int, player_hp: int) -> void:
	s.combat.from_save(EffectKit.fight(enemies, player_timer_ms, player_hp))


## Adds a fake effect to the effects of the fight (it lasts until the loadout changes or the combat is reset).
static func install(s: GameSession, fake: Fake) -> Fake:
	s.combat._fx.effects().append(fake)
	return fake


static func apply(kind: StringName, pct: float, ms: int) -> ConditionApply:
	var app := ConditionApply.new()
	app.condition = kind
	app.pct = pct
	app.ms = ms
	return app


## The conditions of the enemy at `index`.
static func cond(s: GameSession, index: int) -> EnemyConditions:
	return s.combat._encounter.enemies[index].conditions


## Records `combat_condition_damage` and the hits as [time_ms, kind, a, b, c] rows; the time is `clock["t"]` (the test sets it to the
## time at the start of each `advance`) plus the offset inside that `advance`.
static func record(s: GameSession, rows: Array, clock: Dictionary = {}) -> void:
	s.events.combat_condition_damage.connect(func(t: int, d: int, c: StringName) -> void:
		rows.append([int(clock.get("t", 0)) + s.combat.advance_offset_ms, "tick", t, d, String(c)]))
	s.events.combat_hit.connect(func(a: int, t: int, h: bool, d: int, b: bool) -> void:
		rows.append([int(clock.get("t", 0)) + s.combat.advance_offset_ms, "hit", a, t, h, d, b]))
