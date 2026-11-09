class_name Rarities
extends RefCounted
## The five rarities of a piece (docs/01_GDD.md §28.4, docs/02_FORMULAS.md F-84, F-119, F-120): common, magic and rare
## are rolled by the drops; `masterwork` and `legendary` are fixed by the base (`equip.masterwork`, `equip.legendary`).
## Pure functions over balance.json (`rarity.*`).

const COMMON: StringName = &"common"
const MAGIC: StringName = &"magic"
const RARE: StringName = &"rare"
const MASTERWORK: StringName = &"masterwork"
const LEGENDARY: StringName = &"legendary"
## Ascending order (the filter of the Armory, the sorting, the UI).
const ORDER: Array[StringName] = [&"common", &"magic", &"rare", &"masterwork", &"legendary"]


static func is_valid(rarity: StringName) -> bool:
	return ORDER.has(rarity)


## Position in `ORDER`, -1 for an unknown rarity.
static func index(rarity: StringName) -> int:
	return ORDER.find(rarity)


## True for the rarities that a base imposes (never rolled by a drop).
static func is_fixed(rarity: StringName) -> bool:
	return rarity == MASTERWORK or rarity == LEGENDARY


## The rarity a base imposes: masterwork, legendary, or &"" when it is rolled.
static func of_base(base: ItemDef) -> StringName:
	if base == null or base.equip == null:
		return &""
	if base.equip.legendary != null:
		return LEGENDARY
	return MASTERWORK if base.equip.masterwork else &""


## F-119 / F-120: `rarity.<r>.base_mult` for masterwork and legendary, 1 for the others.
static func base_mult(rarity: StringName, data: GameData) -> float:
	if is_fixed(rarity):
		return float(data.balance_value("rarity.%s.base_mult" % rarity))
	return 1.0


## Affix count range [min, max] of the rarity: `rarity.masterwork.affix_count`, `rarity.affix_count.<r>`; (0, 0) for
## common and legendary.
static func affix_range(rarity: StringName, data: GameData) -> Vector2i:
	if rarity == COMMON or rarity == LEGENDARY:
		return Vector2i.ZERO
	var key: String = "rarity.masterwork.affix_count" if rarity == MASTERWORK else "rarity.affix_count.%s" % rarity
	var raw: Variant = data.balance_value(key)
	if not raw is Array or (raw as Array).size() != 2:
		return Vector2i.ZERO
	return Vector2i(int((raw as Array)[0]), int((raw as Array)[1]))
