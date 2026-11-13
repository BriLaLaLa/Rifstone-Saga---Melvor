class_name GuideIndex
extends RefCounted
## "Si ottiene da" / "Serve a" of every item (docs/05_INTERFACES.md §5.19, docs/01_GDD.md §27), built once from GameData.
## Read-only: no state of the game, no signals, never saved. Every number shown comes from the data.
##
## Sources: monster and Rift Stone drops, the drop pool and the legendaries (M14), recipes, blueprints, shop, salvage, starter kit.
## Uses: recipes, blueprints, refinement (ingots, plates, handles, seal, shards, currencies), sockets, altar, food, salvage.

const LOG_CATEGORY: String = "guide"
const SHARD_ITEM: StringName = &"rift_shard"  # same item as Upgrade.SHARD_ITEM (core must not depend on systems)
const ELLIPSIS: String = " e altro"
const SEPARATOR: String = ", "
const LABEL_STARTER_KIT: String = "Kit iniziale"
const LABEL_SALVAGE: String = "Smantellamento"
const LABEL_REFINE: String = "Raffinazione"
const LABEL_SOCKET: String = "Castone"
const LABEL_ALTAR: String = "Altare del Rift"
const LABEL_FOOD: String = "Cibo"
const LABEL_MILESTONE: String = "Traguardo di maestria"
const LABEL_BAG: String = "Slot borsa del Deposito"
const LABEL_CONTRACT: String = "Assumi un aiutante"
const PAGE_DEPOSIT: StringName = &"guide_deposit"
const PAGE_HELPERS: StringName = &"guide_helpers"
const PAGE_FRACTURES: StringName = &"guide_fractures"
const PAGE_DUNGEON: StringName = &"guide_dungeon"
const LABEL_DUNGEON_OPEN: String = "Apri il dungeon"
const LABEL_FRACTURE_SOURCE: String = "Mostri e boss delle Fratture"
const LABEL_FRACTURE_OPEN: String = "Apri una Frattura"

var _data: GameData = null
var _sources: Dictionary[StringName, Array] = {}
var _uses: Dictionary[StringName, Array] = {}
var _no_source: Array[StringName] = []
var _no_use: Array[StringName] = []
var _drops: GuideDrops = null


func _init(data: GameData) -> void:
	_data = data
	_drops = GuideDrops.new(data)
	for item: ItemDef in _data.items():
		_sources[item.id] = []
		_uses[item.id] = []
	_build_sources()
	_build_uses()
	_apply_exceptions()


## Canonical id of a generated page: `item:<id>`, `monster:<id>`, `area:<id>`, `skill:<id>`, `stat:<id>`, `trait:<id>`,
## `ability:<id>` (and `page:<id>` for the hand-written ones).
static func entry(kind: StringName, id: StringName) -> StringName:
	return StringName("%s:%s" % [kind, id])


func sources_of(item_id: StringName) -> Array[GuideRef]:
	return _refs(_sources, item_id)


## M14 (F-124): everything a monster / area / Rift Stone / boss / action can give, with the base percentage; the UI
## blocks the entries whose item is not discovered.
func drops_of(kind: StringName, id: StringName) -> Array[GuideRef]:
	return _drops.drops_of(kind, id)


## M14 (F-124): `drops_of` with the lock state of every entry (`GuideDrops.drops_view`); `discoveries` has `has(item_id)`.
func drops_view(kind: StringName, id: StringName, discoveries: Object) -> Array[Dictionary]:
	return _drops.drops_view(kind, id, discoveries)


## M14 (F-124): the sources of an item only when it is discovered; an item never obtained does not reveal its source.
func sources_visible(item_id: StringName, discoveries: Object) -> Array[GuideRef]:
	return sources_of(item_id) if GuideDrops.is_unlocked(item_id, discoveries) else ([] as Array[GuideRef])


func uses_of(item_id: StringName) -> Array[GuideRef]:
	return _refs(_uses, item_id)


## Items with no source, in data order, minus the declared exceptions (`no_source`).
func items_without_source() -> Array[StringName]:
	return _without(_sources, _no_source)


func items_without_use() -> Array[StringName]:
	return _without(_uses, _no_use)


## `a, b, c e altro`: the first `max_entries` distinct labels, then " e altro" when more entries exist.
func summary_line(refs: Array[GuideRef], max_entries: int = 3) -> String:
	var labels: PackedStringArray = []
	for ref: GuideRef in refs:
		if not labels.has(ref.label):
			labels.append(ref.label)
	var shown: PackedStringArray = labels.slice(0, max_entries)
	return SEPARATOR.join(shown) + (ELLIPSIS if labels.size() > max_entries else "")


## Formats a number without trailing zeros (25.0 -> "25", 0.5 -> "0.5").
static func num(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return str(snappedf(value, 0.01))


func _refs(table: Dictionary[StringName, Array], item_id: StringName) -> Array[GuideRef]:
	var result: Array[GuideRef] = []
	if not table.has(item_id):
		Log.error(LOG_CATEGORY, "guide index: unknown item '%s'" % item_id)
		return result
	for ref: Variant in table[item_id]:
		result.append(ref as GuideRef)
	return result


func _without(table: Dictionary[StringName, Array], exceptions: Array[StringName]) -> Array[StringName]:
	var result: Array[StringName] = []
	for item: ItemDef in _data.items():
		if table[item.id].is_empty() and not exceptions.has(item.id):
			result.append(item.id)
	return result


## The declared exceptions of GameData.guide_exceptions() (M11-02); empty until GameData has it. Overridden in tests.
func _declared_exceptions() -> Dictionary:
	if _data.has_method("guide_exceptions"):
		return _data.call("guide_exceptions") as Dictionary
	return {}


func _apply_exceptions() -> void:
	var declared: Dictionary = _declared_exceptions()
	for id: Variant in declared.get("no_source", []):
		_no_source.append(StringName(str(id)))
	for id: Variant in declared.get("no_use", []):
		_no_use.append(StringName(str(id)))


func _add(table: Dictionary[StringName, Array], item_id: StringName, ref: GuideRef) -> void:
	if not table.has(item_id):
		return  # an id the validator reports elsewhere; the index never invents items
	for known: GuideRef in table[item_id]:
		if known.kind == ref.kind and known.target == ref.target and known.label == ref.label \
				and known.detail == ref.detail:
			return
	if ref.item == &"":
		ref.item = item_id
	table[item_id].append(ref)


func _item_name(item_id: StringName) -> String:
	return _data.item(item_id).name if _data.has_item(item_id) else String(item_id)


# --- sources ---

func _build_sources() -> void:
	for area: AreaDef in _data.areas():
		for monster_id: StringName in area.monster_ids:
			_add_monster_sources(area, _data.monster(monster_id))
		for stone: RiftStoneDef in _data.rift_stones_for_area(area.id):
			_add_stone_sources(area, stone)
	for skill: SkillDef in _data.skills():
		for action: ActionDef in _data.actions_for_skill(skill.id):
			for output: ItemQty in action.outputs:
				_add(_sources, output.item_id, GuideRef.make(GuideRef.KIND_RECIPE, entry(&"skill", skill.id),
						action.name, "%s, livello %d" % [skill.name, action.level]))
			for milestone: MilestoneDef in action.milestones:
				if milestone.type == MilestoneDef.TYPE_BYPRODUCT:
					_add(_sources, milestone.item, GuideRef.make(GuideRef.KIND_MILESTONE, entry(&"skill", skill.id),
							LABEL_MILESTONE, "%s, maestria %d" % [action.name, milestone.at]))
	for def: ItemDef in _data.items():
		if def.is_equippable():
			_add_equipment_sources(def)
	for entry_def: ShopEntryDef in _data.shop_entries():
		if entry_def.effect_item != null:
			var detail: String = "%s oro" % num(entry_def.cost_gold) if entry_def.cost_gold > 0 else ""
			_add(_sources, entry_def.effect_item.item_id, GuideRef.make(GuideRef.KIND_SHOP, &"", entry_def.name, detail))
	_add_starter_kit_sources()
	for def: ItemDef in _data.items():
		if def.is_map():
			_add_card_source(def)
	for extra: Dictionary in _drops.extra_sources():  # M14: drop pool (F-121) and legendaries (F-120)
		_add(_sources, extra["item"], extra["ref"])


func _add_monster_sources(area: AreaDef, monster: MonsterDef) -> void:
	if monster == null:
		return
	for table_id: StringName in area.loot_tables:
		_add_table_sources(table_id, entry(&"monster", monster.id), monster.name, area)
	for table_id: StringName in monster.loot_tables:
		_add_table_sources(table_id, entry(&"monster", monster.id), monster.name, area)
	for drop: DropEntry in monster.drops:
		_add(_sources, drop.item_id, GuideRef.make(GuideRef.KIND_MONSTER, entry(&"monster", monster.id), monster.name,
				"%s, %s%%" % [area.name, num(drop.chance_pct)], drop.item_id, drop.chance_pct))
	if monster.rift_shard_chance > 0.0:
		_add(_sources, SHARD_ITEM, GuideRef.make(GuideRef.KIND_MONSTER, entry(&"monster", monster.id), monster.name,
				"%s, %s%%" % [area.name, num(monster.rift_shard_chance)]))


func _add_stone_sources(area: AreaDef, stone: RiftStoneDef) -> void:
	var target: StringName = entry(&"area", area.id)
	for table_id: StringName in stone.loot_tables:
		_add_table_sources(table_id, target, stone.name, area)
	for drop: DropEntry in stone.drops:
		_add(_sources, drop.item_id, GuideRef.make(GuideRef.KIND_RIFT_STONE, target, stone.name,
				"%s, %s%%" % [area.name, num(drop.chance_pct)], drop.item_id, drop.chance_pct))
	if stone.shards_max > 0:
		_add(_sources, SHARD_ITEM, GuideRef.make(GuideRef.KIND_RIFT_STONE, target, stone.name, area.name))


## The entries of a loot table, attributed to the monster (or Monolith) that rolls it.
func _add_table_sources(table_id: StringName, target: StringName, label: String, area: AreaDef) -> void:
	for table: LootTableDef in _data.loot_tables():
		if table.id != table_id:
			continue
		for drop: DropEntry in table.entries:
			_add(_sources, drop.item_id, GuideRef.make(GuideRef.KIND_LOOT_TABLE, target, label,
					"%s, %s%%" % [area.name, num(drop.chance_pct)], drop.item_id, drop.chance_pct))


## Equipment: forged from its blueprint; components of that blueprint come back from salvage (F-95).
func _add_equipment_sources(def: ItemDef) -> void:
	var blueprint: ItemDef = _data.blueprint_for_base(def.id)
	if blueprint == null:
		return
	_add(_sources, def.id, GuideRef.make(GuideRef.KIND_BLUEPRINT, entry(&"item", blueprint.id), blueprint.name))
	var ratio: float = float(_data.balance_value("salvage.component_ratio"))
	for input: ItemQty in blueprint.blueprint.inputs:
		if floori(input.qty * ratio + 1e-9) > 0:
			_add(_sources, input.item_id, GuideRef.make(GuideRef.KIND_SALVAGE, entry(&"item", def.id), def.name,
					LABEL_SALVAGE))


## A Card also falls inside the Fractures (F-113): from a run of its own grade or of up to `delta` grades below.
func _add_card_source(def: ItemDef) -> void:
	var deltas: Variant = _data.balance_value("fracture.card_drop.monster_delta")
	var span: int = maxi((deltas as Array).size() - 1, 0) if deltas is Array else 0
	var low: int = maxi(1, def.map_grade - span)
	var detail: String = "Frattura di grado %d" % low if low == def.map_grade else "Frattura di grado %d-%d" % [low, def.map_grade]
	_add(_sources, def.id, GuideRef.make(GuideRef.KIND_FRACTURE, entry(&"page", PAGE_FRACTURES), LABEL_FRACTURE_SOURCE, detail))


func _add_starter_kit_sources() -> void:
	var start: Dictionary = _data.balance_value("start") as Dictionary
	var ids: Array[StringName] = []
	for row: Variant in start.get("items", []):
		ids.append(StringName(str((row as Dictionary).get("item", ""))))
	for row: Variant in start.get("armory", []):
		ids.append(StringName(str((row as Dictionary).get("base", ""))))
	for row: Variant in start.get("tools", []):
		ids.append(StringName(str((row as Dictionary).get("base", ""))))
	for id: StringName in ids:
		_add(_sources, id, GuideRef.make(GuideRef.KIND_STARTER_KIT, &"", LABEL_STARTER_KIT))


# --- uses ---

func _build_uses() -> void:
	for skill: SkillDef in _data.skills():
		for action: ActionDef in _data.actions_for_skill(skill.id):
			for input: ItemQty in action.inputs:
				_add(_uses, input.item_id, GuideRef.make(GuideRef.KIND_RECIPE, entry(&"skill", skill.id), action.name,
						"%s, livello %d" % [skill.name, action.level]))
	for blueprint: ItemDef in _data.blueprints():
		_add_blueprint_uses(blueprint)
	_add_refine_uses()
	for def: ItemDef in _data.items():
		_add_item_kind_uses(def)


func _add_blueprint_uses(blueprint: ItemDef) -> void:
	var info: BlueprintInfo = blueprint.blueprint
	var label: String = _item_name(info.base_id)
	var inputs: Array[ItemQty] = info.inputs.duplicate()
	inputs.append_array(info.rare_components)  # M14: two rare components (one in the old blueprints)
	for input: ItemQty in inputs:
		_add(_uses, input.item_id, GuideRef.make(GuideRef.KIND_BLUEPRINT, entry(&"item", blueprint.id),
				blueprint.name))
	_add(_uses, blueprint.id, GuideRef.make(GuideRef.KIND_BLUEPRINT, entry(&"item", info.base_id), label))


## Refinement: ingots by grade, the seal, plates and handles of tool levels, shards, currencies, unique tools.
func _add_refine_uses() -> void:
	var ingots: Array = _data.balance_value("upgrade.ingot_items") as Array
	for index: int in ingots.size():
		_add(_uses, StringName(str(ingots[index])), GuideRef.make(GuideRef.KIND_REFINE, &"", LABEL_REFINE,
				"grado %d" % (index + 1)))
	_add(_uses, StringName(str(_data.balance_value("upgrade.seal_item"))),
			GuideRef.make(GuideRef.KIND_REFINE, &"", LABEL_REFINE))
	for row: Variant in _data.balance_value("upgrade.levels") as Array:
		if int((row as Dictionary).get("shards", 0)) > 0:
			_add(_uses, SHARD_ITEM, GuideRef.make(GuideRef.KIND_REFINE, &"", LABEL_REFINE))
	for key: String in ["tool_upgrade.plate_items", "tool_upgrade.handle_items"]:
		var items: Array = _data.balance_value(key) as Array
		for index: int in items.size():
			_add(_uses, StringName(str(items[index])), GuideRef.make(GuideRef.KIND_REFINE, &"", LABEL_REFINE,
					"grado %d" % (index + 1)))


func _add_item_kind_uses(def: ItemDef) -> void:
	if def.is_bag():
		_add(_uses, def.id, GuideRef.make(GuideRef.KIND_BAG, entry(&"page", PAGE_DEPOSIT), LABEL_BAG,
				"+%d caselle" % def.bag_slots))
	if def.is_map():
		_add(_uses, def.id, GuideRef.make(GuideRef.KIND_FRACTURE, entry(&"page", PAGE_FRACTURES), LABEL_FRACTURE_OPEN))
	if def.dungeon != &"":
		_add(_uses, def.id, GuideRef.make(GuideRef.KIND_DUNGEON, entry(&"page", PAGE_DUNGEON), LABEL_DUNGEON_OPEN))
	if def.is_contract():
		_add(_uses, def.id, GuideRef.make(GuideRef.KIND_CONTRACT, entry(&"page", PAGE_HELPERS), LABEL_CONTRACT))
	if def.is_currency():
		_add(_uses, def.id, GuideRef.make(GuideRef.KIND_REFINE, &"", LABEL_REFINE))
	if def.is_stone():
		_add(_uses, def.id, GuideRef.make(GuideRef.KIND_SOCKET, &"", LABEL_SOCKET))
	if def.is_infusion():
		_add(_uses, def.id, GuideRef.make(GuideRef.KIND_ALTAR, &"", LABEL_ALTAR))
	if def.is_food():
		_add(_uses, def.id, GuideRef.make(GuideRef.KIND_FOOD, &"", LABEL_FOOD, "cura %s" % num(def.food_heal)))
	if def.is_equippable():
		if def.equip.unique:
			_add(_uses, def.id, GuideRef.make(GuideRef.KIND_REFINE, &"", LABEL_REFINE))
		else:
			_add(_uses, def.id, GuideRef.make(GuideRef.KIND_SALVAGE, entry(&"item", def.id), LABEL_SALVAGE))
