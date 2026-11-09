extends GutTest
## Item card of the Alpha (M14-06, docs/01_GDD.md §28-§29): weapon with minimum-maximum damage, speed and damage per second;
## armour with Armour and Barrier and the reduction %; Masterwork and Legendary pieces; refinement cost with the Dust.
## Real data.

var _session: GameSession


func before_each() -> void:
	_session = TestFactory.session(1234, TestFactory.real_data())


func after_each() -> void:
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func _plain(lines: PackedStringArray) -> String:
	var text: String = "\n".join(lines)
	var tags: RegEx = RegEx.create_from_string("\\[/?(color|b)[^\\]]*\\]")
	return tags.sub(text, "", true)


func test_weapon_shows_range_speed_and_dps_from_weapon_math() -> void:
	var uid: int = TestFactory.give_piece(_session, &"emberbronze_sword", &"rare")
	var inst: ItemInstance = _session.armory.get_instance(uid)
	var span: Vector2 = WeaponMath.damage_range(inst, _session.data)
	var pct: float = _session.modifiers.total(&"attack_interval_pct")
	var text: String = _plain(ArmoryTexts.card_top_lines(_session, uid))
	assert_string_contains(text, "Danno: %s - %s" % [NumberFormat.format_number(snappedf(span.x, 0.1)),
			NumberFormat.format_number(snappedf(span.y, 0.1))])
	assert_string_contains(text, "Danno al secondo: %s" % NumberFormat.format_number(
			snappedf(WeaponMath.dps(inst, pct, _session.data), 0.1)))
	var interval: int = CombatMath.attack_interval_ms(
			_session.data.item(inst.base_id).equip.weapon.attack_interval_ms, pct, _session.data)
	assert_string_contains(text, "un attacco ogni %s s" % NumberFormat.format_number(interval / 1000.0))


func test_masterwork_weapon_shows_a_higher_range_than_the_same_base_rolled_common() -> void:
	var common_uid: int = TestFactory.give_piece(_session, &"mw_sword_1", &"masterwork")
	var span: Vector2 = WeaponMath.damage_range(_session.armory.get_instance(common_uid), _session.data)
	var weapon: WeaponInfo = _session.data.item(&"mw_sword_1").equip.weapon
	assert_gt(span.y, float(weapon.dmg_max) - 0.0001, "the Masterwork multiplier never lowers the maximum")


func test_armour_piece_shows_armour_reduction_from_armor_math() -> void:
	var uid: int = TestFactory.give_piece(_session, &"emberbronze_cuirass")
	var armor: int = int(_session.armory.instance_modifiers(uid).filter(
			func(m: Modifier) -> bool: return m.stat == &"armor").map(func(m: Modifier) -> float: return m.value).reduce(
			func(a: float, b: float) -> float: return a + b, 0.0))
	assert_gt(armor, 0)
	var expected: float = ArmorMath.reduction_pct(armor, _session.character.get_level(), _session.data)
	var text: String = _plain(ArmoryTexts.card_top_lines(_session, uid))
	assert_string_contains(text, "Armatura +%d" % armor)
	assert_string_contains(text, "riduce il danno fisico del %s%%" % NumberFormat.format_number(snappedf(expected, 0.1)))
	assert_false(text.contains("Barriera: riduce"), "plate has no Barrier")


func test_cloth_piece_shows_the_barrier_line() -> void:
	var uid: int = TestFactory.give_piece(_session, &"body_cloth_1")
	var text: String = _plain(ArmoryTexts.card_top_lines(_session, uid))
	assert_string_contains(text, "Barriera +")
	assert_string_contains(text, "Barriera: riduce il danno arcano del")


func test_legendary_shows_its_effect_and_hides_the_source_until_discovered() -> void:
	var base: ItemDef = _session.data.item(&"leg_head_1")
	var uid: int = TestFactory.give_piece(_session, &"leg_head_1", &"legendary")
	assert_true(_session.discoveries.has(&"leg_head_1"), "obtained pieces are discovered")
	var text: String = _plain(ArmoryTexts.card_top_lines(_session, uid))
	assert_string_contains(text, base.description)
	assert_string_contains(text, "Fonte: Boss: %s (%s%%)" % [_session.data.boss(base.equip.legendary.source_id).name,
			GuideDrops.pct_text(base.equip.legendary.chance_pct)])


func test_legendary_source_is_hidden_when_not_discovered() -> void:
	var base: ItemDef = _session.data.item(&"leg_head_1")
	var lines: PackedStringArray = ArmoryTexts.legendary_lines(_session, base)
	assert_false(_session.discoveries.has(&"leg_head_1"))
	assert_eq(lines.size(), 1, "the effect only: no source for a piece never obtained")
	assert_eq(lines[0], base.description)


func test_pieces_are_named_with_the_color_of_their_rarity() -> void:
	var uid: int = TestFactory.give_piece(_session, &"mw_sword_1", &"masterwork")
	var tip: String = ArmoryTexts.tooltip_text(_session, uid)
	assert_string_contains(tip, RarityColors.color(&"masterwork").to_html(false))
	assert_string_contains(tip, "Capolavoro")


func test_refine_cost_uses_the_material_grade_and_the_dust_line() -> void:
	var uid: int = TestFactory.give_piece(_session, &"emberbronze_sword")
	var inst: ItemInstance = _session.armory.get_instance(uid)
	var info: Dictionary = RefineTexts.refine_info(_session, uid)
	var cost: Dictionary = Upgrade.cost(inst.upgrade, Upgrade.material_grade(inst, _session.data), _session.data)
	var lines: PackedStringArray = info["cost_lines"]
	assert_eq(lines.size() > 0, true)
	assert_eq(lines.has("%s: %s (ne hai %s)" % [_session.data.item(cost["ingot"]).name,
			NumberFormat.format_int(int(cost["ingots"])), NumberFormat.format_int(_session.bank.get_count(cost["ingot"]))]),
			int(cost["ingots"]) > 0)


func test_refine_cost_shows_the_dust_when_the_step_needs_it() -> void:
	var uid: int = TestFactory.give_piece(_session, &"emberbronze_sword")
	var levels: Array = _session.data.balance_value("upgrade.levels") as Array
	var step: int = -1
	for index: int in levels.size():
		if int((levels[index] as Dictionary).get("dust", 0)) > 0:
			step = index
			break
	assert_gt(step, 0, "the data have a step with Dust")
	var saved: Dictionary = _session.armory.to_save()
	for entry: Dictionary in saved["items"]:
		if int(entry["uid"]) == uid:
			entry["upgrade"] = step
	_session.armory.from_save(saved)
	var cost: Dictionary = Upgrade.cost(step, Upgrade.material_grade(_session.armory.get_instance(uid), _session.data), _session.data)
	var expected: String = "%s: %s (ne hai %s)" % [_session.data.item(Upgrade.DUST_ITEM).name,
			NumberFormat.format_int(int(cost["dust"])), NumberFormat.format_int(_session.bank.get_count(Upgrade.DUST_ITEM))]
	assert_true((RefineTexts.refine_info(_session, uid)["cost_lines"] as PackedStringArray).has(expected), expected)
