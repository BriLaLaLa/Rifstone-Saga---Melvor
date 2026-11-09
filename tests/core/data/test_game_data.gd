extends GutTest
## GameData on the fixtures (content: res://tests/fixtures/data, config: res://data/config): every lookup of
## 05_INTERFACES.md §4, the orderings, `balance_value`, the action icon default, and the no-fallback rules
## (unknown id -> null + error; invalid data -> no Defs, errors with the file). Invalid data sets are copies of the
## fixtures written under user://, changed one file at a time.

const FIXTURE_ROOT: String = "res://tests/fixtures/data"
const V: GDScript = preload("res://tests/core/data/test_data_validator.gd")
const PreRun := preload("res://tests/helpers/gut_pre_run.gd")

var _tmp_root: String = PreRun.test_dir("test_game_data")
var _data: GameData = null


func before_all() -> void:
	_data = GameData.load_from_dirs(FIXTURE_ROOT, V.CONFIG_ROOT)


func after_all() -> void:
	_remove_dir(_tmp_root)


func _ids(defs: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for def: Variant in defs:
		if def is SkillDef:
			result.append((def as SkillDef).id)
		elif def is ActionDef:
			result.append((def as ActionDef).id)
		elif def is MasteryNodeDef:
			result.append((def as MasteryNodeDef).id)
		elif def is ItemDef:
			result.append((def as ItemDef).id)
		elif def is ShopEntryDef:
			result.append((def as ShopEntryDef).id)
		elif def is AreaDef:
			result.append((def as AreaDef).id)
		elif def is ClassDef:
			result.append((def as ClassDef).id)
		elif def is AffixDef:
			result.append((def as AffixDef).id)
	return result


func test_fixtures_load_valid() -> void:
	assert_true(_data.is_valid())
	assert_eq(_data.errors, PackedStringArray())


func test_balance_value_reads_dotted_paths() -> void:
	assert_eq(_data.balance_value("tick_ms"), 100.0)
	assert_eq(int(_data.balance_value("combat.respawn_ms")), 1500)
	assert_eq(_data.balance_value("combat.triangle.beats.blade"), "arcana")
	assert_eq(_data.balance_value("combat.auto_eat_tiers")[0], null)


func test_balance_value_containers_are_copies() -> void:
	var slots: Dictionary = _data.balance_value("slots") as Dictionary
	slots["count"] = 99
	assert_eq(int(_data.balance_value("slots.count")), 4)


func test_balance_value_missing_key_is_null_and_error() -> void:
	assert_null(_data.balance_value("combat.no_such_key"))
	assert_push_error("balance key 'combat.no_such_key' not found")


func test_xp_tables_come_from_the_curves() -> void:
	assert_eq(_data.xp_table().max_level, 99)
	assert_eq(_data.xp_table().xp_for_level(2), 70)
	assert_eq(_data.mastery_table().max_level, 99)
	assert_eq(_data.mastery_table().xp_for_level(2), 20)


func test_stats_registry_is_built() -> void:
	assert_true(_data.stats.has(&"skill_interval_pct"))
	assert_eq(_data.stats.ids().size(), 23)


func test_item_lookup() -> void:
	var item: ItemDef = _data.item(&"test_ration")
	assert_eq(item.food_heal, 20)
	assert_true(_data.has_item(&"rift_shard"))
	assert_false(_data.has_item(&"ghost_item"))
	assert_eq(_data.items().size(), 78)  # M12-02: + 8 contracts (2 gathering skills x 4 grades); M12-03: + 2 byproducts; M12-04: + 8 (dust, crystal, chip, 5 rune grades); M13-01: + 10 Cards


func test_unknown_ids_are_null_with_error() -> void:
	assert_null(_data.item(&"ghost_item"))
	assert_null(_data.skill(&"sorcery"))
	assert_null(_data.action(&"ghost_action"))
	assert_null(_data.mastery_node(&"ghost_node"))
	assert_null(_data.area(&"ghost_area"))
	assert_null(_data.monster(&"ghost_monster"))
	assert_null(_data.shop_entry(&"ghost_entry"))
	assert_push_error(7)


func test_has_area_and_has_monster_do_not_log_errors() -> void:
	assert_true(_data.has_area(&"test_area"))
	assert_false(_data.has_area(&"ghost_area"))
	assert_true(_data.has_monster(&"test_monster_a"))
	assert_false(_data.has_monster(&"ghost_monster"))
	assert_false(_data.has_area(&""))  # an unexpected push_error would fail the test


func test_lists_are_copies() -> void:
	_data.items().clear()
	_data.skills().clear()
	assert_eq(_data.items().size(), 78)  # M12-02: + 8 contracts (2 gathering skills x 4 grades); M12-03: + 2 byproducts; M12-04: + 8
	assert_eq(_data.skills().size(), 4)


func test_skills_are_ordered_by_order() -> void:
	assert_eq(_ids(_data.skills()), [&"test_gather", &"test_gather_b", &"test_craft", &"riftbinding"] as Array[StringName])


func test_skills_by_category() -> void:
	assert_eq(_ids(_data.skills_by_category(&"gathering")), [&"test_gather", &"test_gather_b"] as Array[StringName])
	assert_eq(_ids(_data.skills_by_category(&"artisan")), [&"test_craft", &"riftbinding"] as Array[StringName])
	assert_eq(_data.skill(&"test_craft").mastery_bonuses.size(), 2)


func test_skills_by_unknown_category_is_error() -> void:
	assert_eq(_data.skills_by_category(&"farming").size(), 0)
	assert_eq(_data.skills_by_category(&"combat").size(), 0, "combat is no longer a skill category")
	assert_push_error(2)


func test_actions_are_ordered_by_level_then_id() -> void:
	assert_eq(_ids(_data.actions_for_skill(&"test_gather")),
			[&"gather_bundle", &"gather_twig", &"gather_log"] as Array[StringName])
	assert_eq(_ids(_data.actions_for_skill(&"test_gather_b")), [] as Array[StringName])


func test_mastery_actions_exclude_mastery_false() -> void:
	assert_eq(_ids(_data.mastery_actions_for_skill(&"test_gather")),
			[&"gather_twig", &"gather_log"] as Array[StringName])


func test_actions_of_unknown_skill_is_error() -> void:
	assert_eq(_data.actions_for_skill(&"sorcery").size(), 0)
	assert_push_error("unknown skill 'sorcery'")


func test_action_skill_comes_from_the_file() -> void:
	var craft: ActionDef = _data.action(&"craft_plank")
	assert_eq(craft.skill_id, &"test_craft")
	assert_true(craft.is_artisan())
	assert_eq(craft.inputs[0].item_id, &"test_log")


func test_action_icon_defaults_to_the_first_output() -> void:
	assert_eq(_data.action(&"gather_twig").icon, _data.item(&"test_twig").icon)
	assert_eq(_data.action(&"gather_log").icon, "res://assets/icons/items/test_log_action.png")


func test_mastery_nodes() -> void:
	assert_eq(_ids(_data.mastery_nodes(&"test_gather")),
			[&"test_gather_n1", &"test_gather_n2", &"test_gather_n3"] as Array[StringName])
	assert_eq(_data.mastery_nodes(&"test_craft").size(), 0)
	var node: MasteryNodeDef = _data.mastery_node(&"test_gather_n1")
	assert_eq(node.skill_id, &"test_gather")
	assert_eq(node.modifiers[0].scope_kind, Modifier.SCOPE_SKILL)
	assert_eq(node.modifiers[0].scope_id, &"test_gather")
	assert_eq(_data.mastery_node(&"test_gather_n3").requires,
			[&"test_gather_n1", &"test_gather_n2"] as Array[StringName])


func test_areas_and_monsters() -> void:
	assert_eq(_ids(_data.areas()), [&"test_area", &"test_stone_area", &"test_loot_area", &"cracked_mines", &"rift_threshold"] as Array[StringName])
	var area: AreaDef = _data.area(&"test_area")
	assert_eq(area.monster_ids, [&"test_monster_a", &"test_monster_b"] as Array[StringName])
	assert_eq(area.packs.size(), 2)
	assert_eq(area.packs[0].weight, 3)
	assert_eq(area.packs[1].monster_ids, [&"test_monster_a", &"test_monster_b"] as Array[StringName])
	var monster: MonsterDef = _data.monster(&"test_monster_b")
	assert_eq(monster.xp, 200)
	assert_eq(monster.gold_min, 5)
	assert_eq(monster.gold_max, 12)
	assert_eq(monster.drops.size(), 2)


func test_shop_entries_in_file_order() -> void:
	assert_eq(_ids(_data.shop_entries()),
			[&"test_pocket", &"test_upgrade_1", &"test_upgrade_2", &"test_buy_hatchet",
					&"test_buy_log", &"auto_eat_1"] as Array[StringName])
	assert_eq(_data.shop_entry(&"test_buy_hatchet").effect_item.item_id, &"test_blade")



# --- M4: character, classes, affixes -----------------------------------------------------------------------------

func test_character_xp_table_comes_from_character_curve() -> void:
	assert_not_null(_data.character_xp_table())
	assert_eq(_data.character_xp_table().level_for_xp(1236), 10, "F-71 example, same curve values as xp_curve")


func test_classes_are_ordered_by_order() -> void:
	assert_eq(_ids(_data.classes()), [&"test_class", &"rift_blade"] as Array[StringName])
	var def: ClassDef = _data.character_class(&"test_class")
	assert_eq(def.setups.size(), 4)
	assert_eq(def.setup_for(&"sword", &"sword").id, &"dual_swords")


func test_start_class_exists() -> void:
	var start: StringName = StringName(_data.balance_value("character.start_class") as String)
	assert_not_null(_data.character_class(start))


func test_unknown_class_and_affix_are_null_with_error() -> void:
	assert_null(_data.character_class(&"ghost"))
	assert_null(_data.affix(&"ghost"))
	assert_push_error(2)


func test_affixes_for_slot_keep_the_file_order() -> void:
	assert_eq(_ids(_data.affixes_for_slot(&"weapon")), [&"test_keen", &"test_mighty"] as Array[StringName])
	assert_eq(_ids(_data.affixes_for_slot(&"head")), [&"test_mighty", &"test_nimble"] as Array[StringName])
	assert_eq(_ids(_data.affixes_for_slot(&"tool_forestry")), [&"test_woodsman"] as Array[StringName])
	assert_eq(_data.affixes_for_slot(&"ring").size(), 0)
	assert_eq(_data.affix(&"test_mighty").tiers[1].step, 2.0)


func test_item_kind_and_grade() -> void:
	assert_eq(_data.item(&"test_greatsword").equip.kind, &"greatsword")
	assert_true(_data.item(&"test_greatsword").equip.weapon.two_handed)
	assert_eq(_data.item(&"test_shield").equip.kind, &"shield")
	assert_eq(_data.item(&"test_helm_high").equip.grade, 2)
	assert_eq(_data.item(&"test_helm_high").equip.requirements, {&"character": 10} as Dictionary[StringName, int])


func test_shop_character_requirement() -> void:
	assert_eq(_data.shop_entry(&"test_upgrade_2").req_character, 20)
	assert_eq(_data.shop_entry(&"test_pocket").req_character, 0)

# --- invalid data ------------------------------------------------------------------------------------------------

func test_invalid_data_has_errors_and_no_defs() -> void:
	var root: String = _copy_fixtures()
	_rewrite(root.path_join("items/misc.json"), "rift_shard", "rift_dust")
	var data: GameData = GameData.load_from_dirs(root, V.CONFIG_ROOT)
	assert_false(data.is_valid())
	assert_string_contains("\n".join(data.errors), "required item 'rift_shard'")
	assert_eq(data.items().size(), 0)
	assert_null(data.xp_table())
	assert_null(data.item(&"test_twig"))
	assert_push_error("unknown item 'test_twig'")


func test_broken_json_file_is_reported_with_its_path() -> void:
	var root: String = _copy_fixtures()
	var path: String = root.path_join("shop/shop.json")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{\"entries\": [")
	file.close()
	var data: GameData = GameData.load_from_dirs(root, V.CONFIG_ROOT)
	assert_false(data.is_valid())
	assert_string_contains("\n".join(data.errors), path)


func test_missing_content_folder_is_reported() -> void:
	var root: String = _copy_fixtures()
	_remove_dir(root.path_join("mastery"))
	var data: GameData = GameData.load_from_dirs(root, V.CONFIG_ROOT)
	assert_false(data.is_valid())
	assert_string_contains("\n".join(data.errors), root.path_join("mastery") + ": folder not found")


func test_data_registry_reload_matches_validity() -> void:
	var ok: bool = DataRegistry.reload()
	assert_not_null(DataRegistry.data)
	assert_eq(ok, DataRegistry.data.is_valid())
	if not ok:
		assert_push_error("game data not valid")


func test_doc_in_a_level_map_is_skipped_by_the_defs() -> void:
	var root: String = _copy_fixtures()
	_rewrite(root.path_join("combat/areas.json"), "\"requirements\": {}", "\"requirements\": {\"_doc\": \"none\"}")
	var data: GameData = GameData.load_from_dirs(root, V.CONFIG_ROOT)
	assert_true(data.is_valid(), "; ".join(data.errors))
	assert_eq(data.area(&"test_area").requirements, {} as Dictionary[StringName, int])


# --- helpers -----------------------------------------------------------------------------------------------------

func _copy_fixtures() -> String:
	_remove_dir(_tmp_root)
	_copy_dir(FIXTURE_ROOT, _tmp_root)
	return _tmp_root


func _rewrite(path: String, from: String, to: String) -> void:
	var text: String = FileAccess.get_file_as_string(path).replace(from, to)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _copy_dir(from: String, to: String) -> void:
	DirAccess.make_dir_recursive_absolute(to)
	for name: String in DirAccess.get_files_at(from):
		if name.get_extension() == "json":
			DirAccess.copy_absolute(from.path_join(name), to.path_join(name))
	for name: String in DirAccess.get_directories_at(from):
		_copy_dir(from.path_join(name), to.path_join(name))


func _remove_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for name: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(name))
	for name: String in DirAccess.get_directories_at(path):
		_remove_dir(path.path_join(name))
	DirAccess.remove_absolute(path)
