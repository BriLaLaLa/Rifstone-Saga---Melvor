extends GutTest
## GuideTables (docs/05_INTERFACES.md §5.19): every declared source on the real data, the numbers against the data,
## `page_ids` (one page per item, monster, area, skill, stat, trait and ability) and the unknown-source error.

const REAL_ROOT: String = "res://data"
const CONFIG_ROOT: String = "res://data/config"

var _data: GameData = null


func before_all() -> void:
	_data = GameData.load_from_dirs(REAL_ROOT, CONFIG_ROOT)


func test_ids_are_declared_and_all_build() -> void:
	assert_gt(GuideTables.ids().size(), 0)
	for id: String in GuideTables.ids():
		var rows: Array[Array] = GuideTables.build(id, _data)
		assert_gt(rows.size(), 1, "table %s has a header and rows" % id)
		for row: Array in rows:
			assert_eq(row.size(), rows[0].size(), "table %s: equal columns" % id)


func test_refine_costs_follow_balance() -> void:
	var rows: Array[Array] = GuideTables.build("refine_costs", _data)
	var levels: Array = _data.balance_value("upgrade.levels") as Array
	assert_eq(rows.size(), levels.size() + 1)
	assert_eq(rows[1][0], "+1")
	assert_eq(rows[1][1], GuideIndex.num(float((levels[0] as Dictionary)["success_pct"])))
	assert_eq(rows[levels.size()][4], GuideIndex.num(float((levels[levels.size() - 1] as Dictionary)["shards"])))


func test_tool_upgrades_follow_balance() -> void:
	var rows: Array[Array] = GuideTables.build("tool_upgrades", _data)
	var levels: Array = _data.balance_value("tool_upgrade.levels") as Array
	assert_eq(rows.size(), levels.size() + 1)
	assert_eq(rows[1][4], GuideIndex.num(float((levels[0] as Dictionary)["gold"])))


func test_affix_tiers_follow_the_affixes() -> void:
	var rows: Array[Array] = GuideTables.build("affix_tiers", _data)
	var tier_count: int = 0
	var seen: Dictionary[StringName, bool] = {}
	for item: ItemDef in _data.items():
		if item.is_equippable():
			for affix: AffixDef in _data.affixes_for_slot(item.equip.slot):
				if not seen.has(affix.id):
					seen[affix.id] = true
					tier_count += affix.tiers.size()
	assert_eq(rows.size(), tier_count + 1)


func test_traits_and_abilities_follow_the_class() -> void:
	var class_def: ClassDef = _data.classes()[0]
	var traits: Array[Array] = GuideTables.build("traits", _data)
	assert_eq(traits.size(), class_def.traits.size() + 1)
	assert_eq(traits[1][0], class_def.traits[0].name)
	assert_eq(traits[1][1], str(class_def.traits[0].unlock_level))
	var abilities: Array[Array] = GuideTables.build("abilities", _data)
	assert_eq(abilities.size(), class_def.abilities.size() + 1)
	assert_eq(abilities[1][2], GuideIndex.num(class_def.abilities[0].cooldown_ms / 1000.0))


func test_action_table_of_a_skill() -> void:
	var rows: Array[Array] = GuideTables.build("actions:forging", _data)
	var actions: Array[ActionDef] = _data.actions_for_skill(&"forging")
	assert_eq(rows.size(), actions.size() + 1)
	assert_eq(rows[1][0], actions[0].name)
	assert_eq(rows[1][1], str(actions[0].level))
	assert_eq(rows[1][3], GuideIndex.num(actions[0].interval_ms / 1000.0))


func test_every_skill_has_an_action_table() -> void:
	for skill: SkillDef in _data.skills():
		if not _data.actions_for_skill(skill.id).is_empty():
			assert_gt(GuideTables.build(PREFIX_ACTIONS + String(skill.id), _data).size(), 1, String(skill.id))


const PREFIX_ACTIONS: String = "actions:"


func test_area_and_monster_tables() -> void:
	var area: AreaDef = _data.areas()[0]
	var monsters: Array[Array] = GuideTables.build("area_monsters:%s" % area.id, _data)
	assert_eq(monsters.size(), area.monster_ids.size() + 1)
	var monster: MonsterDef = _data.monster(area.monster_ids[0])
	assert_eq(monsters[1][1], str(monster.hp))
	var drops: Array[Array] = GuideTables.build("monster_drops:%s" % monster.id, _data)
	assert_eq(drops.size(), monster.drops.size() + 1)
	assert_eq(drops[1][1], GuideIndex.num(monster.drops[0].chance_pct))


func test_stats_table_has_every_stat() -> void:
	assert_eq(GuideTables.build("stats", _data).size(), _data.stats.ids().size() + 1)


func test_page_ids_cover_every_entity() -> void:
	var pages: Array[StringName] = GuideTables.page_ids(_data)
	for item: ItemDef in _data.items():
		assert_true(pages.has(GuideIndex.entry(&"item", item.id)), "item " + String(item.id))
	for area: AreaDef in _data.areas():
		assert_true(pages.has(GuideIndex.entry(&"area", area.id)))
		for monster_id: StringName in area.monster_ids:
			assert_true(pages.has(GuideIndex.entry(&"monster", monster_id)))
	for skill: SkillDef in _data.skills():
		assert_true(pages.has(GuideIndex.entry(&"skill", skill.id)))
	for stat_id: StringName in _data.stats.ids():
		assert_true(pages.has(GuideIndex.entry(&"stat", stat_id)))
	for class_def: ClassDef in _data.classes():
		for trait_def: TraitDef in class_def.traits:
			assert_true(pages.has(GuideIndex.entry(&"trait", trait_def.id)))
		for ability: AbilityDef in class_def.abilities:
			assert_true(pages.has(GuideIndex.entry(&"ability", ability.id)))


func test_page_ids_are_unique() -> void:
	var pages: Array[StringName] = GuideTables.page_ids(_data)
	var seen: Dictionary[StringName, bool] = {}
	for id: StringName in pages:
		assert_false(seen.has(id), "duplicate page %s" % id)
		seen[id] = true


func test_unknown_source_gives_empty_table_and_error() -> void:
	assert_eq(GuideTables.build("no_such_table", _data).size(), 0)
	assert_eq(GuideTables.build("actions:no_such_skill", _data).size(), 0)
	assert_eq(GuideTables.build("area_monsters:nowhere", _data).size(), 0)
	assert_push_error(3)
