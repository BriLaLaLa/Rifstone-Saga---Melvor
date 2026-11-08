class_name KillRewards
extends RefCounted
## What a killed enemy gives (docs/05_INTERFACES.md §5.10), in this order: xp (F-28), gold (F-31), drops in data order
## (F-32, one probability roll then one quantity roll per entry), shard (F-07). A drop of a piece (equipment or tool)
## creates `qty` instances (F-84: after the quantity roll, per instance one rarity roll then the affix rolls of F-85)
## that go to the Armory through `add_drop`; any other item goes to the loot bag. Split from `CombatEngine` for size.

const SHARD_ITEM: StringName = &"rift_shard"
const RARITY_STAT: StringName = &"item_rarity_pct"
const EPSILON: float = 1e-9


## F-28: floor(xp x combat.kill_xp_mult); F-71 is applied afterwards by `CharacterSystem.add_xp`.
static func base_xp(session: GameSession, xp: int) -> int:
	return floori(float(xp) * float(session.data.balance_value("combat.kill_xp_mult")) + EPSILON)


## `area_id` is the area of the fight: its loot tables are rolled after the own drops, then those of the monster (M12, 05 §5.22).
static func grant(session: GameSession, loot: LootBag, def: MonsterDef, area_id: StringName = &"") -> void:
	session.character.add_xp(base_xp(session, def.xp))
	var gold_pct: float = session.modifiers.total(&"gold_drop_pct")
	var rolled: int = session.rng.randi_range(def.gold_min, def.gold_max)
	session.wallet.add_gold(int(floor(float(rolled) * (1.0 + gold_pct / 100.0) + EPSILON)))
	roll_drops(session, loot, def.drops, ItemRoller.SOURCE_MONSTER, monster_ilvl(def))
	if area_id != &"":
		roll_tables(session, loot, session.data.area(area_id).loot_tables, ItemRoller.SOURCE_MONSTER, monster_ilvl(def))
	roll_tables(session, loot, def.loot_tables, ItemRoller.SOURCE_MONSTER, monster_ilvl(def))
	var shard_pct: float = def.rift_shard_chance + session.modifiers.total(&"rift_shard_chance")
	if session.rng.roll_pct(shard_pct):
		loot.add(SHARD_ITEM, 1)


## F-32 / F-84. `source` is the rarity source of `ItemRoller.drop_chances`, `ilvl` the item level of the pieces.
static func roll_drops(session: GameSession, loot: LootBag, drops: Array[DropEntry], source: StringName, ilvl: int
) -> void:
	for drop: DropEntry in drops:
		if not session.rng.roll_pct(drop.chance_pct):
			continue
		var qty: int = session.rng.randi_range(drop.qty_min, drop.qty_max)
		var base: ItemDef = session.data.item(drop.item_id)
		if base.equip == null:
			loot.add(drop.item_id, qty)
			continue
		for _i: int in qty:
			session.armory.add_drop(roll_piece(session, base, source, ilvl))


## One new piece: rarity from F-84 (with `item_rarity_pct`), affixes from F-85.
static func roll_piece(session: GameSession, base: ItemDef, source: StringName, ilvl: int) -> ItemInstance:
	var chances: Vector2 = ItemRoller.drop_chances(source, session.modifiers.total(RARITY_STAT), session.data)
	var rarity: StringName = ItemRoller.roll_rarity(chances, session.rng)
	return ItemRoller.create(base, rarity, ilvl, session.data, session.rng)


## F-85 "livello del mostro": the highest of its three combat levels (the data has no single level; request to the
## Reviewer in the M7-03 report).
static func monster_ilvl(def: MonsterDef) -> int:
	return maxi(def.attack_level, maxi(def.power_level, def.defence_level))


## M12: the entries of the loot tables `table_ids`, in order, each rolled like a drop (F-32): a probability roll, then a
## quantity roll. Tables hold no equipment, so the items go to the loot bag. No table, no roll.
static func roll_tables(session: GameSession, loot: LootBag, table_ids: Array[StringName], source: StringName, ilvl: int
) -> void:
	for table_id: StringName in table_ids:
		roll_drops(session, loot, session.data.loot_table(table_id).entries, source, ilvl)
