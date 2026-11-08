class_name GuideNav
extends RefCounted
## Index of the Guide pages (docs/05_INTERFACES.md §5.19, §7.y): which entry ids exist, their title and group, and the
## accent-insensitive title search. Presentation helper: it reads GameData and keeps no game state.

const LOG_CATEGORY: String = "guide"
const KIND_PAGE := &"page"
const KIND_ITEM := &"item"
const KIND_MONSTER := &"monster"
const KIND_AREA := &"area"
const KIND_SKILL := &"skill"
const KIND_STAT := &"stat"
const KIND_TRAIT := &"trait"
const KIND_ABILITY := &"ability"
## Hand-written sections (04_DATA_SCHEMA.md §19) in index order, with their titles.
const SECTION_TITLES: Dictionary[StringName, String] = {
	&"first_steps": "Primi passi",
	&"character": "Personaggio e combattimento",
	&"loot": "Bottino",
	&"crafts": "Mestieri",
	&"altar": "Altare del Rift",
	&"offline": "Offline",
}
## Generated groups after the hand-written sections: kind -> title, in index order.
const KIND_TITLES: Dictionary[StringName, String] = {
	KIND_ITEM: "Oggetti",
	KIND_MONSTER: "Mostri",
	KIND_AREA: "Aree",
	KIND_SKILL: "Mestieri",
	KIND_TRAIT: "Tratti",
	KIND_ABILITY: "Abilità",
	KIND_STAT: "Statistiche",
}
const ACCENTS: Dictionary[String, String] = {
	"à": "a", "á": "a", "â": "a", "ä": "a", "è": "e", "é": "e", "ê": "e", "ë": "e", "ì": "i", "í": "i", "î": "i",
	"ï": "i", "ò": "o", "ó": "o", "ô": "o", "ö": "o", "ù": "u", "ú": "u", "û": "u", "ü": "u",
}

var _data: GameData = null
## Entry id -> {"title": String, "group": String}; insertion order = index order.
var _entries: Dictionary[StringName, Dictionary] = {}
var _by_name: Dictionary[String, StringName] = {}


func _init(data: GameData) -> void:
	_data = data
	_build()


## Every entry id in index order.
func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in _entries:
		result.append(id)
	return result


func has_entry(entry_id: StringName) -> bool:
	return _entries.has(entry_id)


## Title of an entry; empty if unknown.
func title_of(entry_id: StringName) -> String:
	return str(_entries[entry_id]["title"]) if _entries.has(entry_id) else ""


func group_of(entry_id: StringName) -> String:
	return str(_entries[entry_id]["group"]) if _entries.has(entry_id) else ""


## Groups in index order: [{"title": String, "ids": Array[StringName]}].
func groups() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var by_title: Dictionary[String, Dictionary] = {}
	for id: StringName in _entries:
		var title: String = group_of(id)
		if not by_title.has(title):
			by_title[title] = {"title": title, "ids": [] as Array[StringName]}
			result.append(by_title[title])
		(by_title[title]["ids"] as Array[StringName]).append(id)
	return result


## Entry whose title is exactly `name` (used to link names inside tables); `&""` if none.
func entry_by_name(name: String) -> StringName:
	return _by_name.get(name, &"")


## Entries whose title contains `query` ignoring case and accents; an empty query gives the whole index.
func search(query: String) -> Array[StringName]:
	var needle: String = normalize(query)
	var result: Array[StringName] = []
	for id: StringName in _entries:
		if needle.is_empty() or normalize(title_of(id)).contains(needle):
			result.append(id)
	return result


static func normalize(text: String) -> String:
	var result: String = text.strip_edges().to_lower()
	for accent: String in ACCENTS:
		result = result.replace(accent, ACCENTS[accent])
	return result


func _build() -> void:
	var sections: Array[StringName] = []
	sections.assign(SECTION_TITLES.keys())
	var pages: Array[GuidePageDef] = _data.guide_pages()
	for section: StringName in sections:
		for page: GuidePageDef in pages:
			if page.section == section:
				_add(GuideIndex.entry(KIND_PAGE, page.id), page.title, SECTION_TITLES[section])
	var group: String = ""
	for item: ItemDef in _data.items():
		_add(GuideIndex.entry(KIND_ITEM, item.id), item.name, KIND_TITLES[KIND_ITEM])
	group = KIND_TITLES[KIND_MONSTER]
	var seen: Dictionary[StringName, bool] = {}
	for area: AreaDef in _data.areas():
		for monster_id: StringName in area.monster_ids:
			if not seen.has(monster_id):
				seen[monster_id] = true
				_add(GuideIndex.entry(KIND_MONSTER, monster_id), _data.monster(monster_id).name, group)
	for area: AreaDef in _data.areas():
		_add(GuideIndex.entry(KIND_AREA, area.id), area.name, KIND_TITLES[KIND_AREA])
	for skill: SkillDef in _data.skills():
		_add(GuideIndex.entry(KIND_SKILL, skill.id), skill.name, KIND_TITLES[KIND_SKILL])
	for class_def: ClassDef in _data.classes():
		for trait_def: TraitDef in class_def.traits:
			_add(GuideIndex.entry(KIND_TRAIT, trait_def.id), trait_def.name, KIND_TITLES[KIND_TRAIT])
		for ability: AbilityDef in class_def.abilities:
			_add(GuideIndex.entry(KIND_ABILITY, ability.id), ability.name, KIND_TITLES[KIND_ABILITY])
	for stat_id: StringName in _data.stats.ids():
		_add(GuideIndex.entry(KIND_STAT, stat_id), str(_data.stats.info(stat_id).get("name", stat_id)),
				KIND_TITLES[KIND_STAT])


func _add(entry_id: StringName, title: String, group: String) -> void:
	_entries[entry_id] = {"title": title, "group": group}
	if not _by_name.has(title):
		_by_name[title] = entry_id
