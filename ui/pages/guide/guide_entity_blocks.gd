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

const LOCKED_TITLE: String = "???"
const LOCKED_TEXT: String = "Non hai ancora trovato questo oggetto: la sua pagina si apre la prima volta che lo ottieni."
const HEADING_STONE: String = "Monolito del Rift: %s"
const DROPS_NONE_TEXT: String = "Nessun bottino."

var _data: GameData = null
var _index: GuideIndex = null
var _nav: GuideNav = null
## The `Discoveries` of the session (anything with `has(item_id)`); null = nothing discovered (everything locked).
var _discoveries: Object = null


func _init(data: GameData, index: GuideIndex, nav: GuideNav, discoveries: Object = null) -> void:
	_data = data
	_index = index
	_nav = nav
	_discoveries = discoveries


## True when `entry_id` is an item page whose item has not been obtained yet (no name, no page).
func is_locked_item(entry_id: StringName) -> bool:
	var text: String = String(entry_id)
	if not text.begins_with(String(GuideNav.KIND_ITEM) + ":"):
		return false
	return not GuideDrops.is_unlocked(StringName(text.substr(text.find(":") + 1)), _discoveries)


## What an item, monster, area or action can give, with the lock state of every entry (`GuideIndex.drops_view`).
func drops_view(kind: StringName, id: StringName) -> Array[Dictionary]:
	return _index.drops_view(kind, id, _discoveries)


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
	if not GuideDrops.is_unlocked(id, _discoveries):
		return [_plain(LOCKED_TEXT)]
	var blocks: Array[Dictionary] = [_plain(def.description), _plain("Valore: %s oro" % GuideIndex.num(def.value))]
	blocks.append(_heading(HEADING_SOURCES))
	blocks.append_array(_ref_lines(_index.sources_visible(id, _discoveries)))
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
	blocks.append(_drops_block(GuideNav.KIND_MONSTER, id))
	return blocks


func _area(id: StringName) -> Array[Dictionary]:
	var def: AreaDef = _data.area(id)
	var blocks: Array[Dictionary] = [_plain(def.description)]
	for key: StringName in def.requirements:
		blocks.append(_plain("Livello richiesto (%s): %s" % [_requirement_name(key), GuideIndex.num(def.requirements[key])]))
	blocks.append(_heading(HEADING_MONSTERS))
	blocks.append({"type": "table", "source": GuideTables.PREFIX_AREA_MONSTERS + String(id)})
	blocks.append(_heading(HEADING_DROPS))
	blocks.append(_drops_block(GuideNav.KIND_AREA, id))
	for stone: RiftStoneDef in _data.rift_stones_for_area(id):  # M15: only the compile fix; the page is reworked by the UI task
		blocks.append(_heading(HEADING_STONE % stone.name))
		blocks.append(_drops_block(GuideRef.KIND_RIFT_STONE, stone.id))
	return blocks


func _skill(id: StringName) -> Array[Dictionary]:
	var def: SkillDef = _data.skill(id)
	var blocks: Array[Dictionary] = [_plain(def.description)]
	if not _data.actions_for_skill(id).is_empty():
		blocks.append(_heading(HEADING_ACTIONS))
		blocks.append({"type": "table", "source": GuideTables.PREFIX_ACTIONS + String(id)})
		for action: ActionDef in _data.actions_for_skill(id):
			if action.inputs.is_empty() and not action.outputs.is_empty():
				blocks.append(_plain(action.name))
				blocks.append(_drops_block(GuideRef.KIND_ACTION, action.id))
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


## A list of cells with everything `kind` / `id` can give; locked cells for the items not yet obtained.
func _drops_block(kind: StringName, id: StringName) -> Dictionary:
	return {"type": "drops", "kind": kind, "id": id}


func _plain(text: String) -> Dictionary:
	return _rich(GuideRich.escape(text))


func _rich(bbcode: String) -> Dictionary:
	return {"type": "rich", "bb": bbcode}


func _heading(text: String) -> Dictionary:
	return {"type": "heading", "text": text}
