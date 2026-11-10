class_name MonolithLoot
extends RefCounted
## F-127 (docs/02_FORMULAS.md §5f): the guaranteed piece and the Blueprint roll of a destroyed Rift Stone. The shards, the
## drops, the loot tables and the legendaries are rolled by `RiftStone.reward`.


## The guaranteed piece of a stone of `level`: F-121 without the probability roll (type, material, grade from the window of
## `level`), rarity as F-84 with the source `rift_stone` and `item_rarity_pct` raised by `metin.rarity_bonus_pct`, affixes
## as F-85 at item level `level`. Null (after a warning) if the pool has no grade for `level`.
static func guaranteed_piece(level: int, rng: RngService, session: GameSession) -> ItemInstance:
	var data: GameData = session.data
	var base_id: StringName = EquipmentDrop.pick(level, data, rng)
	if base_id == &"":
		Log.warn("combat", "no equipment grade for a Rift Stone of level %d: no guaranteed piece" % level)
		return null
	var bonus: float = float(data.balance_value("metin.rarity_bonus_pct"))
	var chances: Vector2 = ItemRoller.drop_chances(ItemRoller.SOURCE_RIFT_STONE,
			session.modifiers.total(KillRewards.RARITY_STAT) + bonus, data)
	var rarity: StringName = ItemRoller.roll_rarity(chances, rng)
	return ItemRoller.create(data.item(base_id), rarity, level, data, rng)


## `metin.guaranteed_pieces` pieces to the sink, then one Blueprint roll (F-121, `L_m` = `level`).
static func grant(session: GameSession, sink: LootSink, level: int) -> void:
	for _i: int in int(session.data.balance_value("metin.guaranteed_pieces")):
		var piece: ItemInstance = guaranteed_piece(level, session.rng, session)
		if piece != null:
			sink.add_piece(piece)
	var blueprint_id: StringName = EquipmentDrop.roll_blueprint(level, session.data, session.rng)
	if blueprint_id != &"":
		sink.add(blueprint_id, 1)
