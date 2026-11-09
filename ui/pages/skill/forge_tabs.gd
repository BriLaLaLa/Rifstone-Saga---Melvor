class_name ForgeTabs
extends RefCounted
## Sub-tabs of the Forging page (docs/01_GDD.md §29): Lingotti, Piastre, Progetti, Banco del fabbro. Presentation only:
## which tab shows an action of the data (by the prefix of its id, like the Engraver sections) and the labels.

const SKILL: StringName = BlueprintCraft.SKILL
const TAB_INGOTS: StringName = &"ingots"
const TAB_PLATES: StringName = &"plates"
const TAB_BLUEPRINTS: StringName = &"blueprints"
const TAB_BENCH: StringName = &"bench"
const TABS: Array[Dictionary] = [
	{"id": TAB_INGOTS, "label": "Lingotti"},
	{"id": TAB_PLATES, "label": "Piastre"},
	{"id": TAB_BLUEPRINTS, "label": "Progetti"},
	{"id": TAB_BENCH, "label": "Banco del fabbro"},
]
const INGOT_PREFIX: String = "smelt_"


## The tab of the recipe card of `action`: smelting is "Lingotti", every other recipe is "Piastre".
static func tab_of(action: ActionDef) -> StringName:
	return TAB_INGOTS if String(action.id).begins_with(INGOT_PREFIX) else TAB_PLATES
