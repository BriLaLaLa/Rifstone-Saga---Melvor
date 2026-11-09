class_name EngraverSections
extends RefCounted
## Presentation grouping of the Engraver page (docs/05_INTERFACES.md §7.w): the recipes of `riftbinding` in sections by
## kind of action (`ActionDef.kind` and the id prefix), plus the texts of the crystallization cards. Reads the data only.

const SKILL: StringName = &"riftbinding"
const SECTION_SLAB: StringName = &"slab"
const SECTION_MERGE: StringName = &"merge"
const SECTION_CRYSTALS: StringName = &"crystals"
const SECTION_ENGRAVE: StringName = &"engrave"
const SECTION_UPGRADE: StringName = &"upgrade"
## Sections in the order they are drawn, with their titles.
const SECTIONS: Array[StringName] = [SECTION_SLAB, SECTION_MERGE, SECTION_CRYSTALS, SECTION_ENGRAVE, SECTION_UPGRADE]
const TITLES: Dictionary[StringName, String] = {
	SECTION_SLAB: "Lastra",
	SECTION_MERGE: "Fondere",
	SECTION_CRYSTALS: "Cristalli",
	SECTION_ENGRAVE: "Incidere",
	SECTION_UPGRADE: "Potenziare",
}
const PREFIXES: Dictionary[String, StringName] = {
	"make_": SECTION_SLAB,
	"fuse_": SECTION_MERGE,
	"engrave_": SECTION_ENGRAVE,
	"upgrade_": SECTION_UPGRADE,
}
const CHANCE_TEXT: String = "Probabilità: %s%%"
const LOSS_TEXT: String = "Fallimento: perdi %s %s"
const SOURCE_TEXT: String = "Da: %s"
const SECTION_NODE: String = "Section_%s"

static var _index: GuideIndex = null
static var _index_data: GameData = null


## The section of an action of the Engraver; crystallizations by kind, the others by the prefix of the id.
static func section_of(action: ActionDef) -> StringName:
	if action.kind == &"crystallize":
		return SECTION_CRYSTALS
	for prefix: String in PREFIXES:
		if String(action.id).begins_with(prefix):
			return PREFIXES[prefix]
	return SECTION_UPGRADE


static func title_of(section: StringName) -> String:
	return TITLES.get(section, String(section))


## "Probabilità: N%" at the current Engraver level (EngraverResolver, F-104).
static func chance_text(session: GameSession, action: ActionDef) -> String:
	var chance: float = EngraverResolver.crystal_chance_pct(session.skills.get_level(action.skill_id), session.data)
	return CHANCE_TEXT % NumberFormat.format_number(chance)


## "Fallimento: perdi M <ingredient>" (F-104): the loss of the first ingredient (the Dust).
static func loss_text(session: GameSession, action: ActionDef) -> String:
	var input: ItemQty = action.inputs[0]
	var item: ItemDef = session.data.item(input.item_id)
	return LOSS_TEXT % [NumberFormat.format_int(EngraverResolver.fail_loss(input.qty, session.data)),
			item.name if item != null else String(input.item_id)]


## "Da: <sources>" of an ingredient, from the Guide index and only if the item is discovered (F-124); empty otherwise.
static func source_text(item_id: StringName, data: GameData, discoveries: Object) -> String:
	if _index == null or _index_data != data:
		_index = GuideIndex.new(data)
		_index_data = data
	var summary: String = _index.summary_line(_index.sources_visible(item_id, discoveries), 3)
	return SOURCE_TEXT % summary if not summary.is_empty() else ""


## The flow container of the section of `action` inside `parent`: a heading and a flow, made the first time (in the
## order the actions come, which is the order of `SECTIONS` in the data) and remembered in `flows`.
static func flow_for(parent: Container, flows: Dictionary[StringName, HFlowContainer], action: ActionDef) -> HFlowContainer:
	var section: StringName = section_of(action)
	if not flows.has(section):
		var heading: Label = Label.new()
		heading.name = SECTION_NODE % section
		heading.text = title_of(section)
		heading.theme_type_variation = &"HeaderLabel"
		parent.add_child(heading)
		var flow: HFlowContainer = HFlowContainer.new()
		flow.name = "Flow_%s" % section
		parent.add_child(flow)
		flows[section] = flow
	return flows[section]


## Sub-tabs of the Engraver page (docs/01_GDD.md §29): the id of each tab, its label and the sections it shows.
const TAB_SLAB: StringName = &"slabs"
const TAB_MERGE: StringName = &"merge"
const TAB_CRYSTALS: StringName = &"crystals"
const TAB_RUNES: StringName = &"runes"
const TABS: Array[Dictionary] = [
	{"id": TAB_SLAB, "label": "Lastre", "sections": [SECTION_SLAB]},
	{"id": TAB_MERGE, "label": "Fondere", "sections": [SECTION_MERGE]},
	{"id": TAB_CRYSTALS, "label": "Cristalli", "sections": [SECTION_CRYSTALS]},
	{"id": TAB_RUNES, "label": "Rune", "sections": [SECTION_ENGRAVE, SECTION_UPGRADE]},
]


## The tab that shows `section`.
static func tab_of(section: StringName) -> StringName:
	for tab: Dictionary in TABS:
		if (tab["sections"] as Array).has(section):
			return tab["id"]
	return &""


## Shows only the sections of `tab_id`: headings and flows of `parent` (the heading of a tab with one section is hidden,
## the tab label already says it).
static func show_tab(parent: Container, tab_id: StringName) -> void:
	var shown: Array = []
	for tab: Dictionary in TABS:
		if tab["id"] == tab_id:
			shown = tab["sections"]
	for section: StringName in SECTIONS:
		var visible_now: bool = shown.has(section)
		var heading: Node = parent.find_child(SECTION_NODE % section, false, false)
		var flow: Node = parent.find_child("Flow_%s" % section, false, false)
		if heading != null:
			(heading as Control).visible = visible_now and shown.size() > 1
		if flow != null:
			(flow as Control).visible = visible_now
