extends GutTest
## KillRewards (F-32, F-84): drops of pieces become instances in the Armory with the rarity of F-84 and the affixes of
## F-85; the other items go to the loot bag. Fixed seeds through RngService.

const BLADE: StringName = &"test_blade"
const LOG_ITEM: StringName = &"test_log"

var _session: GameSession = null


func before_each() -> void:
	_session = autofree(TestFactory.session(99))


func _drop(item: StringName, chance: float, qty_min: int, qty_max: int) -> Array[DropEntry]:
	var entry := DropEntry.new()
	entry.item_id = item
	entry.chance_pct = chance
	entry.qty_min = qty_min
	entry.qty_max = qty_max
	var list: Array[DropEntry] = [entry]
	return list


func test_base_xp_applies_the_level_difference() -> void:
	# F-130 with one rounding: floor(xp x kill_xp_mult x xp_level_mult(monster level - character level)).
	var mult: float = float(_session.data.balance_value("combat.kill_xp_mult"))
	TestFactory.set_character_level(_session, 10)
	var cases: Dictionary = {10: 1.0, 15: 1.25, 20: 1.5, 40: 1.5, 9: 8.0 / 9.0, 7: 2.0 / 3.0, 2: 1.0 / 9.0, 1: 0.0}
	for level: int in cases:
		assert_eq(KillRewards.base_xp(_session, 1000, level), floori(1000.0 * mult * float(cases[level]) + 1e-9), "monster level %d" % level)
	assert_eq(KillRewards.base_xp(_session, 1000), floori(1000.0 * mult + 1e-9), "no level (Fracture): multiplier 1")


func test_summoned_monster_gives_only_reduced_drops() -> void:
	# V11: the chance of each drop is scaled by combat.summon_drop_pct (25 in the data); no xp, no gold.
	var pct: float = float(_session.data.balance_value("combat.summon_drop_pct"))
	var hits: int = 0
	for _i: int in 400:
		var before: int = _session.combat.loot.used()
		KillRewards.roll_drops(_session, _session.combat.loot, _drop(LOG_ITEM, 100.0, 1, 1), ItemRoller.SOURCE_MONSTER, 1, pct / 100.0)
		hits += _session.combat.loot.used() - before
		_session.combat.loot.collect_all()
	assert_between(hits, 70, 130, "about 25% of 400")
	var def: MonsterDef = _session.data.monster(&"test_monster_a")
	var xp: int = _session.character.get_xp()
	var gold: int = _session.wallet.get_gold()
	KillRewards.grant_summoned(_session, _session.combat.loot, def, &"")
	assert_eq(_session.character.get_xp(), xp, "no xp")
	assert_eq(_session.wallet.get_gold(), gold, "no gold")


func test_piece_drop_creates_instances_in_the_armory() -> void:
	KillRewards.roll_drops(_session, _session.combat.loot, _drop(BLADE, 100.0, 2, 2), ItemRoller.SOURCE_MONSTER, 7)
	_session.combat.loot.collect_all()
	var pieces: Array[ItemInstance] = _session.armory.instances()
	assert_eq(pieces.size(), 2, "qty 2 -> two instances")
	assert_ne(pieces[0].uid, pieces[1].uid)
	for inst: ItemInstance in pieces:
		assert_eq(inst.base_id, BLADE)
		assert_eq(inst.ilvl, 7)
	assert_eq(_session.combat.loot.used(), 0, "pieces never go to the loot bag")


func test_chance_zero_never_drops_and_plain_items_go_to_the_bag() -> void:
	for i: int in 50:
		KillRewards.roll_drops(_session, _session.combat.loot, _drop(BLADE, 0.0, 1, 1), ItemRoller.SOURCE_MONSTER, 1)
	assert_eq(_session.armory.used(), 0)
	KillRewards.roll_drops(_session, _session.combat.loot, _drop(LOG_ITEM, 100.0, 3, 3), ItemRoller.SOURCE_MONSTER, 1)
	assert_eq(_session.combat.loot.items(), [{"item": LOG_ITEM, "qty": 3}])


func test_rarity_distribution_follows_f84() -> void:
	var counts: Dictionary = {&"common": 0, &"magic": 0, &"rare": 0}
	var base: ItemDef = _session.data.item(BLADE)
	for i: int in 3000:
		var inst: ItemInstance = KillRewards.roll_piece(_session, base, ItemRoller.SOURCE_MONSTER, 10)
		counts[inst.rarity] += 1
	assert_between(counts[&"magic"] / 3000.0, 0.22, 0.28, "25% magic (M14: rarity.drop 25 and 5)")
	assert_between(counts[&"rare"] / 3000.0, 0.035, 0.065, "5% rare")


func test_item_rarity_pct_raises_the_drop_chances() -> void:
	_session.modifiers.set_source(&"test:rarity", [Modifier.make(&"item_rarity_pct", 1000.0)])
	var base: ItemDef = _session.data.item(BLADE)
	var rare: int = 0
	for i: int in 1000:
		if KillRewards.roll_piece(_session, base, ItemRoller.SOURCE_MONSTER, 10).rarity == &"rare":
			rare += 1
	assert_between(rare / 1000.0, 0.49, 0.61, "+1000%% -> k 11 -> 55%% rare")


func test_drop_below_the_filter_is_salvaged_at_once() -> void:
	assert_true(_session.armory.set_filter(&"weapon", &"rare", 1).ok)
	watch_signals(_session.events)
	KillRewards.roll_drops(_session, _session.combat.loot, _drop(BLADE, 100.0, 1, 1), ItemRoller.SOURCE_MONSTER, 1)
	_session.combat.loot.collect_all()
	var inst_count: int = _session.armory.used()
	if inst_count == 0:
		assert_signal_emitted(_session.events, "item_salvaged")
	else:
		assert_eq(_session.armory.instances()[0].rarity, &"rare", "only a rare passes the filter")


func test_same_seed_same_drops() -> void:
	var other: GameSession = autofree(TestFactory.session(99))
	for s: GameSession in [_session, other]:
		for i: int in 10:
			KillRewards.roll_drops(s, s.combat.loot, _drop(BLADE, 100.0, 1, 1), ItemRoller.SOURCE_MONSTER, 20)
			s.combat.loot.collect_all()
	var a: Array[ItemInstance] = _session.armory.instances()
	var b: Array[ItemInstance] = other.armory.instances()
	assert_eq(a.size(), b.size())
	for i: int in a.size():
		assert_eq(a[i].to_dict(), b[i].to_dict())


func test_monster_ilvl_is_the_highest_combat_level() -> void:
	var def := MonsterDef.new()
	def.attack_level = 3
	def.power_level = 9
	def.defence_level = 5
	assert_eq(KillRewards.monster_ilvl(def), 9)
