extends GutTest
## Acceptance of M14 (docs/07_TASKS.md M14-10, ALPHA.md §10), end to end on the real data through the public API
## (docs/05_INTERFACES.md §5.24): weapons with a damage range and dps, armour with Armour and Barrier, 15 grades, the
## Masterwork only from blueprints, at least 3 legendaries per slot with an effect and a source, the Guide that opens with
## the discoveries (no "Si ottiene da" in the tooltips), the mastery that shows its next bonus.

const SEED: int = 2468
const SOURCE_LINE: String = "Si ottiene da"
const WEAPON_SLOT: StringName = &"weapon"
const PIECE_SLOTS: Array[StringName] = [&"head", &"body", &"legs", &"feet", &"hands", &"neck", &"ring", &"weapon", &"offhand"]
const TOOL_SLOTS: Array[StringName] = [&"tool_forestry", &"tool_quarrying", &"tool_angling"]

var _data: GameData = null


func before_all() -> void:
	_data = TestFactory.real_data()


func _session() -> GameSession:
	return autofree(TestFactory.session(SEED, _data))


# --- weapons: minimum-maximum damage and damage per second ---------------------------------------------------------

func test_every_weapon_has_a_damage_range_and_a_dps() -> void:
	var count: int = 0
	for def: ItemDef in _data.items():
		if def.equip == null or def.equip.weapon == null:
			continue
		count += 1
		var weapon: WeaponInfo = def.equip.weapon
		assert_gt(weapon.dmg_min, 0, "%s dmg_min" % def.id)
		assert_gt(weapon.dmg_max, weapon.dmg_min - 1, "%s dmg_max >= dmg_min" % def.id)
		assert_gt(weapon.attack_interval_ms, 0, "%s interval" % def.id)
	assert_gt(count, 30, "a weapon for each of the 15 grades, two kinds, and the extra ones")


func test_weapon_range_and_dps_follow_the_rarity_multiplier() -> void:
	var s: GameSession = _session()
	var common: ItemInstance = s.armory.get_instance(TestFactory.give_piece(s, &"emberbronze_sword"))
	var weapon: WeaponInfo = _data.item(&"emberbronze_sword").equip.weapon
	assert_eq(WeaponMath.damage_range(common, _data), Vector2(float(weapon.dmg_min), float(weapon.dmg_max)))
	var base_dps: float = WeaponMath.dps(common, 0.0, _data)
	assert_almost_eq(base_dps, float(weapon.dmg_min + weapon.dmg_max) / 2.0 / (float(weapon.attack_interval_ms) / 1000.0), 0.001)
	var rare: ItemInstance = s.armory.get_instance(TestFactory.give_piece(s, &"emberbronze_sword", &"rare", 10))
	assert_almost_eq(WeaponMath.damage_range(rare, _data).y, WeaponMath.damage_range(common, _data).y * Rarities.base_mult(&"rare", _data), 0.001)
	assert_gt(WeaponMath.dps(common, -10.0, _data), base_dps, "a faster weapon deals more per second")


# --- armour: Armour and Barrier -------------------------------------------------------------------------------------

func test_materials_split_armour_and_barrier() -> void:
	var plate: Dictionary = _mods(EquipmentPool.base_for(&"body", &"plate", 5, _data))
	var leather: Dictionary = _mods(EquipmentPool.base_for(&"body", &"leather", 5, _data))
	var cloth: Dictionary = _mods(EquipmentPool.base_for(&"body", &"cloth", 5, _data))
	assert_gt(plate.get(&"armor", 0.0), leather.get(&"armor", 0.0), "plate: the most Armour")
	assert_gt(leather.get(&"armor", 0.0), cloth.get(&"armor", 0.0))
	assert_gt(cloth.get(&"barrier", 0.0), leather.get(&"barrier", 0.0), "cloth: the most Barrier")
	assert_gt(leather.get(&"barrier", 0.0), plate.get(&"barrier", 0.0))
	assert_true(_data.stats.has(&"armor") and _data.stats.has(&"barrier"))
	assert_false(_data.stats.has(&"damage_reduction"), "the player's damage_reduction is replaced by Armour")


func test_worn_armour_reduces_damage_by_a_capped_percentage() -> void:
	var s: GameSession = _session()
	TestFactory.set_character_level(s, 90)
	for slot: StringName in [&"head", &"body", &"legs", &"feet", &"hands"]:
		var base: StringName = EquipmentPool.base_for(slot, &"plate", 10, _data)
		assert_ne(base, &"", "plate %s grade 10" % slot)
		assert_true(s.equipment.equip(TestFactory.give_piece(s, base)).ok, "wear %s" % base)
	var armor: int = int(floor(s.modifiers.total(&"armor")))
	assert_gt(armor, 0)
	var cap: float = float(_data.balance_value("combat.armor.cap_pct"))
	var low: float = ArmorMath.reduction_pct(armor, 10, _data)
	var high: float = ArmorMath.reduction_pct(armor, 90, _data)
	assert_between(low, 0.0, cap)
	assert_between(high, 0.0, cap)
	assert_gt(low, high, "the same Armour protects less against a stronger attacker")
	assert_lt(ArmorMath.reduction_pct(armor * 1000, 10, _data), cap + 0.0001, "the cap holds")
	var stats: CombatantStats = CombatantStats.for_player(s, 0)
	assert_eq(stats.armor, armor, "the combat number is the floored total")


func _mods(base_id: StringName) -> Dictionary:
	var result: Dictionary = {}
	assert_ne(base_id, &"", "base exists")
	for m: Modifier in _data.item(base_id).equip.modifiers:
		result[m.stat] = result.get(m.stat, 0.0) + m.value
	return result


# --- 15 grades per slot ---------------------------------------------------------------------------------------------

func test_fifteen_grades_for_every_type_and_material() -> void:
	assert_eq((_data.balance_value("equipment.grade_levels") as Array).size(), 15)
	for kind: StringName in EquipmentPool.kinds(_data):
		var materials: Array[StringName] = EquipmentPool.materials_of(kind, _data)
		if materials.is_empty():
			materials = [&""]
		for material: StringName in materials:
			for grade: int in range(1, 16):
				assert_ne(EquipmentPool.base_for(kind, material, grade, _data), &"", "%s %s grade %d" % [kind, material, grade])


# --- the Masterwork only from blueprints ----------------------------------------------------------------------------

func test_no_drop_source_gives_a_masterwork_or_a_legendary_by_chance() -> void:
	var rng: RngService = RngService.new(SEED)
	for level: int in [1, 30, 60, 90]:
		for _i: int in 3000:
			var base_id: StringName = EquipmentDrop.roll(level, _data, rng)
			if base_id == &"":
				continue
			var equip: EquipInfo = _data.item(base_id).equip
			assert_false(equip.masterwork or equip.legendary != null, "%s is a plain base" % base_id)
	var tables: Array[Array] = []
	for area: AreaDef in _data.areas():
		for monster_id: StringName in area.monster_ids:
			tables.append(_data.monster(monster_id).drops)
	for table: LootTableDef in _data.loot_tables():
		tables.append(table.entries)
	for entries: Array in tables:
		for entry: DropEntry in entries:
			var def: ItemDef = _data.item(entry.item_id)
			assert_false(def.equip != null and (def.equip.masterwork or def.equip.legendary != null), "%s is in a drop table" % def.id)
	var rolled: Dictionary = {}
	for _i: int in 5000:
		rolled[ItemRoller.roll_rarity(ItemRoller.drop_chances(&"monster", 0.0, _data), rng)] = true
		rolled[ItemRoller.roll_rarity(ItemRoller.drop_chances(&"monster", 500.0, _data), rng)] = true
	assert_false(rolled.has(Rarities.MASTERWORK) or rolled.has(Rarities.LEGENDARY), "rarity rolls give common, magic or rare")


func test_a_blueprint_crafts_one_masterwork_with_one_or_two_affixes() -> void:
	var s: GameSession = _session()
	var blueprint: ItemDef = _data.blueprints()[0]
	for def: ItemDef in _data.blueprints():
		if def.blueprint.grade < blueprint.blueprint.grade:
			blueprint = def
	assert_gt(blueprint.blueprint.rare_components.size(), 1, "two rare components (Y-rule)")
	TestFactory.make_roomy(s)
	TestFactory.set_level(s, &"forging", BlueprintCraft.required_level(blueprint, _data))
	TestFactory.give(s, blueprint.id, 1)
	for entry: ItemQty in BlueprintCraft.inputs(blueprint):
		TestFactory.give(s, entry.item_id, entry.qty)
	var before: int = s.armory.instances().size()
	assert_true(s.actions.start_blueprint(blueprint.id).ok)
	s.actions.advance(BlueprintCraft.duration_ms(blueprint, 0.0, _data) + 1000)
	var pieces: Array[ItemInstance] = s.armory.instances()
	assert_eq(pieces.size(), before + 1, "exactly one piece")
	var made: ItemInstance = pieces[pieces.size() - 1]
	assert_eq(made.base_id, blueprint.blueprint.base_id)
	assert_eq(made.rarity, Rarities.MASTERWORK)
	assert_between(made.affixes.size(), 1, 2)
	assert_eq(s.bank.get_count(blueprint.id), 0, "the blueprint is spent")
	for entry: ItemQty in BlueprintCraft.inputs(blueprint):
		assert_eq(s.bank.get_count(entry.item_id), 0, "%s is spent" % entry.item_id)


# --- at least 3 legendaries per slot, each with an effect and a source ---------------------------------------------------

func test_three_legendaries_for_every_slot_with_effect_and_source() -> void:
	var per_slot: Dictionary = {}
	for def: ItemDef in _data.legendaries():
		var slot: StringName = EquipmentPool.kind_of(def) if def.equip.slot not in TOOL_SLOTS else def.equip.slot
		per_slot[slot] = per_slot.get(slot, 0) + 1
		var info: LegendaryInfo = def.equip.legendary
		assert_false(info.effects.is_empty(), "%s has an effect" % def.id)
		for effect: ItemEffectDef in info.effects:
			assert_not_null(EffectSet.create_typed(def.id, effect.type, effect.params), "%s: effect %s exists" % [def.id, effect.type])
		assert_gt(info.chance_pct, 0.0, "%s has a drop chance" % def.id)
		if info.source_type == LegendaryInfo.SOURCE_BOSS:
			assert_not_null(_data.boss(info.source_id), "%s: the boss exists" % def.id)
		else:
			assert_eq(info.source_type, LegendaryInfo.SOURCE_MONOLITH)
			assert_true(_data.has_rift_stone(info.source_id), "%s: the Monolith exists" % def.id)
	for kind: StringName in EquipmentPool.kinds(_data):
		assert_gte(per_slot.get(kind, 0), 3, "3 legendaries of type %s" % kind)
	for slot: StringName in TOOL_SLOTS:
		assert_gte(per_slot.get(slot, 0), 3, "3 legendary tools for %s" % slot)


func test_the_source_of_a_legendary_is_in_the_guide_once_discovered() -> void:
	var s: GameSession = _session()
	var guide := GuideIndex.new(_data)
	var legendary: ItemDef = _data.legendaries()[0]
	assert_eq(guide.sources_visible(legendary.id, s.discoveries).size(), 0, "hidden before the first one drops")
	var declared: Array[GuideRef] = guide.sources_of(legendary.id)
	assert_gt(declared.size(), 0, "the data declares the source")
	s.discoveries.note(legendary.id)
	assert_eq(guide.sources_visible(legendary.id, s.discoveries).size(), declared.size())


# --- the Guide opens with the discoveries ---------------------------------------------------------------------------------

func test_drops_are_locked_until_found_and_tooltips_have_no_source_line() -> void:
	var s: GameSession = _session()
	var guide := GuideIndex.new(_data)
	var area: AreaDef = _data.areas()[0]
	var target: Dictionary = {}
	for row: Dictionary in guide.drops_view(&"area", area.id, s.discoveries):
		if not row["unlocked"]:
			target = row
			break
	assert_false(target.is_empty(), "a new character has locked rows")
	assert_eq(target["name"], "???")
	assert_eq(float(target["chance_pct"]), -1.0, "no percentage while locked")
	s.events.item_obtained.emit(target["item"], 1)
	assert_true(s.discoveries.has(target["item"]))
	for row: Dictionary in guide.drops_view(&"area", area.id, s.discoveries):
		if row["item"] == target["item"]:
			assert_true(row["unlocked"])
			assert_eq(row["name"], _data.item(target["item"]).name)
			assert_gte(float(row["chance_pct"]), 0.0)
	for def: ItemDef in _data.items():
		var text: String = "\n".join(ItemTooltipLines.body(def, _data)) + "\n".join(ItemTooltipLines.guide_lines(def, _data))
		assert_false(text.contains(SOURCE_LINE), "%s: no source in the tooltip" % def.id)


# --- mastery: the next bonus ----------------------------------------------------------------------------------------

func test_mastery_shows_the_bonuses_reached_and_the_next_one() -> void:
	var s: GameSession = _session()
	var action: ActionDef = _data.action(&"cut_redbirch")
	var step: int = int(_data.balance_value("mastery.step.every_levels"))
	var info: Dictionary = s.mastery.step_info(&"forestry", action.id)
	assert_eq(info["n"], 0)
	assert_eq(info["next"]["level"], step)
	assert_string_contains(info["next"]["text"], "Al livello %d:" % step)
	s.mastery.from_save({"forestry": {"actions": {action.id: _data.mastery_table().xp_for_level(step)}, "pool": 0}})
	info = s.mastery.step_info(&"forestry", action.id)
	assert_eq(info["n"], 1)
	assert_false((info["current"] as Array).is_empty())
	assert_eq(info["next"]["level"], 2 * step)
