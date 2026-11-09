class_name RarityColors
extends RefCounted
## Colors of the five rarities (docs/01_GDD.md §28.4): white, blue, yellow, purple (Masterwork), orange (Legendary).
## The constants live in `UiStyle`; `UiStyle.rarity_color` answers with this function.

static func color(rarity: StringName) -> Color:
	match rarity:
		Rarities.COMMON:
			return UiStyle.RARITY_COMMON
		Rarities.MAGIC:
			return UiStyle.RARITY_MAGIC
		Rarities.RARE:
			return UiStyle.RARITY_RARE
		Rarities.MASTERWORK:
			return UiStyle.RARITY_MASTERWORK
		Rarities.LEGENDARY:
			return UiStyle.RARITY_LEGENDARY
	return UiStyle.RARITY_UNKNOWN
