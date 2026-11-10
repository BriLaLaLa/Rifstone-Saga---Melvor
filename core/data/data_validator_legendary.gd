class_name DataValidatorLegendary
extends RefCounted
## Part of DataValidator (internal, not API for other modules): the `equip.masterwork` and `equip.legendary` rules of M14
## (docs/04_DATA_SCHEMA.md §21, F-119, F-120). The effects of F-81 are delegated to DataValidatorTraits.

const SOURCE_TYPES: PackedStringArray = ["boss", "monolith"]
const GATHER_TYPES: PackedStringArray = ["gather_bonus_item", "gather_grade_up_pct", "byproduct_mult"]
const RING_NECK_TYPES: PackedStringArray = ["monolith_loot_mult", "card_drop_mult"]
const F120_TYPES: PackedStringArray = ["block_heal_pct", "kill_heal_pct", "armor_pierce_pct", "hit_cap_pct",
	"stat_convert", "double_hit_pct", "execute_mult", "monolith_loot_mult", "gather_bonus_item", "gather_grade_up_pct",
	"byproduct_mult", "card_drop_mult"]
const RING_NECK_SLOTS: PackedStringArray = ["ring", "neck"]
const BOSS_LEGENDARIES_MAX: int = 5
const MULT_MAX: float = 10.0  # format limit of `mult`
const ARMOUR_MATERIAL: String = "plate"
const TOOL_SLOT_PREFIX: String = "tool_"


## `masterwork` and `legendary` of one `equip` object (`category` is the category of its item `e`).
static func validate_equip(v: DataValidatorRules, e: Dictionary, equip: Dictionary, category: String, slot: String) -> void:
	if equip.has("masterwork"):
		v.flag(equip, "masterwork", "equip")
		if equip.get("masterwork") == true:
			if category == "tool" or equip.has("legendary"):
				v.fail("field 'equip.masterwork': a Masterwork is a piece, not a tool or a legendary")
			if DataValidatorM14.ARMOUR_SLOTS.has(slot) and equip.get("material") != ARMOUR_MATERIAL:
				v.fail("field 'equip.masterwork': armour Masterworks are only of material '%s' (Q75)" % ARMOUR_MATERIAL)
	if not equip.has("legendary"):
		return
	var legendary: Dictionary = v.object(equip, "legendary", "equip")
	if not equip.get("legendary") is Dictionary:
		return
	v.keys(legendary, ["source", "effects"], "equip.legendary")
	_source(v, legendary)
	if DataValidatorRules.is_int(e.get("value")) and int(e["value"]) < 1:
		v.fail("a legendary must have 'value' >= 1 (it can be sold)")
	var is_tool_slot: bool = slot.begins_with(TOOL_SLOT_PREFIX)
	if is_tool_slot:
		if equip.get("unique") == true:
			v.fail("field 'equip.unique': a legendary tool is not a unique tool")
		if equip.has("upgrade_extras"):
			v.fail("field 'equip.upgrade_extras': a legendary tool has no refinement")
	var effects: Array[Dictionary] = v.object_list(legendary, "effects", "equip.legendary", 1)
	for index: int in effects.size():
		_effect(v, effects[index], "equip.legendary.effects[%d]" % index, slot, is_tool_slot)


static func _source(v: DataValidatorRules, legendary: Dictionary) -> void:
	var source: Dictionary = v.object(legendary, "source", "equip.legendary")
	if not legendary.get("source") is Dictionary:
		return
	v.keys(source, ["type", "id", "chance_pct"], "equip.legendary.source")
	v.one_of(source, "type", SOURCE_TYPES, "equip.legendary.source")
	v.text(source, "id", "equip.legendary.source")
	v.number(source, "chance_pct", 0.0, 100.0, "equip.legendary.source", true)


# One effect `{"type", ...params}` (flat); the F-81 types go through DataValidatorTraits (`{"type", "params"}` shape).
static func _effect(v: DataValidatorRules, effect: Dictionary, prefix: String, slot: String, is_tool_slot: bool) -> void:
	if not v.text(effect, "type", prefix):
		return
	var type: String = effect["type"] as String
	_placement(v, type, prefix, slot, is_tool_slot)
	if not F120_TYPES.has(type):
		var params: Dictionary = effect.duplicate()
		params.erase("type")
		DataValidatorTraits.validate_effect(v, {"type": type, "params": params}, prefix)
		return
	match type:
		"block_heal_pct", "kill_heal_pct", "armor_pierce_pct", "double_hit_pct", "gather_grade_up_pct":
			v.keys(effect, ["type", "pct"], prefix)
			v.number(effect, "pct", 0.0, 100.0, prefix, true)
		"hit_cap_pct":
			v.keys(effect, ["type", "pct"], prefix)
			v.number(effect, "pct", 1.0, 100.0, prefix)
		"stat_convert":
			v.keys(effect, ["type", "from", "to", "pct"], prefix)
			v.number(effect, "pct", 0.0, 100.0, prefix, true)
			_convert_stats(v, effect, prefix)
		"execute_mult":
			v.keys(effect, ["type", "hp_pct", "mult"], prefix)
			v.number(effect, "hp_pct", 0.0, 100.0, prefix, true)
			v.number(effect, "mult", 1.0, MULT_MAX, prefix, true)
		"monolith_loot_mult", "card_drop_mult", "byproduct_mult":
			v.keys(effect, ["type", "mult"], prefix)
			v.number(effect, "mult", 1.0, MULT_MAX, prefix, true)
		"gather_bonus_item":
			v.keys(effect, ["type", "items", "pct"], prefix)
			v.number(effect, "pct", 0.0, 100.0, prefix, true)
			v.id_list(effect, "items", v.items, "item", 1, prefix)


# Gathering types only on tools, the others only on pieces; the loot types only on rings and amulets.
static func _placement(v: DataValidatorRules, type: String, prefix: String, slot: String, is_tool_slot: bool) -> void:
	if GATHER_TYPES.has(type) != is_tool_slot:
		v.fail("field '%s.type': '%s' %s" % [prefix, type, "needs a tool slot" if GATHER_TYPES.has(type)
				else "is not allowed on a tool"])
	elif RING_NECK_TYPES.has(type) and not RING_NECK_SLOTS.has(slot):
		v.fail("field '%s.type': '%s' is only for a ring or an amulet" % [prefix, type])


static func _convert_stats(v: DataValidatorRules, effect: Dictionary, prefix: String) -> void:
	for key: String in ["from", "to"]:
		if not v.text(effect, key, prefix):
			continue
		if not v.stats.has(StringName(effect[key] as String)):
			v.fail("field '%s.%s': stat '%s' is not in stats.json" % [prefix, key, effect[key]])
		elif not DataValidatorTraits.STAT_TRADE_STATS.has(effect[key]):
			v.fail("field '%s.%s': stat '%s' has no combat effect" % [prefix, key, effect[key]])
	if effect.get("from") is String and effect.get("from") == effect.get("to"):
		v.fail("field '%s': 'from' and 'to' must differ" % prefix)


## Constraints across items, after every item passed its own rules: each legendary source exists (a boss of
## `bosses.json`, a Monolith of `rift_stones.json`), a boss has at most 5 legendaries, every Masterwork base has its
## blueprint.
static func validate_sources(v: DataValidatorRules, items: Dictionary[String, Dictionary],
		bosses: Dictionary[String, Dictionary], stones: Dictionary[String, Dictionary]) -> void:
	var boss_ids: Dictionary[String, bool] = _ids(bosses, "bosses")
	var stone_ids: Dictionary[String, bool] = _ids(stones, "rift_stones", "area")  # M15: a Monolith source is an area id
	var per_boss: Dictionary[String, int] = {}
	var blueprint_bases: Dictionary[String, bool] = {}
	var masterworks: Array[String] = []
	for path: String in items:
		v.at_file(path)
		var list: Variant = items[path].get("items")
		for index: int in (list as Array).size() if list is Array else 0:
			var e: Variant = (list as Array)[index]
			if not e is Dictionary:
				continue
			v.at_entry("item", index, e as Dictionary)
			var equip: Variant = (e as Dictionary).get("equip")
			var blueprint: Variant = (e as Dictionary).get("blueprint")
			if blueprint is Dictionary and (blueprint as Dictionary).get("base") is String:
				blueprint_bases[(blueprint as Dictionary)["base"] as String] = true
			if not equip is Dictionary:
				continue
			if (equip as Dictionary).get("masterwork") == true and (e as Dictionary).get("id") is String:
				masterworks.append((e as Dictionary)["id"] as String)
			var legendary: Variant = (equip as Dictionary).get("legendary")
			if legendary is Dictionary and (legendary as Dictionary).get("source") is Dictionary:
				_check_source(v, (legendary as Dictionary)["source"] as Dictionary, boss_ids, stone_ids, per_boss)
	for boss: String in per_boss:
		if per_boss[boss] > BOSS_LEGENDARIES_MAX:
			v.fail("boss '%s' has %d legendaries, at most %d" % [boss, per_boss[boss], BOSS_LEGENDARIES_MAX])
	for base: String in masterworks:
		if not blueprint_bases.has(base):
			v.fail("item '%s' is a Masterwork but no blueprint crafts it" % base)


static func _check_source(v: DataValidatorRules, source: Dictionary, boss_ids: Dictionary[String, bool],
		stone_ids: Dictionary[String, bool], per_boss: Dictionary[String, int]) -> void:
	if not (source.get("type") is String and source.get("id") is String):
		return
	var id: String = source["id"] as String
	if source["type"] == "boss":
		per_boss[id] = per_boss.get(id, 0) + 1
		if not boss_ids.has(id):
			v.fail("field 'equip.legendary.source.id': unknown boss '%s'" % id)
	elif source["type"] == "monolith" and not stone_ids.has(id):
		v.fail("field 'equip.legendary.source.id': unknown Monolith '%s'" % id)


static func _ids(files: Dictionary[String, Dictionary], key: String, id_field: String = "id") -> Dictionary[String, bool]:
	var result: Dictionary[String, bool] = {}
	for path: String in files:
		var list: Variant = files[path].get(key)
		for e: Variant in (list as Array if list is Array else []):
			if e is Dictionary and (e as Dictionary).get(id_field) is String:
				result[(e as Dictionary)[id_field] as String] = true
	return result
