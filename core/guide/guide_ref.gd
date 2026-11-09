class_name GuideRef
extends RefCounted
## One entry of "Si ottiene da" / "Serve a" for an item (docs/05_INTERFACES.md §5.19): what it is, the page it links to
## and the text to show. Built by GuideIndex from the data; never saved.

const KIND_MONSTER: StringName = &"monster"
const KIND_RECIPE: StringName = &"recipe"
const KIND_BLUEPRINT: StringName = &"blueprint"
const KIND_SHOP: StringName = &"shop"
const KIND_RIFT_STONE: StringName = &"rift_stone"
const KIND_SALVAGE: StringName = &"salvage"
const KIND_STARTER_KIT: StringName = &"starter_kit"
const KIND_REFINE: StringName = &"refine"
const KIND_SOCKET: StringName = &"socket"
const KIND_ALTAR: StringName = &"altar"
const KIND_FOOD: StringName = &"food"
const KIND_LOOT_TABLE: StringName = &"loot_table"
const KIND_MILESTONE: StringName = &"milestone"
const KIND_BAG: StringName = &"bag"
const KIND_CONTRACT: StringName = &"contract"
const KIND_FRACTURE: StringName = &"fracture"
const KIND_POOL: StringName = &"pool"  # M14: the drop pool of equipment and blueprints (F-121), by area
const KIND_BOSS: StringName = &"boss"  # M14: a Fracture boss (legendaries, F-120)
const KIND_ACTION: StringName = &"action"  # M14: the output of a gathering or crafting action

var kind: StringName = &""
## Canonical id of the linked page (GuideIndex.entry), &"" when the entry links to no page.
var target: StringName = &""
var label: String = ""
## Optional, e.g. area and percentage; numbers always come from the data.
var detail: String = ""
## M14 (F-124): the item concerned (what `GuideIndex.drops_of` gives; the queried item in `sources_of`) and the base
## percentage 0..100 of the source, -1 when it does not apply (recipes, shop, kit).
var item: StringName = &""
var chance_pct: float = -1.0


static func make(kind_: StringName, target_: StringName, label_: String, detail_: String = "", item_: StringName = &"",
		chance_pct_: float = -1.0) -> GuideRef:
	var ref := GuideRef.new()
	ref.kind = kind_
	ref.target = target_
	ref.label = label_
	ref.detail = detail_
	ref.item = item_
	ref.chance_pct = chance_pct_
	return ref
