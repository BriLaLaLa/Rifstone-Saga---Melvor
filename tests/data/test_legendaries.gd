extends GutTest
## M14-05: the 39 legendaries of the real data (F-120, 01_GDD.md §28.5, docs/NOMI.md): 3 per slot (10 piece slots and
## the 3 tools), a declared source and effect each, statistics of the model of their slot, grade and material, every boss
## and every Monolith with its sources.

const SLOTS: Array[String] = ["sword", "greatsword", "shield", "head", "body", "legs", "feet", "hands", "ring", "neck",
	"tool_forestry", "tool_quarrying", "tool_angling"]
const BOSSES: Array[String] = ["boss_grade_1", "boss_grade_2", "boss_grade_3", "boss_grade_4", "boss_grade_5",
	"boss_grade_6", "boss_grade_7", "boss_grade_8", "boss_grade_9", "boss_grade_10"]
const MONOLITHS: Array[String] = ["redrock_stone", "whisper_stone", "mine_stone", "threshold_stone"]
## Tool modifiers per Monolith: [skill_interval_pct, double_item_chance] (NOMI.md, starting values).
const TOOL_STATS: Dictionary = {"redrock_stone": [-26.0, 3.0], "whisper_stone": [-28.0, 4.0], "mine_stone": [-30.0, 5.0],
	"threshold_stone": [-35.0, 7.0]}
const F120_TYPES: Array[StringName] = [&"block_heal_pct", &"kill_heal_pct", &"armor_pierce_pct", &"hit_cap_pct", &"stat_convert",
	&"double_hit_pct", &"execute_mult", &"monolith_loot_mult", &"gather_bonus_item", &"gather_grade_up_pct", &"byproduct_mult",
	&"card_drop_mult"]

var _data: GameData = null
var _models: Dictionary = {}
var _legendaries: Array[ItemDef] = []


func before_all() -> void:
	_data = GameData.load_from_dirs()
	_legendaries = _data.legendaries()
	for item: ItemDef in _data.items():
		if item.category == &"equipment" and not item.equip.masterwork and item.equip.legendary == null:
			_models["%s:%s:%d" % [_kind(item), String(item.equip.material), item.equip.grade]] = item


func _kind(item: ItemDef) -> String:
	if String(item.equip.slot).begins_with("tool_"):
		return String(item.equip.slot)
	return String(item.equip.kind) if item.equip.kind != &"" else String(item.equip.slot)


func _ids(path: String, key: String) -> Dictionary:
	var ids: Dictionary = {}
	for e: Dictionary in (JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary)[key]:
		ids[e["id"]] = true
	return ids


func test_39_legendaries_3_for_each_of_the_13_slots() -> void:
	assert_eq(_legendaries.size(), 39)
	var per_slot: Dictionary = {}
	for item: ItemDef in _legendaries:
		per_slot[_kind(item)] = int(per_slot.get(_kind(item), 0)) + 1
	for slot: String in SLOTS:
		assert_eq(int(per_slot.get(slot, 0)), 3, "legendaries of %s" % slot)


func test_every_legendary_has_a_valid_source_and_an_effect() -> void:
	var bosses: Dictionary = _ids("res://data/maps/bosses.json", "bosses")
	var stones: Dictionary = _ids("res://data/combat/rift_stones.json", "rift_stones")
	for item: ItemDef in _legendaries:
		var leg: LegendaryInfo = item.equip.legendary
		assert_gt(leg.effects.size(), 0, "%s has an effect" % item.id)
		assert_gte(item.value, 1, "%s can be sold" % item.id)
		assert_false(item.equip.unique, item.id)
		assert_true(FileAccess.file_exists(item.icon), item.icon)
		assert_false(item.description.is_empty(), item.id)
		if leg.source_type == LegendaryInfo.SOURCE_BOSS:
			assert_true(bosses.has(String(leg.source_id)), "%s: boss %s exists" % [item.id, leg.source_id])
			assert_eq(leg.chance_pct, 0.6, "%s: boss chance (Q76)" % item.id)
			assert_false(String(item.equip.slot).begins_with("tool_"), "%s: the tools come from the Monoliths" % item.id)
		else:
			assert_eq(leg.source_type, LegendaryInfo.SOURCE_MONOLITH, item.id)
			assert_true(stones.has(String(leg.source_id)), "%s: Monolith %s exists" % [item.id, leg.source_id])
			assert_eq(leg.chance_pct, 0.3, "%s: Monolith chance (Q76)" % item.id)
			assert_true(String(item.equip.slot).begins_with("tool_"), "%s: only tools come from the Monoliths" % item.id)


func test_every_boss_and_every_monolith_has_its_legendaries() -> void:
	for boss: String in BOSSES:
		assert_eq(_data.legendaries_from(LegendaryInfo.SOURCE_BOSS, StringName(boss)).size(), 3, boss)
	var tools: int = 0
	for stone: String in MONOLITHS:
		var from_stone: Array[ItemDef] = _data.legendaries_from(LegendaryInfo.SOURCE_MONOLITH, StringName(stone))
		assert_gte(from_stone.size(), 2, stone)
		tools += from_stone.size()
	assert_eq(tools, 9)


func test_pieces_have_the_statistics_of_the_model_of_their_slot_grade_and_material() -> void:
	for item: ItemDef in _legendaries:
		if String(item.equip.slot).begins_with("tool_"):
			continue
		var model: ItemDef = _models.get("%s:%s:%d" % [_kind(item), String(item.equip.material), item.equip.grade])
		assert_not_null(model, "model of %s" % item.id)
		if model == null:
			continue
		assert_eq(item.equip.requirements, model.equip.requirements, item.id)
		assert_eq(item.equip.modifiers.size(), model.equip.modifiers.size(), item.id)
		for i: int in mini(item.equip.modifiers.size(), model.equip.modifiers.size()):
			assert_eq(item.equip.modifiers[i].value, model.equip.modifiers[i].value, "%s %s" % [item.id, item.equip.modifiers[i].stat])
		if model.equip.weapon != null:
			assert_eq(item.equip.weapon.dmg_max, model.equip.weapon.dmg_max, item.id)


func test_legendary_grades_follow_the_boss_that_drops_them() -> void:
	# the grades of the legendaries of a boss are 10-15 of the pieces: levels 45, 50, 70, 80, 90 (NOMI.md)
	for item: ItemDef in _legendaries:
		if not String(item.equip.slot).begins_with("tool_"):
			assert_true([10, 11, 13, 14, 15].has(item.equip.grade), "%s grade %d" % [item.id, item.equip.grade])


func test_tools_replace_the_unique_tool_and_use_the_monolith_values() -> void:
	for item: ItemDef in _legendaries:
		if not String(item.equip.slot).begins_with("tool_"):
			continue
		var skill: String = String(item.equip.slot).trim_prefix("tool_")
		assert_eq(item.category, &"tool", item.id)
		assert_eq(item.equip.requirements.keys(), [StringName(skill)], "%s needs the level of its trade" % item.id)
		assert_true([10, 30, 50, 75].has(item.equip.requirements[StringName(skill)]), item.id)
		assert_eq(item.equip.upgrade_extras.size(), 0, "no refinement")
		var stats: Array = TOOL_STATS[String(item.equip.legendary.source_id)]
		var values: Dictionary = {}
		for m: Modifier in item.equip.modifiers:
			values[String(m.stat)] = m.value
			assert_eq([m.scope_kind, m.scope_id], [&"skill", StringName(skill)], item.id)
		assert_eq(values, {"skill_interval_pct": stats[0], "double_item_chance": stats[1]}, item.id)


func test_effects_are_of_the_closed_list_of_f120_and_f81() -> void:
	var seen: Dictionary = {}
	for item: ItemDef in _legendaries:
		for effect: ItemEffectDef in item.equip.legendary.effects:
			seen[effect.type] = true
			var gather: bool = [&"gather_bonus_item", &"gather_grade_up_pct", &"byproduct_mult"].has(effect.type)
			assert_eq(gather, String(item.equip.slot).begins_with("tool_"), "%s: %s" % [item.id, effect.type])
	for type: StringName in F120_TYPES:
		assert_true(seen.has(type), "a legendary uses %s" % type)


func test_effect_examples_of_nomi() -> void:
	var by_name: Dictionary = {}
	for item: ItemDef in _legendaries:
		by_name[item.name] = item.equip.legendary.effects[0]
	assert_eq(by_name["Spaccapalude"].type, &"on_kill_timer_cut")
	assert_eq(by_name["Spaccapalude"].params["pct"], 100.0)
	assert_eq(by_name["Scudo del Giuramento Spezzato"].type, &"block_heal_pct")
	assert_eq(by_name["Zanna d'Argento"].type, &"monolith_loot_mult")
	assert_eq(by_name["Zanna d'Argento"].params["mult"], 2.0)
	assert_eq(by_name["Canna del Leviatano Dormiente"].type, &"gather_grade_up_pct")
	assert_eq(by_name["Piccone del Cercatore"].type, &"gather_bonus_item")
	assert_eq((by_name["Piccone del Cercatore"].params["items"] as Array).size(), 4, "the four Shards")
	assert_eq(by_name["Calzoni del Vento Alto"].params["from"], "evasion_bonus")
	assert_eq(by_name["Calzoni del Vento Alto"].params["to"], "armor")
	assert_eq(by_name["Zoccoli del Gran Cinghiale"].params["rule"], "lowest_hp")


func test_legendaries_never_drop_from_lists() -> void:
	var ids: Dictionary = {}
	for item: ItemDef in _legendaries:
		ids[item.id] = true
	for table: LootTableDef in _data.loot_tables():
		for entry: DropEntry in table.entries:
			assert_false(ids.has(entry.item_id), "%s in %s" % [entry.item_id, table.id])
