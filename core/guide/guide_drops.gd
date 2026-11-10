class_name GuideDrops
extends RefCounted
## F-124 (docs/02_FORMULAS.md, 05_INTERFACES.md §5.24): everything a monster, an area, a Monolith, a boss or an action
## can give, with the base percentage, for the Guide ("wiki a scoperta"). Also the sources of the drop pool (F-121) and
## of the legendaries (F-120) that `GuideIndex` merges into its "Si ottiene da". Read-only logic over `GameData`; the
## UI blocks the entries whose item is not in `Discoveries`.

const LOG_CATEGORY: String = "guide"
const SHARD_ITEM: StringName = &"rift_shard"
const DUST_ITEM: StringName = &"rift_dust"
const LABEL_POOL: String = "Mostri di %s"
const KIND_MONSTER: StringName = &"monster"
const KIND_AREA: StringName = &"area"
const KIND_STONE: StringName = &"rift_stone"
const KIND_BOSS: StringName = &"boss"
const KIND_ACTION: StringName = &"action"
const FRACTURE_GRADES: int = 10  # grades of the Cards (F-110); the bosses are looked up by grade

var _data: GameData
var _tables: Dictionary = {}  # monster level -> EquipmentPool.table


func _init(data: GameData) -> void:
	_data = data


## `kind` &"monster" / &"area" / &"rift_stone" / &"boss" / &"action"; everything it can give, the item with its chance
## (`GuideRef.item`, `GuideRef.chance_pct`, -1 when it does not apply), without repeating an item. Unknown id: error and [].
func drops_of(kind: StringName, id: StringName) -> Array[GuideRef]:
	var refs: Array[GuideRef] = []
	if not _is_known(kind, id):
		Log.error(LOG_CATEGORY, "guide drops: unknown %s '%s'" % [kind, id])
		return refs
	match kind:
		KIND_MONSTER:
			_monster_refs(refs, _data.monster(id), _area_of_monster(id))
		KIND_AREA:
			_area_refs(refs, _data.area(id))
		KIND_STONE:
			_stone_refs(refs, _data.rift_stone(id))
		KIND_BOSS:
			_boss_refs(refs, id)
		KIND_ACTION:
			_action_refs(refs, _data.action(id))
	return refs


## Pool pieces and blueprints by area (the best chance among its monsters) and legendaries by boss or Monolith:
## [{"item": id, "ref": GuideRef}] to merge into the sources of the items.
func extra_sources() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for area: AreaDef in _data.areas():
		var best: Dictionary = _best_pool(area)
		for item_id: StringName in best:
			var pct: float = best[item_id]
			result.append({"item": item_id, "ref": GuideRef.make(GuideRef.KIND_POOL, GuideIndex.entry(&"area", area.id),
					LABEL_POOL % area.name, "%s, %s%%" % [area.name, pct_text(pct)], item_id, pct)})
	for def: ItemDef in _data.legendaries():
		result.append({"item": def.id, "ref": _legendary_ref(def.id, def.equip.legendary)})
	return result


## Percentage text with up to four decimals and no trailing zeros (0.0208 stays 0.0208, 2.5 is 2.5, 8 is 8).
static func pct_text(value: float) -> String:
	var text: String = String.num(snappedf(value, 0.0001), 4)
	if text.contains("."):
		text = text.rstrip("0").rstrip(".")
	return text


func _is_known(kind: StringName, id: StringName) -> bool:
	match kind:
		KIND_MONSTER: return _data.has_monster(id)
		KIND_AREA: return _data.has_area(id)
		KIND_STONE: return _data.has_rift_stone(id)
		KIND_ACTION: return _data.has_action(id)
		KIND_BOSS: return _boss_def(id) != null
	return false


func _area_of_monster(monster_id: StringName) -> AreaDef:
	for area: AreaDef in _data.areas():
		if area.monster_ids.has(monster_id):
			return area
	return null


func _table(level: int) -> Dictionary:
	if not _tables.has(level):
		_tables[level] = EquipmentPool.table(level, _data)
	return _tables[level]


func _best_pool(area: AreaDef) -> Dictionary:
	var best: Dictionary = {}
	for monster_id: StringName in area.monster_ids:
		var table: Dictionary = _table(EquipmentPool.monster_level(_data.monster(monster_id)))
		for item_id: StringName in table:
			best[item_id] = maxf(float(best.get(item_id, 0.0)), float(table[item_id]))
	return best


# --- entries ---

func _put(refs: Array[GuideRef], kind: StringName, item_id: StringName, chance: float) -> void:
	if not _data.has_item(item_id):
		return
	for known: GuideRef in refs:
		if known.item == item_id:
			if chance > known.chance_pct:
				known.chance_pct = chance
				known.detail = _detail(chance)
			return
	refs.append(GuideRef.make(kind, GuideIndex.entry(&"item", item_id), _data.item(item_id).name, _detail(chance), item_id,
			chance))


func _detail(chance: float) -> String:
	return "%s%%" % pct_text(chance) if chance >= 0.0 else ""


func _drops(refs: Array[GuideRef], kind: StringName, drops: Array[DropEntry]) -> void:
	for drop: DropEntry in drops:
		_put(refs, kind, drop.item_id, drop.chance_pct)


func _tables_of(refs: Array[GuideRef], kind: StringName, table_ids: Array[StringName]) -> void:
	for table_id: StringName in table_ids:
		for table: LootTableDef in _data.loot_tables():
			if table.id == table_id:
				_drops(refs, kind, table.entries)


func _monster_refs(refs: Array[GuideRef], monster: MonsterDef, area: AreaDef) -> void:
	_drops(refs, KIND_MONSTER, monster.drops)
	if area != null:
		_tables_of(refs, KIND_MONSTER, area.loot_tables)
	_tables_of(refs, KIND_MONSTER, monster.loot_tables)
	if monster.rift_shard_chance > 0.0:
		_put(refs, KIND_MONSTER, SHARD_ITEM, monster.rift_shard_chance)
	var table: Dictionary = _table(EquipmentPool.monster_level(monster))
	for item_id: StringName in table:
		_put(refs, GuideRef.KIND_POOL, item_id, table[item_id])


func _area_refs(refs: Array[GuideRef], area: AreaDef) -> void:
	for monster_id: StringName in area.monster_ids:
		_monster_refs(refs, _data.monster(monster_id), area)


func _stone_refs(refs: Array[GuideRef], stone: RiftStoneDef) -> void:
	_drops(refs, KIND_STONE, stone.drops)
	_tables_of(refs, KIND_STONE, stone.loot_tables)
	if stone.shards_max > 0:
		_put(refs, KIND_STONE, SHARD_ITEM, -1.0)
	_legendaries(refs, LegendaryInfo.SOURCE_MONOLITH, stone.area_id)  # M15: a Monolith source is the area id


func _boss_def(id: StringName) -> BossDef:
	for grade: int in range(1, FRACTURE_GRADES + 1):
		var boss: BossDef = _data.boss_for_grade(grade)
		if boss != null and boss.id == id:
			return boss
	return null


func _boss_refs(refs: Array[GuideRef], id: StringName) -> void:
	var boss: BossDef = _boss_def(id)
	_drops(refs, KIND_BOSS, boss.drops)
	_tables_of(refs, KIND_BOSS, boss.loot_tables)
	_put(refs, KIND_BOSS, DUST_ITEM, 100.0)
	_legendaries(refs, LegendaryInfo.SOURCE_BOSS, id)


func _legendaries(refs: Array[GuideRef], source_type: StringName, source_id: StringName) -> void:
	var kind: StringName = KIND_BOSS if source_type == LegendaryInfo.SOURCE_BOSS else KIND_STONE
	for def: ItemDef in _data.legendaries_from(source_type, source_id):
		_put(refs, kind, def.id, def.equip.legendary.chance_pct)


func _action_refs(refs: Array[GuideRef], action: ActionDef) -> void:
	for output: ItemQty in action.outputs:
		_put(refs, KIND_ACTION, output.item_id, -1.0)
	for milestone: MilestoneDef in action.milestones:
		if milestone.type == MilestoneDef.TYPE_BYPRODUCT:
			_put(refs, KIND_ACTION, milestone.item, -1.0)


func _legendary_ref(item_id: StringName, info: LegendaryInfo) -> GuideRef:
	var pct: String = pct_text(info.chance_pct)
	if info.source_type == LegendaryInfo.SOURCE_BOSS:
		var boss: BossDef = _boss_def(info.source_id)
		return GuideRef.make(GuideRef.KIND_BOSS, GuideIndex.entry(&"page", &"guide_fractures"),
				boss.name if boss != null else String(info.source_id), "Boss, %s%%" % pct, item_id, info.chance_pct)
	# M15: the source of a Monolith legendary is an area id (any Monolith of that area)
	var area: AreaDef = _data.area(info.source_id) if _data.has_area(info.source_id) else null
	var target: StringName = GuideIndex.entry(&"area", area.id) if area != null else &""
	return GuideRef.make(GuideRef.KIND_RIFT_STONE, target, area.name if area != null else String(info.source_id),
			"Monolito, %s%%" % pct, item_id, info.chance_pct)


# --- discoveries (F-124): `discoveries` is anything with `has(item_id) -> bool` (the `Discoveries` of the session) ---

const LOCKED_NAME: String = "???"


## `drops_of` with the lock state: `[{"ref": GuideRef, "item": id, "unlocked": bool, "name": String, "chance_pct": float}]`.
## A locked entry shows `???` and no percentage; an unlocked one its name and the base percentage of the data.
func drops_view(kind: StringName, id: StringName, discoveries: Object) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for ref: GuideRef in drops_of(kind, id):
		var unlocked: bool = is_unlocked(ref.item, discoveries)
		result.append({"ref": ref, "item": ref.item, "unlocked": unlocked,
				"name": _data.item(ref.item).name if unlocked else LOCKED_NAME,
				"chance_pct": ref.chance_pct if unlocked else -1.0})
	return result


## True when the item was obtained at least once (its page and its source are open).
static func is_unlocked(item_id: StringName, discoveries: Object) -> bool:
	return discoveries != null and bool(discoveries.call("has", item_id))
