class_name BossRewards
extends RefCounted
## The guaranteed rewards of a Fracture boss (docs/02_FORMULAS.md F-115): one piece at least magic and the Rift Dust, into
## the bag of the Fracture through the sink. The drops of the boss (F-32) and the Card (F-113) are rolled by the caller.

const LOG_CATEGORY: String = "fracture"
const DUST_ITEM: StringName = &"rift_dust"


## Rolls, in order: the base of the piece, its rarity (a common one becomes magic), its affixes (F-85, `ilvl` of the boss),
## then the dust quantity.
static func grant(session: GameSession, sink: LootSink, run: FractureRun, boss: MonsterDef) -> void:
	var data: GameData = session.data
	var grade: int = data.fracture_grade(run.grade).piece_grade
	var bases: Array[ItemDef] = piece_bases(session.character.class_def(), grade, data)
	if bases.is_empty():
		Log.warn(LOG_CATEGORY, "no equipment base of grade %d for the boss piece" % grade)
	else:
		var base: ItemDef = bases[session.rng.randi_range(0, bases.size() - 1)]
		var chances: Vector2 = ItemRoller.drop_chances(ItemRoller.SOURCE_MONSTER,
				session.modifiers.total(KillRewards.RARITY_STAT), data)
		var rarity: StringName = ItemRoller.roll_rarity(chances, session.rng)
		if rarity == &"common":
			rarity = &"magic"
		sink.add_piece(ItemRoller.create(base, rarity, KillRewards.monster_ilvl(boss), data, session.rng))
	var def: BossDef = boss if boss is BossDef else run.boss_def(data)
	var dust: int = session.rng.randi_range(def.dust_min, def.dust_max)
	sink.add(DUST_ITEM, dust_qty(dust, FractureScaler.total(run.effects, FractureScaler.REWARD_DUST)))
	for piece: ItemInstance in LegendaryRoller.drops(LegendaryInfo.SOURCE_BOSS, def.id, data, session.rng):
		sink.add_piece(piece)  # F-120: with the bag of the Fracture; lost with it on a defeat


## F-115: `dust x (1 + dust_pct / 100)`, rounded.
static func dust_qty(dust: int, dust_pct: float) -> int:
	return int(round(float(dust) * (1.0 + dust_pct / 100.0)))


## The `equipment` bases of `grade` that `class_def` can wear: a weapon or offhand of an allowed kind, any other slot.
static func piece_bases(class_def: ClassDef, grade: int, data: GameData) -> Array[ItemDef]:
	var result: Array[ItemDef] = []
	for def: ItemDef in data.items():
		if def.category != &"equipment" or def.equip == null or def.equip.grade != grade or not data.is_equipment_pool_base(def.id):
			continue
		if def.equip.slot == &"weapon" and (class_def == null or not class_def.weapon_kinds.has(def.equip.kind)):
			continue
		if def.equip.slot == &"offhand" and (class_def == null or not class_def.offhand_kinds.has(def.equip.kind)):
			continue
		result.append(def)
	return result
