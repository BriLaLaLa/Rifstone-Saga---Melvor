class_name KillRewards
extends RefCounted
## What a killed enemy gives (docs/05_INTERFACES.md §5.10), in this order: xp (F-28), gold (F-31), drops in data order
## (F-32, one probability roll then one quantity roll per entry), shard (F-07). Split from `CombatEngine` for size.

const SHARD_ITEM: StringName = &"rift_shard"
const EPSILON: float = 1e-9


static func grant(session: GameSession, loot: LootBag, def: MonsterDef) -> void:
	session.character.add_xp(def.xp)
	var gold_pct: float = session.modifiers.total(&"gold_drop_pct")
	var rolled: int = session.rng.randi_range(def.gold_min, def.gold_max)
	session.wallet.add_gold(int(floor(float(rolled) * (1.0 + gold_pct / 100.0) + EPSILON)))
	for drop: DropEntry in def.drops:
		if session.rng.roll_pct(drop.chance_pct):
			loot.add(drop.item_id, session.rng.randi_range(drop.qty_min, drop.qty_max))
	var shard_pct: float = def.rift_shard_chance + session.modifiers.total(&"rift_shard_chance")
	if session.rng.roll_pct(shard_pct):
		loot.add(SHARD_ITEM, 1)
