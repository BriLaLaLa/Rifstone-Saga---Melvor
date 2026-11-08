class_name GuideEntityBlocks
extends RefCounted
## Blocks of the pages generated for each entity (item, monster, area, skill, stat, trait, ability): everything comes
## from GameData, GuideIndex and GuideTables at the moment of the call. Same block format as the hand-written pages,
## plus `{"type": "rich", "bb": <BBCode>}`.

const HEADING_SOURCES: String = "Si ottiene da"
const HEADING_USES: String = "Serve a"
const HEADING_DROPS: String = "Bottino"
const HEADING_MONSTERS: String = "Mostri"
const HEADING_ACTIONS: String = "Azioni"
const NONE_TEXT: String = "Nessuno."
const BULLET: String = "- "
const SEPARATOR: String = " - "

var _data: GameData = null
var _index: GuideIndex = null
var _nav: GuideNav = null


func _init(data: GameData, index: GuideIndex, nav: GuideNav) -> void:
	_data = data
	_index = index
	_nav = nav


## Blocks of the generated page `entry_id` (`<kind>:<id>`); empty for a kind that is not generated.
func build(entry_id: StringName) -> Array[Dictionary]:
	var text: String = String(entry_id)
	var kind: StringName = StringName(text.get_slice(":", 0))
	var id: StringName = StringName(text.substr(text.find(":") + 1))
	match kind:
		GuideNav.KIND_ITEM:
			return _item(id)
		GuideNav.KIND_MONSTER:
			return _monster(id)
		GuideNav.KIND_AREA:
			return _area(id)
		GuideNav.KIND_SKILL:
			return _skill(id)
		GuideNav.KIND_STAT:
			return _stat(id)
		GuideNav.KIND_TRAIT:
			return _trait(id)
		GuideNav.KIND_ABILITY:
			return _ability(id)
	return []


func _item(id: StringName) -> Array[Dictionary]:
	var def: ItemDef = _data.item(id)
	var blocks: Array[Dictionary] = [_plain(def.description), _plain("Valore: %s oro" % GuideIndex.num(def.value))]
	blocks.append(_heading(HEADING_SOURCES))
	blocks.append_array(_ref_lines(_index.sources_of(id)))
	blocks.append(_heading(HEADING_USES))
	blocks.append_array(_ref_lines(_index.uses_of(id)))
	return blocks


func _monster(id: StringName) -> Array[Dictionary]:
	var def: MonsterDef = _data.monster(id)
	var blocks: Array[Dictionary] = [_plain(def.description)]
	blocks.append(_plain("Punti vita: %s%sEsperienza: %s%sStile: %s%sIntervallo: %s s" % [GuideIndex.num(def.hp),
			SEPARATOR, GuideIndex.num(def.xp), SEPARATOR, def.style, SEPARATOR,
			GuideIndex.num(def.attack_interval_ms / 1000.0)]))
	var places: PackedStringArray = []
	for area: AreaDef in _data.areas():
		if area.monster_ids.has(id):
			places.append(GuideRich.link(GuideIndex.entry(GuideNav.KIND_AREA, area.id), area.name))
	if not places.is_empty():
		blocks.append(_rich("Si trova in: " + ", ".join(places)))
	blocks.append(_heading(HEADING_DROPS))
	blocks.append({"type": "table", "source": GuideTables.PREFIX_MONSTER_DROPS + String(id)})
	return blocks


func _area(id: StringName) -> Array[Dictionary]:
	var def: AreaDef = _data.area(id)
	var blocks: Array[Dictionary] = [_plain(def.description)]
	for key: StringName in def.requirements:
		blocks.append(_plain("Livello richiesto (%s): %s" % [_requirement_name(key), GuideIndex.num(def.requirements[key])]))
	blocks.append(_heading(HEADING_MONSTERS))
	blocks.append({"type": "table", "source": GuideTables.PREFIX_AREA_MONSTERS + String(id)})
	return blocks


func _skill(id: StringName) -> Array[Dictionary]:
	var def: SkillDef = _data.skill(id)
	var blocks: Array[Dictionary] = [_plain(def.description)]
	if not _data.actions_for_skill(id).is_empty():
		blocks.append(_heading(HEADING_ACTIONS))
		blocks.append({"type": "table", "source": GuideTables.PREFIX_ACTIONS + String(id)})
	return blocks


func _stat(id: StringName) -> Array[Dictionary]:
	var info: Dictionary = _data.stats.info(id)
	return [_plain(str(info.get("description", ""))),
			_plain("Minimo: %s%sMassimo: %s" % [GuideIndex.num(float(info.get("min", 0))), SEPARATOR,
					GuideIndex.num(float(info.get("max", 0)))])]


func _trait(id: StringName) -> Array[Dictionary]:
	for class_def: ClassDef in _data.classes():
		for def: TraitDef in class_def.traits:
			if def.id == id:
				return [_plain(def.description), _plain("Si sblocca al livello %s" % GuideIndex.num(def.unlock_level))]
	return []


func _ability(id: StringName) -> Array[Dictionary]:
	for class_def: ClassDef in _data.classes():
		for def: AbilityDef in class_def.abilities:
			if def.id == id:
				return [_plain(def.description), _plain("Si sblocca al livello %s%sRicarica: %s s" % [
						GuideIndex.num(def.unlock_level), SEPARATOR, GuideIndex.num(def.cooldown_ms / 1000.0)])]
	return []


func _requirement_name(key: StringName) -> String:
	if key == &"character":
		return "Personaggio"
	var skill_entry: StringName = GuideIndex.entry(GuideNav.KIND_SKILL, key)
	return _nav.title_of(skill_entry) if _nav.has_entry(skill_entry) else String(key)


func _ref_lines(refs: Array[GuideRef]) -> Array[Dictionary]:
	if refs.is_empty():
		return [_plain(NONE_TEXT)]
	var lines: Array[Dictionary] = []
	for ref: GuideRef in refs:
		var label: String = GuideRich.link(ref.target, ref.label) if _nav.has_entry(ref.target) \
				else GuideRich.escape(ref.label)
		var detail: String = (" (%s)" % GuideRich.escape(ref.detail)) if not ref.detail.is_empty() else ""
		lines.append(_rich(BULLET + label + detail))
	return lines


func _plain(text: String) -> Dictionary:
	return _rich(GuideRich.escape(text))


func _rich(bbcode: String) -> Dictionary:
	return {"type": "rich", "bb": bbcode}


func _heading(text: String) -> Dictionary:
	return {"type": "heading", "text": text}
