class_name DungeonRewards
extends RefCounted
## The rewards of a dungeon that are not kill drops (docs/02_FORMULAS.md F-142, F-143): the prize of a room or of a stage and
## the loot of the final boss. Pure logic: gold goes to the wallet, everything else to the sink (the bag of the run).
## Every number comes from the DungeonDef; the order of the rolls on the generator of the slot is fixed (tests).

const LOG_CATEGORY: String = "dungeon"
const DUST_ITEM: StringName = &"rift_dust"
const CURRENCY_CATEGORY: StringName = &"currency"


## A sink that puts everything in `bag` and tells the UI (`dungeon_bag_changed`). The sink of the kills of the engine is
## `DungeonSink` (M22-05); this one is used for the prizes of this module.
class BagSink:
	extends LootSink

	var _session: GameSession
	var _bag: FractureBag

	func _init(session: GameSession, bag: FractureBag) -> void:
		_session = session
		_bag = bag

	func add(item_id: StringName, qty: int) -> bool:
		_bag.add_stack(item_id, qty)
		_changed()
		return true

	func add_piece(inst: ItemInstance) -> void:
		_bag.add_piece(inst)
		_changed()

	func drop_card(grade: int) -> void:
		var card: MapCard = MapCardRoller.create(grade, _session.cards.roll_rarity(), _session.data, _session.rng)
		if card != null:
			_bag.add_card(card)
			_changed()

	func _changed() -> void:
		var counts: Dictionary = _bag.counts()
		_session.events.dungeon_bag_changed.emit(counts["stacks"], counts["pieces"], counts["cards"])


## F-142: the prize of a room or of a stage, every key optional, in this order: gold (wallet), Dust, one Crystal with
## `crystal_pct`, one piece with `piece_pct` (F-121 steps 2-3 at `level`, at least magic).
static func room_reward(reward: Dictionary, level: int, sink: LootSink, session: GameSession) -> void:
	var rng: RngService = session.rng
	if reward.has("gold"):
		var gold: Vector2i = reward["gold"]
		session.wallet.add_gold(rng.randi_range(gold.x, gold.y))
	if reward.has("dust"):
		var dust: Vector2i = reward["dust"]
		sink.add(DUST_ITEM, rng.randi_range(dust.x, dust.y))
	if reward.has("crystal_pct") and rng.roll_pct(float(reward["crystal_pct"])):
		_crystal(session, sink)
	if reward.has("piece_pct") and rng.roll_pct(float(reward["piece_pct"])):
		_piece(session, sink, level, &"", Rarities.MAGIC)


## F-143 points 1-7, in order, into the sink: gold, Dust, the pieces, the Crystals, the Card, the drops of the boss and the
## legendaries of the dungeon (one `roll_pct` each). `level` of the pieces = the level of the monster of the last stage.
static func boss_loot(session: GameSession, sink: LootSink, def: DungeonDef) -> void:
	var rng: RngService = session.rng
	var boss: MonsterDef = def.stages[def.stages.size() - 1].monster
	var level: int = EquipmentPool.monster_level(boss)
	session.wallet.add_gold(rng.randi_range(def.boss_gold.x, def.boss_gold.y))
	var dust: int = rng.randi_range(def.boss_dust.x, def.boss_dust.y)
	sink.add(DUST_ITEM, BossRewards.dust_qty(dust, 0.0))  # no stat raises it: `dust_pct` is a Card reward (F-111)
	for rule: Dictionary in def.boss_pieces:
		_piece(session, sink, level, rule.get("rarity", &""), rule.get("min_rarity", Rarities.MAGIC))
	for _i: int in def.boss_crystals:
		_crystal(session, sink)
	if rng.roll_pct(def.boss_card_pct):
		sink.drop_card(def.boss_card_grade)
	KillRewards.roll_drops(session, sink, def.boss_drops, ItemRoller.SOURCE_MONSTER, KillRewards.monster_ilvl(boss))
	for piece: ItemInstance in LegendaryRoller.drops(LegendaryInfo.SOURCE_DUNGEON, def.id, session.data, rng):
		sink.add_piece(piece)


## The currency items (Crystals) of the data, in order: a Crystal is uniform among them.
static func crystal_ids(data: GameData) -> Array[StringName]:
	var result: Array[StringName] = []
	for item: ItemDef in data.items():
		if item.category == CURRENCY_CATEGORY:
			result.append(item.id)
	return result


static func _crystal(session: GameSession, sink: LootSink) -> void:
	var ids: Array[StringName] = crystal_ids(session.data)
	if ids.is_empty():
		Log.warn(LOG_CATEGORY, "no Crystal in the data: the reward is skipped")
		return
	sink.add(ids[session.rng.randi_range(0, ids.size() - 1)], 1)


# F-121 steps 2-3 at `level`; the rarity is `fixed` or rolled as F-84 and raised to at least `at_least`; affixes F-85 at `level`.
static func _piece(session: GameSession, sink: LootSink, level: int, fixed: StringName, at_least: StringName) -> void:
	var base_id: StringName = EquipmentDrop.pick(level, session.data, session.rng)
	if base_id == &"":
		Log.warn(LOG_CATEGORY, "no equipment grade for level %d: the piece is skipped" % level)
		return
	var rarity: StringName = fixed
	if rarity == &"":
		var chances: Vector2 = ItemRoller.drop_chances(ItemRoller.SOURCE_MONSTER,
				session.modifiers.total(KillRewards.RARITY_STAT), session.data)
		rarity = ItemRoller.roll_rarity(chances, session.rng)
		if Rarities.ORDER.find(rarity) < Rarities.ORDER.find(at_least):
			rarity = at_least
	sink.add_piece(ItemRoller.create(session.data.item(base_id), rarity, level, session.data, session.rng))
