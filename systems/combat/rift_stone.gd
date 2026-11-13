class_name RiftStone
extends RefCounted
## The Rift Stones of an area (docs/01_GDD.md §24b, F-87, M15): when one appears, which one, its encounter and its rewards.
## State: `since` (kills of ordinary monsters since the last stone, the pity counter), `pending` (the next encounter is the
## stone) with `stone_id` (the stone drawn when it appeared), `fired` (the wave thresholds already fired in the stone fight,
## F-126) and `skip_level` (F-128, the slot setting "skip the stones up to level X"; 0 = off).
## The stone is an `Encounter.Enemy` with a fixed pulse (`metin.pulse_damage`, F-125): its "attack" is the pulse every
## `pulse_ms`, so the engine's timers need no special case. Its summoned waves are `StoneFight`. Everything random goes
## through `session.rng`.

const SHARD_ITEM: StringName = KillRewards.SHARD_ITEM
const STYLE_KEY: String = "combat.unarmed.style"  # the stone has the neutral style of the unarmed player
const CHANCE_KEY: String = "rift_stone.chance_pct"
const PITY_KEY: String = "rift_stone.pity_kills"
const LOG_CATEGORY: String = "combat"

var since: int = 0
var pending: bool = false
var stone_id: StringName = &""
var fired: Array[int] = []
var skip_level: int = 0

var _session: GameSession


func _init(session: GameSession) -> void:
	_session = session


## F-87, after the kill of an ordinary monster in `area_id`: `since += 1`, and the stone appears when `since` reaches
## `rift_stone.pity_kills` or `roll_pct(rift_stone.chance_pct)` succeeds (no roll once the pity is reached); then one stone of
## the pool of the area is drawn (uniform). An area without stone, or a stone already pending, changes nothing (no counting,
## no roll). A stone at or under the skip level (F-128) is discarded at once: `rift_stone_skipped`, no appearance.
func on_kill(area_id: StringName) -> void:
	var pool: Array[RiftStoneDef] = _session.data.rift_stones_for_area(area_id)
	if pool.is_empty() or pending:
		return
	since += 1
	if since >= int(_session.data.balance_value(PITY_KEY)) or _session.rng.roll_pct(chance_pct(area_id)):
		since = 0
		var def: RiftStoneDef = _draw(pool)
		if is_skipped(def):
			_session.events.rift_stone_skipped.emit(def.id)
			return
		pending = true
		stone_id = def.id
		_session.events.rift_stone_appeared.emit(def.id)


## F-87 (Q46): the chance of the stone of `area_id`: the `rift_stone_chance_pct` of the area or else the global one.
func chance_pct(area_id: StringName) -> float:
	var own: float = _session.data.area(area_id).rift_stone_chance_pct
	return own if own >= 0.0 else float(_session.data.balance_value(CHANCE_KEY))


## F-128: true if `def` is at or under the skip level.
func is_skipped(def: RiftStoneDef) -> bool:
	return skip_level != 0 and def.level <= skip_level


## The next encounter of `area_id`: the pending stone alone (consumed; its waves come with the hits) or else a pack drawn by
## F-77. A pending stone of another area is drawn again from the pool of `area_id`; a pending stone at or under the skip level
## (F-128) is discarded (`rift_stone_skipped`, `since` = 0) and the pack is drawn.
func next_encounter(area_id: StringName) -> Encounter:
	var pool: Array[RiftStoneDef] = _session.data.rift_stones_for_area(area_id)
	var def: RiftStoneDef = null
	if pending and not pool.is_empty():
		def = _session.data.rift_stone(stone_id) if _session.data.has_rift_stone(stone_id) else null
		if def == null or def.area_id != area_id:
			def = _draw(pool)
	var was_pending: bool = pending
	pending = false
	stone_id = &""
	fired = []
	if def != null and is_skipped(def):
		since = 0
		_session.events.rift_stone_skipped.emit(def.id)
		def = null
	if def == null:
		if was_pending:
			since = 0
		return Encounter.spawn(_session.data.area(area_id), _session.data, _session.rng)
	var result := Encounter.new()
	result.enemies.append(enemy(def, _session.data))
	return result


static func enemy(def: RiftStoneDef, data: GameData) -> Encounter.Enemy:
	var style := StringName(str(data.balance_value(STYLE_KEY)))
	var monster: MonsterDef = def.to_monster(style, StoneFight.max_hp(def.level, data))
	return Encounter.Enemy.new(monster, data, StoneFight.pulse_damage(data))


## F-126 for a hit that left `enemy` (the stone) with `enemy.hp`: the thresholds newly crossed, remembered as fired.
func crossed(enemy: Encounter.Enemy) -> Array[int]:
	var result: Array[int] = StoneFight.waves_crossed(enemy.hp, enemy.stats.max_hp, fired, StoneFight.thresholds(_session.data))
	fired.append_array(result)
	return result


## For `get_state`: `{"id", "level", "hp", "max_hp", "fired"}` of the stone of `encounter`, `{}` without one.
func view(encounter: Encounter) -> Dictionary:
	for e: Encounter.Enemy in encounter.enemies:
		if e.is_stone():
			var level: int = _session.data.rift_stone(e.def.id).level if _session.data.has_rift_stone(e.def.id) else 0
			return {"id": e.def.id, "level": level, "hp": e.hp, "max_hp": e.stats.max_hp, "fired": fired.duplicate()}
	return {}


## Rewards of the killed stone `def`: xp (F-28), shards in its range, drops (F-32) with the rarity of the stone (F-84) and the
## item level of the highest monster of the area, the loot tables, the legendaries of the area (F-120), then the guaranteed
## piece and the Blueprint roll (F-127).
func reward(loot: LootSink, def: RiftStoneDef, loot_mult: float = 1.0) -> void:
	_session.character.add_xp(KillRewards.base_xp(_session, def.xp, def.level))  # F-130: level of the stone
	var sink: LootSink = ScaledSink.new(loot, loot_mult) if loot_mult != 1.0 else loot  # F-120 monolith_loot_mult
	sink.add(SHARD_ITEM, _session.rng.randi_range(def.shards_min, def.shards_max))
	var ilvl: int = _area_ilvl(def.area_id)
	KillRewards.roll_drops(_session, sink, def.drops, ItemRoller.SOURCE_RIFT_STONE, ilvl)
	KillRewards.roll_tables(_session, sink, def.loot_tables, ItemRoller.SOURCE_RIFT_STONE, ilvl)
	# F-120 (M15): a Monolith source is the area id, so any stone of the area can drop the legendary.
	for piece: ItemInstance in LegendaryRoller.drops(LegendaryInfo.SOURCE_MONOLITH, def.area_id, _session.data, _session.rng):
		loot.add_piece(piece)
	MonolithLoot.grant(_session, sink, def.level)


func reset() -> void:
	since = 0
	pending = false
	stone_id = &""
	fired = []
	skip_level = _initial_skip()


func to_save() -> Dictionary:
	return {"since": since, "pending": pending, "stone_id": String(stone_id) if pending else ""}


## The thresholds already fired, for `modules.combat.wave` (docs/05_INTERFACES.md §6).
func wave_to_save() -> Dictionary:
	return {"fired": fired.duplicate()}


## Tolerant: anything malformed counts as 0 / false / empty; an unknown `stone_id` drops the pending flag. The skip level is
## not touched (it is read by the engine).
func from_save(d: Variant) -> void:
	var level: int = skip_level
	reset()
	skip_level = level
	if not d is Dictionary:
		return
	var saved: Dictionary = d
	since = maxi(0, int(saved["since"])) if saved.get("since") is int or saved.get("since") is float else 0
	pending = saved.get("pending") == true
	stone_id = StringName(str(saved.get("stone_id", "")))
	if pending and not _session.data.has_rift_stone(stone_id):
		Log.warn(LOG_CATEGORY, "saved pending Rift Stone '%s' is unknown: dropped" % stone_id)
		pending = false
		stone_id = &""


## Tolerant: a malformed `wave` is empty; unknown thresholds are dropped.
func wave_from_save(d: Variant) -> void:
	fired = []
	if not d is Dictionary or not (d as Dictionary).get("fired") is Array:
		return
	var valid: Array[int] = StoneFight.thresholds(_session.data)
	for entry: Variant in ((d as Dictionary)["fired"] as Array):
		if (entry is int or entry is float) and valid.has(int(entry)) and not fired.has(int(entry)):
			fired.append(int(entry))


func _initial_skip() -> int:
	return clampi(int(_session.data.balance_value("combat.skip_stone_level")), 0, 99)


# Uniform draw (F-87, Z2).
func _draw(pool: Array[RiftStoneDef]) -> RiftStoneDef:
	return pool[_session.rng.randi_range(0, pool.size() - 1)]


func _area_ilvl(area_id: StringName) -> int:
	var best: int = 1
	for monster_id: StringName in _session.data.area(area_id).monster_ids:
		best = maxi(best, KillRewards.monster_ilvl(_session.data.monster(monster_id)))
	return best
