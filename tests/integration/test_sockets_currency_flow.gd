extends GutTest
## Integration, piece sockets and Rift currencies (M8, F-89, GDD §26, 05 §5.17) on the real data and a real session:
## sockets from rarity and refinement, stones in and out, worn pieces that follow, the "refinement under the sockets"
## rule, currencies with a fixed seed, and save -> load -> save with Altar, sockets and currencies together.

const SEED: int = 80602
const NOW_MS: int = 1793603600000
const BLADE: StringName = &"emberbronze_sword"
const ILVL: int = 50
const SHADE: StringName = &"stone_shade_chip"  # evasion_bonus +3: no base weapon or weapon affix gives evasion
const EMBER: StringName = &"stone_ember_stone"  # power_bonus +8

var _s: GameSession = null


func before_each() -> void:
	_s = TestFactory.session_no_kit(SEED, TestFactory.real_data())


func after_each() -> void:
	if _s != null:
		_s.free()
	_s = null


func _piece(rarity: StringName, upgrade: int = 0) -> int:
	var uid: int = TestFactory.give_piece(_s, BLADE, rarity, ILVL)
	_set_upgrade(_s, uid, upgrade)
	return uid


# Test shortcut through the save format (the real path needs gold, ingots and luck); only for unworn pieces.
func _set_upgrade(s: GameSession, uid: int, upgrade: int) -> void:
	var saved: Dictionary = s.armory.to_save()
	for entry: Dictionary in saved["items"]:
		if int(entry["uid"]) == uid:
			entry["upgrade"] = upgrade
	s.armory.from_save(saved)


func _evasion() -> float:
	return _s.modifiers.total(&"evasion_bonus")


func _affix_ids(inst: ItemInstance) -> Array[String]:
	var out: Array[String] = []
	for roll: AffixRoll in inst.affixes:
		out.append("%s/%d/%s" % [roll.affix_id, roll.tier, roll.value])
	return out


func test_f89_examples_on_real_pieces() -> void:
	assert_eq(_s.armory.socket_count(_piece(&"rare", 7)), 3, "rare +7")
	assert_eq(_s.armory.socket_count(_piece(&"common", 9)), 1, "common +9")
	assert_eq(_s.armory.socket_count(_piece(&"magic", 6)), 1, "magic +6")
	assert_eq(_s.armory.socket_count(_piece(&"common", 0)), 0)
	assert_eq(_s.armory.socket_count(_piece(&"rare", 0)), 2)


func test_socket_and_clear_stone_conserve_the_object() -> void:
	var uid: int = _piece(&"rare")
	TestFactory.give(_s, SHADE, 3)
	watch_signals(_s.events)
	assert_true(_s.armory.socket_stone(uid, SHADE).ok)
	assert_eq(_s.bank.get_count(SHADE), 2, "one stone left the bank")
	assert_eq(_s.armory.get_instance(uid).sockets, [SHADE] as Array[StringName], "and sits in the piece (one place)")
	assert_signal_emitted(_s.events, "armory_changed")
	assert_true(_s.armory.socket_stone(uid, SHADE).ok)
	assert_eq(_s.armory.socket_stone(uid, SHADE).reason, Reasons.SOCKET_OCCUPIED, "2 sockets on a rare +0")
	assert_eq(_s.bank.get_count(SHADE), 1)
	assert_true(_s.armory.clear_socket(uid, 0).ok)
	assert_eq(_s.bank.get_count(SHADE), 1, "removing destroys the stone, it does not return")
	assert_eq(_s.armory.get_instance(uid).sockets.size(), 1)
	assert_eq(_s.armory.clear_socket(uid, 5).reason, Reasons.SLOT_EMPTY)
	assert_eq(_s.armory.clear_socket(9999, 0).reason, Reasons.UNKNOWN_ID)


func test_socket_refusals_change_nothing() -> void:
	var common: int = _piece(&"common")
	TestFactory.give(_s, SHADE, 1)
	assert_eq(_s.armory.socket_stone(common, SHADE).reason, Reasons.SOCKET_LOCKED, "0 sockets")
	var rare: int = _piece(&"rare")
	assert_eq(_s.armory.socket_stone(rare, &"rift_shard").reason, Reasons.NOT_EQUIPPABLE)
	assert_eq(_s.armory.socket_stone(rare, &"inf_bulwark").reason, Reasons.NOT_EQUIPPABLE)
	assert_eq(_s.armory.socket_stone(rare, &"stone_eye_heart").reason, Reasons.NOT_ENOUGH_ITEMS)
	assert_eq(_s.armory.socket_stone(9999, SHADE).reason, Reasons.UNKNOWN_ID)
	assert_eq(_s.bank.get_count(SHADE), 1)
	assert_true(_s.armory.get_instance(rare).sockets.is_empty())


func test_worn_piece_follows_socketing_and_clearing() -> void:
	var uid: int = _piece(&"rare")
	assert_true(_s.equipment.equip(uid).ok)
	var base: float = _evasion()
	var stats_before: CombatantStats = CombatantStats.for_player(_s)
	TestFactory.give(_s, SHADE, 2)
	assert_true(_s.armory.socket_stone(uid, SHADE).ok)
	assert_eq(_evasion() - base, 3.0, "the worn piece updated at once")
	assert_gt(CombatantStats.for_player(_s).evasion, stats_before.evasion, "and the combat stat")
	assert_true(_s.armory.socket_stone(uid, SHADE).ok)
	assert_eq(_evasion() - base, 6.0)
	assert_true(_s.armory.clear_socket(uid, 0).ok)
	assert_eq(_evasion() - base, 3.0)
	assert_true(_s.armory.clear_socket(uid, 0).ok)
	assert_eq(_evasion(), base)
	assert_true(_s.armory.is_worn(uid), "still worn")


func test_every_stone_changes_the_stat_it_declares() -> void:
	var uid: int = _piece(&"rare")
	assert_true(_s.equipment.equip(uid).ok)
	var stones: Array[ItemDef] = []
	for def: ItemDef in _s.data.items():
		if def.category == &"stone":
			stones.append(def)
	assert_eq(stones.size(), 12)
	var seen: Dictionary[StringName, bool] = {}
	for def: ItemDef in stones:
		var before: CombatantStats = CombatantStats.for_player(_s)
		TestFactory.give(_s, def.id, 1)
		assert_true(_s.armory.socket_stone(uid, def.id).ok, def.id)
		var after: CombatantStats = CombatantStats.for_player(_s)
		for mod: Modifier in def.stone_modifiers:
			seen[mod.stat] = true
			match mod.stat:
				&"power_bonus":
					assert_gt(after.max_hit, before.max_hit, "%s raises the max hit" % def.id)
				&"accuracy_bonus":
					assert_gt(after.accuracy, before.accuracy, "%s raises accuracy" % def.id)
				&"evasion_bonus":
					assert_gt(after.evasion, before.evasion, "%s raises evasion" % def.id)
				&"max_hp_flat":
					assert_gt(after.max_hp, before.max_hp, "%s raises max hp" % def.id)
				_:
					fail_test("stone %s uses %s, which has no check here" % [def.id, mod.stat])
		assert_true(_s.armory.clear_socket(uid, 0).ok)
	assert_eq(seen.size(), 4, "power, accuracy, evasion, max hp")
	for stat: StringName in seen:
		assert_true(_s.data.stats.has(stat), "%s is in stats.json" % stat)


func test_refinement_below_the_sockets_keeps_stones_inactive_and_reactivates() -> void:
	var uid: int = _piece(&"rare", 7)
	TestFactory.give(_s, SHADE, 3)
	for i: int in 3:
		assert_true(_s.armory.socket_stone(uid, SHADE).ok, "socket %d" % i)
	assert_true(_s.equipment.equip(uid).ok)
	var base: float = _evasion() - 9.0
	assert_eq(_evasion() - base, 9.0, "three active stones")
	# A failed refinement attempt would bring +7 back to +6: here through a loaded copy of the slot.
	var saved: Dictionary = _s.to_save(NOW_MS)
	for entry: Dictionary in saved[GameSession.MODULES_KEY]["armory"]["items"]:
		entry["upgrade"] = 6
	var low: GameSession = TestFactory.session_no_kit(SEED, TestFactory.real_data())
	assert_true(low.from_save(saved).ok)
	var low_uid: int = low.equipment.get_uid(&"weapon")
	assert_eq(low.armory.get_instance(low_uid).sockets.size(), 3, "all three stones are still in the piece")
	assert_eq(low.armory.socket_count(low_uid), 2)
	assert_eq(low.modifiers.total(&"evasion_bonus"), 6.0, "only the first two work at +6")
	assert_eq(low.armory.socket_stone(low_uid, SHADE).reason, Reasons.SOCKET_OCCUPIED, "no free socket meanwhile")
	# Back to +7: active again.
	var back: Dictionary = low.to_save(NOW_MS)
	for entry: Dictionary in back[GameSession.MODULES_KEY]["armory"]["items"]:
		entry["upgrade"] = 7
	var again: GameSession = TestFactory.session_no_kit(SEED, TestFactory.real_data())
	assert_true(again.from_save(back).ok)
	assert_eq(again.modifiers.total(&"evasion_bonus"), 9.0, "the third stone works again")
	low.free()
	again.free()


func test_currencies_on_real_pieces_with_a_fixed_seed() -> void:
	var uid: int = _piece(&"common", 7)
	var data: GameData = _s.data
	TestFactory.give(_s, &"currency_spark", 1)
	TestFactory.give(_s, &"currency_crown", 1)
	TestFactory.give(_s, &"currency_flux", 3)
	assert_eq(_s.armory.use_currency(uid, &"currency_crown").reason, Reasons.REQUIREMENT_NOT_MET, "crown needs magic")
	assert_eq(_s.armory.use_currency(uid, &"currency_flux").reason, Reasons.REQUIREMENT_NOT_MET, "flux needs magic or rare")
	assert_eq(_s.bank.get_count(&"currency_crown"), 1, "refusals spend nothing")
	assert_true(_s.armory.use_currency(uid, &"currency_spark").ok)
	var magic: ItemInstance = _s.armory.get_instance(uid)
	var m_range: Array = data.balance_value("rarity.affix_count.magic") as Array
	assert_eq(magic.rarity, &"magic")
	assert_between(magic.affixes.size(), int(m_range[0]), int(m_range[1]))
	assert_eq(magic.upgrade, 7, "refinement kept")
	assert_eq(_s.armory.socket_count(uid), 2, "magic +7: 1 + 1")
	TestFactory.give(_s, SHADE, 1)
	assert_true(_s.armory.socket_stone(uid, SHADE).ok)
	assert_true(_s.armory.use_currency(uid, &"currency_flux").ok)
	var rerolled: ItemInstance = _s.armory.get_instance(uid)
	assert_eq(rerolled.rarity, &"magic")
	assert_eq(rerolled.sockets, [SHADE] as Array[StringName], "sockets kept by reroll")
	assert_eq(rerolled.upgrade, 7)
	var kept: Array[String] = _affix_ids(rerolled)
	assert_true(_s.armory.use_currency(uid, &"currency_crown").ok)
	var rare: ItemInstance = _s.armory.get_instance(uid)
	var r_range: Array = data.balance_value("rarity.affix_count.rare") as Array
	assert_eq(rare.rarity, &"rare")
	assert_between(rare.affixes.size(), int(r_range[0]), int(r_range[1]))
	assert_eq(_affix_ids(rare).slice(0, kept.size()), kept.slice(0, mini(kept.size(), rare.affixes.size())), "to_rare keeps the existing affixes")
	assert_eq(rare.sockets, [SHADE] as Array[StringName])
	assert_eq(_s.armory.socket_count(uid), 3, "rare +7")
	assert_eq(_s.bank.get_count(&"currency_spark") + _s.bank.get_count(&"currency_crown"), 0)
	assert_eq(_s.bank.get_count(&"currency_flux"), 2)
	# Same seed, same sequence: identical outcome.
	var twin: GameSession = TestFactory.session_no_kit(SEED, TestFactory.real_data())
	var tuid: int = TestFactory.give_piece(twin, BLADE, &"common", ILVL)
	TestFactory.give(twin, &"currency_spark", 1)
	assert_true(twin.armory.use_currency(tuid, &"currency_spark").ok)
	assert_eq(_affix_ids(twin.armory.get_instance(tuid)), _affix_ids(magic), "deterministic with the same seed")
	twin.free()


func test_currency_refusals_locked_worn_unknown_and_missing() -> void:
	var uid: int = _piece(&"magic")
	TestFactory.give(_s, &"currency_flux", 1)
	assert_true(_s.armory.set_locked(uid, true).ok)
	var before: Array[String] = _affix_ids(_s.armory.get_instance(uid))
	assert_eq(_s.armory.use_currency(uid, &"currency_flux").reason, Reasons.ITEM_LOCKED)
	assert_true(_s.armory.set_locked(uid, false).ok)
	assert_true(_s.equipment.equip(uid).ok)
	assert_eq(_s.armory.use_currency(uid, &"currency_flux").reason, Reasons.ITEM_EQUIPPED)
	assert_true(_s.equipment.unequip(&"weapon").ok)
	assert_eq(_s.armory.use_currency(uid, &"rift_shard").reason, Reasons.NOT_EQUIPPABLE, "not a currency")
	assert_eq(_s.armory.use_currency(9999, &"currency_flux").reason, Reasons.UNKNOWN_ID)
	assert_true(_s.armory.use_currency(uid, &"currency_flux").ok)
	assert_eq(_s.armory.use_currency(uid, &"currency_flux").reason, Reasons.NOT_ENOUGH_ITEMS)
	assert_eq(_s.bank.get_count(&"currency_flux"), 0)
	assert_eq(_s.armory.get_instance(uid).rarity, &"magic")
	assert_gt(before.size(), 0)


func test_reroll_eventually_changes_the_affixes() -> void:
	var uid: int = _piece(&"rare")
	TestFactory.give(_s, &"currency_flux", 6)
	var seen: Dictionary = {}
	seen[str(_affix_ids(_s.armory.get_instance(uid)))] = true
	for i: int in 6:
		assert_true(_s.armory.use_currency(uid, &"currency_flux").ok)
		seen[str(_affix_ids(_s.armory.get_instance(uid)))] = true
	assert_gt(seen.size(), 1, "the draws are not constant")


func test_save_load_save_identical_with_altar_sockets_and_currencies() -> void:
	TestFactory.set_level(_s, &"riftbinding", 40)
	TestFactory.give(_s, &"inf_bulwark", 1)
	TestFactory.give(_s, &"inf_keen_edge", 1)
	assert_true(_s.rift.socket(0, &"inf_bulwark").ok)
	assert_true(_s.rift.socket(2, &"inf_keen_edge").ok)
	var worn: int = _piece(&"common", 9)
	TestFactory.give(_s, &"currency_spark", 1)
	assert_true(_s.armory.use_currency(worn, &"currency_spark").ok)
	TestFactory.give(_s, SHADE, 3)
	assert_true(_s.armory.socket_stone(worn, SHADE).ok)
	var spare: int = _piece(&"rare", 7)
	assert_true(_s.armory.socket_stone(spare, SHADE).ok)
	assert_true(_s.armory.socket_stone(spare, SHADE).ok)
	assert_true(_s.equipment.equip(worn).ok)
	var text: String = SaveCodec.encode(_s.to_save(NOW_MS))
	var copy: GameSession = TestFactory.session_no_kit(SEED + 7, TestFactory.real_data())
	assert_true(copy.from_save(SaveCodec.decode(text)).ok)
	assert_eq(SaveCodec.encode(copy.to_save(NOW_MS)), text, "save -> load -> save identical")
	assert_eq(copy.rift.get_socket(2), &"inf_keen_edge")
	assert_eq(copy.armory.get_instance(spare).sockets.size(), 2)
	assert_eq(copy.armory.get_instance(worn).rarity, &"magic")
	assert_true(copy.armory.is_worn(worn))
	for stat: StringName in [&"evasion_bonus", &"max_hp_flat", &"accuracy_pct", &"power_bonus"]:
		assert_eq(copy.modifiers.total(stat), _s.modifiers.total(stat), "%s identical after the load" % stat)
	copy.free()


func test_stat_registry_covers_every_stat_of_infusions_and_stones() -> void:
	var stats: StatRegistry = _s.data.stats
	var used: Dictionary[StringName, bool] = {}
	for def: ItemDef in _s.data.items():
		var mods: Array[Modifier] = []
		if def.category == &"infusion":
			mods = def.infusion_modifiers
		elif def.category == &"stone":
			mods = def.stone_modifiers
		for mod: Modifier in mods:
			used[mod.stat] = true
	assert_gt(used.size(), 8)
	for stat: StringName in used:
		assert_true(stats.has(stat), "%s is registered" % stat)
		var ref: String = str(stats.info(stat)["test"])
		var parts: PackedStringArray = ref.split("::")
		assert_eq(parts.size(), 2, "%s: test reference" % stat)
		if parts.size() == 2:
			var path: String = "res://" + parts[0]
			assert_true(FileAccess.file_exists(path), "%s: %s exists" % [stat, path])
			if FileAccess.file_exists(path):
				assert_true(FileAccess.get_file_as_string(path).contains("func " + parts[1]), "%s: %s defined" % [stat, ref])
