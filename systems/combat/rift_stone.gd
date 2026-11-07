class_name RiftStone
extends RefCounted
## The Rift Stone of an area (docs/01_GDD.md §24, F-87): when it appears, its encounter and its rewards. State: `since`
## (kills of ordinary monsters since the last stone, the pity counter) and `pending` (the next encounter is the stone).
## The stone is an `Encounter.Enemy` with a pulse: its "attack" is `pulse_damage` every `pulse_ms` (`Encounter`),
## so the engine's timers need no special case. Everything random goes through `session.rng`.

const SHARD_ITEM: StringName = KillRewards.SHARD_ITEM
const STYLE_KEY: String = "combat.unarmed.style"  # the stone has the neutral style of the unarmed player
const CHANCE_KEY: String = "rift_stone.chance_pct"
const PITY_KEY: String = "rift_stone.pity_kills"

var since: int = 0
var pending: bool = false

var _session: GameSession


func _init(session: GameSession) -> void:
	_session = session


## F-87, after the kill of an ordinary monster in `area_id`: `since += 1`, and the stone appears when `since` reaches
## `rift_stone.pity_kills` or `roll_pct(rift_stone.chance_pct)` succeeds (no roll once the pity is reached). An area
## without stone, or a stone already pending, changes nothing (no counting, no roll).
func on_kill(area_id: StringName) -> void:
	var def: RiftStoneDef = _session.data.rift_stone_for_area(area_id)
	if def == null or pending:
		return
	since += 1
	if since >= int(_session.data.balance_value(PITY_KEY)) or _session.rng.roll_pct(chance_pct(area_id)):
		since = 0
		pending = true
		_session.events.rift_stone_appeared.emit(def.id)


## F-87 (Q46): the chance of the stone of `area_id`: the `rift_stone_chance_pct` of the area or else the global one.
func chance_pct(area_id: StringName) -> float:
	var own: float = _session.data.area(area_id).rift_stone_chance_pct
	return own if own >= 0.0 else float(_session.data.balance_value(CHANCE_KEY))


## The next encounter of `area_id`: the pending stone (the stone first, then the summoned pack if any; consumed) or
## else a pack drawn by F-77.
func next_encounter(area_id: StringName) -> Encounter:
	var def: RiftStoneDef = _session.data.rift_stone_for_area(area_id)
	if not pending or def == null:
		pending = false
		return Encounter.spawn(_session.data.area(area_id), _session.data, _session.rng)
	pending = false
	var result := Encounter.new()
	result.enemies.append(enemy(def, _session.data))
	if def.summon_pack >= 0:
		for monster_id: StringName in _session.data.area(area_id).packs[def.summon_pack].monster_ids:
			result.enemies.append(Encounter.Enemy.new(_session.data.monster(monster_id), _session.data))
	return result


static func enemy(def: RiftStoneDef, data: GameData) -> Encounter.Enemy:
	var style := StringName(str(data.balance_value(STYLE_KEY)))
	return Encounter.Enemy.new(def.to_monster(style), data, def.pulse_damage)


## Rewards of the killed stone of `area_id`: xp (F-28), shards in its range, drops (F-32) with the rarity of the
## stone (F-84) and the item level of the highest monster of the area.
func reward(loot: LootBag, area_id: StringName) -> void:
	var def: RiftStoneDef = _session.data.rift_stone_for_area(area_id)
	if def == null:
		return
	_session.character.add_xp(KillRewards.base_xp(_session, def.xp))
	loot.add(SHARD_ITEM, _session.rng.randi_range(def.shards_min, def.shards_max))
	KillRewards.roll_drops(_session, loot, def.drops, ItemRoller.SOURCE_RIFT_STONE, _area_ilvl(area_id))


func reset() -> void:
	since = 0
	pending = false


func to_save() -> Dictionary:
	return {"since": since, "pending": pending}


## Tolerant: anything malformed counts as 0 / false.
func from_save(d: Variant) -> void:
	reset()
	if not d is Dictionary:
		return
	var saved: Dictionary = d
	since = maxi(0, int(saved["since"])) if saved.get("since") is int or saved.get("since") is float else 0
	pending = saved.get("pending") == true


func _area_ilvl(area_id: StringName) -> int:
	var best: int = 1
	for monster_id: StringName in _session.data.area(area_id).monster_ids:
		best = maxi(best, KillRewards.monster_ilvl(_session.data.monster(monster_id)))
	return best
